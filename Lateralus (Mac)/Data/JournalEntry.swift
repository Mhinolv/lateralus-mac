import Foundation
import SwiftData

/// Version 1 of the journal schema. This declaration is frozen: future
/// model changes belong in a new `VersionedSchema` plus a migration stage.
enum LateralusSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [JournalEntry.self] }

    /// One saved response. Voice notes live as files in the attachment
    /// store; the database owns only their stable filenames. Sketch data is
    /// small enough to live in the row (externalized by SwiftData).
    @Model
    final class JournalEntry {
        var id: UUID = UUID()
        var date: Date = Date()
        var exerciseRaw: String = Exercise.diary.rawValue
        var promptHeadline: String = ""
        var promptDetail: String?
        var responseText: String = ""
        /// Reserved: favorites are not currently surfaced in the UI, but
        /// the column stays so the frozen V1 schema never has to change.
        var isFavorite: Bool = false
        var isDaily: Bool = false
        /// Filename inside the attachment store's VoiceNotes directory.
        var voiceNoteFile: String?
        /// Encoded `Sketch`, if the user drew one.
        @Attribute(.externalStorage) var sketchData: Data?

        init(prompt: Prompt, responseText: String, isDaily: Bool, date: Date = .now) {
            self.id = UUID()
            self.date = date
            self.exerciseRaw = prompt.exercise.rawValue
            self.promptHeadline = prompt.headline
            self.promptDetail = prompt.detail
            self.responseText = responseText
            self.isDaily = isDaily
        }

        /// Identifiers written by a future schema stay visible as an
        /// explicit fallback instead of crashing or masquerading.
        var exercise: Exercise { Exercise(rawValue: exerciseRaw) ?? .unknown }

        var prompt: Prompt {
            Prompt(exercise: exercise, headline: promptHeadline, detail: promptDetail)
        }
    }
}

/// App-facing alias; the schema snapshot behind it stays immutable.
typealias JournalEntry = LateralusSchemaV1.JournalEntry

enum LateralusMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [LateralusSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
