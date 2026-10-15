import SwiftData
import UniformTypeIdentifiers
import XCTest
@testable import Lateralus__Mac_

@MainActor
final class JournalArchiveTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var store: AttachmentStore!
    private var storeRoot: URL!
    private var destination: URL!

    /// 2026-10-15 10:30:00.250 UTC — a fractional second checks date precision.
    private let exportDate = Date(timeIntervalSince1970: 1_792_060_200.25)
    private let utc = TimeZone(identifier: "UTC")!

    override func setUp() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: JournalEntry.self,
            migrationPlan: LateralusMigrationPlan.self,
            configurations: configuration
        )
        context = ModelContext(container)
        let root = FileManager.default.temporaryDirectory.appending(path: "archive-\(UUID().uuidString)")
        storeRoot = root.appending(path: "VoiceNotes")
        destination = root.appending(path: "Destination")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        store = AttachmentStore(voiceNotesDirectory: storeRoot)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: storeRoot.deletingLastPathComponent())
    }

    private var repository: EntryRepository {
        EntryRepository(context: context, attachments: store)
    }

    private func makeTemporaryRecording(_ contents: String = "audio") throws -> URL {
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

    /// Three entries: text only (daily, favorite), sketch, voice note.
    @discardableResult
    private func saveSampleEntries() throws -> [JournalEntry] {
        let text = try repository.save(
            prompt: PromptEngine.prompt(for: .redefine, comboIndex: 0),
            responseText: "A place that recognizes you.", isDaily: true,
            temporaryVoiceNoteURL: nil, sketchData: nil,
            date: Date(timeIntervalSince1970: 1_791_000_000.125)
        )
        text.isFavorite = true
        let sketch = try repository.save(
            prompt: Prompt(exercise: .diary, headline: "Diary", detail: "Draw it"),
            responseText: "", isDaily: false,
            temporaryVoiceNoteURL: nil, sketchData: sampleSketchData(),
            date: Date(timeIntervalSince1970: 1_791_100_000)
        )
        let voice = try repository.save(
            prompt: Prompt(exercise: .diary, headline: "Diary", detail: nil),
            responseText: "spoken", isDaily: false,
            temporaryVoiceNoteURL: makeTemporaryRecording(), sketchData: nil,
            date: Date(timeIntervalSince1970: 1_791_200_000)
        )
        try context.save()
        return [text, sketch, voice]
    }

    private func allEntries() throws -> [JournalEntry] {
        try context.fetch(FetchDescriptor<JournalEntry>())
    }

    private func export() throws -> URL {
        try JournalArchive.export(
            JournalArchive.sources(for: allEntries(), attachments: store),
            into: destination, date: exportDate
        )
    }

    private func destinationContents() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: destination.path(percentEncoded: false)).sorted()
    }

    // MARK: - Manifest layout

    func testExportWritesManifestLayout() throws {
        let entries = try saveSampleEntries()
        let archive = try export()

        let day = exportDate.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day())
        XCTAssertEqual(archive.lastPathComponent, "Lateralus Archive \(day).lateralusarchive")
        XCTAssertEqual(try destinationContents(), [archive.lastPathComponent], "Only the package, no staging folder")

        let manifest = try JournalArchive.decoder.decode(
            JournalArchive.Manifest.self,
            from: Data(contentsOf: archive.appending(path: "manifest.json"))
        )
        XCTAssertEqual(manifest.format, "lateralus-archive")
        XCTAssertEqual(manifest.formatVersion, 1)
        XCTAssertEqual(manifest.entryCount, 3)
        XCTAssertEqual(manifest.createdAt, exportDate)

        let sketchID = entries[1].id.uuidString
        let voiceFile = try XCTUnwrap(entries[2].voiceNoteFile)
        XCTAssertEqual(manifest.files.map(\.path), [
            "Sketches/\(sketchID).json",
            "VoiceNotes/\(voiceFile)",
            "entries.json",
        ])

        for file in manifest.files {
            let data = try Data(contentsOf: archive.appending(path: file.path))
            XCTAssertEqual(file.size, data.count, file.path)
            XCTAssertEqual(file.sha256, JournalArchive.sha256(data), file.path)
            XCTAssertEqual(file.sha256.count, 64, file.path)
        }
        XCTAssertEqual(
            try Data(contentsOf: archive.appending(path: "VoiceNotes/\(voiceFile)")),
            Data("audio".utf8)
        )
        XCTAssertEqual(
            try Data(contentsOf: archive.appending(path: "Sketches/\(sketchID).json")),
            try XCTUnwrap(entries[1].sketchData),
            "Sketch bytes are copied as stored"
        )
    }

    func testEntriesDocumentKeepsEveryField() throws {
        let entries = try saveSampleEntries()
        let archive = try export()

        let document = try JournalArchive.decoder.decode(
            JournalArchive.EntriesDocument.self,
            from: Data(contentsOf: archive.appending(path: "entries.json"))
        )
        XCTAssertEqual(document.formatVersion, 1)
        XCTAssertEqual(document.entries.map(\.id), entries.map(\.id), "Oldest first")

        for (exported, entry) in zip(document.entries, entries) {
            XCTAssertEqual(exported.date, entry.date)
            XCTAssertEqual(exported.exercise, entry.exerciseRaw)
            XCTAssertEqual(exported.promptHeadline, entry.promptHeadline)
            XCTAssertEqual(exported.promptDetail, entry.promptDetail)
            XCTAssertEqual(exported.responseText, entry.responseText)
            XCTAssertEqual(exported.isDaily, entry.isDaily)
            XCTAssertEqual(exported.isFavorite, entry.isFavorite)
        }
        XCTAssertTrue(document.entries[0].isFavorite)
        XCTAssertNil(document.entries[0].sketchFile)
        XCTAssertNil(document.entries[0].voiceNoteFile)
        XCTAssertEqual(document.entries[1].sketchFile, "Sketches/\(entries[1].id.uuidString).json")
        XCTAssertEqual(document.entries[2].voiceNoteFile, "VoiceNotes/\(try XCTUnwrap(entries[2].voiceNoteFile))")
    }

    func testEmptyJournalWritesValidArchive() throws {
        let archive = try JournalArchive.export([], into: destination, date: exportDate)
        let manifest = try JournalArchive.validate(at: archive)
        XCTAssertEqual(manifest.entryCount, 0)
        XCTAssertEqual(manifest.files.map(\.path), ["entries.json"])
    }

    func testSecondExportOnSameDayAddsNumber() throws {
        try saveSampleEntries()
        let first = try export()
        let second = try export()
        let third = try export()
        XCTAssertEqual(second.deletingPathExtension().lastPathComponent, first.deletingPathExtension().lastPathComponent + " 2")
        XCTAssertEqual(third.deletingPathExtension().lastPathComponent, first.deletingPathExtension().lastPathComponent + " 3")
        XCTAssertEqual(try destinationContents().count, 3)
        XCTAssertNoThrow(try JournalArchive.validate(at: second))
    }

    func testArchiveNameUsesLocalDay() {
        let folder = URL(filePath: "/nonexistent-\(UUID().uuidString)", directoryHint: .isDirectory)
        // 2026-10-15 23:30 UTC is already 2026-10-16 in Tokyo.
        let late = Date(timeIntervalSince1970: 1_792_107_000)
        XCTAssertEqual(
            JournalArchive.availableURL(in: folder, date: late, timeZone: utc).lastPathComponent,
            "Lateralus Archive 2026-10-15.lateralusarchive"
        )
        XCTAssertEqual(
            JournalArchive.availableURL(in: folder, date: late, timeZone: TimeZone(identifier: "Asia/Tokyo")!).lastPathComponent,
            "Lateralus Archive 2026-10-16.lateralusarchive"
        )
    }

    /// LaunchServices may not register the test host, so check the
    /// declaration the app ships instead of asking `UTType` for conformance.
    func testArchiveTypeIsDeclaredAsPackage() throws {
        let declarations = try XCTUnwrap(
            Bundle.main.object(forInfoDictionaryKey: "UTExportedTypeDeclarations") as? [[String: Any]]
        )
        let declaration = try XCTUnwrap(declarations.first {
            $0["UTTypeIdentifier"] as? String == UTType.lateralusArchive.identifier
        })
        XCTAssertEqual(UTType.lateralusArchive.identifier, "Mhinoverse.Lateralus--Mac-.archive")
        XCTAssertTrue((declaration["UTTypeConformsTo"] as? [String] ?? []).contains("com.apple.package"))
        let tags = try XCTUnwrap(declaration["UTTypeTagSpecification"] as? [String: Any])
        XCTAssertEqual(tags["public.filename-extension"] as? [String], [JournalArchive.fileExtension])
    }

    // MARK: - Missing attachment

    func testMissingVoiceNoteAbortsAndLeavesNothing() throws {
        let entries = try saveSampleEntries()
        store.remove(file: try XCTUnwrap(entries[2].voiceNoteFile))

        XCTAssertThrowsError(try export()) { error in
            XCTAssertEqual(
                error as? JournalArchive.ExportError,
                .missingAttachment(entryDate: entries[2].date)
            )
            let day = entries[2].date.formatted(date: .long, time: .omitted)
            XCTAssertEqual(
                error.localizedDescription,
                "The file for an entry from \(day) is missing. No archive was saved."
            )
        }
        XCTAssertEqual(try destinationContents(), [], "No package and no staging folder may remain")
    }

    // MARK: - Checksum validation

    func testValidateAcceptsFreshArchive() throws {
        try saveSampleEntries()
        let manifest = try JournalArchive.validate(at: export())
        XCTAssertEqual(manifest.entryCount, 3)
    }

    func testValidateIgnoresFinderMetadata() throws {
        try saveSampleEntries()
        let archive = try export()
        try Data("finder".utf8).write(to: archive.appending(path: ".DS_Store"))
        XCTAssertNoThrow(try JournalArchive.validate(at: archive))
    }

    func testValidateRejectsChangedFile() throws {
        let entries = try saveSampleEntries()
        let archive = try export()
        let path = "VoiceNotes/\(try XCTUnwrap(entries[2].voiceNoteFile))"
        // Same size, different bytes: only the checksum can catch it.
        try Data("AUDIO".utf8).write(to: archive.appending(path: path))
        XCTAssertThrowsError(try JournalArchive.validate(at: archive)) { error in
            XCTAssertEqual(error as? JournalArchive.ValidationError, .checksumMismatch(path))
        }
    }

    func testValidateRejectsChangedEntries() throws {
        try saveSampleEntries()
        let archive = try export()
        let url = archive.appending(path: "entries.json")
        var text = try String(contentsOf: url, encoding: .utf8)
        text = text.replacingOccurrences(of: "spoken", with: "SPOKEN")
        try text.write(to: url, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try JournalArchive.validate(at: archive)) { error in
            XCTAssertEqual(error as? JournalArchive.ValidationError, .checksumMismatch("entries.json"))
        }
    }

    func testValidateRejectsMissingFile() throws {
        let entries = try saveSampleEntries()
        let archive = try export()
        let path = "Sketches/\(entries[1].id.uuidString).json"
        try FileManager.default.removeItem(at: archive.appending(path: path))
        XCTAssertThrowsError(try JournalArchive.validate(at: archive)) { error in
            XCTAssertEqual(error as? JournalArchive.ValidationError, .missingFile(path))
        }
    }

    func testValidateRejectsMissingManifest() throws {
        try saveSampleEntries()
        let archive = try export()
        try FileManager.default.removeItem(at: archive.appending(path: "manifest.json"))
        XCTAssertThrowsError(try JournalArchive.validate(at: archive)) { error in
            XCTAssertEqual(error as? JournalArchive.ValidationError, .missingFile("manifest.json"))
        }
    }

    func testValidateRejectsUnlistedFile() throws {
        try saveSampleEntries()
        let archive = try export()
        try Data("extra".utf8).write(to: archive.appending(path: "VoiceNotes/extra.m4a"))
        XCTAssertThrowsError(try JournalArchive.validate(at: archive)) { error in
            XCTAssertEqual(error as? JournalArchive.ValidationError, .unlistedFile("VoiceNotes/extra.m4a"))
        }
    }

    func testValidateRejectsNewerFormatVersion() throws {
        try saveSampleEntries()
        let archive = try export()
        let url = archive.appending(path: "manifest.json")
        var manifest = try JournalArchive.decoder.decode(JournalArchive.Manifest.self, from: Data(contentsOf: url))
        manifest.formatVersion = JournalArchive.formatVersion + 1
        try JournalArchive.encoder.encode(manifest).write(to: url)
        XCTAssertThrowsError(try JournalArchive.validate(at: archive)) { error in
            XCTAssertEqual(error as? JournalArchive.ValidationError, .unsupportedFormat)
        }
    }

    func testValidateRejectsEntryCountMismatch() throws {
        try saveSampleEntries()
        let archive = try export()
        let url = archive.appending(path: "manifest.json")
        var manifest = try JournalArchive.decoder.decode(JournalArchive.Manifest.self, from: Data(contentsOf: url))
        manifest.entryCount = 2
        try JournalArchive.encoder.encode(manifest).write(to: url)
        XCTAssertThrowsError(try JournalArchive.validate(at: archive)) { error in
            XCTAssertEqual(error as? JournalArchive.ValidationError, .entryCountMismatch)
        }
    }

    func testSHA256KnownVector() {
        XCTAssertEqual(
            JournalArchive.sha256(Data("abc".utf8)),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    }

    // MARK: - App model flow

    func testAppModelReportsSuccess() async throws {
        try saveSampleEntries()
        let model = AppModel()
        await model.exportArchive(try allEntries(), into: destination, attachments: store)

        guard case .success(let url, let count) = model.archiveExportResult else {
            return XCTFail("Expected success, got \(String(describing: model.archiveExportResult))")
        }
        XCTAssertEqual(count, 3)
        XCTAssertNoThrow(try JournalArchive.validate(at: url))
        XCTAssertFalse(model.isExportingArchive)
        XCTAssertEqual(model.archiveExportResult?.title, "Archive Exported")
    }

    func testAppModelReportsMissingAttachment() async throws {
        let entries = try saveSampleEntries()
        store.remove(file: try XCTUnwrap(entries[2].voiceNoteFile))
        let model = AppModel()
        await model.exportArchive(try allEntries(), into: destination, attachments: store)

        let result = try XCTUnwrap(model.archiveExportResult)
        XCTAssertEqual(result.title, "Couldn’t Export Archive")
        XCTAssertTrue(result.message.hasSuffix("is missing. No archive was saved."), result.message)
        XCTAssertEqual(try destinationContents(), [])
    }

    /// Async on purpose: releasing an `AppModel` from a synchronous XCTest
    /// method crashes in `swift_task_deinitOnExecutor` (Swift runtime, macOS 15).
    func testExportCommandDisabledForEmptyJournal() async {
        let model = AppModel()
        XCTAssertFalse(model.canExportArchive)
        model.journalEntryCount = 1
        XCTAssertTrue(model.canExportArchive)
    }

    func testSuccessMessageCountsEntries() {
        let url = URL(filePath: "/tmp/Lateralus Archive 2026-10-15.lateralusarchive", directoryHint: .isDirectory)
        func message(_ count: Int) -> String {
            ArchiveExportResult.success(url: url, entryCount: count).message
        }
        XCTAssertTrue(message(1).hasPrefix("Saved 1 entry to “Lateralus Archive 2026-10-15"), message(1))
        XCTAssertTrue(message(2).hasPrefix("Saved 2 entries to “"), message(2))
        XCTAssertTrue(message(0).hasPrefix("Saved 0 entries to “"), message(0))
        XCTAssertTrue(message(1).hasSuffix("”."), message(1))
    }
}
