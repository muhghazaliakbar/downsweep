import Foundation

/// Bundle ID → installed app, built once per scan from the usual application folders.
public struct InstalledAppIndex: Sendable {
    public struct Entry: Hashable, Sendable {
        public let url: URL
        public let info: AppBundleInfo
    }

    private let entries: [String: Entry]

    public init(entries: [Entry]) {
        var byID: [String: Entry] = [:]
        for entry in entries {
            // Keep the newest copy when the same app is installed twice.
            if let existing = byID[entry.info.bundleID],
               AppVersion(existing.info.version) >= AppVersion(entry.info.version) { continue }
            byID[entry.info.bundleID] = entry
        }
        self.entries = byID
    }

    public func entry(for bundleID: String) -> Entry? { entries[bundleID] }

    public static func defaultSearchPaths(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [URL] {
        [
            URL(filePath: "/Applications", directoryHint: .isDirectory),
            home.appending(path: "Applications", directoryHint: .isDirectory),
        ]
    }

    /// Looks two levels deep so `/Applications/Utilities` and `/Applications/Setapp` are covered.
    public static func build(searchPaths: [URL] = defaultSearchPaths()) -> InstalledAppIndex {
        var found: [Entry] = []
        for root in searchPaths {
            collectApps(in: root, depth: 2, into: &found)
        }
        return InstalledAppIndex(entries: found)
    }

    private static func collectApps(in folder: URL, depth: Int, into found: inout [Entry]) {
        guard depth > 0,
              let children = try? FileManager.default.contentsOfDirectory(
                  at: folder, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
              )
        else { return }
        for child in children {
            if child.pathExtension == "app" {
                let plist = child.appending(path: "Contents/Info.plist")
                if let data = try? Data(contentsOf: plist),
                   let info = AppBundleInfo(infoPlist: data, fallbackName: child.deletingPathExtension().lastPathComponent) {
                    found.append(Entry(url: child, info: info))
                }
            } else if (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                collectApps(in: child, depth: depth - 1, into: &found)
            }
        }
    }
}
