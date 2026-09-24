import SwiftUI
import SweepCore
import UniformTypeIdentifiers

/// "This Week": the last 7 days as a card, with ways to share it.
struct WeeklySummaryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let summary = WeeklySummary(history: model.history, endingAt: .now)
        let image = SummaryCard.render(summary)

        VStack(spacing: 18) {
            SummaryCard(summary: summary)
                .clipShape(.rect(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: 18, y: 8)

            if summary.isEmpty {
                Text("Nothing swept in the last 7 days yet. Your card fills in as Downsweep cleans up.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            HStack(spacing: 10) {
                if let image {
                    let picture = Image(nsImage: image)
                    ShareLink(item: picture, preview: SharePreview("Cleaned this week", image: picture)) {
                        Label("Share…", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.glassProminent)
                    .help("Share the card as an image")

                    Button("Copy Image", systemImage: "doc.on.doc") { copy(image) }
                        .buttonStyle(.glass)
                        .help("Copy the card to the clipboard, ready to paste")

                    Button("Save…", systemImage: "square.and.arrow.down") { save(image) }
                        .buttonStyle(.glass)
                        .help("Save the card as a PNG image")
                }
            }
            .controlSize(.large)
            .disabled(summary.isEmpty)
        }
        .padding(28)
    }

    private func copy(_ image: NSImage) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }

    private func save(_ image: NSImage) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = String(localized: "Downsweep week.png")
        guard panel.runModal() == .OK, let url = panel.url,
              let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
        else { return }
        try? png.write(to: url)
    }
}

/// The shareable card. Plain fills only: ImageRenderer doesn't draw glass or materials.
struct SummaryCard: View {
    let summary: WeeklySummary

    static let side: CGFloat = 400

    /// A square PNG-ready image, 1080 px wide like most social posts.
    @MainActor
    static func render(_ summary: WeeklySummary) -> NSImage? {
        let renderer = ImageRenderer(content: SummaryCard(summary: summary))
        renderer.scale = 1080 / side
        return renderer.nsImage
    }

    private var hero: String {
        summary.bytesFreed > 0
            ? summary.bytesFreed.fileSize
            : String(AttributedString(localized: "^[\(summary.itemCount) item](inflect: true)").characters)
    }

    private var heroCaption: String {
        let items = String(AttributedString(localized: "^[\(summary.itemCount) item](inflect: true)").characters)
        return summary.bytesFreed > 0
            ? String(localized: "freed from Downloads, across \(items)")
            : String(localized: "tidied in my Downloads folder")
    }

    private var dateRange: String {
        let start = summary.interval.start.formatted(.dateTime.day().month(.abbreviated))
        let end = summary.interval.end.formatted(.dateTime.day().month(.abbreviated).year())
        return "\(start) – \(end)"
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.58, blue: 1), Color(red: 0.08, green: 0.22, blue: 0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // The app glyph, oversized and faint, as a watermark.
            Image(nsImage: MenuBarIcon.idle)
                .renderingMode(.template)
                .resizable()
                .foregroundStyle(.white.opacity(0.08))
                .frame(width: 300, height: 300)
                .offset(x: 170, y: 150)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(nsImage: MenuBarIcon.idle)
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 22, height: 22)
                    Text("Downsweep")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                }

                Spacer()

                Text("This week I cleaned up")
                    .font(.system(size: 18, weight: .medium))
                    .opacity(0.85)
                Text(hero)
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(heroCaption)
                    .font(.system(size: 16))
                    .opacity(0.85)

                Spacer()

                HStack(spacing: 8) {
                    stat(summary.trashedCount, String(localized: "trashed"), systemImage: "trash")
                    stat(summary.movedCount, String(localized: "sorted"), systemImage: "folder")
                    stat(summary.taggedCount, String(localized: "tagged"), systemImage: "tag")
                }

                HStack {
                    Text(dateRange)
                    Spacer()
                    Text(verbatim: "github.com/muhghazaliakbar/downsweep")
                        .lineLimit(1)
                        .fixedSize()
                }
                .font(.system(size: 11, weight: .medium))
                .opacity(0.7)
                .padding(.top, 16)
            }
            .padding(28)
        }
        .foregroundStyle(.white)
        .frame(width: Self.side, height: Self.side)
        .environment(\.colorScheme, .dark)
    }

    private func stat(_ count: Int, _ title: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(count, format: .number)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .monospacedDigit()
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .medium))
                .opacity(0.85)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.14), in: .rect(cornerRadius: 14, style: .continuous))
    }
}
