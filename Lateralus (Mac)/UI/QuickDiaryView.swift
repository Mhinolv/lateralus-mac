import AppKit
import SwiftData
import SwiftUI

/// The text of the menu bar composer and the result of the last save. The
/// app owns one for its life, so text stays when the panel closes.
@Observable
final class QuickDiaryModel {
    enum Status: Equatable {
        case none
        case saved
        case failed

        var message: String? {
            switch self {
            case .none: nil
            case .saved: "Saved to Journal"
            case .failed: "Couldn’t save. Try again."
            }
        }
    }

    var text = ""
    private(set) var status: Status = .none
    /// Changes on every save, so the view restarts the 2 s timer for
    /// `Saved to Journal` after each save.
    private(set) var saveCount = 0

    /// Nonisolated for the same reason as `AppModel.deinit` (#17).
    nonisolated deinit {}

    var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Saves the text as a text-only Diary entry. A success clears the text.
    /// A failure keeps it, so the user can try again.
    func save(with repository: EntryRepository) {
        guard canSave else { return }
        saveCount += 1
        do {
            try repository.save(
                prompt: Prompt(exercise: .diary, headline: "Diary", detail: nil),
                responseText: text.trimmingCharacters(in: .whitespacesAndNewlines),
                isDaily: false,
                temporaryVoiceNoteURL: nil,
                sketchData: nil
            )
            text = ""
            status = .saved
        } catch {
            status = .failed
        }
    }

    /// Removes `Saved to Journal` when its time ends. A failure message stays.
    func clearSavedStatus() {
        if status == .saved { status = .none }
    }
}

/// The panel of the menu bar item: a quick, text-only Diary entry. It uses
/// the app's store directly, so it saves with no main window open.
struct QuickDiaryView: View {
    let model: QuickDiaryModel
    let container: ModelContainer?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @FocusState private var editorFocused: Bool

    private var isRestoring: Bool { ArchiveRestoreStatus.shared.isBusy }

    private var statusLine: (text: String, color: Color)? {
        if container == nil {
            return ("Journal unavailable. Open Lateralus for details.", Theme.accentStrong)
        }
        if isRestoring {
            return (ArchiveRestoreStatus.shared.title, Theme.inkTertiary)
        }
        guard let message = model.status.message else { return nil }
        return (message, model.status == .failed ? Theme.accentStrong : Theme.inkTertiary)
    }

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 12) {
            Label("Diary", systemImage: Exercise.diary.symbol)
                .font(Theme.display(15))
                .foregroundStyle(Theme.ink)

            ZStack(alignment: .topLeading) {
                if model.text.isEmpty {
                    Text("Whatever's on your mind…")
                        .font(Theme.ui(14))
                        .foregroundStyle(Theme.inkTertiary)
                        .padding(.top, 14)
                        .padding(.leading, 14)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $model.text)
                    .focused($editorFocused)
                    .scrollContentBackground(.hidden)
                    .font(Theme.ui(14))
                    .lineSpacing(4)
                    .foregroundStyle(Theme.ink)
                    .padding(8)
            }
            .frame(height: 120)
            .inputWell(fill: Theme.surface)
            .disabled(container == nil)

            if let statusLine {
                Text(statusLine.text)
                    .font(Theme.ui(12))
                    .foregroundStyle(statusLine.color)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button("Open Lateralus") { openMainWindow() }
                    .buttonStyle(.plain)
                    .font(Theme.ui(13))
                    .foregroundStyle(Theme.inkSecondary)
                Spacer()
                Button {
                    save()
                } label: {
                    PrimaryActionButtonLabel(title: "Save", enabled: saveEnabled)
                }
                .buttonStyle(.plain)
                .disabled(!saveEnabled)
                .keyboardShortcut("s", modifiers: .command)
                .help("Save to journal (⌘S)")
            }
        }
        .padding(16)
        .frame(width: 320)
        .background(AppBackground())
        .background {
            // Escape closes the panel. A key equivalent reaches the button
            // before the text editor can use the key.
            Button("Close") { dismiss() }
                .keyboardShortcut(.cancelAction)
                .opacity(0)
                .accessibilityHidden(true)
        }
        .preferredColorScheme(.light)
        .onAppear { editorFocused = true }
        .task(id: model.saveCount) {
            guard model.status == .saved else { return }
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            model.clearSavedStatus()
        }
    }

    private var saveEnabled: Bool {
        container != nil && !isRestoring && model.canSave
    }

    private func save() {
        guard saveEnabled, let container else { return }
        model.save(with: EntryRepository(context: container.mainContext))
        editorFocused = true
    }

    /// Brings an open main window to the front. Opens one if none is open.
    private func openMainWindow() {
        NSApp.activate()
        let existing = NSApp.windows.first { window in
            window.identifier?.rawValue.hasPrefix("main") == true
                && (window.isVisible || window.isMiniaturized)
        }
        if let existing {
            if existing.isMiniaturized { existing.deminiaturize(nil) }
            existing.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }
        dismiss()
    }
}

/// Lateralus > Settings… (⌘,). The first settings window: future settings
/// go here too.
struct SettingsView: View {
    @AppStorage(SettingsKey.showMenuBarComposer) private var showMenuBarComposer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Show in menu bar", isOn: $showMenuBarComposer)
                .font(Theme.ui(14))
                .foregroundStyle(Theme.ink)
                .tint(Theme.accent)
            Text("Write a quick diary entry from the menu bar.")
                .font(Theme.ui(12))
                .foregroundStyle(Theme.inkTertiary)
        }
        .padding(24)
        .frame(width: 380, alignment: .leading)
        .background(AppBackground())
        .preferredColorScheme(.light)
    }
}

enum SettingsKey {
    static let showMenuBarComposer = "showMenuBarComposer"
}

struct QuickDiaryView_Previews: PreviewProvider {
    static var previews: some View {
        QuickDiaryView(model: QuickDiaryModel(), container: nil)
        SettingsView()
    }
}
