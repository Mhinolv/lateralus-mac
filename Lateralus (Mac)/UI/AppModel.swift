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

    /// Kept current by RootView so the Export Archive command can disable
    /// itself for an empty journal.
    var journalEntryCount = 0

    /// Set by the Export Archive command; consumed by RootView, which owns
    /// the model context.
    var pendingArchiveExport = false
    private(set) var isExportingArchive = false
    var archiveExportResult: ArchiveExportResult?

    var canExportArchive: Bool { journalEntryCount > 0 && !isExportingArchive }

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

    /// Copies the entries on the main actor, then writes the archive off it.
    func exportArchive(_ entries: [JournalEntry], into folder: URL, attachments: AttachmentStore = .live) async {
        guard !isExportingArchive else { return }
        isExportingArchive = true
        defer { isExportingArchive = false }

        let sources = JournalArchive.sources(for: entries, attachments: attachments)
        do {
            let url = try await Task.detached(priority: .userInitiated) {
                try JournalArchive.export(sources, into: folder)
            }.value
            archiveExportResult = .success(url: url, entryCount: sources.count)
        } catch {
            archiveExportResult = .failure(message: error.localizedDescription)
        }
    }
}

/// The outcome shown in the alert after File > Export Archive….
enum ArchiveExportResult: Equatable {
    case success(url: URL, entryCount: Int)
    case failure(message: String)

    var title: String {
        switch self {
        case .success: "Archive Exported"
        case .failure: "Couldn’t Export Archive"
        }
    }

    var message: String {
        switch self {
        case .success(let url, let entryCount):
            let entries = entryCount == 1 ? "1 entry" : "\(entryCount) entries"
            let name = FileManager.default.displayName(atPath: url.path(percentEncoded: false))
            return "Saved \(entries) to “\(name)”."
        case .failure(let message):
            return message
        }
    }
}

extension FocusedValues {
    /// Published by the key window's RootView so menu commands act on it.
    @Entry var appModel: AppModel?
}
