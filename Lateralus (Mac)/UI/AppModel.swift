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

    var canExportArchive: Bool {
        journalEntryCount > 0 && !isExportingArchive && !restoreStatus.isBusy
    }

    /// Shared by every window, so all of them block edits during a restore.
    let restoreStatus: ArchiveRestoreStatus

    /// Set by the Restore Archive command or the empty Journal button;
    /// consumed by RootView, which shows the open panel.
    var pendingArchiveRestore = false
    /// True in the one window that runs the restore and shows its sheets.
    private(set) var ownsArchiveRestore = false
    /// A checked archive that waits for the user to confirm.
    var archiveRestorePlan: JournalArchive.RestorePlan?
    var archiveRestoreResult: ArchiveRestoreResult?

    var canRestoreArchive: Bool {
        journalEntryCount == 0 && !isExportingArchive && !restoreStatus.isBusy && archiveRestorePlan == nil
    }

    init(restoreStatus: ArchiveRestoreStatus = .shared) {
        self.restoreStatus = restoreStatus
    }

    /// The default main-actor isolation makes the deinit hop to the main
    /// executor. On macOS 15 that hop aborts the process (#17), and the
    /// deinit touches no state, so keep it nonisolated.
    nonisolated deinit {}

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

    /// Validates the chosen package off the main actor. On success the
    /// confirm alert shows the plan. Nothing is written yet.
    func checkArchive(at url: URL) async {
        guard canRestoreArchive else { return }
        ownsArchiveRestore = true
        restoreStatus.phase = .checking
        defer {
            restoreStatus.phase = nil
            ownsArchiveRestore = false
        }
        do {
            archiveRestorePlan = try await Task.detached(priority: .userInitiated) {
                try JournalArchive.restorePlan(at: url)
            }.value
        } catch {
            archiveRestoreResult = .failure(JournalArchive.RestoreError(error))
        }
    }

    /// Writes the confirmed plan through the repository, then shows the
    /// Journal. A failure keeps nothing.
    func restoreArchive(_ plan: JournalArchive.RestorePlan, repository: EntryRepository) async {
        archiveRestorePlan = nil
        guard !restoreStatus.isBusy else { return }
        let total = plan.entries.count
        ownsArchiveRestore = true
        restoreStatus.phase = .restoring(completed: 0, total: total)
        defer {
            restoreStatus.phase = nil
            ownsArchiveRestore = false
        }
        do {
            try await repository.restore(plan) { completed in
                restoreStatus.phase = .restoring(completed: completed, total: total)
            }
            archiveRestoreResult = .success(entryCount: total)
            select(.journal)
        } catch {
            archiveRestoreResult = .failure(JournalArchive.RestoreError(error))
        }
    }
}

/// The app-wide state of File > Restore Archive…. One restore runs at a
/// time. Every window reads this state to show a scrim and block edits.
@Observable
final class ArchiveRestoreStatus {
    enum Phase: Equatable {
        case checking
        case restoring(completed: Int, total: Int)
    }

    static let shared = ArchiveRestoreStatus()

    var phase: Phase?

    var isBusy: Bool { phase != nil }

    /// Nonisolated for the same reason as `AppModel.deinit` (#17).
    nonisolated deinit {}

    var title: String {
        switch phase {
        case .checking: "Checking archive…"
        case .restoring, nil: "Restoring archive…"
        }
    }

    /// `12 of 42` while entries are written. Nil while checking.
    var progressText: String? {
        guard case .restoring(let completed, let total) = phase else { return nil }
        return "\(completed) of \(total)"
    }

    var accessibilityLabel: String {
        guard let progressText else { return "Checking archive" }
        return "Restoring archive, \(progressText)"
    }
}

extension JournalArchive.RestorePlan {
    var confirmTitle: String {
        "Restore \(entryCount(entries.count))?"
    }

    var confirmMessage: String {
        let attachments = attachmentCount == 1 ? "1 attachment" : "\(attachmentCount) attachments"
        return "Lateralus adds \(entryCount(entries.count)) and \(attachments) from “\(displayName)”."
    }
}

private func entryCount(_ count: Int) -> String {
    count == 1 ? "1 entry" : "\(count) entries"
}

/// The outcome shown in the alert after File > Restore Archive….
enum ArchiveRestoreResult: Equatable {
    case success(entryCount: Int)
    case failure(JournalArchive.RestoreError)

    var title: String {
        switch self {
        case .success: "Archive Restored"
        case .failure: "Couldn’t Restore Archive"
        }
    }

    var message: String {
        switch self {
        case .success(let count):
            count == 1 ? "1 entry is back in your journal." : "\(count) entries are back in your journal."
        case .failure(let error):
            error.errorDescription ?? ""
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
