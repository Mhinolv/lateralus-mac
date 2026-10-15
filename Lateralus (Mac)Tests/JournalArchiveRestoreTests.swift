import SwiftData
import XCTest
@testable import Lateralus__Mac_

/// File > Restore Archive… (#6): validation before any write, the
/// transactional restore, and the app model flow.
@MainActor
final class JournalArchiveRestoreTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var store: AttachmentStore!
    private var root: URL!
    private var destination: URL!

    override func setUp() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: JournalEntry.self,
            migrationPlan: LateralusMigrationPlan.self,
            configurations: configuration
        )
        context = ModelContext(container)
        root = FileManager.default.temporaryDirectory.appending(path: "restore-\(UUID().uuidString)")
        destination = root.appending(path: "Destination")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        store = AttachmentStore(voiceNotesDirectory: root.appending(path: "VoiceNotes"))
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
    }

    private var repository: EntryRepository {
        var repository = EntryRepository(context: context, attachments: store)
        repository.isLocked = { false }
        return repository
    }

    private func makeTemporaryRecording(_ contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "fake-\(UUID().uuidString).m4a")
        try Data(contents.utf8).write(to: url)
        return url
    }

    private func sampleSketchData() throws -> Data {
        var sketch = Sketch()
        sketch.strokes.append(Sketch.Stroke(
            points: [.init(x: 1, y: 2), .init(x: 3, y: 4)],
            red: 0.1, green: 0.2, blue: 0.3, width: 3
        ))
        return try XCTUnwrap(sketch.encoded())
    }

    private struct Snapshot: Equatable {
        var id: UUID
        var date: Date
        var exerciseRaw: String
        var promptHeadline: String
        var promptDetail: String?
        var responseText: String
        var isDaily: Bool
        var isFavorite: Bool
        var sketchData: Data?
        var voiceNote: Data?
    }

    private func snapshots() throws -> [Snapshot] {
        try allEntries()
            .sorted { $0.date < $1.date }
            .map { entry in
                Snapshot(
                    id: entry.id, date: entry.date, exerciseRaw: entry.exerciseRaw,
                    promptHeadline: entry.promptHeadline, promptDetail: entry.promptDetail,
                    responseText: entry.responseText, isDaily: entry.isDaily, isFavorite: entry.isFavorite,
                    sketchData: entry.sketchData,
                    voiceNote: try entry.voiceNoteFile.map { try Data(contentsOf: XCTUnwrap(store.url(forFile: $0))) }
                )
            }
    }

    /// Four entries: text (daily, favorite), sketch, and two voice notes.
    private func saveSampleEntries() throws {
        let text = try repository.save(
            prompt: PromptEngine.prompt(for: .redefine, comboIndex: 0),
            responseText: "A place that recognizes you.", isDaily: true,
            temporaryVoiceNoteURL: nil, sketchData: nil,
            date: Date(timeIntervalSince1970: 1_791_000_000.125)
        )
        text.isFavorite = true
        try repository.save(
            prompt: Prompt(exercise: .diary, headline: "Diary", detail: "Draw it"),
            responseText: "", isDaily: false,
            temporaryVoiceNoteURL: nil, sketchData: sampleSketchData(),
            date: Date(timeIntervalSince1970: 1_791_100_000)
        )
        try repository.save(
            prompt: Prompt(exercise: .diary, headline: "Diary", detail: nil),
            responseText: "spoken", isDaily: false,
            temporaryVoiceNoteURL: makeTemporaryRecording("first audio"), sketchData: nil,
            date: Date(timeIntervalSince1970: 1_791_200_000)
        )
        try repository.save(
            prompt: Prompt(exercise: .diary, headline: "Diary", detail: nil),
            responseText: "spoken again", isDaily: false,
            temporaryVoiceNoteURL: makeTemporaryRecording("second audio"), sketchData: nil,
            date: Date(timeIntervalSince1970: 1_791_300_000)
        )
        try context.save()
    }

    private func allEntries() throws -> [JournalEntry] {
        try context.fetch(FetchDescriptor<JournalEntry>())
    }

    private func storedFiles() -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: store.voiceNotesDirectory.path(percentEncoded: false))) ?? []
    }

    private func export() throws -> URL {
        try JournalArchive.export(
            JournalArchive.sources(for: allEntries(), attachments: store), into: destination
        )
    }

    /// Exports the sample journal, then deletes every entry: the data loss
    /// that restore repairs.
    private func exportThenEmptyJournal() throws -> URL {
        try saveSampleEntries()
        let archive = try export()
        for entry in try allEntries() {
            try repository.delete(entry)
        }
        XCTAssertEqual(try allEntries().count, 0)
        XCTAssertEqual(storedFiles(), [])
        return archive
    }

    /// Edits `entries.json` and the manifest, and keeps the checksum of
    /// `entries.json` correct so only the edited fact is wrong.
    private func rewrite(
        _ archive: URL,
        entries editEntries: (inout JournalArchive.EntriesDocument) -> Void = { _ in },
        manifest editManifest: (inout JournalArchive.Manifest) -> Void = { _ in }
    ) throws {
        let entriesURL = archive.appending(path: JournalArchive.entriesFilename)
        var document = try JournalArchive.decoder.decode(
            JournalArchive.EntriesDocument.self, from: Data(contentsOf: entriesURL)
        )
        editEntries(&document)
        let entriesData = try JournalArchive.encoder.encode(document)
        try entriesData.write(to: entriesURL)

        let manifestURL = archive.appending(path: JournalArchive.manifestFilename)
        var manifest = try JournalArchive.decoder.decode(
            JournalArchive.Manifest.self, from: Data(contentsOf: manifestURL)
        )
        if let index = manifest.files.firstIndex(where: { $0.path == JournalArchive.entriesFilename }) {
            manifest.files[index].size = entriesData.count
            manifest.files[index].sha256 = JournalArchive.sha256(entriesData)
        }
        editManifest(&manifest)
        try JournalArchive.encoder.encode(manifest).write(to: manifestURL)
    }

    private func assertRejected(
        _ archive: URL, as expected: JournalArchive.RestoreError,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertThrowsError(try JournalArchive.restorePlan(at: archive), file: file, line: line) { error in
            XCTAssertEqual(JournalArchive.RestoreError(error), expected, "\(error)", file: file, line: line)
        }
    }

    // MARK: - Success

    func testRestoreBringsBackEveryFieldAndAttachment() async throws {
        try saveSampleEntries()
        let before = try snapshots()
        let archive = try export()
        for entry in try allEntries() {
            try repository.delete(entry)
        }

        let plan = try JournalArchive.restorePlan(at: archive)
        var progress: [Int] = []
        try await repository.restore(plan) { progress.append($0) }

        XCTAssertEqual(try snapshots(), before, "IDs, dates, text, flags, sketch and voice bytes all return")
        XCTAssertEqual(progress, [1, 2, 3, 4])
        XCTAssertEqual(storedFiles().count, 2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: archive.path(percentEncoded: false)), "The archive stays")
    }

    func testRestoredVoiceNotesGetNewStoreFilenames() async throws {
        let archive = try exportThenEmptyJournal()
        try await repository.restore(JournalArchive.restorePlan(at: archive))
        for file in try allEntries().compactMap(\.voiceNoteFile) {
            XCTAssertTrue(file.hasPrefix("note-") && file.hasSuffix(".m4a"), file)
            XCTAssertNotNil(store.url(forFile: file))
        }
    }

    func testRestoreKeepsUnknownDiscipline() async throws {
        let archive = try exportThenEmptyJournal()
        try rewrite(archive, entries: { $0.entries[0].exercise = "future-discipline" })
        try await repository.restore(JournalArchive.restorePlan(at: archive))
        let entry = try XCTUnwrap(allEntries().first { $0.exerciseRaw == "future-discipline" })
        XCTAssertEqual(entry.exercise, .unknown)
    }

    func testRestoreEmptyArchive() async throws {
        let archive = try JournalArchive.export([], into: destination)
        let plan = try JournalArchive.restorePlan(at: archive)
        XCTAssertEqual(plan.entries.count, 0)
        try await repository.restore(plan)
        XCTAssertEqual(try allEntries().count, 0)
    }

    func testPlanCountsEntriesAndAttachments() throws {
        let archive = try exportThenEmptyJournal()
        let plan = try JournalArchive.restorePlan(at: archive)
        XCTAssertEqual(plan.entries.count, 4)
        XCTAssertEqual(plan.attachmentCount, 3)
        XCTAssertEqual(plan.confirmTitle, "Restore 4 entries?")
        XCTAssertEqual(
            plan.confirmMessage,
            "Lateralus adds 4 entries and 3 attachments from “\(plan.displayName)”."
        )
        XCTAssertTrue(plan.displayName.hasPrefix("Lateralus Archive "), plan.displayName)
    }

    func testConfirmWordingIsSingular() {
        let entry = JournalArchive.Entry(
            id: UUID(), date: .now, exercise: "diary", promptHeadline: "Diary", promptDetail: nil,
            responseText: "", isDaily: false, isFavorite: false,
            sketchFile: "Sketches/a.json", voiceNoteFile: nil
        )
        let plan = JournalArchive.RestorePlan(
            root: URL(filePath: "/tmp/Backup.lateralusarchive", directoryHint: .isDirectory), entries: [entry]
        )
        XCTAssertEqual(plan.confirmTitle, "Restore 1 entry?")
        XCTAssertTrue(plan.confirmMessage.hasPrefix("Lateralus adds 1 entry and 1 attachment from “"), plan.confirmMessage)
    }

    // MARK: - Rejected before any write

    func testRejectsNewerArchiveVersion() throws {
        let archive = try exportThenEmptyJournal()
        try rewrite(archive, manifest: { $0.formatVersion = JournalArchive.formatVersion + 1 })
        assertRejected(archive, as: .unsupportedVersion)
    }

    func testRejectsNewerEntriesVersion() throws {
        let archive = try exportThenEmptyJournal()
        try rewrite(archive, entries: { $0.formatVersion = JournalArchive.formatVersion + 1 })
        assertRejected(archive, as: .unsupportedVersion)
    }

    func testRejectsBadChecksum() throws {
        let archive = try exportThenEmptyJournal()
        let plan = try JournalArchive.restorePlan(at: archive)
        let path = try XCTUnwrap(plan.entries[2].voiceNoteFile)
        // Same size, different bytes.
        try Data("FIRST AUDIO".utf8).write(to: archive.appending(path: path))
        assertRejected(archive, as: .damaged)
    }

    func testRejectsMissingAndUnlistedFiles() throws {
        let archive = try exportThenEmptyJournal()
        let plan = try JournalArchive.restorePlan(at: archive)
        try FileManager.default.removeItem(at: archive.appending(path: try XCTUnwrap(plan.entries[1].sketchFile)))
        assertRejected(archive, as: .damaged)

        let second = try export()
        try Data("x".utf8).write(to: second.appending(path: "extra.txt"))
        assertRejected(second, as: .damaged)
    }

    func testRejectsEntryAttachmentNotInManifest() throws {
        let archive = try exportThenEmptyJournal()
        try rewrite(archive, entries: { $0.entries[0].voiceNoteFile = "VoiceNotes/absent.m4a" })
        assertRejected(archive, as: .damaged)
    }

    func testRejectsManifestPathOutsideArchive() throws {
        let archive = try exportThenEmptyJournal()
        // A real file with a correct checksum, so only the path is wrong.
        let outside = Data("secret".utf8)
        try outside.write(to: destination.appending(path: "outside.txt"))
        try rewrite(archive, manifest: {
            $0.files.append(.init(path: "../outside.txt", size: outside.count, sha256: JournalArchive.sha256(outside)))
        })
        assertRejected(archive, as: .unsafePath)
    }

    func testRejectsAbsoluteAndDotPaths() throws {
        for path in ["/etc/hosts", "VoiceNotes/../../x.m4a", "./entries.json", "VoiceNotes//x.m4a", "~/x"] {
            let archive = try JournalArchive.export([], into: destination)
            try rewrite(archive, manifest: { $0.files.append(.init(path: path, size: 0, sha256: "")) })
            assertRejected(archive, as: .unsafePath)
            XCTAssertThrowsError(try JournalArchive.validate(at: archive)) { error in
                XCTAssertEqual(error as? JournalArchive.ValidationError, .unsafePath(path))
            }
        }
    }

    func testRejectsEntryPathOutsideArchive() throws {
        let archive = try exportThenEmptyJournal()
        try rewrite(archive, entries: { $0.entries[0].sketchFile = "../Destination/outside.json" })
        assertRejected(archive, as: .unsafePath)
    }

    func testRejectsSymbolicLinkOutOfArchive() throws {
        let archive = try exportThenEmptyJournal()
        let outside = Data("secret".utf8)
        let target = destination.appending(path: "outside.m4a")
        try outside.write(to: target)
        try FileManager.default.createSymbolicLink(
            at: archive.appending(path: "VoiceNotes/link.m4a"), withDestinationURL: target
        )
        try rewrite(archive, manifest: {
            $0.files.append(.init(path: "VoiceNotes/link.m4a", size: outside.count, sha256: JournalArchive.sha256(outside)))
        })
        assertRejected(archive, as: .unsafePath)
    }

    func testRejectsDuplicateEntryID() throws {
        let archive = try exportThenEmptyJournal()
        var duplicateID: UUID?
        try rewrite(archive, entries: { document in
            var copy = document.entries[0]
            copy.responseText = "copy"
            duplicateID = copy.id
            document.entries.append(copy)
        }, manifest: { $0.entryCount += 1 })
        assertRejected(archive, as: .duplicateEntry)
        XCTAssertThrowsError(try JournalArchive.validate(at: archive)) { error in
            XCTAssertEqual(error as? JournalArchive.ValidationError, .duplicateEntryID(try! XCTUnwrap(duplicateID)))
        }
    }

    func testRejectsWhatIsNotAnArchive() throws {
        let archive = try exportThenEmptyJournal()

        let renamed = destination.appending(path: "Renamed.folder", directoryHint: .isDirectory)
        try FileManager.default.copyItem(at: archive, to: renamed)
        assertRejected(renamed, as: .notArchive)

        let plainFile = destination.appending(path: "Fake.lateralusarchive")
        try Data("not a folder".utf8).write(to: plainFile)
        assertRejected(plainFile, as: .notArchive)

        let emptyPackage = destination.appending(path: "Empty.lateralusarchive", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: emptyPackage, withIntermediateDirectories: false)
        assertRejected(emptyPackage, as: .notArchive)

        let garbled = try export()
        try Data("{".utf8).write(to: garbled.appending(path: JournalArchive.manifestFilename))
        assertRejected(garbled, as: .notArchive)

        let otherFormat = try export()
        try rewrite(otherFormat, manifest: { $0.format = "someone-else" })
        assertRejected(otherFormat, as: .notArchive)
    }

    func testRestoreRefusesJournalWithEntries() async throws {
        try saveSampleEntries()
        let archive = try export()
        let filesBefore = Set(storedFiles())

        do {
            try await repository.restore(JournalArchive.restorePlan(at: archive))
            XCTFail("Restore must refuse a journal with entries")
        } catch {
            XCTAssertEqual(error as? JournalArchive.RestoreError, .journalNotEmpty)
        }
        XCTAssertEqual(try allEntries().count, 4)
        XCTAssertEqual(Set(storedFiles()), filesBefore)
    }

    // MARK: - Mid-import failure

    func testFailedSaveLeavesNoEntriesAndNoFiles() async throws {
        let archive = try exportThenEmptyJournal()
        var failing = repository
        failing.commitChanges = { _ in throw CocoaError(.fileWriteOutOfSpace) }

        do {
            try await failing.restore(JournalArchive.restorePlan(at: archive))
            XCTFail("Expected the save to fail")
        } catch {
            XCTAssertEqual((error as? CocoaError)?.code, .fileWriteOutOfSpace)
            XCTAssertTrue(
                JournalArchive.RestoreError(error).localizedDescription.hasPrefix("Nothing was restored. "),
                JournalArchive.RestoreError(error).localizedDescription
            )
        }
        XCTAssertEqual(try allEntries().count, 0)
        XCTAssertEqual(storedFiles(), [], "Copied voice notes are removed")

        // Nothing stays pending either: a later save adds no restored row.
        try context.save()
        XCTAssertEqual(try allEntries().count, 0)
    }

    func testFailedCopyRemovesEarlierCopies() async throws {
        let archive = try exportThenEmptyJournal()
        let plan = try JournalArchive.restorePlan(at: archive)
        // The file vanishes after the check: the first voice note copies,
        // the second fails.
        try FileManager.default.removeItem(at: archive.appending(path: try XCTUnwrap(plan.entries[3].voiceNoteFile)))

        var progress: [Int] = []
        do {
            try await repository.restore(plan) { progress.append($0) }
            XCTFail("Expected the copy to fail")
        } catch {
            XCTAssertEqual(progress, [1, 2, 3])
        }
        XCTAssertEqual(try allEntries().count, 0)
        XCTAssertEqual(storedFiles(), [])
    }

    // MARK: - App model flow
    // Async on purpose: see `testExportCommandDisabledForEmptyJournal`.

    func testAppModelRestoresAndShowsJournal() async throws {
        let archive = try exportThenEmptyJournal()
        let status = ArchiveRestoreStatus()
        let model = AppModel(restoreStatus: status)
        XCTAssertTrue(model.canRestoreArchive)

        await model.checkArchive(at: archive)
        let plan = try XCTUnwrap(model.archiveRestorePlan)
        XCTAssertNil(model.archiveRestoreResult)
        XCTAssertFalse(status.isBusy)
        XCTAssertFalse(model.canRestoreArchive, "One restore at a time")
        XCTAssertEqual(try allEntries().count, 0, "Checking writes nothing")

        await model.restoreArchive(plan, repository: repository)
        XCTAssertEqual(model.archiveRestoreResult, .success(entryCount: 4))
        XCTAssertEqual(model.archiveRestoreResult?.title, "Archive Restored")
        XCTAssertEqual(model.archiveRestoreResult?.message, "4 entries are back in your journal.")
        XCTAssertEqual(model.selection, .journal)
        XCTAssertNil(model.archiveRestorePlan)
        XCTAssertFalse(status.isBusy)
        XCTAssertFalse(model.ownsArchiveRestore)
        XCTAssertEqual(try allEntries().count, 4)
    }

    func testAppModelReportsDamagedArchive() async throws {
        let archive = try exportThenEmptyJournal()
        try Data("{}".utf8).write(to: archive.appending(path: JournalArchive.entriesFilename))
        let status = ArchiveRestoreStatus()
        let model = AppModel(restoreStatus: status)

        await model.checkArchive(at: archive)
        XCTAssertNil(model.archiveRestorePlan)
        XCTAssertEqual(model.archiveRestoreResult, .failure(.damaged))
        XCTAssertEqual(model.archiveRestoreResult?.title, "Couldn’t Restore Archive")
        XCTAssertEqual(model.archiveRestoreResult?.message, "A file in this archive is damaged. Nothing was restored.")
        XCTAssertFalse(status.isBusy)
        XCTAssertEqual(try allEntries().count, 0)
    }

    func testAppModelReportsMidImportFailure() async throws {
        let archive = try exportThenEmptyJournal()
        let model = AppModel(restoreStatus: ArchiveRestoreStatus())
        var failing = repository
        failing.commitChanges = { _ in throw CocoaError(.fileWriteOutOfSpace) }

        await model.restoreArchive(try JournalArchive.restorePlan(at: archive), repository: failing)
        guard case .failure(.failed(let message)) = model.archiveRestoreResult else {
            return XCTFail("Expected a failure, got \(String(describing: model.archiveRestoreResult))")
        }
        XCTAssertFalse(message.isEmpty)
        XCTAssertEqual(model.selection, .today, "The Journal opens only on success")
        XCTAssertEqual(try allEntries().count, 0)
        XCTAssertEqual(storedFiles(), [])
    }

    func testRestoreCommandNeedsEmptyIdleJournal() async {
        let status = ArchiveRestoreStatus()
        let model = AppModel(restoreStatus: status)
        XCTAssertTrue(model.canRestoreArchive)

        model.journalEntryCount = 1
        XCTAssertFalse(model.canRestoreArchive)
        XCTAssertTrue(model.canExportArchive)

        status.phase = .restoring(completed: 0, total: 3)
        XCTAssertFalse(model.canExportArchive, "No export during a restore")
        model.journalEntryCount = 0
        XCTAssertFalse(model.canRestoreArchive, "No second restore")

        // Another window shares the status, so it is blocked too.
        let otherWindow = AppModel(restoreStatus: status)
        XCTAssertFalse(otherWindow.canRestoreArchive)
        XCTAssertFalse(otherWindow.ownsArchiveRestore)
    }

    func testStatusTextForSheetAndScrim() {
        let status = ArchiveRestoreStatus()
        status.phase = .checking
        XCTAssertEqual(status.title, "Checking archive…")
        XCTAssertNil(status.progressText)
        status.phase = .restoring(completed: 12, total: 42)
        XCTAssertEqual(status.title, "Restoring archive…")
        XCTAssertEqual(status.progressText, "12 of 42")
        XCTAssertEqual(status.accessibilityLabel, "Restoring archive, 12 of 42")
    }

    func testWritesFailWhileRestoreRuns() throws {
        var locked = EntryRepository(context: context, attachments: store)
        locked.isLocked = { true }
        XCTAssertThrowsError(try locked.save(
            prompt: Prompt(exercise: .diary, headline: "Diary", detail: nil),
            responseText: "blocked", isDaily: false, temporaryVoiceNoteURL: nil, sketchData: nil
        )) { error in
            XCTAssertEqual(error as? EntryRepositoryError, .restoreInProgress)
        }
        XCTAssertEqual(try allEntries().count, 0)
    }

    func testErrorMessagesMatchDesign() {
        let expected: [(JournalArchive.RestoreError, String)] = [
            (.notArchive, "This file is not a Lateralus archive."),
            (.unsupportedVersion, "This archive version is not supported. Update Lateralus, then try again."),
            (.damaged, "A file in this archive is damaged. Nothing was restored."),
            (.unsafePath, "This archive points to a file outside the archive. Nothing was restored."),
            (.duplicateEntry, "This archive lists the same entry twice. Nothing was restored."),
            (.journalNotEmpty, "Restore works only into an empty journal."),
            (.failed("The disk is full."), "Nothing was restored. The disk is full."),
        ]
        for (error, message) in expected {
            XCTAssertEqual(error.localizedDescription, message)
        }
        XCTAssertEqual(ArchiveRestoreResult.success(entryCount: 1).message, "1 entry is back in your journal.")
    }
}
