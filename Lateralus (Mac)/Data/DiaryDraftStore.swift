import Foundation

/// Unsaved Diary text, kept on disk so a crash or quit does not lose it.
/// Drafts live outside SwiftData: they never count as entries, streaks or
/// Insights activity.
struct DiaryDraft: Codable, Equatable, Identifiable {
    var version = 1
    let id: UUID
    var text: String
    var updatedAt: Date

    init(id: UUID, text: String, updatedAt: Date) {
        self.id = id
        self.text = text
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .distantPast
    }
}

/// Owns the Drafts directory in Application Support. One file per composer
/// draft ID, so two composer windows never overwrite each other.
struct DiaryDraftStore {
    let directory: URL

    static let live = DiaryDraftStore(
        directory: URL.applicationSupportDirectory
            .appending(path: "Lateralus", directoryHint: .isDirectory)
            .appending(path: "Drafts", directoryHint: .isDirectory)
    )

    private func url(for id: UUID) -> URL {
        directory.appending(path: "diary-\(id.uuidString).json")
    }

    /// Writes the draft, or removes it when the text has no content.
    func write(id: UUID, text: String, now: Date = .now) throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            remove(id: id)
            return
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(DiaryDraft(id: id, text: text, updatedAt: now))
        try data.write(to: url(for: id), options: .atomic)
    }

    func draft(id: UUID) -> DiaryDraft? {
        guard let data = try? Data(contentsOf: url(for: id)) else { return nil }
        return try? JSONDecoder().decode(DiaryDraft.self, from: data)
    }

    func remove(id: UUID) {
        try? FileManager.default.removeItem(at: url(for: id))
    }

    /// Every readable draft with content, newest first. Unreadable files are
    /// skipped, not deleted.
    func allDrafts() -> [DiaryDraft] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return [] }
        return contents
            .filter { $0.pathExtension == "json" }
            .compactMap { try? JSONDecoder().decode(DiaryDraft.self, from: Data(contentsOf: $0)) }
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    /// The newest draft that no open composer owns.
    func newestOrphan(excluding owned: Set<UUID>) -> DiaryDraft? {
        allDrafts().first { !owned.contains($0.id) }
    }

    /// Restore puts the draft into an empty editor, or appends it after a
    /// blank line when the editor already has text.
    static func merge(existing: String, draft: String) -> String {
        guard !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return draft }
        var head = existing
        while head.last?.isNewline == true { head.removeLast() }
        return head + "\n\n" + draft
    }
}

/// The draft IDs that open composers own in this process. A draft outside
/// this set is an orphan and can be offered for recovery.
@MainActor
final class DiaryDraftOwnership {
    static let shared = DiaryDraftOwnership()

    private(set) var owned: Set<UUID> = []

    func claim(_ id: UUID) { owned.insert(id) }
    func release(_ id: UUID) { owned.remove(id) }
}
