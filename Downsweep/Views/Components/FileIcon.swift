import AppKit
import SwiftUI

/// A file's icon: a colored tile per file kind, so a long list of downloads scans at a glance.
/// Folders and apps keep their Finder icon, which already identifies them.
struct FileIcon: View {
    let url: URL
    /// Pass it when known to skip a disk read.
    var isDirectory: Bool?

    var body: some View {
        let kind = FileKind(url: url, isDirectory: isDirectory)
        Group {
            if kind.usesFinderIcon {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                FileKindTile(kind: kind, fileExtension: url.pathExtension)
            }
        }
        .accessibilityHidden(true)
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
