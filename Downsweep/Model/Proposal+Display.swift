import SwiftUI
import SweepCore

extension ProposalCategory {
    var title: String {
        switch self {
        case .installers: String(localized: "Installed Installers")
        case .duplicates: String(localized: "Duplicates")
        case .sourceRules: String(localized: "Sort by Source")
        case .stale: String(localized: "Stale Files")
        }
    }

    var symbol: String {
        switch self {
        case .installers: "shippingbox"
        case .duplicates: "plus.square.on.square"
        case .sourceRules: "arrow.triangle.branch"
        case .stale: "clock.badge.exclamationmark"
        }
    }

    var tint: Color {
        switch self {
        case .installers: .blue
        case .duplicates: .purple
        case .sourceRules: .teal
        case .stale: .orange
        }
    }
}

extension ReviewSection {
    var title: String {
        switch self {
        case .all: String(localized: "All Suggestions")
        case .category(let category): category.title
        case .history: String(localized: "History")
        }
    }

    var symbol: String {
        switch self {
        case .all: "tray.full"
        case .category(let category): category.symbol
        case .history: "clock.arrow.circlepath"
        }
    }
}

extension Proposal {
    /// One sentence, shown under the file name and stored in history.
    var reasonText: String {
        switch reason {
        case .installerAlreadyInstalled(let match):
            String(localized: "Installer for \(match.installer.name) \(match.installer.version) — \(match.installedVersion) is already installed")
        case .duplicate(let original):
            String(localized: "Identical copy of \(original.lastPathComponent)")
        case .sourceRule(let rule):
            String(localized: "Downloaded from \(rule.normalizedDomain)")
        case .stale(let days):
            String(localized: "Not opened in \(days) days")
        case .expired(let days):
            String(localized: "Stale and untouched for \(days) days")
        }
    }

    var actionTitle: String {
        switch action {
        case .moveToTrash: String(localized: "Move to Trash")
        case .move(let folder): String(localized: "Move to \(folder.lastPathComponent)")
        case .tag(let tag): String(localized: "Tag \(tag)")
        }
    }

    var actionSymbol: String {
        switch action {
        case .moveToTrash: "trash"
        case .move: "folder"
        case .tag: "tag"
        }
    }
}

extension HistoryEntry.Kind {
    var title: String {
        switch self {
        case .trash: String(localized: "Moved to Trash")
        case .move: String(localized: "Moved")
        case .tag: String(localized: "Tagged")
        }
    }

    var symbol: String {
        switch self {
        case .trash: "trash"
        case .move: "folder"
        case .tag: "tag"
        }
    }
}

extension Int64 {
    var fileSize: String { formatted(.byteCount(style: .file)) }
}
