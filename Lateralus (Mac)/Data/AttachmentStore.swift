import Foundation

/// Owns the VoiceNotes directory in Application Support and keeps it
/// consistent with the database: files are committed by move, deleted with
/// their entries, and orphans are swept at startup.
struct AttachmentStore {
    let voiceNotesDirectory: URL

    static let live = AttachmentStore(
        voiceNotesDirectory: URL.applicationSupportDirectory
            .appending(path: "Lateralus", directoryHint: .isDirectory)
            .appending(path: "VoiceNotes", directoryHint: .isDirectory)
    )

    /// A scratch location for in-progress recordings. Never committed
    /// directly; `commit` moves it into the store.
    func temporaryRecordingURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "recording-\(UUID().uuidString).m4a")
    }

    /// Moves a finished temporary recording into the store and returns the
    /// stable filename the database should own.
    func commit(temporaryURL: URL) throws -> String {
        try FileManager.default.createDirectory(at: voiceNotesDirectory, withIntermediateDirectories: true)
        let filename = "note-\(UUID().uuidString).m4a"
        try FileManager.default.moveItem(
            at: temporaryURL,
            to: voiceNotesDirectory.appending(path: filename)
        )
        return filename
    }

    /// Copies a voice note from a restored archive into the store under a
    /// new stable filename. The source stays in place. Nonisolated so the
    /// copy can run off the main actor.
    nonisolated func commitCopy(of sourceURL: URL) throws -> String {
        try FileManager.default.createDirectory(at: voiceNotesDirectory, withIntermediateDirectories: true)
        let filename = "note-\(UUID().uuidString).m4a"
        try FileManager.default.copyItem(at: sourceURL, to: voiceNotesDirectory.appending(path: filename))
        return filename
    }

    func url(forFile filename: String) -> URL? {
        let url = voiceNotesDirectory.appending(path: filename)
        return FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) ? url : nil
    }

    func remove(file filename: String) {
        try? FileManager.default.removeItem(at: voiceNotesDirectory.appending(path: filename))
    }

    /// Deletes files no entry references. Missing referenced files are left
    /// to the UI, which simply hides the player for that entry.
    func sweepOrphans(referencedFiles: Set<String>) {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: voiceNotesDirectory, includingPropertiesForKeys: nil
        ) else { return }
        for url in contents where !referencedFiles.contains(url.lastPathComponent) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
