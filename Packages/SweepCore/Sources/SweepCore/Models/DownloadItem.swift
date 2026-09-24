import Foundation

/// A single top-level entry in the watched folder. Folders and bundles count as one item.
public struct DownloadItem: Identifiable, Hashable, Sendable {
    public var id: URL { url }

    public let url: URL
    public let size: Int64
    public let isDirectory: Bool
    /// When the item landed in the folder (`kMDItemDateAdded`).
    public let dateAdded: Date?
    /// When the item was last opened (`kMDItemLastUsedDate`), or the newest child for folders.
    public let lastUsed: Date?
    /// When the content last changed; for folders, the newest change anywhere inside.
    /// A recent value means the item may still be downloading, copying or unpacking.
    public let contentModified: Date?
    /// Source URLs recorded by the browser (`kMDItemWhereFroms`): usually the file URL, then the referrer.
    public let whereFroms: [URL]

    public init(
        url: URL,
        size: Int64,
        isDirectory: Bool = false,
        dateAdded: Date?,
        lastUsed: Date? = nil,
        contentModified: Date? = nil,
        whereFroms: [URL] = []
    ) {
        self.url = url
        self.size = size
        self.isDirectory = isDirectory
        self.dateAdded = dateAdded
        self.lastUsed = lastUsed
        self.contentModified = contentModified
        self.whereFroms = whereFroms
    }

    public var name: String { url.lastPathComponent }

    public var fileExtension: String { url.pathExtension.lowercased() }

    /// Hosts of every recorded source URL, lowercased, without duplicates.
    public var sourceHosts: [String] {
        var seen = Set<String>()
        return whereFroms.compactMap { $0.host()?.lowercased() }.filter { seen.insert($0).inserted }
    }

    /// The host people recognise: the referrer when present (e.g. `mail.google.com`), else the file host.
    public var primarySourceHost: String? { sourceHosts.last }

    public var isPartialDownload: Bool {
        FolderScanner.partialExtensions.contains(fileExtension)
    }
}
