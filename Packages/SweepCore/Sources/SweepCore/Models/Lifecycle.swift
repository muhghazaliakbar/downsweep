import Foundation

public struct LifecycleThresholds: Codable, Hashable, Sendable {
    /// Items younger than this are never touched.
    public var newDays: Int
    /// Items opened within this window count as active.
    public var activeDays: Int
    /// Items idle for this long become stale and get tagged.
    public var staleDays: Int
    /// Stale items left alone for this long become expired and go to the Trash.
    public var expireAfterStaleDays: Int

    public init(newDays: Int = 3, activeDays: Int = 14, staleDays: Int = 30, expireAfterStaleDays: Int = 14) {
        self.newDays = newDays
        self.activeDays = activeDays
        self.staleDays = staleDays
        self.expireAfterStaleDays = expireAfterStaleDays
    }

    public static let `default` = LifecycleThresholds()
}

public enum LifecycleStage: String, Codable, CaseIterable, Sendable {
    case new
    case active
    /// Not opened recently, but not stale yet. No action.
    case idle
    case stale
    case expired
    /// No date information at all. Never acted on automatically.
    case unknown
}

public enum Lifecycle {
    public static func stage(
        for item: DownloadItem,
        thresholds: LifecycleThresholds = .default,
        now: Date = .now
    ) -> LifecycleStage {
        guard let added = item.dateAdded else { return .unknown }
        if days(from: added, to: now) < thresholds.newDays { return .new }

        let idle = idleDays(for: item, now: now) ?? 0
        if idle < thresholds.activeDays { return .active }
        if idle < thresholds.staleDays { return .idle }
        if idle < thresholds.staleDays + thresholds.expireAfterStaleDays { return .stale }
        return .expired
    }

    /// Whole days since the item was last opened, falling back to when it was added.
    public static func idleDays(for item: DownloadItem, now: Date = .now) -> Int? {
        guard let reference = [item.lastUsed, item.dateAdded].compactMap({ $0 }).max() else { return nil }
        return days(from: reference, to: now)
    }

    static func days(from start: Date, to end: Date) -> Int {
        max(0, Int(end.timeIntervalSince(start) / 86_400))
    }
}
