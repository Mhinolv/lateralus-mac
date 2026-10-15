import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appModel = AppModel()
    @State private var appNow = Date.now

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
