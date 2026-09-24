import Foundation

/// Files downloaded from `domain` (and its subdomains) move to `destination`.
public struct SourceRule: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var domain: String
    /// Lowercased extensions without the dot. Empty matches every file.
    public var extensions: [String]
    public var destination: URL
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        domain: String,
        extensions: [String] = [],
        destination: URL,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.domain = domain
        self.extensions = extensions
        self.destination = destination
        self.isEnabled = isEnabled
    }

    public var normalizedDomain: String {
        var value = domain.trimmingCharacters(in: .whitespaces).lowercased()
        if value.hasPrefix("*.") { value.removeFirst(2) }
        return value
    }

    public func matches(_ item: DownloadItem) -> Bool {
        guard isEnabled, !normalizedDomain.isEmpty else { return false }
        if !extensions.isEmpty, !extensions.contains(item.fileExtension) { return false }
        return item.sourceHosts.contains { $0 == normalizedDomain || $0.hasSuffix("." + normalizedDomain) }
    }
}

public extension SourceRule {
    /// Starter rules offered in Settings; disabled until the person turns them on.
    static func templates(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [SourceRule] {
        let documents = home.appending(path: "Documents", directoryHint: .isDirectory)
        return [
            SourceRule(domain: "mail.google.com", destination: documents.appending(path: "Attachments"), isEnabled: false),
            SourceRule(domain: "github.com", destination: home.appending(path: "Developer/GitHub"), isEnabled: false),
            SourceRule(domain: "klikbca.com", extensions: ["pdf"], destination: documents.appending(path: "Finance"), isEnabled: false),
        ]
    }
}
