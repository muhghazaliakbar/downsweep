import SwiftUI
import SweepCore
import UniformTypeIdentifiers

/// A Finder-style "Kind" for an item, used for icons and the Review filter.
enum FileKind: String, CaseIterable, Identifiable {
    case folder, application
    case image, video, audio, pdf, document, spreadsheet, presentation
    case archive, installer, code, text, font, other

    var id: Self { self }

    init(item: DownloadItem) {
        self.init(url: item.url, isDirectory: item.isDirectory)
    }

    /// Reads the disk to tell folders from files when `isDirectory` isn't known.
    init(url: URL, isDirectory: Bool? = nil) {
        let ext = url.pathExtension.lowercased()
        let isDirectory = isDirectory
            ?? (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory
            ?? url.hasDirectoryPath
        let type = UTType(filenameExtension: ext)

        if isDirectory {
            // Bundles such as apps and screen savers are directories that Finder shows as one file.
            self = ext == "app" || type?.conforms(to: .package) == true ? .application : .folder
            return
        }
        if let kind = Self.byExtension[ext] {
            self = kind
            return
        }
        guard let type else {
            self = .other
            return
        }
        let rules: [(UTType, FileKind)] = [
            (.image, .image), (.movie, .video), (.audio, .audio), (.pdf, .pdf),
            (.spreadsheet, .spreadsheet), (.presentation, .presentation),
            (.diskImage, .installer), (.archive, .archive),
            (.font, .font), (.sourceCode, .code), (.script, .code), (.text, .text),
        ]
        self = rules.first { type.conforms(to: $0.0) }?.1 ?? .other
    }

    /// Common downloads whose UTType is missing or too generic to classify.
    private static let byExtension: [String: FileKind] = [
        "doc": .document, "docx": .document, "pages": .document, "odt": .document, "rtf": .document,
        "xls": .spreadsheet, "xlsx": .spreadsheet, "numbers": .spreadsheet, "csv": .spreadsheet, "ods": .spreadsheet,
        "ppt": .presentation, "pptx": .presentation, "key": .presentation, "odp": .presentation,
        "zip": .archive, "rar": .archive, "7z": .archive, "tar": .archive, "gz": .archive, "tgz": .archive, "xz": .archive,
        "dmg": .installer, "pkg": .installer, "mpkg": .installer, "iso": .installer,
        "json": .code, "js": .code, "ts": .code, "html": .code, "css": .code, "swift": .code, "py": .code,
        "sh": .code, "xml": .code, "yml": .code, "yaml": .code, "sql": .code,
        "fig": .image, "sketch": .image, "psd": .image, "ai": .image, "svg": .image, "webp": .image, "heic": .image,
    ]

    /// Folders and apps are drawn with their Finder icon, which already identifies them.
    var usesFinderIcon: Bool { self == .folder || self == .application }

    var title: String {
        switch self {
        case .folder: String(localized: "Folders")
        case .application: String(localized: "Apps & Bundles")
        case .image: String(localized: "Images")
        case .video: String(localized: "Movies")
        case .audio: String(localized: "Music & Audio")
        case .pdf: String(localized: "PDF Documents")
        case .document: String(localized: "Documents")
        case .spreadsheet: String(localized: "Spreadsheets")
        case .presentation: String(localized: "Presentations")
        case .archive: String(localized: "Archives")
        case .installer: String(localized: "Disk Images & Installers")
        case .code: String(localized: "Code")
        case .text: String(localized: "Text")
        case .font: String(localized: "Fonts")
        case .other: String(localized: "Other")
        }
    }

    var symbol: String {
        switch self {
        case .folder: "folder"
        case .application: "app.dashed"
        case .image: "photo"
        case .video: "film"
        case .audio: "waveform"
        case .pdf: "doc.richtext"
        case .document: "doc.text"
        case .spreadsheet: "tablecells"
        case .presentation: "rectangle.on.rectangle.angled"
        case .archive: "doc.zipper"
        case .installer: "shippingbox"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .text: "text.alignleft"
        case .font: "textformat"
        case .other: "doc"
        }
    }

    var tint: Color {
        switch self {
        case .folder: .blue
        case .application: .gray
        case .image: .purple
        case .video: .indigo
        case .audio: .pink
        case .pdf: .red
        case .document: .blue
        case .spreadsheet: .green
        case .presentation: .orange
        case .archive: .brown
        case .installer: .cyan
        case .code: .teal
        case .text: .gray
        case .font: .mint
        case .other: Color(white: 0.5)
        }
    }
}
