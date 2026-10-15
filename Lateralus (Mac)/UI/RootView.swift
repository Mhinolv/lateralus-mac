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
            }
            // Critically damped (no bounce) — this is a reposition, not a flick,
            // so it should settle calmly rather than overshoot.
            .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 1.0), value: appModel.isSidebarVisible)
        }
        .overlay {
            // The window that runs the restore shows its own sheet instead.
            if appModel.restoreStatus.isBusy && !appModel.ownsArchiveRestore {
                ArchiveRestoreScrim(status: appModel.restoreStatus)
            }
        }
        .frame(minWidth: 900, minHeight: 620)
        .toolbar { toolbarItems }
        .toolbarBackground(Theme.background, for: .windowToolbar)
        .environment(appModel)
        .focusedSceneValue(\.appModel, appModel)
        .environment(\.appNow, appNow)
        .task {
            // A restore copies voice notes before their rows exist. A window
            // opened then must not sweep them as orphans.
            guard !appModel.restoreStatus.isBusy else { return }
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
        .onChange(of: appModel.pendingArchiveRestore) { _, pending in
            guard pending else { return }
            appModel.pendingArchiveRestore = false
            // Leave the menu action before the panel runs its modal loop.
            Task { await restoreArchive() }
        }
        .sheet(isPresented: Binding(
            get: { appModel.ownsArchiveRestore && appModel.restoreStatus.isBusy },
            set: { _ in }
        )) {
            ArchiveRestoreSheet(status: appModel.restoreStatus)
                .interactiveDismissDisabled()
        }
        .alert(
            Text(appModel.archiveRestorePlan?.confirmTitle ?? ""),
            isPresented: Binding(
                get: { appModel.archiveRestorePlan != nil },
                set: { if !$0 { appModel.archiveRestorePlan = nil } }
            ),
            presenting: appModel.archiveRestorePlan
        ) { plan in
            Button("Restore") {
                Task {
                    await appModel.restoreArchive(plan, repository: EntryRepository(context: modelContext))
                }
            }
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) {}
        } message: { plan in
            Text(plan.confirmMessage)
        }
        .alert(
            Text(appModel.archiveRestoreResult?.title ?? ""),
            isPresented: Binding(
                get: { appModel.archiveRestoreResult != nil },
                set: { if !$0 { appModel.archiveRestoreResult = nil } }
            ),
            presenting: appModel.archiveRestoreResult
        ) { _ in
            Button("OK") {}
                .keyboardShortcut(.defaultAction)
        } message: { result in
            Text(result.message)
        }
    }

    private func restoreArchive() async {
        guard appModel.canRestoreArchive else { return }
        let panel = NSOpenPanel()
        let delegate = ArchiveOpenPanelDelegate()
        panel.delegate = delegate
        panel.title = "Restore Archive"
        panel.prompt = "Restore"
        panel.canChooseFiles = true
        // A team build's archive type may not be registered, so Finder
        // treats the package as a folder. Folders must stay choosable.
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        let response = withExtendedLifetime(delegate) { panel.runModal() }
        guard response == .OK, let url = panel.url else { return }
        await appModel.checkArchive(at: url)
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

    /// Sidebar toggle first, New Diary Entry always last. Screen items go
    /// between them. System buttons give hover, press and disabled states.
    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                appModel.toggleSidebar()
            } label: {
                Label(appModel.isSidebarVisible ? "Hide Sidebar" : "Show Sidebar", systemImage: "sidebar.left")
            }
            .help("Show or hide the sidebar (⌃⌘S)")
            .accessibilityIdentifier("toolbar-sidebar")
        }
        if appModel.canDealNewPrompt {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appModel.pendingNewPrompt = true
                } label: {
                    Label("New Prompt", systemImage: "arrow.triangle.2.circlepath")
                        .labelStyle(.iconOnly)
                }
                .keyboardShortcut("r", modifiers: .command)
                .help("Deal another prompt (⌘R)")
                .accessibilityIdentifier("session-new-prompt")
                .disabled(appModel.restoreStatus.isBusy)
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                appModel.showDiaryComposer = true
            } label: {
                Label("New Diary Entry", systemImage: "square.and.pencil")
                    .labelStyle(.iconOnly)
            }
            .help("New diary entry (⌘N)")
            .accessibilityIdentifier("toolbar-diary")
            .disabled(appModel.restoreStatus.isBusy)
        }
    }

    /// Today sets its own title because a daily session replaces it in place.
    @ViewBuilder
    private var detail: some View {
        switch appModel.selection {
        case .today:
            TodayView()
        case .journal:
            JournalView()
                .navigationTitle(SidebarItem.journal.title)
        case .insights:
            InsightsView()
                .navigationTitle(SidebarItem.insights.title)
        case .practice(let exercise):
            PracticeContainer(exercise: exercise)
                .navigationTitle(SidebarItem.practice(exercise).title)
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
