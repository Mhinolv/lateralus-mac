import SwiftData
import XCTest
@testable import Lateralus__Mac_

@MainActor
final class QuickDiaryModelTests: XCTestCase {

    private struct ForcedSaveFailure: Error {}

    private var container: ModelContainer!
    private var context: ModelContext!
    private var storeRoot: URL!

    override func setUp() async throws {
        container = try ModelContainer(
            for: JournalEntry.self,
            migrationPlan: LateralusMigrationPlan.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
        storeRoot = FileManager.default.temporaryDirectory
            .appending(path: "quick-diary-\(UUID().uuidString)")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: storeRoot)
    }

    private var repository: EntryRepository {
        var repository = EntryRepository(context: context, attachments: AttachmentStore(voiceNotesDirectory: storeRoot))
        repository.isLocked = { false }
        return repository
    }

    private func fetchAll() throws -> [JournalEntry] {
        try context.fetch(FetchDescriptor<JournalEntry>())
    }

    func testSaveCreatesTextOnlyDiaryEntry() throws {
        let model = QuickDiaryModel()
        model.text = "  A door that opens inward.\n"
        model.save(with: repository)

        let entries = try fetchAll()
        XCTAssertEqual(entries.count, 1)
        let entry = try XCTUnwrap(entries.first)
        XCTAssertEqual(entry.exercise, .diary)
        XCTAssertEqual(entry.responseText, "A door that opens inward.")
        XCTAssertFalse(entry.isDaily)
        XCTAssertNil(entry.voiceNoteFile)
        XCTAssertNil(entry.sketchData)
    }

    func testSaveClearsTextAndShowsSaved() {
        let model = QuickDiaryModel()
        model.text = "Idea"
        model.save(with: repository)
        XCTAssertEqual(model.text, "")
        XCTAssertEqual(model.status, .saved)
        XCTAssertEqual(model.status.message, "Saved to Journal")
        XCTAssertFalse(model.canSave)
    }

    func testEmptyOrBlankTextCannotSave() throws {
        let model = QuickDiaryModel()
        for blank in ["", " ", "\n\t \n"] {
            model.text = blank
            XCTAssertFalse(model.canSave)
            model.save(with: repository)
        }
        XCTAssertEqual(try fetchAll().count, 0)
        XCTAssertEqual(model.status, .none)
    }

    func testFailedSaveKeepsText() throws {
        let model = QuickDiaryModel()
        model.text = "Keep me"
        var failing = repository
        failing.commitChanges = { _ in throw ForcedSaveFailure() }
        model.save(with: failing)

        XCTAssertEqual(model.text, "Keep me")
        XCTAssertEqual(model.status, .failed)
        XCTAssertEqual(model.status.message, "Couldn’t save. Try again.")
        XCTAssertEqual(try fetchAll().count, 0, "A failed save must not leave a row")
    }

    func testSaveDuringRestoreKeepsText() throws {
        let model = QuickDiaryModel()
        model.text = "Wait for restore"
        var locked = repository
        locked.isLocked = { true }
        model.save(with: locked)

        XCTAssertEqual(model.text, "Wait for restore")
        XCTAssertEqual(model.status, .failed)
        XCTAssertEqual(try fetchAll().count, 0)
    }

    func testRetryAfterFailureSaves() throws {
        let model = QuickDiaryModel()
        model.text = "Second try"
        var failing = repository
        failing.commitChanges = { _ in throw ForcedSaveFailure() }
        model.save(with: failing)
        model.save(with: repository)

        XCTAssertEqual(model.text, "")
        XCTAssertEqual(model.status, .saved)
        XCTAssertEqual(try fetchAll().map(\.responseText), ["Second try"])
    }

    func testSavedStatusClearsButFailedStays() {
        let model = QuickDiaryModel()
        model.text = "One"
        model.save(with: repository)
        model.clearSavedStatus()
        XCTAssertEqual(model.status, .none)

        model.text = "Two"
        var failing = repository
        failing.commitChanges = { _ in throw ForcedSaveFailure() }
        model.save(with: failing)
        model.clearSavedStatus()
        XCTAssertEqual(model.status, .failed)
    }

    func testEverySaveChangesSaveCount() {
        let model = QuickDiaryModel()
        model.text = "One"
        model.save(with: repository)
        model.text = "Two"
        model.save(with: repository)
        XCTAssertEqual(model.saveCount, 2)
    }
}
