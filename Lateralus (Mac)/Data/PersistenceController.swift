import Foundation
import SwiftData

/// Opens the journal store, keeping failures survivable: if the container
/// can't open, the app shows a recovery screen instead of crashing, and
/// existing data is never deleted to "fix" a launch.
@Observable
final class PersistenceController {
    private(set) var container: ModelContainer?
    private(set) var errorMessage: String?

    init(inMemory: Bool = false) {
        self.inMemory = inMemory
        load()
    }

    private let inMemory: Bool

    /// Nonisolated for the same reason as `AppModel.deinit` (#17).
    nonisolated deinit {}

    func load() {
        do {
            let configuration = ModelConfiguration(
                schema: Schema(versionedSchema: LateralusSchemaV1.self),
                isStoredInMemoryOnly: inMemory
            )
            container = try ModelContainer(
                for: JournalEntry.self,
                migrationPlan: LateralusMigrationPlan.self,
                configurations: configuration
            )
            errorMessage = nil
        } catch {
            container = nil
            errorMessage = error.localizedDescription
        }
    }
}
