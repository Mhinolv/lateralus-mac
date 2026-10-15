import SwiftData
import SwiftUI

@main
struct LateralusApp: App {
    @State private var persistence = PersistenceController(
        inMemory: ProcessInfo.processInfo.arguments.contains("--ui-test-in-memory")
    )

    var body: some Scene {
        WindowGroup(id: "main") {
            Group {
                if let container = persistence.container {
                    RootView()
                        .modelContainer(container)
                } else {
                    RecoveryView(details: persistence.errorMessage, retry: persistence.load)
                }
            }
            .preferredColorScheme(.light)
        }
        .defaultSize(width: 1120, height: 720)
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            LateralusCommands()
        }
    }
}

/// Menu bar commands, acting on whichever window is key via `FocusedValues`.
/// A window without a live `RootView` (e.g. the recovery screen) publishes no
/// value, so every model-mutating item disables itself automatically.
struct LateralusCommands: Commands {
    @FocusedValue(\.appModel) private var appModel
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Diary Entry") {
                appModel?.showDiaryComposer = true
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(appModel == nil)

            Divider()

            Button("New Window") {
                openWindow(id: "main")
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Divider()

            // No shortcut: ⌘E is the system "Use Selection for Find".
            Button("Export Archive…") {
                appModel?.pendingArchiveExport = true
            }
            .disabled(!(appModel?.canExportArchive ?? false))
        }
        CommandGroup(after: .pasteboard) {
            Button("Find in Journal") {
                appModel?.select(.journal)
                appModel?.pendingSearchFocus = true
            }
            .keyboardShortcut("f", modifiers: .command)
            .disabled(appModel == nil)
        }
        CommandGroup(after: .toolbar) {
            Button(appModel?.isSidebarVisible ?? true ? "Hide Sidebar" : "Show Sidebar") {
                appModel?.toggleSidebar()
            }
            .keyboardShortcut("s", modifiers: [.command, .control])
            .disabled(appModel == nil)
        }
        CommandMenu("Go") {
            Button("Today") { appModel?.select(.today) }
                .keyboardShortcut("1", modifiers: .command)
                .disabled(appModel == nil)
            Button("Journal") { appModel?.select(.journal) }
                .keyboardShortcut("2", modifiers: .command)
                .disabled(appModel == nil)
            Button("Insights") { appModel?.select(.insights) }
                .keyboardShortcut("3", modifiers: .command)
                .disabled(appModel == nil)
            Divider()
            ForEach(Exercise.practice) { exercise in
                Button(exercise.title) { appModel?.select(.practice(exercise)) }
                    .disabled(appModel == nil)
            }
        }
    }
}

/// Shown instead of the UI when the journal store can't open. Existing
/// data is never deleted to "fix" a launch.
private struct RecoveryView: View {
    let details: String?
    let retry: () -> Void

    var body: some View {
        ZStack {
            AppBackground()
                .gesture(WindowDragGesture())
            VStack(spacing: 0) {
                // A ring, not a warning triangle. The store failing to open
                // is a recoverable hiccup, and the screen's whole job is to
                // say so before it says anything else.
                Circle()
                    .strokeBorder(Theme.accent, lineWidth: 3)
                    .frame(width: 20, height: 20)
                    .frame(width: 56, height: 56)
                    .background(Theme.accentSoft, in: .circle)
                    .padding(.bottom, 28)

                Text("Journal unavailable")
                    .font(Theme.display(30))
                    .foregroundStyle(Theme.ink)
                    .padding(.bottom, 14)

                Text("Nothing was deleted. Lateralus couldn't open your journal file this time — try again, or check the detail below if it keeps happening.")
                    .font(Theme.ui(16))
                    .lineSpacing(5)
                    .foregroundStyle(Theme.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 440)
                    .padding(.bottom, 32)

                Button(action: retry) {
                    PrimaryActionButtonLabel(title: "Try Again")
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)

                if let details, !details.isEmpty {
                    Text(details)
                        .font(Theme.mono(12, .regular))
                        .foregroundStyle(Theme.inkTertiary)
                        .textSelection(.enabled)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.surface, in: .rect(cornerRadius: Theme.radiusSmall))
                        .padding(.top, 28)
                }
            }
            .frame(maxWidth: 640)
            .padding(48)
        }
        .frame(minWidth: 640, minHeight: 420)
    }
}
