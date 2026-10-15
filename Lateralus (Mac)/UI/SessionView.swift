import SwiftData
import SwiftUI

/// One challenge session: prompt and guidance on the left, the response
/// studio on the right. Used for the daily featured challenge (pushed from
/// Today) and for practice (hosted directly in the detail pane).
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

    @State private var text = ""
    @State private var connectingWord = ""
    @State private var recorder = VoiceNoteRecorder()
    @State private var player = VoiceNotePlayer()
    @State private var sketch = Sketch()
    @State private var sketchHistory = SketchHistory()
    @State private var showCanvas = false
    @State private var savedEntry: JournalEntry?
    @State private var saveErrorMessage = ""
    @State private var showSaveError = false
    @State private var showNewPromptConfirmation = false
    @State private var showBackConfirmation = false
    @FocusState private var editorFocused: Bool

    private var exercise: Exercise { prompt.exercise }
    private var isCommonThread: Bool { exercise == .commonThread }

    /// The input/saved card swap settles into place rather than just
    /// flashing in — a materialize, not a bare crossfade.
    private var cardMaterialize: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.97, anchor: .top))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                sessionHeader
                HStack(alignment: .top, spacing: 32) {
                    promptColumn
                    responseColumn
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 44)
            .padding(.bottom, 56)
            .frame(maxWidth: 1080, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .onChange(of: connectingWord) { _, newValue in
            guard isCommonThread else { return }
            let sanitized = newValue.components(separatedBy: .whitespacesAndNewlines).joined()
            if sanitized != newValue { connectingWord = sanitized }
        }
        .onChange(of: hasUnsavedContent) { _, dirty in
            appModel.sessionHasUnsavedWork = dirty
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

    // MARK: - Header

    /// Inline session chrome: back control, discipline identity, and the
    /// new-prompt action — all in the app's own style.
    private var sessionHeader: some View {
        HStack(spacing: 16) {
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
            Text(exercise.title)
                .font(Theme.display(20))
                .foregroundStyle(Theme.ink)
            Spacer()
            if onNewPrompt != nil && savedEntry == nil {
                Button {
                    requestNewPrompt()
                } label: {
                    SecondaryActionButtonLabel(title: "⌘R New Prompt")
                }
                .buttonStyle(.plain)
                .keyboardShortcut("r", modifiers: .command)
                .accessibilityIdentifier("session-new-prompt")
                .help("Deal another prompt (⌘R)")
            }
        }
    }

    // MARK: - Prompt column

    private var promptColumn: some View {
        VStack(alignment: .leading, spacing: 20) {
            instructionBanner
            promptCard
            responseGuide
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var responseColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            if savedEntry == nil {
                inputCard
                    .transition(cardMaterialize)
            } else {
                savedCard
                    .transition(cardMaterialize)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// The discipline's standing rule. An accent wash rather than a card:
    /// it's an instruction that applies to every prompt in the discipline,
    /// so it should read as a margin note above the prompt, not as a peer
    /// of it.
    private var instructionBanner: some View {
        Text(exercise.directive)
            .font(Theme.ui(14))
            .lineSpacing(3)
            .foregroundStyle(Theme.accentStrong)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.accentSoft, in: .rect(cornerRadius: Theme.radiusMedium))
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(prompt.headline)
                .font(Theme.display(isCommonThread ? 28 : 22, weight: .regular))
                .lineSpacing(4)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            if let detail = prompt.detail {
                VStack(alignment: .leading, spacing: 4) {
                    if let label = prompt.detailLabel {
                        Text(label)
                            .font(Theme.ui(11, .semibold))
                            .textCase(.uppercase)
                            .kerning(0.9)
                            .foregroundStyle(Theme.inkTertiary)
                    }
                    Text(detail)
                        .font(Theme.ui(14))
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(cornerRadius: Theme.radiusLarge, elevation: .sm)
    }

    /// Guidance, set plainly on the ground. It was a card; that gave three
    /// optional hints the same visual weight as the prompt itself. Offering
    /// a way in shouldn't look like a requirement.
    private var responseGuide: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("A way in, if you want one")
                .font(Theme.ui(13, .semibold))
                .foregroundStyle(Theme.inkTertiary)
                .padding(.bottom, 2)
            ForEach(Array(exercise.responseGuide.enumerated()), id: \.element) { index, item in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(Theme.ui(11, .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 22, height: 22)
                        .background(Theme.surfaceSunken, in: .circle)
                    Text(item)
                        .font(Theme.ui(14.5))
                        .lineSpacing(3)
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let stretch = exercise.stretchPrompt {
                Text("Stretch: \(stretch)")
                    .font(Theme.ui(13, italic: true))
                    .foregroundStyle(Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Response column

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if isCommonThread {
                TextField("Connecting word…", text: $connectingWord)
                    .textFieldStyle(.plain)
                    .focused($editorFocused)
                    .font(Theme.ui(15, .semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .inputWell()
                    .autocorrectionDisabled()
            }

            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .font(Theme.ui(15))
                            .foregroundStyle(Theme.inkTertiary)
                            .padding(.top, 14)
                            .padding(.leading, 14)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $text)
                        .focused($editorFocused)
                        .scrollContentBackground(.hidden)
                        .font(Theme.ui(15))
                        .lineSpacing(4)
                        .foregroundStyle(Theme.ink)
                        .frame(minHeight: isCommonThread ? 140 : 240)
                        .padding(8)
                }
                .inputWell()

                if !isCommonThread && !text.isEmpty {
                    Text("\(text.split(whereSeparator: \.isWhitespace).count) words")
                        .font(Theme.ui(12))
                        .foregroundStyle(Theme.inkTertiary)
                        .monospacedDigit()
                }
            }

            MediaAttachmentsBar(
                recorder: recorder,
                player: player,
                sketch: $sketch,
                showCanvas: $showCanvas,
                tint: exercise.tint
            )

            if showCanvas {
                SketchCanvas(sketch: $sketch, history: $sketchHistory, tint: exercise.tint)
            }

            Button {
                save()
            } label: {
                PrimaryActionButtonLabel(title: "Save to Journal", enabled: canSave, fullWidth: true)
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
            .keyboardShortcut("s", modifiers: .command)
            .help("Save to journal (⌘S)")
            .padding(.top, 4)
        }
        .padding(24)
        .paperCard(cornerRadius: Theme.radiusLarge, elevation: .sm)
    }

    private var placeholder: String {
        if isCommonThread { return "Explain the connection (optional)…" }
        return "Type your idea — or record it, or sketch it below…"
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
                    .foregroundStyle(Theme.accent)
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
                    Button { onNewPrompt?() } label: {
                        PrimaryActionButtonLabel(title: "New Prompt", fullWidth: true)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("r", modifiers: .command)
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
            withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 1.0)) { savedEntry = entry }
        } catch {
            saveErrorMessage = error.localizedDescription
            showSaveError = true
        }
    }

    /// A second attempt at the same prompt; the saved entry stays untouched.
    private func reset() {
        player.stop()
        recorder.discard()
        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 1.0)) {
            savedEntry = nil
            text = ""
            connectingWord = ""
            sketch = Sketch()
            showCanvas = false
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

/// Voice-note controls and the sketch toggle, shared by sessions and Diary.
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
