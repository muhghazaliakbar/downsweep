import Foundation

/// The identity of an app bundle found inside an installer or on disk.
public struct AppBundleInfo: Codable, Hashable, Sendable {
    public let bundleID: String
    public let name: String
    public let version: String

    public init(bundleID: String, name: String, version: String) {
        self.bundleID = bundleID
        self.name = name
        self.version = version
    }

    init?(infoPlist data: Data, fallbackName: String) {
        guard
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let bundleID = plist["CFBundleIdentifier"] as? String
        else { return nil }
        let name = (plist["CFBundleDisplayName"] as? String) ?? (plist["CFBundleName"] as? String) ?? fallbackName
        let version = (plist["CFBundleShortVersionString"] as? String) ?? (plist["CFBundleVersion"] as? String) ?? "0"
        self.init(bundleID: bundleID, name: name, version: version)
    }
}

public struct InstallerMatch: Hashable, Sendable {
    public let installer: AppBundleInfo
    public let installedVersion: String
    public let installedURL: URL

    public init(installer: AppBundleInfo, installedVersion: String, installedURL: URL) {
        self.installer = installer
        self.installedVersion = installedVersion
        self.installedURL = installedURL
    }
}

public enum InstallerStatus: Hashable, Sendable {
    /// The installed app is the same version or newer. Safe to trash the installer.
    case installed(InstallerMatch)
    /// The installer carries a newer version than what is installed. Never trashed.
    case newerThanInstalled(InstallerMatch)
    case notInstalled(AppBundleInfo)
    /// Encrypted, licence-gated, corrupt, or timed out.
    case uninspectable(reason: String)
}

/// Dotted numeric versions: "2.10.1 (431)" compares as [2, 10, 1].
public struct AppVersion: Comparable, Sendable {
    public let components: [Int]

    public init(_ string: String) {
        let head = string.split(whereSeparator: { !($0.isNumber || $0 == ".") }).first ?? ""
        components = head.split(separator: ".").map { Int($0) ?? 0 }
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        for index in 0..<max(lhs.components.count, rhs.components.count) {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right }
        }
        return false
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool { !(lhs < rhs) && !(rhs < lhs) }
}
