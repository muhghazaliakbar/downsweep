import Foundation

/// Lists the top level of a folder. Never recurses into subfolders for actions.
public struct FolderScanner: Sendable {
    /// Extensions browsers use while a download is still in progress.
    public static let partialExtensions: Set<String> = ["crdownload", "download", "part", "partial", "opdownload", "td"]

    public var ignoredNames: Set<String>

    public init(ignoredNames: Set<String> = [".DS_Store", ".localized"]) {
        self.ignoredNames = ignoredNames
    }

    public func scan(folder: URL) throws -> [DownloadItem] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return urls
            .filter { !ignoredNames.contains($0.lastPathComponent) }
            .filter { !Self.partialExtensions.contains($0.pathExtension.lowercased()) }
            .compactMap(MetadataReader.item(at:))
    }
}
