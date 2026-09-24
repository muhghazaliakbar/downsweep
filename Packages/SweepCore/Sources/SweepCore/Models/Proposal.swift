import Foundation

public enum ProposedAction: Hashable, Sendable {
    case moveToTrash
    case move(to: URL)
    case tag(String)
}

public enum ProposalCategory: String, CaseIterable, Identifiable, Sendable {
    case installers
    case duplicates
    case sourceRules
    case stale

    public var id: String { rawValue }
}

public enum ProposalReason: Hashable, Sendable {
    case installerAlreadyInstalled(InstallerMatch)
    case duplicate(original: URL)
    case sourceRule(SourceRule)
    case stale(idleDays: Int)
    case expired(idleDays: Int)

    public var category: ProposalCategory {
        switch self {
        case .installerAlreadyInstalled: .installers
        case .duplicate: .duplicates
        case .sourceRule: .sourceRules
        case .stale, .expired: .stale
        }
    }
}

/// A suggested action on one item, with the reason shown to the person.
public struct Proposal: Identifiable, Hashable, Sendable {
    public let id: URL
    public let item: DownloadItem
    public let action: ProposedAction
    public let reason: ProposalReason

    public init(item: DownloadItem, action: ProposedAction, reason: ProposalReason) {
        self.id = item.url
        self.item = item
        self.action = action
        self.reason = reason
    }

    /// Bytes this proposal frees from the watched folder (tags free nothing).
    public var reclaimableBytes: Int64 {
        switch action {
        case .moveToTrash, .move: item.size
        case .tag: 0
        }
    }
}

/// Automatic mode stops and asks when one pass would move this much.
public enum SafetyLimit {
    public static let maxItems = 50
    public static let maxBytes: Int64 = 10 * 1_000_000_000

    public static func requiresConfirmation(_ proposals: [Proposal]) -> Bool {
        let moving = proposals.filter { $0.reclaimableBytes > 0 }
        return moving.count > maxItems || moving.reduce(0) { $0 + $1.item.size } > maxBytes
    }
}
