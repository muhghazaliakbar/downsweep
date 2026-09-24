import Foundation

/// Lists the top level of a folder. Never recurses into subfolders for actions.
public struct FolderScanner: Sendable {
    /// Extensions browsers use while a download is still in progress.
    public static let partialExtensions: Set<String> = ["crdownload", "download", "part", "partial", "opdownload", "td"]

    public var ignoredNames: Set<String>

    public init(ignoredNames: Set<String> = [".DS_Store", ".localized"]) {
        self.ignoredNames = ignoredNames
    }

    /// `progress` gets (items read, total) as metadata is read; folders are sized recursively, so this is slow.
    public func scan(folder: URL, progress: (_ completed: Int, _ total: Int) -> Void = { _, _ in }) throws -> [DownloadItem] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        let candidates = urls
            .filter { !ignoredNames.contains($0.lastPathComponent) }
            .filter { !Self.partialExtensions.contains($0.pathExtension.lowercased()) }
        var items: [DownloadItem] = []
        items.reserveCapacity(candidates.count)
        for (index, url) in candidates.enumerated() {
            if let item = MetadataReader.item(at: url) { items.append(item) }
            progress(index + 1, candidates.count)
        }
        return items
    }
}
