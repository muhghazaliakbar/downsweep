import CryptoKit
import Foundation

/// Finds browser re-downloads such as `report (1).pdf` or `report-2.pdf` that are byte-identical.
public enum DuplicateFinder {
    public typealias Hasher = @Sendable (URL) throws -> String

    /// Returns duplicate URL → the original that should be kept (the oldest copy).
    public static func duplicates(in items: [DownloadItem], hasher: Hasher = sha256) -> [URL: URL] {
        var result: [URL: URL] = [:]
        for group in candidateGroups(items) {
            let byHash = Dictionary(grouping: group) { (try? hasher($0.url)) ?? UUID().uuidString }
            for copies in byHash.values where copies.count > 1 {
                let sorted = copies.sorted { ($0.dateAdded ?? .distantFuture) < ($1.dateAdded ?? .distantFuture) }
                let original = sorted[0].url
                for copy in sorted.dropFirst() { result[copy.url] = original }
            }
        }
        return result
    }

    /// Same base name, extension and size, with at least one member carrying a copy suffix.
    static func candidateGroups(_ items: [DownloadItem]) -> [[DownloadItem]] {
        struct Key: Hashable { let base: String; let ext: String; let size: Int64 }
        let files = items.filter { !$0.isDirectory && $0.size > 0 }
        let groups = Dictionary(grouping: files) { item in
            Key(base: baseName(of: item.url).lowercased(), ext: item.fileExtension, size: item.size)
        }
        return groups.values.filter { group in
            group.count > 1 && group.contains { baseName(of: $0.url) != $0.url.deletingPathExtension().lastPathComponent }
        }
    }

    /// `report (2)` → `report`, `report-2` → `report`, `report` → `report`.
    static func baseName(of url: URL) -> String {
        let stem = url.deletingPathExtension().lastPathComponent
        if let match = stem.wholeMatch(of: /(.+?)(?: \(\d{1,3}\)|-\d{1,3})/) {
            return String(match.1)
        }
        return stem
    }

    @Sendable public static func sha256(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
