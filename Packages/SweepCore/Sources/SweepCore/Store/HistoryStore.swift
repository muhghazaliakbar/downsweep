import Foundation

/// Action history as JSON in Application Support. Entries older than 90 days are dropped on save.
///
/// JSON keeps v0.1 dependency-free; the spec's SQLite store (GRDB) replaces this in M2.
public actor HistoryStore {
    public static let retention: TimeInterval = 90 * 86_400

    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func applicationSupport() -> HistoryStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return HistoryStore(fileURL: base.appending(path: "Downsweep/history.json"))
    }

    public func load() -> [HistoryEntry] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([HistoryEntry].self, from: data)) ?? []
    }

    public func save(_ entries: [HistoryEntry], now: Date = .now) throws {
        let kept = entries.filter { now.timeIntervalSince($0.date) < Self.retention }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(kept).write(to: fileURL, options: .atomic)
    }
}
