import SwiftUI

/// The reading pane: one saved entry in full.
struct EntryDetailView: View {
    let entry: JournalEntry
    /// The open edit of the response text, or nil in read mode. The journal
    /// owns it so selection changes can guard unsaved changes.
    @Binding var edit: ResponseEdit?
    let onSaveEdit: () -> Void
    let onDelete: () -> Void

    @State private var player = VoiceNotePlayer()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                promptCard
                if let editBinding = Binding($edit) {
                    EntryTextEditor(
                        edit: editBinding,
                        onCancel: { edit = nil },
                        onSave: onSaveEdit
                    )
                } else if !entry.responseText.isEmpty {
                    Text(entry.responseText)
                        .font(Theme.ui(16))
                        .lineSpacing(6)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let file = entry.voiceNoteFile {
                    voiceNoteCard(file: file)
                }
                if let data = entry.sketchData {
                    SketchImage(data: data)
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 48)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onDisappear { player.stop() }
        .onChange(of: entry.id) { player.stop() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Tag(text: entry.exercise.title, size: 12)
            if entry.isDaily { Badge(text: "Daily") }
            Text(entry.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
                .font(Theme.ui(13))
                .foregroundStyle(Theme.inkTertiary)
            Spacer(minLength: 12)

            if edit == nil && !entry.responseText.isEmpty {
                Button {
                    edit = ResponseEdit(original: entry.responseText)
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.inkTertiary)
                        .frame(width: 30, height: 30)
                        .contentShape(.rect)
                        .hoverHighlight()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("detail-edit")
                .accessibilityLabel("Edit Response")
                .help("Edit the response text")
            }

            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkTertiary)
                    .frame(width: 30, height: 30)
                    .contentShape(.rect)
                    .hoverHighlight()
            }
            .buttonStyle(.plain)
            .disabled(edit != nil)
            .accessibilityIdentifier("detail-delete")
            .accessibilityLabel("Delete Entry")
            .help("Delete this entry")
        }
    }

    /// The prompt recap, in an accent wash and the display serif — it's the
    /// question quoted back, not another paragraph of the answer.
    @ViewBuilder
    private var promptCard: some View {
        if entry.exercise != .diary {
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.promptHeadline)
                    .font(Theme.display(19, weight: .regular))
                    .lineSpacing(3)
                    .foregroundStyle(Theme.accentStrong)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                if let detail = entry.promptDetail {
                    Text(detail)
                        .font(Theme.ui(13.5))
                        .foregroundStyle(Theme.accentStrong.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.accentSoft, in: .rect(cornerRadius: Theme.radiusMedium))
        }
    }

    @ViewBuilder
    private func voiceNoteCard(file: String) -> some View {
        if let url = AttachmentStore.live.url(forFile: file) {
            Button {
                player.toggle(url: url)
            } label: {
                Label(
                    player.isPlaying ? "Pause voice note" : "Play voice note",
                    systemImage: player.isPlaying ? "pause.circle.fill" : "play.circle.fill"
                )
                .font(Theme.ui(13.5, .medium))
                .foregroundStyle(Theme.inkSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface, in: .rect(cornerRadius: Theme.radiusSmall))
                .contentShape(.rect)
                .hoverHighlight()
            }
            .buttonStyle(.plain)
        } else {
            Label("This entry's voice note file is missing.", systemImage: "waveform.slash")
                .font(Theme.ui(12))
                .foregroundStyle(Theme.inkTertiary)
        }
    }
}
