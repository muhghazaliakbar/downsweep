import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// A file's icon: a colored tile per file kind, so a long list of downloads scans at a glance.
/// Folders and apps keep their Finder icon, which already identifies them.
struct FileIcon: View {
    let url: URL

    var body: some View {
        Group {
            if let kind = FileKind(url: url) {
                FileKindTile(kind: kind, fileExtension: url.pathExtension)
            } else {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            }
        }
        .accessibilityHidden(true)
    }
}

enum FileKind {
    case image, video, audio, pdf, document, spreadsheet, presentation
    case archive, installer, code, text, font, other

    /// `nil` for folders and bundles such as apps, which draw their own icon.
    init?(url: URL) {
        let ext = url.pathExtension.lowercased()
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? url.hasDirectoryPath
        if isDirectory || ext == "app" { return nil }
        if let kind = Self.byExtension[ext] {
            self = kind
            return
        }
        guard let type = UTType(filenameExtension: ext) else {
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

    var symbol: String {
        switch self {
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

/// A rounded tile with the kind's symbol, plus the extension once the tile is big enough to read it.
private struct FileKindTile: View {
    let kind: FileKind
    let fileExtension: String

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let showsExtension = side >= 28 && !fileExtension.isEmpty && fileExtension.count <= 5

            RoundedRectangle(cornerRadius: side * 0.24, style: .continuous)
                .fill(kind.tint.gradient)
                .overlay {
                    VStack(spacing: side * 0.02) {
                        Image(systemName: kind.symbol)
                            .font(.system(size: side * (showsExtension ? 0.38 : 0.5), weight: .semibold))
                        if showsExtension {
                            Text(fileExtension.uppercased())
                                .font(.system(size: side * 0.2, weight: .bold, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(side * 0.08)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: side * 0.24, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
                }
                .frame(width: side, height: side)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
