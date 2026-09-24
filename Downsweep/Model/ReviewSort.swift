import Foundation
import SweepCore

/// Finder-style "Sort By" for the Review list.
enum ReviewSort: String, CaseIterable, Identifiable {
    case name, kind, dateAdded, lastOpened, size

    var id: Self { self }

    var title: String {
        switch self {
        case .name: String(localized: "Name")
        case .kind: String(localized: "Kind")
        case .dateAdded: String(localized: "Date Added")
        case .lastOpened: String(localized: "Date Last Opened")
        case .size: String(localized: "Size")
        }
    }

    /// Finder's default direction when picking a column: dates and sizes start with the biggest.
    var defaultAscending: Bool {
        switch self {
        case .name, .kind: true
        case .dateAdded, .lastOpened, .size: false
        }
    }

    func orderTitle(ascending: Bool) -> String {
        switch self {
        case .name, .kind: ascending ? String(localized: "A to Z") : String(localized: "Z to A")
        case .dateAdded, .lastOpened: ascending ? String(localized: "Oldest First") : String(localized: "Newest First")
        case .size: ascending ? String(localized: "Smallest First") : String(localized: "Largest First")
        }
    }

    /// The date a row shows next to the size, matching the sort when it's by date.
    func displayedDate(for item: DownloadItem) -> Date? {
        self == .lastOpened ? item.lastUsed : item.dateAdded
    }

    /// Sorts stably by this key; items without a date always go last, like in Finder.
    func sorted(_ proposals: [Proposal], ascending: Bool) -> [Proposal] {
        let kindTitles: [URL: String] = self == .kind
            ? Dictionary(proposals.map { ($0.id, FileKind(item: $0.item).title) }, uniquingKeysWith: { a, _ in a })
            : [:]
        return proposals.sorted { lhs, rhs in
            let order = compare(lhs.item, rhs.item, ascending: ascending, kindTitles: kindTitles)
            if order != .orderedSame { return order == .orderedAscending }
            return lhs.item.name.localizedStandardCompare(rhs.item.name) == .orderedAscending
        }
    }

    private func compare(_ lhs: DownloadItem, _ rhs: DownloadItem, ascending: Bool, kindTitles: [URL: String]) -> ComparisonResult {
        func directed<T: Comparable>(_ a: T, _ b: T) -> ComparisonResult {
            if a == b { return .orderedSame }
            return (a < b) == ascending ? .orderedAscending : .orderedDescending
        }
        func dates(_ a: Date?, _ b: Date?) -> ComparisonResult {
            switch (a, b) {
            case let (a?, b?): directed(a, b)
            case (nil, nil): .orderedSame
            case (nil, _): .orderedDescending
            case (_, nil): .orderedAscending
            }
        }
        switch self {
        case .name:
            let order = lhs.name.localizedStandardCompare(rhs.name)
            return ascending || order == .orderedSame ? order : (order == .orderedAscending ? .orderedDescending : .orderedAscending)
        case .kind:
            return directed(kindTitles[lhs.url, default: ""], kindTitles[rhs.url, default: ""])
        case .dateAdded:
            return dates(lhs.dateAdded, rhs.dateAdded)
        case .lastOpened:
            return dates(lhs.lastUsed, rhs.lastUsed)
        case .size:
            return directed(lhs.size, rhs.size)
        }
    }
}
