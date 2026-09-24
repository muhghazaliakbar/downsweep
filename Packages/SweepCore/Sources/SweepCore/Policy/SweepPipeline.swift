import Foundation

public struct SweepConfiguration: Codable, Hashable, Sendable {
    public var thresholds: LifecycleThresholds
    public var rules: [SourceRule]
    public var pinned: Set<URL>
    public var detectInstallers: Bool
    public var detectDuplicates: Bool

    public init(
        thresholds: LifecycleThresholds = .default,
        rules: [SourceRule] = SourceRule.templates(),
        pinned: Set<URL> = [],
        detectInstallers: Bool = true,
        detectDuplicates: Bool = true
    ) {
        self.thresholds = thresholds
        self.rules = rules
        self.pinned = pinned
        self.detectInstallers = detectInstallers
        self.detectDuplicates = detectDuplicates
    }
}

public struct ScanResult: Sendable {
    public let folder: URL
    public let items: [DownloadItem]
    public let proposals: [Proposal]
    public let installerStatus: [URL: InstallerStatus]
    public let finishedAt: Date

    public var reclaimableBytes: Int64 { proposals.reduce(0) { $0 + $1.reclaimableBytes } }

    /// Most common source hosts in the folder, to seed new rules.
    public var topSourceHosts: [(host: String, count: Int)] {
        let hosts = items.compactMap(\.primarySourceHost)
        return Dictionary(grouping: hosts, by: { $0 })
            .map { ($0.key, $0.value.count) }
            .sorted { $0.1 == $1.1 ? $0.0 < $1.0 : $0.1 > $1.1 }
    }
}

/// Scan → inspect → decide. Runs off the main actor; performs no file changes.
public enum SweepPipeline {
    public static func run(
        folder: URL,
        configuration: SweepConfiguration,
        now: Date = .now
    ) async throws -> ScanResult {
        let items = try FolderScanner().scan(folder: folder)

        var installerStatus: [URL: InstallerStatus] = [:]
        if configuration.detectInstallers {
            let inspector = InstallerInspector(index: InstalledAppIndex.build())
            let installers = items.filter { InstallerInspector.supportedExtensions.contains($0.fileExtension) }
            // Few at a time: each DMG is a mount.
            for batch in installers.chunked(into: 4) {
                await withTaskGroup(of: (URL, InstallerStatus?).self) { group in
                    for item in batch {
                        group.addTask { (item.url, await inspector.inspect(item)) }
                    }
                    for await (url, status) in group {
                        if let status { installerStatus[url] = status }
                    }
                }
            }
        }

        let duplicates = configuration.detectDuplicates ? DuplicateFinder.duplicates(in: items) : [:]

        let context = PolicyContext(
            thresholds: configuration.thresholds,
            rules: configuration.rules,
            pinned: configuration.pinned,
            installerStatus: installerStatus,
            duplicates: duplicates,
            now: now
        )
        return ScanResult(
            folder: folder,
            items: items,
            proposals: PolicyEngine.proposals(for: items, context: context),
            installerStatus: installerStatus,
            finishedAt: now
        )
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
