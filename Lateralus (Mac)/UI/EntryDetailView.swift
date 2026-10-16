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
            VStack(alignment: .leading, spacing: 18) {
                header
                prompt
                if let editBinding = Binding($edit) {
                    EntryTextEditor(
                        edit: editBinding,
                        onCancel: { edit = nil },
                        onSave: onSaveEdit
                    )
                } else if !entry.responseText.isEmpty {
                    Text(entry.responseText)
                        .font(EntryTextEditor.responseFont)
                        .lineSpacing(EntryTextEditor.responseLineSpacing)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let file = entry.voiceNoteFile {
                    voiceNote(file: file)
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
            .padding(.horizontal, 36)
            .padding(.vertical, 30)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
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
        HStack(spacing: 8) {
            Tag(text: entry.exercise.title, size: 12.5)
            if entry.isDaily { Badge(text: "Daily") }
            Text(entry.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
                .font(Theme.ui(12.5))
                .foregroundStyle(Theme.inkTertiary)
                .lineLimit(1)
            Spacer(minLength: 8)

            if edit == nil && !entry.responseText.isEmpty {
                Button {
                    edit = ResponseEdit(original: entry.responseText)
                } label: {
                    SecondaryActionButtonLabel(title: "Edit", systemImage: "square.and.pencil", small: true)
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
                    IconCapsuleLabel(systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("detail-export-sketch")
                .accessibilityLabel("Export Sketch")
                .help("Export the sketch as a PNG image")
            }

            Button {
                onDelete()
            } label: {
                IconCapsuleLabel(systemImage: "trash")
            }
            .buttonStyle(.plain)
            .disabled(edit != nil)
            .accessibilityIdentifier("detail-delete")
            .accessibilityLabel("Delete Entry")
            .help("Delete this entry")
        }
    }

    /// The prompt recap: the display serif on the ground, no wash — it's
    /// the question quoted back, not another paragraph of the answer. A
    /// rule divides it from the response.
    @ViewBuilder
    private var prompt: some View {
        if entry.exercise != .diary {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.promptHeadline)
                    .font(Theme.display(28, weight: .regular))
                    .kerning(-0.3)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                if let detail = entry.promptDetail {
                    Text(Self.detailLine(label: entry.prompt.detailLabel, detail: detail))
                        .font(Theme.ui(13))
                        .foregroundStyle(Theme.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                Rectangle()
                    .fill(Theme.divider)
                    .frame(height: 1)
                    .padding(.top, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// "The Catch · It must make no sound." — or the detail alone when its
    /// discipline has no label.
    static func detailLine(label: String?, detail: String) -> String {
        guard let label, !label.isEmpty else { return detail }
        return "\(label) · \(detail)"
    }

    @ViewBuilder
    private func voiceNote(file: String) -> some View {
        if let url = AttachmentStore.live.url(forFile: file) {
            Button {
                player.toggle(url: url)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.primaryLabel)
                        .frame(width: 26, height: 26)
                        .background(Theme.primaryFill, in: .circle)
                    Text(player.isPlaying ? "Pause voice note" : "Play voice note")
                        .font(Theme.ui(13, .medium))
                        .foregroundStyle(Theme.inkSecondary)
                }
                .padding(.leading, 6)
                .padding(.trailing, 16)
                .padding(.vertical, 5)
                .background(Theme.surface, in: .rect(cornerRadius: Theme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusMedium)
                        .strokeBorder(Theme.divider, lineWidth: 1)
                )
                .contentShape(.rect(cornerRadius: Theme.radiusMedium))
                .hoverHighlight(cornerRadius: Theme.radiusMedium)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.isPlaying ? "Pause voice note" : "Play voice note")
        } else {
            Label("This entry's voice note file is missing.", systemImage: "waveform.slash")
                .font(Theme.ui(12))
                .foregroundStyle(Theme.inkTertiary)
        }
    }
}
