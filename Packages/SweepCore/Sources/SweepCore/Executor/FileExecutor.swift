import Foundation

public struct HistoryEntry: Codable, Hashable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable { case trash, move, tag }

    public let id: UUID
    public let date: Date
    public let kind: Kind
    public let originalURL: URL
    /// Where the item ended up (Trash or destination). `nil` for tags.
    public let resultURL: URL?
    public let tag: String?
    public let bytes: Int64
    public let reason: String
    public var undone: Bool

    public init(
        id: UUID = UUID(), date: Date = .now, kind: Kind, originalURL: URL, resultURL: URL?,
        tag: String? = nil, bytes: Int64, reason: String, undone: Bool = false
    ) {
        self.id = id
        self.date = date
        self.kind = kind
        self.originalURL = originalURL
        self.resultURL = resultURL
        self.tag = tag
        self.bytes = bytes
        self.reason = reason
        self.undone = undone
    }
}

public enum ExecutorError: LocalizedError, Equatable {
    case itemChanged(URL)
    case cannotUndo(URL)

    public var errorDescription: String? {
        switch self {
        case .itemChanged(let url): "\(url.lastPathComponent) changed since it was scanned, so it was left alone."
        case .cannotUndo(let url): "\(url.lastPathComponent) is no longer where Downsweep put it."
        }
    }
}

/// The only code that touches files. Three actions: Trash, move, tag. Never deletes.
public struct FileExecutor: Sendable {
    public init() {}

    public func perform(_ proposal: Proposal, reason: String) throws -> HistoryEntry {
        let item = proposal.item
        try verifyUnchanged(item)

        switch proposal.action {
        case .moveToTrash:
            var trashed: NSURL?
            try FileManager.default.trashItem(at: item.url, resultingItemURL: &trashed)
            return HistoryEntry(kind: .trash, originalURL: item.url, resultURL: trashed as URL?, bytes: item.size, reason: reason)

        case .move(let folder):
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let destination = Self.uniqueDestination(for: item.name, in: folder)
            try FileManager.default.moveItem(at: item.url, to: destination)
            return HistoryEntry(kind: .move, originalURL: item.url, resultURL: destination, bytes: item.size, reason: reason)

        case .tag(let tag):
            try Self.setTag(tag, on: item.url, present: true)
            return HistoryEntry(kind: .tag, originalURL: item.url, resultURL: nil, tag: tag, bytes: 0, reason: reason)
        }
    }

    public func undo(_ entry: HistoryEntry) throws {
        switch entry.kind {
        case .trash, .move:
            guard let result = entry.resultURL, FileManager.default.fileExists(atPath: result.path) else {
                throw ExecutorError.cannotUndo(entry.originalURL)
            }
            let folder = entry.originalURL.deletingLastPathComponent()
            let destination = FileManager.default.fileExists(atPath: entry.originalURL.path)
                ? Self.uniqueDestination(for: entry.originalURL.lastPathComponent, in: folder)
                : entry.originalURL
            try FileManager.default.moveItem(at: result, to: destination)
        case .tag:
            try Self.setTag(entry.tag ?? PolicyEngine.staleTag, on: entry.originalURL, present: false)
        }
    }

    /// The file must still exist with the size seen at scan time, or nothing happens.
    private func verifyUnchanged(_ item: DownloadItem) throws {
        guard FileManager.default.fileExists(atPath: item.url.path) else { throw ExecutorError.itemChanged(item.url) }
        guard !item.isDirectory else { return }
        // URL caches resource values; a stale cache would hide exactly the change we check for.
        var fresh = item.url
        fresh.removeAllCachedResourceValues()
        let size = (try? fresh.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey]))
            .map { Int64($0.totalFileAllocatedSize ?? $0.fileSize ?? 0) }
        if let size, size != item.size { throw ExecutorError.itemChanged(item.url) }
    }

    /// `Report.pdf` → `Report 2.pdf` → `Report 3.pdf`, like Finder.
    public static func uniqueDestination(for name: String, in folder: URL) -> URL {
        let candidate = folder.appending(path: name)
        guard FileManager.default.fileExists(atPath: candidate.path) else { return candidate }
        let stem = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var index = 2
        while true {
            let next = folder.appending(path: ext.isEmpty ? "\(stem) \(index)" : "\(stem) \(index).\(ext)")
            if !FileManager.default.fileExists(atPath: next.path) { return next }
            index += 1
        }
    }

    static func tags(of url: URL) -> [String] {
        (try? url.resourceValues(forKeys: [.tagNamesKey]).tagNames) ?? []
    }

    static func setTag(_ tag: String, on url: URL, present: Bool) throws {
        var tags = tags(of: url).filter { $0 != tag }
        if present { tags.append(tag) }
        try (url as NSURL).setResourceValue(tags, forKey: .tagNamesKey)
    }
}
