import Foundation

/// Everything the policy needs besides the items themselves. Plain data, so tests can build it by hand.
public struct PolicyContext: Sendable {
    public var thresholds: LifecycleThresholds
    public var rules: [SourceRule]
    public var pinned: Set<URL>
    public var installerStatus: [URL: InstallerStatus]
    /// Duplicate URL → original to keep.
    public var duplicates: [URL: URL]
    public var now: Date

    public init(
        thresholds: LifecycleThresholds = .default,
        rules: [SourceRule] = [],
        pinned: Set<URL> = [],
        installerStatus: [URL: InstallerStatus] = [:],
        duplicates: [URL: URL] = [:],
        now: Date = .now
    ) {
        self.thresholds = thresholds
        self.rules = rules
        self.pinned = pinned
        self.installerStatus = installerStatus
        self.duplicates = duplicates
        self.now = now
    }
}

/// Pure function from items + context to proposals. At most one proposal per item.
public enum PolicyEngine {
    public static let staleTag = "Stale"
    /// Installers and duplicates are proposed once they are at least this old; lifecycle rules wait longer.
    public static let gracePeriod: TimeInterval = 60 * 60

    public static func proposals(for items: [DownloadItem], context: PolicyContext) -> [Proposal] {
        items.compactMap { proposal(for: $0, context: context) }
    }

    /// Checks run in priority order: the most certain reason wins.
    public static func proposal(for item: DownloadItem, context: PolicyContext) -> Proposal? {
        if context.pinned.contains(item.url) || item.isPartialDownload { return nil }
        // Give the person time to finish installing or opening what they just downloaded.
        if let added = item.dateAdded, context.now.timeIntervalSince(added) < gracePeriod { return nil }

        let installer = context.installerStatus[item.url]
        if case .installed(let match) = installer {
            return Proposal(item: item, action: .moveToTrash, reason: .installerAlreadyInstalled(match))
        }

        if let original = context.duplicates[item.url] {
            return Proposal(item: item, action: .moveToTrash, reason: .duplicate(original: original))
        }

        if Lifecycle.stage(for: item, thresholds: context.thresholds, now: context.now) == .new { return nil }

        if let rule = context.rules.first(where: { $0.matches(item) }) {
            return Proposal(item: item, action: .move(to: rule.destination), reason: .sourceRule(rule))
        }

        let idle = Lifecycle.idleDays(for: item, now: context.now) ?? 0
        switch Lifecycle.stage(for: item, thresholds: context.thresholds, now: context.now) {
        case .expired:
            // An installer newer than the installed app might still be needed: tag it, never trash it.
            if case .newerThanInstalled = installer {
                return Proposal(item: item, action: .tag(staleTag), reason: .stale(idleDays: idle))
            }
            return Proposal(item: item, action: .moveToTrash, reason: .expired(idleDays: idle))
        case .stale:
            return Proposal(item: item, action: .tag(staleTag), reason: .stale(idleDays: idle))
        case .new, .active, .idle, .unknown:
            return nil
        }
    }
}
