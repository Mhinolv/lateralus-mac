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
