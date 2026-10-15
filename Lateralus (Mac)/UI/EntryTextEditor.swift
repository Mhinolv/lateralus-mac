import SwiftUI

/// An open edit of one saved response. Comparisons ignore leading and
/// trailing whitespace, because Save trims it away.
struct ResponseEdit: Equatable {
    let original: String
    var text: String

    init(original: String) {
        self.original = original
        self.text = original
    }

    var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Unsaved work the navigation guards protect.
    var hasChanges: Bool {
        trimmed != original.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSave: Bool {
        hasChanges && !trimmed.isEmpty
    }
}

/// The inline editor that replaces a saved response in the reading pane,
/// with Cancel and Save below it. ⌘S saves, Escape cancels.
struct EntryTextEditor: View {
    @Binding var edit: ResponseEdit
    let onCancel: () -> Void
    let onSave: () -> Void

    @FocusState private var focused: Bool

    /// The response type, shared with the reading pane so an edit does not
    /// reflow the text.
    static let responseFont = Theme.display(18, weight: .regular)
    static let responseLineSpacing: CGFloat = 8

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            TextEditor(text: $edit.text)
                .focused($focused)
                .scrollContentBackground(.hidden)
                .font(Self.responseFont)
                .lineSpacing(Self.responseLineSpacing)
                .foregroundStyle(Theme.ink)
                .padding(8)
                .frame(minHeight: 160)
                .inputWell(fill: Theme.surface)
                .accessibilityIdentifier("detail-edit-text")

            HStack(spacing: 12) {
                Button(action: onCancel) {
                    SecondaryActionButtonLabel(title: "Cancel")
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("detail-edit-cancel")
                .help("Discard the changes (Esc)")

                Button(action: onSave) {
                    PrimaryActionButtonLabel(title: "Save", enabled: edit.canSave)
                }
                .buttonStyle(.plain)
                .disabled(!edit.canSave)
                .keyboardShortcut("s", modifiers: .command)
                .accessibilityIdentifier("detail-edit-save")
                .help("Save the response (⌘S)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .onAppear { focused = true }
    }
}

struct EntryTextEditor_Previews: PreviewProvider {
    static var previews: some View {
        EntryTextEditor(
            edit: .constant(ResponseEdit(original: "A place that recognizes you.")),
            onCancel: {},
            onSave: {}
        )
        .padding(40)
        .frame(width: 640)
        .background(Theme.background)
    }
}
