import SwiftData
import SwiftUI

/// The three equal ways to answer a prompt. One save stores all three, and
/// a mode change never clears content.
enum ResponseMode: CaseIterable, Identifiable {
    case text, sketch, voice

    var id: Self { self }

    var title: String {
        switch self {
        case .text: "Text"
        case .sketch: "Sketch"
        case .voice: "Voice"
        }
    }

    var symbol: String {
        switch self {
        case .text: "character.cursor.ibeam"
        case .sketch: "scribble.variable"
        case .voice: "mic"
        }
    }

    /// The key for ⌥⌘1, ⌥⌘2 and ⌥⌘3.
    var shortcutKey: Character {
        switch self {
        case .text: "1"
        case .sketch: "2"
        case .voice: "3"
        }
    }

    static let emptyStatus = "Empty"

    /// "48 words", "1 word", or "Empty".
    static func textStatus(_ text: String) -> String {
        let words = text.split(whereSeparator: \.isWhitespace).count
        return words == 0 ? emptyStatus : "\(words) word\(words == 1 ? "" : "s")"
    }

    /// "14 strokes", "1 stroke", or "Empty".
    static func sketchStatus(_ sketch: Sketch) -> String {
        let strokes = sketch.strokes.count
        return strokes == 0 ? emptyStatus : "\(strokes) stroke\(strokes == 1 ? "" : "s")"
    }

    /// The recording length, such as "0:42", or "Empty".
    static func voiceStatus(duration: TimeInterval, hasRecording: Bool) -> String {
        hasRecording ? voiceNoteDuration(duration) : emptyStatus
    }
}

/// One challenge session: the prompt and its guide on top, then the
/// response area — a rail of three equal modes and the pane of the selected
/// one. Used for the daily featured challenge (pushed from Today) and for
/// practice (hosted directly in the detail pane).
struct SessionView: View {
    let prompt: Prompt
    let isDaily: Bool
    /// Practice only: ask the host for a fresh prompt.
    var onNewPrompt: (() -> Void)?
    /// Daily only: leave the session after finishing.
    var onDone: (() -> Void)?
    /// Daily only: return to the Today overview (guards unsaved work).
    var onBack: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(AppModel.self) private var appModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var mode: ResponseMode = .text
    @State private var text = ""
    @State private var connectingWord = ""
    @State private var recorder = VoiceNoteRecorder()
    @State private var player = VoiceNotePlayer()
    @State private var sketch = Sketch()
    @State private var sketchHistory = SketchHistory()
    @State private var savedEntry: JournalEntry?
    @State private var saveErrorMessage = ""
    @State private var showSaveError = false
    @State private var showNewPromptConfirmation = false
    @State private var showBackConfirmation = false
    /// The width of the detail pane. Below `guideBreakpoint` the guide panel
    /// moves under the prompt.
    @State private var detailWidth: CGFloat = 1080
    @FocusState private var editorFocused: Bool

    private static let guideBreakpoint: CGFloat = 820
    private static let paneMinHeight: CGFloat = 280

    private var exercise: Exercise { prompt.exercise }
    private var isCommonThread: Bool { exercise == .commonThread }

    /// The response/saved card swap settles into place rather than just
    /// flashing in — a materialize, not a bare crossfade. If Reduce Motion
    /// is on, it is a crossfade only.
    private var cardMaterialize: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.97, anchor: .top))
    }

    private var cardAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 1.0)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                topRow
                responseArea
            }
            .padding(.horizontal, 44)
            .padding(.top, 28)
            .padding(.bottom, 56)
            .frame(maxWidth: 1080, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            detailWidth = width
        }
        .onChange(of: connectingWord) { _, newValue in
            guard isCommonThread else { return }
            let sanitized = newValue.components(separatedBy: .whitespacesAndNewlines).joined()
            if sanitized != newValue { connectingWord = sanitized }
        }
        .onChange(of: hasUnsavedContent) { _, dirty in
            appModel.sessionHasUnsavedWork = dirty
        }
        .onChange(of: appModel.pendingNewPrompt) { _, pending in
            guard pending else { return }
            appModel.pendingNewPrompt = false
            requestNewPrompt()
        }
        .onDisappear {
            appModel.sessionHasUnsavedWork = false
            player.stop()
            // A recording that was never saved shouldn't leave a file behind.
            if savedEntry == nil {
                recorder.discard()
            } else {
                recorder.stop()
            }
        }
        .alert("Couldn’t Save", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage)
        }
        .confirmationDialog(
            "Deal a new prompt and discard this response?",
            isPresented: $showNewPromptConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard and Continue", role: .destructive) {
                appModel.sessionHasUnsavedWork = false
                onNewPrompt?()
            }
            Button("Keep This Response", role: .cancel) {}
        }
        .confirmationDialog(
            "Discard this response?",
            isPresented: $showBackConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard Response", role: .destructive) {
                appModel.sessionHasUnsavedWork = false
                onBack?()
            }
            Button("Keep Editing", role: .cancel) {}
        }
    }

    // MARK: - Top row

    /// The prompt, with the guide panel beside it. If the detail pane is
    /// narrow, the guide panel moves under the prompt.
    @ViewBuilder
    private var topRow: some View {
        if detailWidth >= Self.guideBreakpoint {
            HStack(alignment: .top, spacing: 40) {
                promptBlock
                guidePanel
                    .frame(width: 280)
            }
        } else {
            VStack(alignment: .leading, spacing: 24) {
                promptBlock
                guidePanel
            }
        }
    }

    private var promptBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                if onBack != nil {
                    Button {
                        requestBack()
                    } label: {
                        Label("Today", systemImage: "chevron.left")
                            .font(Theme.ui(14))
                            .foregroundStyle(Theme.inkSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .contentShape(.rect)
                            .hoverHighlight()
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("session-back")
                    .help("Back to Today")
                }
                Text("\(exercise.title) · \(isDaily ? "Daily" : "Practice")")
                    .font(Theme.ui(12, .semibold))
                    .foregroundStyle(Theme.inkTertiary)
            }

            headline

            if let detail = prompt.detail {
                detailLine(detail)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }

            Text(exercise.directive)
                .font(Theme.ui(13))
                .lineSpacing(3)
                .foregroundStyle(Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The hero prompt, with its dealt fragment on the `Highlight` mark.
    private var headline: some View {
        Text(Highlight.attributed(prompt.headline, marking: prompt.markedPhrase))
            .font(Theme.display(isCommonThread ? 44 : 38, weight: .regular))
            .kerning(-0.5)
            .lineSpacing(2)
            .foregroundStyle(Theme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }

    /// "The Catch." in interface type, then the detail in display italic.
    private func detailLine(_ detail: String) -> Text {
        let body = Text(detail)
            .font(Theme.display(17, weight: .regular, italic: true))
            .foregroundStyle(Theme.inkSecondary)
        guard let label = prompt.detailLabel else { return body }
        return Text("\(label). ")
            .font(Theme.ui(14, .semibold))
            .foregroundStyle(Theme.ink)
            + body
    }

    /// Optional hints, in a quiet panel so they don't compete with the prompt.
    private var guidePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("A way in")
                .font(Theme.ui(13, .semibold))
                .foregroundStyle(Theme.ink)
            ForEach(Array(exercise.responseGuide.enumerated()), id: \.element) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(index + 1)")
                        .font(Theme.display(13, weight: .regular, italic: true))
                        .foregroundStyle(Theme.accentText)
                    Text(item)
                        .font(Theme.ui(13.5))
                        .lineSpacing(3)
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let stretch = exercise.stretchPrompt {
                Text("Stretch: \(stretch)")
                    .font(Theme.ui(12.5, italic: true))
                    .foregroundStyle(Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .outlinedCard(cornerRadius: Theme.radiusMedium, elevation: .none)
    }

    // MARK: - Response area

    @ViewBuilder
    private var responseArea: some View {
        if savedEntry == nil {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    ResponseModeRail(
                        mode: $mode,
                        textStatus: ResponseMode.textStatus(composedResponseText),
                        sketchStatus: ResponseMode.sketchStatus(sketch),
                        recorder: recorder
                    )
                    saveButton
                }
                .frame(width: 150)

                modePane
                    .frame(maxWidth: .infinity, minHeight: Self.paneMinHeight, alignment: .topLeading)
            }
            .transition(cardMaterialize)
        } else {
            savedCard
                .transition(cardMaterialize)
        }
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            PrimaryActionButtonLabel(title: "Save to Journal", enabled: canSave, fullWidth: true)
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .keyboardShortcut("s", modifiers: .command)
        .help("Save to journal (⌘S)")
    }

    @ViewBuilder
    private var modePane: some View {
        switch mode {
        case .text:
            textPane
        case .sketch:
            SketchCanvas(sketch: $sketch, history: $sketchHistory, tint: exercise.tint, floatingTools: true)
                .frame(minHeight: Self.paneMinHeight)
        case .voice:
            VoiceResponsePane(recorder: recorder, player: player)
                .frame(maxWidth: .infinity, minHeight: Self.paneMinHeight)
                .outlinedCard(cornerRadius: Theme.radiusMedium, elevation: .none)
        }
    }

    private var textPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isCommonThread {
                TextField("Connecting word…", text: $connectingWord)
                    .textFieldStyle(.plain)
                    .focused($editorFocused)
                    .font(Theme.ui(15, .semibold))
                    .foregroundStyle(Theme.accentText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .inputWell()
                    .autocorrectionDisabled()
            }

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(Theme.display(17, weight: .regular))
                        .foregroundStyle(Theme.inkTertiary)
                        .padding(.top, 14)
                        .padding(.leading, 14)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .focused($editorFocused)
                    .scrollContentBackground(.hidden)
                    .font(Theme.display(17, weight: .regular))
                    .lineSpacing(6)
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, minHeight: isCommonThread ? 180 : 240)
                    .padding(8)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: Self.paneMinHeight, alignment: .topLeading)
        .outlinedCard(cornerRadius: Theme.radiusMedium, elevation: .none)
    }

    private var placeholder: String {
        if isCommonThread { return "Explain the connection (optional)…" }
        return "Type your idea…"
    }

    private var savedCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 20, height: 20)
                    .background(Theme.accentSoft, in: .circle)
                Text("Saved to your journal")
                    .font(Theme.ui(14, .semibold))
                    .foregroundStyle(Theme.accentText)
            }
            if let saved = savedEntry, !saved.responseText.isEmpty {
                Text(saved.responseText)
                    .font(Theme.ui(15))
                    .lineSpacing(5)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            if let file = savedEntry?.voiceNoteFile,
               let url = AttachmentStore.live.url(forFile: file) {
                Button {
                    player.toggle(url: url)
                } label: {
                    Label(
                        "Voice note · \(voiceNoteDuration(recorder.duration))",
                        systemImage: player.isPlaying ? "pause.circle.fill" : "play.circle.fill"
                    )
                    .font(Theme.ui(13.5, .medium))
                    .foregroundStyle(Theme.inkSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.background, in: .rect(cornerRadius: Theme.radiusSmall))
                }
                .buttonStyle(.plain)
            }
            if let data = savedEntry?.sketchData {
                SketchImage(data: data)
            }
            HStack(spacing: 12) {
                Button { reset() } label: {
                    SecondaryActionButtonLabel(title: "Answer Again", fullWidth: true)
                }
                .buttonStyle(.plain)

                if let onDone {
                    Button {
                        player.stop()
                        onDone()
                    } label: {
                        PrimaryActionButtonLabel(title: "Done", fullWidth: true)
                    }
                    .buttonStyle(.plain)
                } else if onNewPrompt != nil {
                    // ⌘R lives on the toolbar New Prompt button.
                    Button { onNewPrompt?() } label: {
                        PrimaryActionButtonLabel(title: "New Prompt", fullWidth: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(cornerRadius: Theme.radiusLarge, elevation: .sm)
    }

    // MARK: - State

    private var composedResponseText: String {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isCommonThread else { return body }
        let word = connectingWord.trimmingCharacters(in: .whitespacesAndNewlines)
        return [word, body].filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    private var canSave: Bool {
        !composedResponseText.isEmpty || recorder.fileURL != nil || !sketch.isEmpty
    }

    private var hasUnsavedContent: Bool {
        savedEntry == nil && canSave
    }

    // MARK: - Actions

    private func save() {
        recorder.stop()
        editorFocused = false
        do {
            let entry = try EntryRepository(context: modelContext).save(
                prompt: prompt,
                responseText: composedResponseText,
                isDaily: isDaily,
                temporaryVoiceNoteURL: recorder.fileURL,
                sketchData: sketch.isEmpty ? nil : sketch.encoded()
            )
            recorder.markCommitted()
            appModel.sessionHasUnsavedWork = false
            sketchHistory.reset()
            withAnimation(cardAnimation) { savedEntry = entry }
        } catch {
            saveErrorMessage = error.localizedDescription
            showSaveError = true
        }
    }

    /// A second attempt at the same prompt; the saved entry stays untouched.
    private func reset() {
        player.stop()
        recorder.discard()
        withAnimation(cardAnimation) {
            savedEntry = nil
            text = ""
            connectingWord = ""
            sketch = Sketch()
            sketchHistory.reset()
        }
    }

    private func requestNewPrompt() {
        if hasUnsavedContent {
            showNewPromptConfirmation = true
        } else {
            onNewPrompt?()
        }
    }

    private func requestBack() {
        if hasUnsavedContent {
            showBackConfirmation = true
        } else {
            onBack?()
        }
    }
}

/// The mode rail: one equal-weight row each for Text, Sketch and Voice, with
/// the content status of each. Its own view, so the recorder's duration
/// ticks redraw only the rail.
private struct ResponseModeRail: View {
    @Binding var mode: ResponseMode
    let textStatus: String
    let sketchStatus: String
    let recorder: VoiceNoteRecorder

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(ResponseMode.allCases) { candidate in
                row(candidate)
            }
        }
    }

    private func status(for candidate: ResponseMode) -> String {
        switch candidate {
        case .text: textStatus
        case .sketch: sketchStatus
        case .voice:
            ResponseMode.voiceStatus(
                duration: recorder.duration,
                hasRecording: recorder.isRecording || recorder.fileURL != nil
            )
        }
    }

    private func row(_ candidate: ResponseMode) -> some View {
        let selected = mode == candidate
        let status = status(for: candidate)
        return Button {
            mode = candidate
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: candidate.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 3) {
                    Text(candidate.title)
                        .font(Theme.ui(14, .semibold))
                    Text(status)
                        .font(Theme.mono(11))
                        .foregroundStyle(selected ? Theme.accentText : Theme.inkTertiary)
                }
            }
            .foregroundStyle(selected ? Theme.ink : Theme.inkSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Theme.surface : .clear, in: .rect(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .strokeBorder(selected ? Theme.divider : .clear, lineWidth: 1)
            )
            .contentShape(.rect(cornerRadius: Theme.radiusMedium))
            .hoverHighlight(cornerRadius: Theme.radiusMedium)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(KeyEquivalent(candidate.shortcutKey), modifiers: [.command, .option])
        .help("\(candidate.title) (⌥⌘\(candidate.shortcutKey))")
        .accessibilityLabel(candidate.title)
        .accessibilityValue(status)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("session-mode-\(candidate.title.lowercased())")
    }
}

/// The Voice pane: the record button, then the player and the trash for a
/// finished recording. Recording stops itself at five minutes.
private struct VoiceResponsePane: View {
    let recorder: VoiceNoteRecorder
    let player: VoiceNotePlayer

    var body: some View {
        VStack(spacing: 18) {
            Button {
                if recorder.isRecording {
                    recorder.stop()
                } else {
                    player.stop()
                    recorder.record()
                }
            } label: {
                if recorder.isRecording {
                    PrimaryActionButtonLabel(title: "Stop · \(voiceNoteDuration(recorder.duration))")
                        .monospacedDigit()
                } else {
                    SecondaryActionButtonLabel(
                        title: recorder.phase == .recorded ? "Re-record" : "Record",
                        systemImage: "mic.fill"
                    )
                }
            }
            .buttonStyle(.plain)
            .help(recorder.isRecording ? "Stop recording" : "Record a voice note (up to 5 minutes)")

            if recorder.phase == .recorded, let url = recorder.fileURL {
                HStack(spacing: 10) {
                    Button {
                        player.toggle(url: url)
                    } label: {
                        SecondaryActionButtonLabel(
                            title: voiceNoteDuration(recorder.duration),
                            systemImage: player.isPlaying ? "pause.fill" : "play.fill"
                        )
                        .monospacedDigit()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(player.isPlaying ? "Pause voice note" : "Play voice note")
                    .help("Play back the recording")

                    Button {
                        player.stop()
                        recorder.discard()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.inkSecondary)
                            .frame(width: 36, height: 36)
                            .contentShape(.circle)
                            .hoverHighlight(in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Discard recording")
                    .help("Discard the recording")
                }
            }

            if case .denied = recorder.phase {
                Text("Microphone access is off. Enable it in System Settings → Privacy & Security → Microphone to record voice notes.")
                    .font(Theme.ui(12))
                    .foregroundStyle(Theme.inkTertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 340)
            }
            if case .failed(let message) = recorder.phase {
                Text(message)
                    .font(Theme.ui(12))
                    .foregroundStyle(Theme.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 340)
            }
        }
        .padding(24)
    }
}

/// Voice-note controls and the sketch toggle, used by the Diary composer.
struct MediaAttachmentsBar: View {
    let recorder: VoiceNoteRecorder
    let player: VoiceNotePlayer
    @Binding var sketch: Sketch
    @Binding var showCanvas: Bool
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(Theme.dividerSoft)
                .frame(height: 1)
                .padding(.bottom, 4)
            HStack(spacing: 14) {
                recordButton
                if recorder.phase == .recorded, let url = recorder.fileURL {
                    Button {
                        player.toggle(url: url)
                    } label: {
                        Label(
                            voiceNoteDuration(recorder.duration),
                            systemImage: player.isPlaying ? "pause.circle.fill" : "play.circle.fill"
                        )
                        .foregroundStyle(tint)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(player.isPlaying ? "Pause voice note" : "Play voice note")
                    .help("Play back the recording")

                    Button {
                        player.stop()
                        recorder.discard()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(Theme.inkTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Discard recording")
                    .help("Discard the recording")
                }

                Spacer()

                Toggle(isOn: reduceMotion ? $showCanvas : $showCanvas.animation(.snappy)) {
                    Label("Sketch", systemImage: "scribble.variable")
                }
                .toggleStyle(.button)
                .buttonStyle(.borderless)
                .tint(tint)
                .help(sketch.isEmpty ? "Open the drawing canvas" : "Show or hide your drawing")
            }
            .font(Theme.ui(13.5, .medium))

            if case .denied = recorder.phase {
                Text("Microphone access is off. Enable it in System Settings → Privacy & Security → Microphone to record voice notes.")
                    .font(Theme.ui(12))
                    .foregroundStyle(Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if case .failed(let message) = recorder.phase {
                Text(message)
                    .font(Theme.ui(12))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var recordButton: some View {
        Button {
            if recorder.isRecording {
                recorder.stop()
            } else {
                player.stop()
                recorder.record()
            }
        } label: {
            Label {
                Text(recorder.isRecording
                    ? "Stop · \(voiceNoteDuration(recorder.duration))"
                    : (recorder.phase == .recorded ? "Re-record" : "Record"))
                    .monospacedDigit()
            } icon: {
                Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .foregroundStyle(recorder.isRecording ? .red : tint)
            }
        }
        .buttonStyle(.plain)
        .help(recorder.isRecording ? "Stop recording" : "Record a voice note (up to 5 minutes)")
    }
}
