import SwiftUI
import UniformTypeIdentifiers

/// The reading pane: one saved entry in full.
struct EntryDetailView: View {
    let entry: JournalEntry
    /// The open edit of the response text, or nil in read mode. The journal
    /// owns it so selection changes can guard unsaved changes.
    @Binding var edit: ResponseEdit?
    let onSaveEdit: () -> Void
    let onDelete: () -> Void

    @State private var player = VoiceNotePlayer()
    @State private var exportError: String?

    /// The saved sketch, when it has strokes to export.
    private var exportableSketch: Sketch? {
        guard let data = entry.sketchData, let sketch = Sketch.decode(data), !sketch.isEmpty else { return nil }
        return sketch
    }

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
                        .contextMenu {
                            if let sketch = exportableSketch {
                                Button("Export Sketch…") {
                                    // Leave the menu action before the panel runs its modal loop.
                                    Task { exportSketch(sketch) }
                                }
                            }
                        }
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 48)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onDisappear { player.stop() }
        .onChange(of: entry.id) { player.stop() }
        .alert(
            "Couldn’t Export Sketch",
            isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })
        ) {
            Button("OK") {}
                .keyboardShortcut(.defaultAction)
        } message: {
            Text(exportError ?? "")
        }
    }

    /// Asks for a destination and writes the sketch there as a PNG. Cancel
    /// does nothing, success shows nothing, and the entry never changes.
    private func exportSketch(_ sketch: Sketch) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = SketchExport.defaultFileName(for: entry.date)
        panel.prompt = "Export"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try SketchExport.write(sketch, to: url)
        } catch {
            exportError = error.localizedDescription
        }
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

            if let sketch = exportableSketch {
                Button {
                    exportSketch(sketch)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.inkTertiary)
                        .frame(width: 30, height: 30)
                        .contentShape(.rect)
                        .hoverHighlight()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("detail-export-sketch")
                .accessibilityLabel("Export Sketch")
                .help("Export the sketch as a PNG image")
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
