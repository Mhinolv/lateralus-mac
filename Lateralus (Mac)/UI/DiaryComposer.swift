import SwiftData
import SwiftUI

/// A promptless entry: free writing with the same voice-note and sketch
/// tools every challenge response gets. Presented as a sheet (⌘N).
struct DiaryComposer: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var text = ""
    @State private var recorder = VoiceNoteRecorder()
    @State private var player = VoiceNotePlayer()
    @State private var sketch = Sketch()
    @State private var showCanvas = false
    @State private var saved = false
    @State private var saveErrorMessage = ""
    @State private var showSaveError = false
    @State private var showDiscardConfirmation = false
    @FocusState private var editorFocused: Bool

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || recorder.fileURL != nil
            || !sketch.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Diary", systemImage: Exercise.diary.symbol)
                    .font(Theme.display(18))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button("Close") { requestClose() }
                    .buttonStyle(.plain)
                    .font(Theme.ui(14))
                    .foregroundStyle(Theme.inkTertiary)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.dividerSoft).frame(height: 1)
            }

            VStack(alignment: .leading, spacing: 16) {
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Whatever's on your mind…")
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
                        .padding(8)
                }
                .frame(minHeight: 220)
                .inputWell(fill: Theme.surface)

                MediaAttachmentsBar(
                    recorder: recorder,
                    player: player,
                    sketch: $sketch,
                    showCanvas: $showCanvas,
                    tint: Exercise.diary.tint
                )

                if showCanvas {
                    SketchCanvas(sketch: $sketch, tint: Exercise.diary.tint)
                }
            }
            .padding(24)

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button {
                    save()
                } label: {
                    PrimaryActionButtonLabel(title: "Save to Journal", enabled: canSave)
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .keyboardShortcut("s", modifiers: .command)
                .help("Save to journal (⌘S)")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.dividerSoft).frame(height: 1)
            }
        }
        .frame(minWidth: 560, idealWidth: 620, minHeight: 460)
        .background(AppBackground())
        .onAppear { editorFocused = true }
        .onDisappear {
            player.stop()
            if !saved {
                recorder.discard()
            }
        }
        .interactiveDismissDisabled(hasUnsavedContent)
        .alert("Couldn’t Save", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage)
        }
        .confirmationDialog(
            "Discard this diary entry?",
            isPresented: $showDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard Entry", role: .destructive) { closeImmediately() }
            Button("Keep Editing", role: .cancel) {}
        }
    }

    private var hasUnsavedContent: Bool {
        !saved && canSave
    }

    private func save() {
        recorder.stop()
        editorFocused = false
        do {
            _ = try EntryRepository(context: modelContext).save(
                prompt: Prompt(exercise: .diary, headline: "Diary", detail: nil),
                responseText: text.trimmingCharacters(in: .whitespacesAndNewlines),
                isDaily: false,
                temporaryVoiceNoteURL: recorder.fileURL,
                sketchData: sketch.isEmpty ? nil : sketch.encoded()
            )
            recorder.markCommitted()
            saved = true
            dismiss()
        } catch {
            saveErrorMessage = error.localizedDescription
            showSaveError = true
        }
    }

    private func requestClose() {
        if hasUnsavedContent {
            showDiscardConfirmation = true
        } else {
            closeImmediately()
        }
    }

    private func closeImmediately() {
        player.stop()
        recorder.discard()
        dismiss()
    }
}
