import CryptoKit
import Foundation
import UniformTypeIdentifiers

extension UTType {
    /// A `.lateralusarchive` package. Declared in Info.plist as conforming to
    /// `com.apple.package`, so Finder shows the archive folder as one item.
    /// The identifier is `<bundle ID>.archive`, the same as Info.plist, so team
    /// builds with `LATERALUS_ID_SUFFIX` declare and use the same type.
    nonisolated static let lateralusArchive = UTType(
        exportedAs: (Bundle.main.bundleIdentifier ?? "Mhinoverse.Lateralus--Mac-") + ".archive",
        conformingTo: .package
    )
}

/// The on-disk journal archive written by File > Export Archive… and read
/// back by restore. Layout inside the package:
///
///     manifest.json          format version, entry count, checksums
///     entries.json           every entry, versioned
///     Sketches/<id>.json     encoded `Sketch` per entry that has one
///     VoiceNotes/<file>.m4a  the voice note per entry that has one
///
/// Files are staged in a hidden folder next to the destination and renamed
/// into place last, so a failed export never leaves a package with the
/// final name. The manifest is the last file written.
nonisolated enum JournalArchive {
    static let format = "lateralus-archive"
    static let formatVersion = 1
    static let fileExtension = "lateralusarchive"
    static let manifestFilename = "manifest.json"
    static let entriesFilename = "entries.json"
    static let sketchesDirectory = "Sketches"
    static let voiceNotesDirectory = "VoiceNotes"

    /// One journal entry as written to `entries.json`. Attachment fields are
    /// paths relative to the package root.
    struct Entry: Codable, Equatable, Sendable {
        var id: UUID
        var date: Date
        var exercise: String
        var promptHeadline: String
        var promptDetail: String?
        var responseText: String
        var isDaily: Bool
        var isFavorite: Bool
        var sketchFile: String?
        var voiceNoteFile: String?
    }

    struct EntriesDocument: Codable, Equatable, Sendable {
        var formatVersion: Int
        var entries: [Entry]
    }

    struct Manifest: Codable, Equatable, Sendable {
        struct File: Codable, Equatable, Sendable {
            var path: String
            var size: Int
            var sha256: String
        }

        var format: String
        var formatVersion: Int
        var createdAt: Date
        var entryCount: Int
        var files: [File]
    }

    /// A value copy of one entry and the location of its voice note, taken
    /// on the main actor so the file work can run off it.
    struct Source: Sendable {
        var id: UUID
        var date: Date
        var exerciseRaw: String
        var promptHeadline: String
        var promptDetail: String?
        var responseText: String
        var isDaily: Bool
        var isFavorite: Bool
        var sketchData: Data?
        var voiceNoteURL: URL?
    }

    enum ExportError: LocalizedError, Equatable {
        /// An entry references a voice note that is not in the store.
        case missingAttachment(entryDate: Date)

        var errorDescription: String? {
            switch self {
            case .missingAttachment(let date):
                "The file for an entry from \(date.formatted(date: .long, time: .omitted)) is missing. No archive was saved."
            }
        }
    }

    enum ValidationError: Error, Equatable {
        case notArchive
        case unsupportedFormat
        case missingFile(String)
        case checksumMismatch(String)
        case unlistedFile(String)
        case entryCountMismatch
        /// A path that is absolute, climbs with `..`, or resolves outside
        /// the package through a symbolic link.
        case unsafePath(String)
        case duplicateEntryID(UUID)
    }

    /// The reasons File > Restore Archive… stops, worded for the alert.
    enum RestoreError: LocalizedError, Equatable {
        case notArchive
        case unsupportedVersion
        case damaged
        case unsafePath
        case duplicateEntry
        case journalNotEmpty
        /// A failure after the restore started. Nothing was kept.
        case failed(String)

        init(_ error: any Error) {
            switch error {
            case let error as RestoreError:
                self = error
            case let error as ValidationError:
                switch error {
                case .notArchive, .missingFile(JournalArchive.manifestFilename): self = .notArchive
                case .unsupportedFormat: self = .unsupportedVersion
                case .missingFile, .checksumMismatch, .unlistedFile, .entryCountMismatch: self = .damaged
                case .unsafePath: self = .unsafePath
                case .duplicateEntryID: self = .duplicateEntry
                }
            case is DecodingError:
                self = .notArchive
            default:
                self = .failed(error.localizedDescription)
            }
        }

        var errorDescription: String? {
            switch self {
            case .notArchive: "This file is not a Lateralus archive."
            case .unsupportedVersion: "This archive version is not supported. Update Lateralus, then try again."
            case .damaged: "A file in this archive is damaged. Nothing was restored."
            case .unsafePath: "This archive points to a file outside the archive. Nothing was restored."
            case .duplicateEntry: "This archive lists the same entry twice. Nothing was restored."
            case .journalNotEmpty: "Restore works only into an empty journal."
            case .failed(let message): "Nothing was restored. \(message)"
            }
        }
    }

    /// A validated archive, ready to restore. Every attachment path in
    /// `entries` is safe and listed in the manifest with a good checksum.
    struct RestorePlan: Equatable, Sendable {
        var root: URL
        var entries: [Entry]

        var attachmentCount: Int {
            entries.reduce(0) { count, entry in
                count + (entry.sketchFile == nil ? 0 : 1) + (entry.voiceNoteFile == nil ? 0 : 1)
            }
        }

        var displayName: String {
            FileManager.default.displayName(atPath: root.path(percentEncoded: false))
        }
    }

    // MARK: - Coding

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(.iso8601WithFractionalSeconds))
        }
        return encoder
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            if let date = try? Date(text, strategy: .iso8601WithFractionalSeconds) {
                return date
            }
            return try Date(text, strategy: .iso8601)
        }
        return decoder
    }

    // MARK: - Export

    /// Takes a value copy of every entry, oldest first.
    @MainActor
    static func sources(for entries: [JournalEntry], attachments: AttachmentStore) -> [Source] {
        entries
            .sorted { ($0.date, $0.id.uuidString) < ($1.date, $1.id.uuidString) }
            .map { entry in
                Source(
                    id: entry.id,
                    date: entry.date,
                    exerciseRaw: entry.exerciseRaw,
                    promptHeadline: entry.promptHeadline,
                    promptDetail: entry.promptDetail,
                    responseText: entry.responseText,
                    isDaily: entry.isDaily,
                    isFavorite: entry.isFavorite,
                    sketchData: entry.sketchData,
                    voiceNoteURL: entry.voiceNoteFile.map {
                        attachments.voiceNotesDirectory.appending(path: $0)
                    }
                )
            }
    }

    /// The first free `Lateralus Archive yyyy-MM-dd[ n].lateralusarchive`
    /// URL in `folder`.
    static func availableURL(in folder: URL, date: Date, timeZone: TimeZone = .current) -> URL {
        let day = date.formatted(Date.ISO8601FormatStyle(timeZone: timeZone).year().month().day())
        let base = "Lateralus Archive \(day)"
        var candidate = folder.appending(path: "\(base).\(fileExtension)", directoryHint: .isDirectory)
        var suffix = 2
        while FileManager.default.fileExists(atPath: candidate.path(percentEncoded: false)) {
            candidate = folder.appending(path: "\(base) \(suffix).\(fileExtension)", directoryHint: .isDirectory)
            suffix += 1
        }
        return candidate
    }

    /// Writes a complete archive into `folder` and returns its URL. If any
    /// step fails, the staged files are removed and nothing is left behind.
    @discardableResult
    static func export(_ sources: [Source], into folder: URL, date: Date = .now) throws -> URL {
        let fileManager = FileManager.default
        let staging = folder.appending(
            path: ".Lateralus Archive \(UUID().uuidString).staging",
            directoryHint: .isDirectory
        )
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: false)
        do {
            try writeContents(sources, to: staging, date: date)
            let destination = availableURL(in: folder, date: date)
            try fileManager.moveItem(at: staging, to: destination)
            return destination
        } catch {
            try? fileManager.removeItem(at: staging)
            throw error
        }
    }

    private static func writeContents(_ sources: [Source], to root: URL, date: Date) throws {
        let fileManager = FileManager.default
        var files: [Manifest.File] = []
        var entries: [Entry] = []

        func write(_ data: Data, to path: String) throws {
            let url = root.appending(path: path)
            try fileManager.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try data.write(to: url, options: .withoutOverwriting)
            files.append(Manifest.File(path: path, size: data.count, sha256: sha256(data)))
        }

        for source in sources {
            var sketchPath: String?
            if let sketchData = source.sketchData {
                let path = "\(sketchesDirectory)/\(source.id.uuidString).json"
                try write(sketchData, to: path)
                sketchPath = path
            }

            var voiceNotePath: String?
            if let voiceNoteURL = source.voiceNoteURL {
                guard fileManager.fileExists(atPath: voiceNoteURL.path(percentEncoded: false)) else {
                    throw ExportError.missingAttachment(entryDate: source.date)
                }
                let path = "\(voiceNotesDirectory)/\(voiceNoteURL.lastPathComponent)"
                try write(Data(contentsOf: voiceNoteURL, options: .mappedIfSafe), to: path)
                voiceNotePath = path
            }

            entries.append(Entry(
                id: source.id,
                date: source.date,
                exercise: source.exerciseRaw,
                promptHeadline: source.promptHeadline,
                promptDetail: source.promptDetail,
                responseText: source.responseText,
                isDaily: source.isDaily,
                isFavorite: source.isFavorite,
                sketchFile: sketchPath,
                voiceNoteFile: voiceNotePath
            ))
        }

        let document = EntriesDocument(formatVersion: formatVersion, entries: entries)
        try write(encoder.encode(document), to: entriesFilename)

        let manifest = Manifest(
            format: format,
            formatVersion: formatVersion,
            createdAt: date,
            entryCount: entries.count,
            files: files.sorted { $0.path < $1.path }
        )
        try encoder.encode(manifest)
            .write(to: root.appending(path: manifestFilename), options: .withoutOverwriting)
    }

    // MARK: - Validation

    /// Reads the manifest and checks that every listed file exists with the
    /// recorded size and checksum, that no file is unlisted, and that the
    /// entry count matches `entries.json`.
    @discardableResult
    static func validate(at root: URL) throws -> Manifest {
        try validatedContents(at: root).manifest
    }

    /// Validates the package at `url` for File > Restore Archive…. Nothing
    /// is written. The package is matched by its extension, not its type
    /// identifier, because team builds declare a different identifier.
    static func restorePlan(at url: URL) throws -> RestorePlan {
        var isDirectory: ObjCBool = false
        guard url.pathExtension.lowercased() == fileExtension,
              FileManager.default.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectory),
              isDirectory.boolValue
        else { throw ValidationError.notArchive }
        return RestorePlan(root: url, entries: try validatedContents(at: url).document.entries)
    }

    private static func validatedContents(at root: URL) throws -> (manifest: Manifest, document: EntriesDocument) {
        let manifestURL = root.appending(path: manifestFilename)
        guard let manifestData = try? Data(contentsOf: manifestURL) else {
            throw ValidationError.missingFile(manifestFilename)
        }
        let manifest = try decoder.decode(Manifest.self, from: manifestData)
        guard manifest.format == format else { throw ValidationError.notArchive }
        guard manifest.formatVersion <= formatVersion else { throw ValidationError.unsupportedFormat }

        // Check every path before any file is read through it.
        for file in manifest.files {
            try checkSafe(file.path, in: root)
        }

        for file in manifest.files {
            guard let data = try? Data(contentsOf: root.appending(path: file.path), options: .mappedIfSafe) else {
                throw ValidationError.missingFile(file.path)
            }
            guard data.count == file.size, sha256(data) == file.sha256 else {
                throw ValidationError.checksumMismatch(file.path)
            }
        }

        let listed = Set(manifest.files.map(\.path))
        for path in try relativeFilePaths(in: root) where path != manifestFilename && !listed.contains(path) {
            throw ValidationError.unlistedFile(path)
        }

        guard listed.contains(entriesFilename) else {
            throw ValidationError.missingFile(entriesFilename)
        }
        let document = try decoder.decode(
            EntriesDocument.self, from: Data(contentsOf: root.appending(path: entriesFilename))
        )
        guard document.formatVersion <= formatVersion else { throw ValidationError.unsupportedFormat }
        guard document.entries.count == manifest.entryCount else {
            throw ValidationError.entryCountMismatch
        }

        var ids: Set<UUID> = []
        for entry in document.entries {
            guard ids.insert(entry.id).inserted else { throw ValidationError.duplicateEntryID(entry.id) }
            for path in [entry.sketchFile, entry.voiceNoteFile].compactMap(\.self) {
                try checkSafe(path, in: root)
                guard listed.contains(path), path != entriesFilename else {
                    throw ValidationError.missingFile(path)
                }
            }
        }
        return (manifest, document)
    }

    /// Throws `unsafePath` unless `path` is a plain relative path that
    /// stays inside `root`, also after symbolic links resolve.
    private static func checkSafe(_ path: String, in root: URL) throws {
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !path.isEmpty, !path.hasPrefix("/"), !path.hasPrefix("~"),
              !components.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." })
        else { throw ValidationError.unsafePath(path) }

        // A missing file is reported later as missing, not as unsafe.
        let url = root.appending(path: path)
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return }
        let rootPath = root.resolvingSymlinksInPath().path(percentEncoded: false)
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard url.resolvingSymlinksInPath().path(percentEncoded: false).hasPrefix(prefix) else {
            throw ValidationError.unsafePath(path)
        }
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Package-relative paths of every visible regular file. Hidden files
    /// such as Finder's `.DS_Store` are ignored.
    private static func relativeFilePaths(in root: URL) throws -> [String] {
        let rootPath = root.resolvingSymlinksInPath().path(percentEncoded: false)
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: [.isRegularFileKey], options: .skipsHiddenFiles
        ) else { return [] }
        var paths: [String] = []
        for case let url as URL in enumerator {
            guard try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { continue }
            let path = url.resolvingSymlinksInPath().path(percentEncoded: false)
            paths.append(path.hasPrefix(prefix) ? String(path.dropFirst(prefix.count)) : url.lastPathComponent)
        }
        return paths
    }
}

private extension FormatStyle where Self == Date.ISO8601FormatStyle {
    nonisolated static var iso8601WithFractionalSeconds: Date.ISO8601FormatStyle {
        Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    }
}

private extension ParseStrategy where Self == Date.ISO8601FormatStyle {
    nonisolated static var iso8601WithFractionalSeconds: Date.ISO8601FormatStyle {
        Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    }
}
