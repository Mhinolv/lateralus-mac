import SwiftData
import XCTest
@testable import Lateralus__Mac_

@MainActor
final class DiaryDraftStoreTests: XCTestCase {

    private var root: URL!
    private var store: DiaryDraftStore!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "drafts-\(UUID().uuidString)")
        store = DiaryDraftStore(directory: root)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func fileCount() -> Int {
        (try? FileManager.default.contentsOfDirectory(atPath: root.path(percentEncoded: false)))?.count ?? 0
    }

    // MARK: - Writing

    func testWritePersistsDraftToDisk() throws {
        let id = UUID()
        try store.write(id: id, text: "A long thought")

        XCTAssertEqual(fileCount(), 1)
        XCTAssertEqual(store.draft(id: id)?.text, "A long thought")
        // A fresh store on the same directory sees it, as after a relaunch.
        XCTAssertEqual(DiaryDraftStore(directory: root).allDrafts().map(\.id), [id])
    }

    func testRewriteReplacesSameFile() throws {
        let id = UUID()
        try store.write(id: id, text: "First")
        try store.write(id: id, text: "First, then more")

        XCTAssertEqual(fileCount(), 1)
        XCTAssertEqual(store.draft(id: id)?.text, "First, then more")
    }

    func testWhitespaceOnlyTextRemovesDraft() throws {
        let id = UUID()
        try store.write(id: id, text: "Something")
        try store.write(id: id, text: "  \n\t ")

        XCTAssertNil(store.draft(id: id))
        XCTAssertEqual(fileCount(), 0)
    }

    func testEmptyTextNeverCreatesFile() throws {
        try store.write(id: UUID(), text: "")
        XCTAssertEqual(fileCount(), 0)
    }

    func testTextIsKeptExactly() throws {
        let id = UUID()
        let text = "  Line one\n\nLine two — ünïcødé \u{1F600}\n"
        try store.write(id: id, text: text)
        XCTAssertEqual(store.draft(id: id)?.text, text)
    }

    func testRemoveDeletesFile() throws {
        let id = UUID()
        try store.write(id: id, text: "Gone soon")
        store.remove(id: id)

        XCTAssertNil(store.draft(id: id))
        XCTAssertEqual(fileCount(), 0)
        store.remove(id: id) // Removing again is harmless.
    }

    // MARK: - Separate composers

    func testTwoComposersKeepSeparateDrafts() throws {
        let first = UUID()
        let second = UUID()
        try store.write(id: first, text: "Window one")
        try store.write(id: second, text: "Window two")
        try store.write(id: first, text: "Window one, edited")

        XCTAssertEqual(fileCount(), 2)
        XCTAssertEqual(store.draft(id: first)?.text, "Window one, edited")
        XCTAssertEqual(store.draft(id: second)?.text, "Window two")

        store.remove(id: first)
        XCTAssertEqual(store.draft(id: second)?.text, "Window two")
    }

    // MARK: - Orphans

    func testNewestOrphanSkipsOwnedDrafts() throws {
        let old = UUID()
        let newer = UUID()
        let newest = UUID()
        try store.write(id: old, text: "Old", now: Date(timeIntervalSince1970: 100))
        try store.write(id: newer, text: "Newer", now: Date(timeIntervalSince1970: 200))
        try store.write(id: newest, text: "Newest", now: Date(timeIntervalSince1970: 300))

        XCTAssertEqual(store.newestOrphan(excluding: [])?.id, newest)
        XCTAssertEqual(store.newestOrphan(excluding: [newest])?.id, newer)
        XCTAssertNil(store.newestOrphan(excluding: [old, newer, newest]))
    }

    func testNextOrphanShowsAfterNewestIsDiscarded() throws {
        let old = UUID()
        let new = UUID()
        try store.write(id: old, text: "Old", now: Date(timeIntervalSince1970: 100))
        try store.write(id: new, text: "New", now: Date(timeIntervalSince1970: 200))

        store.remove(id: try XCTUnwrap(store.newestOrphan(excluding: [])).id)
        XCTAssertEqual(store.newestOrphan(excluding: [])?.id, old)
    }

    func testNoDirectoryMeansNoOrphans() {
        XCTAssertTrue(store.allDrafts().isEmpty)
        XCTAssertNil(store.newestOrphan(excluding: []))
    }

    func testUnreadableFilesAreSkippedNotDeleted() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: root.appending(path: "diary-broken.json"))
        try Data("other".utf8).write(to: root.appending(path: "notes.txt"))
        let id = UUID()
        try store.write(id: id, text: "Good")

        XCTAssertEqual(store.allDrafts().map(\.id), [id])
        XCTAssertEqual(fileCount(), 3)
    }

    func testDecodesDraftWithMissingOptionalFields() throws {
        let id = UUID()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data(#"{"id":"\#(id.uuidString)","text":"Old format"}"#.utf8)
            .write(to: root.appending(path: "diary-\(id.uuidString).json"))

        let draft = try XCTUnwrap(store.draft(id: id))
        XCTAssertEqual(draft.text, "Old format")
        XCTAssertEqual(draft.version, 1)
        XCTAssertEqual(draft.updatedAt, .distantPast)
    }

    // MARK: - Ownership

    func testOwnershipClaimAndRelease() {
        // Uses the shared registry: freeing a main-actor instance in the
        // test host crashes in the Swift runtime's isolated deinit.
        let ownership = DiaryDraftOwnership.shared
        let first = UUID()
        let second = UUID()
        ownership.claim(first)
        ownership.claim(second)
        XCTAssertTrue(ownership.owned.isSuperset(of: [first, second]))

        ownership.release(first)
        XCTAssertFalse(ownership.owned.contains(first))
        XCTAssertTrue(ownership.owned.contains(second))
        ownership.release(second)
    }

    // MARK: - Restore

    func testMergeIntoEmptyEditorReplaces() {
        XCTAssertEqual(DiaryDraftStore.merge(existing: "", draft: "Recovered"), "Recovered")
        XCTAssertEqual(DiaryDraftStore.merge(existing: " \n ", draft: "Recovered"), "Recovered")
    }

    func testMergeAppendsAfterBlankLine() {
        XCTAssertEqual(DiaryDraftStore.merge(existing: "Typed", draft: "Recovered"), "Typed\n\nRecovered")
        XCTAssertEqual(DiaryDraftStore.merge(existing: "Typed\n\n\n", draft: "Recovered"), "Typed\n\nRecovered")
    }

    // MARK: - Metrics

    func testDraftsDoNotCreateEntries() throws {
        let container = try ModelContainer(
            for: JournalEntry.self,
            migrationPlan: LateralusMigrationPlan.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        try store.write(id: UUID(), text: "Not an entry")

        // Streaks and Insights read only journal entries.
        XCTAssertTrue(try context.fetch(FetchDescriptor<JournalEntry>()).isEmpty)
    }
}
