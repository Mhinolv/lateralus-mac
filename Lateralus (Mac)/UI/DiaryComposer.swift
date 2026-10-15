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
    @State private var sketchHistory = SketchHistory()
    @State private var showCanvas = false
    @State private var saved = false
    @State private var saveErrorMessage = ""
    @State private var showSaveError = false
    @State private var showDiscardConfirmation = false
    /// The draft file this composer owns for its life. Restore adopts the
    /// orphan's ID instead.
    @State private var draftID = UUID()
    @State private var draftStatus: DraftStatus = .none
    @State private var orphanDraft: DiaryDraft?
    /// Set on save or discard, so a pending autosave does not write again.
    @State private var finished = false
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
                if let orphanDraft {
                    recoveryBanner(for: orphanDraft)
                }

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
                    SketchCanvas(sketch: $sketch, history: $sketchHistory, tint: Exercise.diary.tint)
                }
            }
            .padding(24)

            Spacer(minLength: 0)

            HStack(spacing: 16) {
                Spacer()
                if let message = draftStatus.message {
                    Text(message)
                        .font(Theme.ui(12))
                        .foregroundStyle(Theme.inkTertiary)
                }
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
        .onAppear {
            editorFocused = true
            DiaryDraftOwnership.shared.claim(draftID)
            orphanDraft = DiaryDraftStore.live.newestOrphan(excluding: DiaryDraftOwnership.shared.owned)
        }
        .onDisappear {
            player.stop()
            if !saved {
                recorder.discard()
            }
            DiaryDraftOwnership.shared.release(draftID)
        }
        .task(id: text) {
            // Autosave about one second after the last edit. A new edit
            // cancels the wait.
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            writeDraft()
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
            finishDraft()
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
        finishDraft()
        dismiss()
    }

    // MARK: - Drafts

    private func writeDraft() {
        guard !finished else { return }
        do {
            try DiaryDraftStore.live.write(id: draftID, text: text)
            draftStatus = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .none : .saved
        } catch {
            draftStatus = .failed
        }
    }

    private func finishDraft() {
        finished = true
        DiaryDraftStore.live.remove(id: draftID)
    }

    private func restore(_ draft: DiaryDraft) {
        orphanDraft = nil
        // Another window can restore the same draft first.
        guard !DiaryDraftOwnership.shared.owned.contains(draft.id) else { return }
        DiaryDraftOwnership.shared.release(draftID)
        DiaryDraftStore.live.remove(id: draftID)
        draftID = draft.id
        DiaryDraftOwnership.shared.claim(draft.id)
        text = DiaryDraftStore.merge(existing: text, draft: draft.text)
        writeDraft()
        editorFocused = true
    }

    private func recoveryBanner(for draft: DiaryDraft) -> some View {
        HStack(spacing: 16) {
            Text("Unsaved text from \(draft.updatedAt.formatted(date: .abbreviated, time: .shortened)) is available.")
                .font(Theme.ui(13.5))
                .foregroundStyle(Theme.accentStrong)
            Spacer(minLength: 0)
            Button("Discard") {
                DiaryDraftStore.live.remove(id: draft.id)
                orphanDraft = nil
            }
            .buttonStyle(.plain)
            .font(Theme.ui(13.5))
            .foregroundStyle(Theme.inkSecondary)
            Button("Restore") { restore(draft) }
                .buttonStyle(.plain)
                .font(Theme.ui(13.5, .semibold))
                .foregroundStyle(Theme.accent)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Theme.accentSoft, in: .rect(cornerRadius: Theme.radiusMedium))
    }
}

/// Footer feedback for autosave. Never an alert.
enum DraftStatus: Equatable {
    case none
    case saved
    case failed

    var message: String? {
        switch self {
        case .none: nil
        case .saved: "Draft saved"
        case .failed: "Draft not saved"
        }
    }
}
