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
        let file = entry.voiceNoteFile
        context.delete(entry)
        try context.save()
        if let file {
            attachments.remove(file: file)
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

    var errorDescription: String? {
        switch self {
        case .emptyResponse: "A response can’t be empty."
        }
    }
}
