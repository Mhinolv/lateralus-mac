import SwiftData
import XCTest
@testable import Lateralus__Mac_

@MainActor
final class EntryRepositoryTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var store: AttachmentStore!
    private var storeRoot: URL!

    override func setUp() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: JournalEntry.self,
            migrationPlan: LateralusMigrationPlan.self,
            configurations: configuration
        )
        context = ModelContext(container)
        storeRoot = FileManager.default.temporaryDirectory
            .appending(path: "attachments-\(UUID().uuidString)")
        store = AttachmentStore(voiceNotesDirectory: storeRoot)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: storeRoot)
    }

    private var repository: EntryRepository {
        EntryRepository(context: context, attachments: store)
    }

    private func makeTemporaryRecording() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "fake-\(UUID().uuidString).m4a")
        try Data("audio".utf8).write(to: url)
        return url
    }

    private func fetchAll() throws -> [JournalEntry] {
        try context.fetch(FetchDescriptor<JournalEntry>())
    }

    // MARK: - Saving

    func testSavePersistsEntry() throws {
        let prompt = PromptEngine.prompt(for: .redefine, comboIndex: 0)
        try repository.save(
            prompt: prompt, responseText: "A place that recognizes you.",
            isDaily: true, temporaryVoiceNoteURL: nil, sketchData: nil
        )
        let saved = try XCTUnwrap(fetchAll().first)
        XCTAssertEqual(saved.promptHeadline, prompt.headline)
        XCTAssertEqual(saved.exercise, .redefine)
        XCTAssertTrue(saved.isDaily)
        XCTAssertFalse(saved.isFavorite)
    }

    func testSaveCommitsVoiceNoteIntoStore() throws {
        let temp = try makeTemporaryRecording()
        let entry = try repository.save(
            prompt: Prompt(exercise: .diary, headline: "Diary", detail: nil),
            responseText: "", isDaily: false,
            temporaryVoiceNoteURL: temp, sketchData: nil
        )
        let filename = try XCTUnwrap(entry.voiceNoteFile)
        XCTAssertNotNil(store.url(forFile: filename), "Committed file missing from store")
        XCTAssertFalse(FileManager.default.fileExists(atPath: temp.path), "Temp file should be moved, not copied")
    }

    func testSaveWithMissingTemporaryFileThrowsAndPersistsNothing() throws {
        let ghost = FileManager.default.temporaryDirectory.appending(path: "missing-\(UUID().uuidString).m4a")
        XCTAssertThrowsError(
            try repository.save(
                prompt: Prompt(exercise: .diary, headline: "Diary", detail: nil),
                responseText: "hello", isDaily: false,
                temporaryVoiceNoteURL: ghost, sketchData: nil
            )
        )
        XCTAssertTrue(try fetchAll().isEmpty, "Failed save must not leave a row behind")
    }

    // MARK: - Editing response text

    private struct ForcedSaveFailure: Error {}

    @discardableResult
    private func saveTextEntry(_ text: String, date: Date = .now) throws -> JournalEntry {
        try repository.save(
            prompt: PromptEngine.prompt(for: .redefine, comboIndex: 0),
            responseText: text, isDaily: true,
            temporaryVoiceNoteURL: nil, sketchData: nil, date: date
        )
    }

    /// Reads the entry from a fresh context, so the result shows the store, not memory.
    private func storedText(of entry: JournalEntry) throws -> String? {
        let id = entry.id
        let fresh = ModelContext(container)
        return try fresh.fetch(FetchDescriptor<JournalEntry>(predicate: #Predicate { $0.id == id }))
            .first?.responseText
    }

    func testUpdateResponseTextPersistsTrimmedText() throws {
        let entry = try saveTextEntry("A place taht recognizes you.")
        try repository.updateResponseText(of: entry, to: "  A place that recognizes you.\n")
        XCTAssertEqual(entry.responseText, "A place that recognizes you.")
        XCTAssertEqual(try storedText(of: entry), "A place that recognizes you.")
        XCTAssertEqual(try fetchAll().count, 1, "An edit must not add an entry")
    }

    func testUpdateResponseTextKeepsEverythingElse() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let temp = try makeTemporaryRecording()
        let entry = try repository.save(
            prompt: PromptEngine.prompt(for: .redefine, comboIndex: 0),
            responseText: "before", isDaily: true,
            temporaryVoiceNoteURL: temp, sketchData: Data("sketch".utf8), date: date
        )
        let file = entry.voiceNoteFile
        try repository.updateResponseText(of: entry, to: "after")
        XCTAssertEqual(entry.date, date)
        XCTAssertEqual(entry.exercise, .redefine)
        XCTAssertTrue(entry.isDaily)
        XCTAssertEqual(entry.voiceNoteFile, file)
        XCTAssertEqual(entry.sketchData, Data("sketch".utf8))
        XCTAssertNotNil(store.url(forFile: try XCTUnwrap(file)), "An edit must not touch the voice note")
    }

    func testUpdateResponseTextFailureKeepsOriginalText() throws {
        let entry = try saveTextEntry("original")
        var failing = repository
        failing.commitChanges = { _ in throw ForcedSaveFailure() }
        XCTAssertThrowsError(try failing.updateResponseText(of: entry, to: "edited"))
        XCTAssertEqual(entry.responseText, "original")
        XCTAssertEqual(try storedText(of: entry), "original")
    }

    func testUpdateResponseTextRejectsEmptyText() throws {
        let entry = try saveTextEntry("original")
        XCTAssertThrowsError(try repository.updateResponseText(of: entry, to: " \n\t ")) { error in
            XCTAssertEqual(error as? EntryRepositoryError, .emptyResponse)
        }
        XCTAssertEqual(entry.responseText, "original")
        XCTAssertEqual(try storedText(of: entry), "original")
    }

    func testUpdateResponseTextDoesNotChangeActivity() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: now))
        try saveTextEntry("today", date: now)
        let older = try saveTextEntry("yesterday", date: yesterday)

        func metrics() throws -> ActivityMetrics {
            ActivityMetrics(
                entries: try fetchAll().map { (date: $0.date, exercise: $0.exercise) },
                now: now, calendar: calendar
            )
        }
        let before = try metrics()
        try repository.updateResponseText(of: older, to: "yesterday, edited today")
        let after = try metrics()

        XCTAssertEqual(after.total, before.total)
        XCTAssertEqual(after.streak, before.streak)
        XCTAssertEqual(after.thisWeek, before.thisWeek)
        XCTAssertEqual(after.disciplineCounts, before.disciplineCounts)
        XCTAssertEqual(after.lastSevenDays.map(\.count), before.lastSevenDays.map(\.count))
        XCTAssertEqual(older.date, yesterday)
    }

    // MARK: - Deleting

    func testDeleteRemovesEntryAndVoiceNote() throws {
        let temp = try makeTemporaryRecording()
        let entry = try repository.save(
            prompt: Prompt(exercise: .diary, headline: "Diary", detail: nil),
            responseText: "", isDaily: false,
            temporaryVoiceNoteURL: temp, sketchData: nil
        )
        let filename = try XCTUnwrap(entry.voiceNoteFile)
        try repository.delete(entry)
        XCTAssertTrue(try fetchAll().isEmpty)
        XCTAssertNil(store.url(forFile: filename), "Voice note should be deleted with its entry")
    }

    // MARK: - Startup reconciliation

    func testReconcileClearsMissingReferencesAndSweepsOrphans() throws {
        // Entry whose file vanished.
        let temp = try makeTemporaryRecording()
        let entry = try repository.save(
            prompt: Prompt(exercise: .diary, headline: "Diary", detail: nil),
            responseText: "", isDaily: false,
            temporaryVoiceNoteURL: temp, sketchData: nil
        )
        let filename = try XCTUnwrap(entry.voiceNoteFile)
        store.remove(file: filename)

        // Orphan file nothing references.
        try FileManager.default.createDirectory(at: storeRoot, withIntermediateDirectories: true)
        let orphan = storeRoot.appending(path: "orphan.m4a")
        try Data("orphan".utf8).write(to: orphan)

        try repository.reconcileAttachments()

        XCTAssertNil(entry.voiceNoteFile, "Dangling reference should be cleared")
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphan.path), "Orphan should be swept")
    }

    // MARK: - Unknown-type resilience

    func testUnknownExerciseIdentifierStaysVisible() throws {
        let entry = try repository.save(
            prompt: PromptEngine.prompt(for: .backstory, comboIndex: 0),
            responseText: "story", isDaily: false,
            temporaryVoiceNoteURL: nil, sketchData: nil
        )
        entry.exerciseRaw = "hologramSculpting" // written by some future version
        try context.save()

        let reloaded = try XCTUnwrap(fetchAll().first)
        XCTAssertEqual(reloaded.exercise, .unknown)
        XCTAssertFalse(reloaded.exercise.title.isEmpty)
        XCTAssertEqual(reloaded.responseText, "story")
    }

    // MARK: - Sketch round-trip

    func testSketchEncodingRoundTrip() throws {
        var sketch = Sketch()
        sketch.strokes.append(Sketch.Stroke(
            points: [.init(x: 1, y: 2), .init(x: 3, y: 4)],
            red: 0.1, green: 0.2, blue: 0.3, width: 3
        ))
        let data = try XCTUnwrap(sketch.encoded())
        let decoded = try XCTUnwrap(Sketch.decode(data))
        XCTAssertEqual(decoded, sketch)
    }

    func testVoiceNoteDurationFormatting() {
        XCTAssertEqual(voiceNoteDuration(0), "0:00")
        XCTAssertEqual(voiceNoteDuration(61), "1:01")
        XCTAssertEqual(voiceNoteDuration(300), "5:00")
    }
}
