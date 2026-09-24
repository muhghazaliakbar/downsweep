import CoreServices
import Foundation

/// Reads Spotlight and file-system metadata for one item, with fallbacks when Spotlight has nothing.
public enum MetadataReader {
    private static let resourceKeys: Set<URLResourceKey> = [
        .isDirectoryKey, .totalFileAllocatedSizeKey, .fileSizeKey,
        .addedToDirectoryDateKey, .creationDateKey, .contentAccessDateKey, .contentModificationDateKey,
    ]

    public static func item(at url: URL) -> DownloadItem? {
        guard let values = try? url.resourceValues(forKeys: resourceKeys) else { return nil }
        let spotlight = MDItemCreateWithURL(kCFAllocatorDefault, url as CFURL)
        let isDirectory = values.isDirectory ?? false

        let dateAdded = spotlight.flatMap { attribute($0, kMDItemDateAdded) as Date? }
            ?? values.addedToDirectoryDate
            ?? values.creationDate

        var lastUsed = spotlight.flatMap { attribute($0, kMDItemLastUsedDate) as Date? }
        var size = Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
        var contentModified = values.contentModificationDate

        if isDirectory {
            let contents = directorySummary(url)
            size = contents.size
            contentModified = [contentModified, contents.newestModification].compactMap { $0 }.max()
            lastUsed = [lastUsed, contents.newestModification].compactMap { $0 }.max()
        }

        let whereFroms = (spotlight.flatMap { attribute($0, kMDItemWhereFroms) as [String]? } ?? extendedAttributeWhereFroms(url))
            .compactMap(URL.init(string:))

        return DownloadItem(
            url: url,
            size: size,
            isDirectory: isDirectory,
            dateAdded: dateAdded,
            lastUsed: lastUsed,
            contentModified: contentModified,
            whereFroms: whereFroms
        )
    }

    private static func attribute<T>(_ item: MDItem, _ name: CFString) -> T? {
        MDItemCopyAttribute(item, name) as? T
    }

    /// Spotlight can lag or be disabled; the browser also writes the list as an extended attribute.
    private static func extendedAttributeWhereFroms(_ url: URL) -> [String] {
        let name = "com.apple.metadata:kMDItemWhereFroms"
        return url.withUnsafeFileSystemRepresentation { path -> [String] in
            guard let path else { return [] }
            let length = getxattr(path, name, nil, 0, 0, 0)
            guard length > 0 else { return [] }
            var data = Data(count: length)
            let read = data.withUnsafeMutableBytes { getxattr(path, name, $0.baseAddress, length, 0, 0) }
            guard read == length else { return [] }
            return (try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String]) ?? []
        }
    }

    static func directorySummary(_ url: URL) -> (size: Int64, newestModification: Date?) {
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys) else {
            return (0, nil)
        }
        var size: Int64 = 0
        var newest: Date?
        for case let child as URL in enumerator {
            guard let values = try? child.resourceValues(forKeys: Set(keys)) else { continue }
            size += Int64(values.totalFileAllocatedSize ?? 0)
            if let modified = values.contentModificationDate, modified > (newest ?? .distantPast) {
                newest = modified
            }
        }
        return (size, newest)
    }
}
