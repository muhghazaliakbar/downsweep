import Foundation

/// What Downsweep did over one week, built from history. Undone actions don't count.
public struct WeeklySummary: Hashable, Sendable {
    public let interval: DateInterval
    public let trashedCount: Int
    public let movedCount: Int
    public let taggedCount: Int
    /// Bytes moved to the Trash: the space the week actually gave back.
    public let bytesFreed: Int64
    /// Bytes moved into folders by source rules.
    public let bytesOrganized: Int64

    public var itemCount: Int { trashedCount + movedCount + taggedCount }
    public var isEmpty: Bool { itemCount == 0 }

    public init(history: [HistoryEntry], endingAt end: Date, days: Int = 7) {
        let interval = DateInterval(start: end.addingTimeInterval(-Double(days) * 86_400), end: end)
        let counted = history.filter { !$0.undone && interval.contains($0.date) }
        func entries(_ kind: HistoryEntry.Kind) -> [HistoryEntry] { counted.filter { $0.kind == kind } }

        self.interval = interval
        trashedCount = entries(.trash).count
        movedCount = entries(.move).count
        taggedCount = entries(.tag).count
        bytesFreed = entries(.trash).reduce(0) { $0 + $1.bytes }
        bytesOrganized = entries(.move).reduce(0) { $0 + $1.bytes }
    }

    /// Summaries go out on Monday at 9:00 local time, covering the week before.
    public static let deliveryTime = DateComponents(hour: 9, minute: 0, weekday: 2)

    /// The first delivery time after `lastDelivery`. It can be in the past when the Mac was
    /// asleep or the app wasn't running; the summary is then due right away.
    public static func nextDelivery(after lastDelivery: Date, calendar: Calendar = .current) -> Date {
        calendar.nextDate(after: lastDelivery, matching: deliveryTime, matchingPolicy: .nextTime)
            ?? lastDelivery.addingTimeInterval(7 * 86_400)
    }
}
