import Foundation
import SwiftData

/// Every journal write goes through here so database rows and attachment
/// files can't drift apart: the voice note is committed first and rolled
/// back if the database save fails.
struct EntryRepository {
    let context: ModelContext
    let attachments: AttachmentStore
    /// Writes pending edits to the store. Tests replace it to force a failure.
    var commitChanges: (ModelContext) throws -> Void = { try $0.save() }
    /// True while an archive restore runs in any window. Every write then
    /// fails with `restoreInProgress`.
    var isLocked: () -> Bool = { ArchiveRestoreStatus.shared.isBusy }

    init(context: ModelContext, attachments: AttachmentStore = .live) {
        self.context = context
        self.attachments = attachments
    }

    @discardableResult
    func save(
        prompt: Prompt,
        responseText: String,
        isDaily: Bool,
        temporaryVoiceNoteURL: URL?,
        sketchData: Data?,
        date: Date = .now
    ) throws -> JournalEntry {
        guard !isLocked() else { throw EntryRepositoryError.restoreInProgress }
        let entry = JournalEntry(prompt: prompt, responseText: responseText, isDaily: isDaily, date: date)
        entry.sketchData = sketchData

        var committedFile: String?
        if let temporaryVoiceNoteURL {
            committedFile = try attachments.commit(temporaryURL: temporaryVoiceNoteURL)
            entry.voiceNoteFile = committedFile
        }

        context.insert(entry)
        do {
            try context.save()
        } catch {
            context.delete(entry)
            if let committedFile {
                attachments.remove(file: committedFile)
            }
            throw error
        }
        return entry
    }

    /// Replaces the response text of a saved entry. The date and the
    /// attachments stay, so an edit never counts as new activity. If the
    /// save fails, the entry keeps its original text.
    func updateResponseText(of entry: JournalEntry, to newText: String) throws {
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw EntryRepositoryError.emptyResponse }
        guard !isLocked() else { throw EntryRepositoryError.restoreInProgress }
        let original = entry.responseText
        entry.responseText = trimmed
        do {
            try commitChanges(context)
        } catch {
            entry.responseText = original
            throw error
        }
    }

    func delete(_ entry: JournalEntry) throws {
        guard !isLocked() else { throw EntryRepositoryError.restoreInProgress }
        let file = entry.voiceNoteFile
        context.delete(entry)
        try context.save()
        if let file {
            attachments.remove(file: file)
        }
    }

    /// Adds every entry of a validated archive in one transaction. A
    /// private context without autosave holds the new rows, so nothing is
    /// visible until the single save at the end. If any step fails, the
    /// rows are dropped and every copied voice note is removed.
    func restore(
        _ plan: JournalArchive.RestorePlan,
        progress: (_ completed: Int) -> Void = { _ in }
    ) async throws {
        let restoreContext = ModelContext(context.container)
        restoreContext.autosaveEnabled = false
        guard try restoreContext.fetchCount(FetchDescriptor<JournalEntry>()) == 0 else {
            throw JournalArchive.RestoreError.journalNotEmpty
        }

        let store = attachments
        var copiedFiles: [String] = []
        do {
            for (index, archived) in plan.entries.enumerated() {
                let entry = JournalEntry(
                    prompt: Prompt(exercise: .unknown, headline: archived.promptHeadline, detail: archived.promptDetail),
                    responseText: archived.responseText,
                    isDaily: archived.isDaily,
                    date: archived.date
                )
                entry.id = archived.id
                // Keep the raw value, so a discipline from a newer build survives.
                entry.exerciseRaw = archived.exercise
                entry.isFavorite = archived.isFavorite

                let sketchURL = archived.sketchFile.map { plan.root.appending(path: $0) }
                let voiceNoteURL = archived.voiceNoteFile.map { plan.root.appending(path: $0) }
                let (sketchData, voiceNoteFile) = try await Task.detached(priority: .userInitiated) {
                    try (
                        sketchURL.map { try Data(contentsOf: $0) },
                        voiceNoteURL.map { try store.commitCopy(of: $0) }
                    )
                }.value
                if let voiceNoteFile {
                    copiedFiles.append(voiceNoteFile)
                }
                entry.sketchData = sketchData
                entry.voiceNoteFile = voiceNoteFile

                restoreContext.insert(entry)
                progress(index + 1)
            }
            try commitChanges(restoreContext)
        } catch {
            restoreContext.rollback()
            copiedFiles.forEach(attachments.remove)
            throw error
        }
    }

    /// Startup reconciliation: clears references to attachment files that
    /// vanished, then sweeps files no entry references.
    func reconcileAttachments() throws {
        let entries = try context.fetch(FetchDescriptor<JournalEntry>())
        var referenced: Set<String> = []
        for entry in entries {
            guard let file = entry.voiceNoteFile else { continue }
            if attachments.url(forFile: file) == nil {
                entry.voiceNoteFile = nil
            } else {
                referenced.insert(file)
            }
        }
        if context.hasChanges {
            try context.save()
        }
        attachments.sweepOrphans(referencedFiles: referenced)
    }
}

enum EntryRepositoryError: LocalizedError {
    case emptyResponse
    case restoreInProgress

    var errorDescription: String? {
        switch self {
        case .emptyResponse: "A response can’t be empty."
        case .restoreInProgress: "Lateralus is restoring an archive. Try again when it ends."
        }
    }
}
