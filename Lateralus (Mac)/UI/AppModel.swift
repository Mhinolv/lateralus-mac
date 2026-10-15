import Foundation
import Observation
import SwiftUI

/// Where the window can be. Practice sessions live in the detail pane, so
/// navigation itself is what can destroy unsaved work — the model guards it.
enum SidebarItem: Hashable {
    case today
    case journal
    case insights
    case practice(Exercise)
}

/// Window-level navigation and cross-cutting UI state, shared with the
/// menu bar commands via `FocusedValues.appModel`. One instance per window.
@Observable
final class AppModel {
    var showDiaryComposer = false

    /// The active session's unsaved-content flag. Registered by whichever
    /// session view is on screen.
    var sessionHasUnsavedWork = false

    private(set) var selection: SidebarItem = .today
    var pendingSelection: SidebarItem?
    var showDiscardNavigationDialog = false

    /// Persisted across windows and launches; each window starts from the
    /// last chosen value but can diverge afterward.
    var isSidebarVisible = UserDefaults.standard.object(forKey: "sidebarVisible") as? Bool ?? true

    /// Set by the Find menu command; consumed by JournalView once its
    /// search field exists to focus.
    var pendingSearchFocus = false

    func toggleSidebar() {
        isSidebarVisible.toggle()
        UserDefaults.standard.set(isSidebarVisible, forKey: "sidebarVisible")
    }

    /// Navigation entry point: honors the unsaved-work guard.
    func select(_ item: SidebarItem) {
        guard item != selection else { return }
        if sessionHasUnsavedWork {
            pendingSelection = item
            showDiscardNavigationDialog = true
        } else {
            selection = item
        }
    }

    /// The user confirmed discarding the in-progress response.
    func confirmPendingSelection() {
        sessionHasUnsavedWork = false
        if let pendingSelection {
            selection = pendingSelection
        }
        pendingSelection = nil
    }

    func cancelPendingSelection() {
        pendingSelection = nil
    }
}

extension FocusedValues {
    /// Published by the key window's RootView so menu commands act on it.
    @Entry var appModel: AppModel?
}
