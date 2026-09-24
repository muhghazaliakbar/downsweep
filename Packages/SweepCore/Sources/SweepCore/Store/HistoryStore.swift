import Foundation
import GRDB

/// Action history in a SQLite database in Application Support. Entries older than 90 days are
/// dropped when the history is loaded.
///
/// Each action is one insert or update, instead of rewriting the whole history. A `history.json`
/// left by v0.1 is imported once, then renamed to `history.json.imported`.
public actor HistoryStore {
    public static let retention: TimeInterval = 90 * 86_400

    private let database: DatabaseQueue

    /// Opens (or creates) the database, importing `legacyJSON` if it exists and the database is empty.
    public init(databaseURL: URL, legacyJSON: URL? = nil) throws {
        try FileManager.default.createDirectory(at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        database = try DatabaseQueue(path: databaseURL.path)
        try Self.migrator.migrate(database)
        if let legacyJSON { try Self.importLegacyJSON(legacyJSON, into: database) }
    }

    /// A throwaway store, for tests and for when the database can't be opened.
    public init() {
        // An in-memory database can't fail to open, and the schema is fixed.
        database = try! DatabaseQueue()
        try! Self.migrator.migrate(database)
    }

    public static func applicationSupport() throws -> HistoryStore {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Downsweep", directoryHint: .isDirectory)
        return try HistoryStore(
            databaseURL: folder.appending(path: "history.sqlite"),
            legacyJSON: folder.appending(path: "history.json")
        )
    }

    /// Newest first, after dropping entries past the retention window.
    public func load(now: Date = .now) throws -> [HistoryEntry] {
        try database.write { db in
            try HistoryEntry.filter(Column("date") < now.addingTimeInterval(-Self.retention)).deleteAll(db)
            return try HistoryEntry.order(Column("date").desc).fetchAll(db)
        }
    }

    public func append(_ entries: [HistoryEntry]) throws {
        try database.write { db in
            for entry in entries { try entry.insert(db) }
        }
    }

    public func setUndone(_ id: UUID, _ undone: Bool = true) throws {
        try database.write { db in
            _ = try HistoryEntry.filter(key: id).updateAll(db, Column("undone").set(to: undone))
        }
    }

    // MARK: - Schema

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("history") { db in
            try db.create(table: HistoryEntry.databaseTableName) { table in
                table.primaryKey("id", .blob)
                table.column("date", .datetime).notNull().indexed()
                table.column("kind", .text).notNull()
                table.column("originalURL", .text).notNull()
                table.column("resultURL", .text)
                table.column("tag", .text)
                table.column("bytes", .integer).notNull()
                table.column("reason", .text).notNull()
                table.column("undone", .boolean).notNull().defaults(to: false)
            }
        }
        return migrator
    }

    private static func importLegacyJSON(_ url: URL, into database: DatabaseQueue) throws {
        guard let data = try? Data(contentsOf: url) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries = (try? decoder.decode([HistoryEntry].self, from: data)) ?? []
        try database.write { db in
            guard try HistoryEntry.fetchCount(db) == 0 else { return }
            for entry in entries { try entry.insert(db, onConflict: .ignore) }
        }
        // Keep the old file rather than delete it, in case anything went wrong.
        let imported = url.appendingPathExtension("imported")
        try? FileManager.default.removeItem(at: imported)
        try FileManager.default.moveItem(at: url, to: imported)
    }
}

extension HistoryEntry: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "history"
}
