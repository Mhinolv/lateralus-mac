import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appModel = AppModel()
    @State private var appNow = Date.now
    @Query private var entries: [JournalEntry]

    var body: some View {
        ZStack {
            AppBackground()
            HStack(spacing: 0) {
                if appModel.isSidebarVisible {
                    SideBar()
                        .transition(.move(edge: .leading))
                }
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .safeAreaInset(edge: .top, spacing: 0) {
                        if !appModel.isSidebarVisible {
                            // The sidebar's background is the only window-drag
                            // surface (hidden title bar); replace it while collapsed.
                            Color.clear
                                .frame(height: 36)
                                .contentShape(.rect)
                                .gesture(WindowDragGesture())
                        }
                    }
            }
            // Critically damped (no bounce) — this is a reposition, not a flick,
            // so it should settle calmly rather than overshoot.
            .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 1.0), value: appModel.isSidebarVisible)
        }
        .frame(minWidth: 900, minHeight: 620)
        .environment(appModel)
        .focusedSceneValue(\.appModel, appModel)
        .environment(\.appNow, appNow)
        .task {
            try? EntryRepository(context: modelContext).reconcileAttachments()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            appNow = .now
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            appNow = .now
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            appNow = .now
        }
        .sheet(isPresented: $appModel.showDiaryComposer) {
            DiaryComposer()
                .environment(\.appNow, appNow)
        }
        .confirmationDialog(
            "Discard this response?",
            isPresented: $appModel.showDiscardNavigationDialog,
            titleVisibility: .visible
        ) {
            Button("Discard Response", role: .destructive) {
                appModel.confirmPendingSelection()
            }
            Button("Keep Editing", role: .cancel) {
                appModel.cancelPendingSelection()
            }
        } message: {
            Text("You have unsaved work in this session. Leaving now will throw it away.")
        }
        .onChange(of: entries.count, initial: true) { _, count in
            appModel.journalEntryCount = count
        }
        .onChange(of: appModel.pendingArchiveExport) { _, pending in
            guard pending else { return }
            appModel.pendingArchiveExport = false
            // Leave the menu action before the panel runs its modal loop.
            Task { await exportArchive() }
        }
        .alert(
            Text(appModel.archiveExportResult?.title ?? ""),
            isPresented: Binding(
                get: { appModel.archiveExportResult != nil },
                set: { if !$0 { appModel.archiveExportResult = nil } }
            ),
            presenting: appModel.archiveExportResult
        ) { result in
            if case .success(let url, _) = result {
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
            Button("OK") {}
                .keyboardShortcut(.defaultAction)
        } message: { result in
            Text(result.message)
        }
    }

    private func exportArchive() async {
        guard appModel.canExportArchive else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export"
        panel.message = "Choose a folder for the journal archive."
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        await appModel.exportArchive(entries, into: folder)
    }

    @ViewBuilder
    private var detail: some View {
        switch appModel.selection {
        case .today:
            TodayView()
        case .journal:
            JournalView()
        case .insights:
            InsightsView()
        case .practice(let exercise):
            PracticeContainer(exercise: exercise)
        }
    }
}

/// Hosts a practice session and deals a fresh prompt each time the
/// discipline (or session round) changes.
private struct PracticeContainer: View {
    let exercise: Exercise
    @State private var round = 0

    var body: some View {
        SessionView(
            prompt: PromptEngine.practice(exercise),
            isDaily: false,
            onNewPrompt: { round += 1 }
        )
        .id("\(exercise.rawValue)-\(round)")
    }
}

private struct AppNowKey: EnvironmentKey {
    static let defaultValue = Date.now
}

extension EnvironmentValues {
    /// The moment the UI believes it is "now" — refreshed on day rollover,
    /// timezone changes, and app activation so the daily challenge stays
    /// honest without polling.
    var appNow: Date {
        get { self[AppNowKey.self] }
        set { self[AppNowKey.self] = newValue }
    }
}
