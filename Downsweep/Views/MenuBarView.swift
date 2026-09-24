import SwiftUI
import SweepCore

struct MenuBarView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let progress = model.scanProgress {
                ProgressView(value: progress.fractionCompleted)
                    .progressViewStyle(.linear)
                    .controlSize(.mini)
                    .animation(.smooth, value: progress)
                    .transition(.opacity)
            }

            summary

            if let pausedUntil = model.pausedUntil, model.isPaused {
                PausedBanner(until: pausedUntil)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if let pending = model.pendingConfirmation {
                SafetyBanner(proposals: pending)
            } else if let error = model.lastError {
                ErrorBanner(message: error)
            }

            GlassEffectContainer(spacing: 10) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(ProposalCategory.allCases) { category in
                        CategoryCard(
                            category: category,
                            count: model.proposals(in: .category(category)).count,
                            bytes: model.bytes(in: .category(category))
                        ) {
                            openReview(.category(category))
                        }
                    }
                }
            }

            actions
            footer
        }
        .padding(16)
        .frame(width: 360)
        .animation(.smooth, value: model.isScanning)
        .animation(.smooth, value: model.isPaused)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 40, height: 40)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text("Downsweep")
                    .font(.headline)
                Text(statusLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .contentTransition(.opacity)
                    .animation(.smooth, value: statusLine)
            }

            Spacer(minLength: 8)

            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Button {
                        Task { await model.scan() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .symbolEffect(.rotate, options: .repeating, isActive: model.isScanning)
                            .headerCircle()
                    }
                    .buttonStyle(.plain)
                    .disabled(model.isScanning)
                    .help("Scan the folder now")

                    Menu {
                        Button(model.isPaused ? "Resume" : "Pause for 24 Hours",
                               systemImage: model.isPaused ? "play" : "pause") {
                            model.togglePause()
                        }
                        Button("This Week’s Summary…", systemImage: "chart.bar.doc.horizontal") {
                            openWindow(id: WindowID.weeklySummary)
                            NSApp.bringToFront()
                        }
                        Divider()
                        Button("Settings…", systemImage: "gearshape") {
                            NSApp.bringToFront()
                            openSettings()
                        }
                        .keyboardShortcut(",")
                        Button("Quit Downsweep", systemImage: "power") {
                            NSApp.terminate(nil)
                        }
                        .keyboardShortcut("q")
                    } label: {
                        Image(systemName: "ellipsis")
                            .headerCircle()
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("Pause, settings and quit")
                }
            }
        }
    }

    private var statusLine: String {
        if let progress = model.scanProgress { return progress.statusText }
        if model.isPaused { return String(localized: "Paused") }
        return model.settings.mode == .automatic
            ? String(localized: "Sweeping automatically")
            : String(localized: "Review mode")
    }

    // MARK: - Summary

    private var summary: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Text(model.reclaimableBytes.fileSize)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.smooth, value: model.reclaimableBytes)
                Text(summaryCaption)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if model.reclaimableBytes > 0 {
                BreakdownBar(segments: ProposalCategory.allCases.map { ($0.tint, model.bytes(in: .category($0))) })
                    .frame(height: 8)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quinary, in: .rect(cornerRadius: 18))
    }

    private var summaryCaption: String {
        let folder = model.settings.folderURL.lastPathComponent
        if model.proposals.isEmpty { return String(localized: "\(folder) is tidy") }
        return String(AttributedString(localized: "^[\(model.proposals.count) item](inflect: true) ready to sweep from \(folder)").characters)
    }

    // MARK: - Actions

    private var actions: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    Task { await model.apply(model.proposals) }
                } label: {
                    Label("Sweep All", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .disabled(model.proposals.isEmpty)
                .help("Do every suggested action now. You can undo from History.")

                Button {
                    openReview(.all)
                } label: {
                    Label("Review", systemImage: "list.bullet.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .help("Open the Review window to choose item by item")
            }
            .controlSize(.extraLarge)
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Label(model.settings.folderURL.lastPathComponent, systemImage: "folder")
            Spacer()
            if let finished = model.result?.finishedAt {
                Text("Checked \(finished, format: .relative(presentation: .named, unitsStyle: .abbreviated))")
            }
        }
        .font(.caption)
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 4)
    }

    private func openReview(_ section: ReviewSection) {
        model.reviewSection = section
        openWindow(id: WindowID.review)
        NSApp.bringToFront()
    }
}

private extension View {
    /// A round glass button face for the header, big enough to hit comfortably.
    func headerCircle() -> some View {
        font(.system(size: 13, weight: .semibold))
            .frame(width: 32, height: 32)
            .contentShape(.circle)
            .glassEffect(.regular.interactive(), in: .circle)
    }
}

/// Storage-style bar: one colored segment per category, sized by reclaimable bytes.
private struct BreakdownBar: View {
    let segments: [(color: Color, bytes: Int64)]

    var body: some View {
        let visible = segments.filter { $0.bytes > 0 }
        let total = max(visible.reduce(0) { $0 + $1.bytes }, 1)
        GeometryReader { proxy in
            let spacing = 2.0 * Double(max(visible.count - 1, 0))
            HStack(spacing: 2) {
                ForEach(visible.indices, id: \.self) { index in
                    Capsule()
                        .fill(visible[index].color.gradient)
                        // Keep tiny categories visible as a sliver.
                        .frame(width: max(6, (proxy.size.width - spacing) * Double(visible[index].bytes) / Double(total)))
                }
            }
            .frame(width: proxy.size.width, alignment: .leading)
            .clipShape(.capsule)
        }
        .animation(.smooth, value: segments.map(\.bytes))
        .accessibilityHidden(true)
    }
}

private struct CategoryCard: View {
    let category: ProposalCategory
    let count: Int
    let bytes: Int64
    let action: () -> Void

    private var isEmpty: Bool { count == 0 }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Image(systemName: category.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(category.tint))
                        .frame(width: 30, height: 30)
                        .background((isEmpty ? Color.secondary : category.tint).opacity(0.16), in: .circle)
                    Spacer()
                    if isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green.opacity(0.8))
                    } else {
                        Text(count, format: .number)
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(category.tint.opacity(0.2), in: .capsule)
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(category.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(isEmpty ? String(localized: "All clear") : bytes.fileSize)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .glassEffect(
            isEmpty ? .regular.interactive() : .regular.tint(category.tint.opacity(0.1)).interactive(),
            in: .rect(cornerRadius: 16)
        )
        .help(isEmpty
            ? "Nothing in \(category.title) right now"
            : "Review \(count) items in \(category.title)")
    }
}

private struct PausedBanner: View {
    @Environment(AppModel.self) private var model
    let until: Date

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "pause.circle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
                .symbolEffect(.pulse, options: .repeating)
            VStack(alignment: .leading, spacing: 1) {
                Text("Paused until \(until, format: .dateTime.weekday(.abbreviated).hour().minute())")
                    .font(.callout.weight(.semibold))
                Text("Nothing is swept automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button("Resume", systemImage: "play.fill") { model.togglePause() }
                .buttonStyle(.glassProminent)
                .tint(.orange)
                .controlSize(.small)
                .help("Resume sweeping now")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(.orange.opacity(0.18)), in: .rect(cornerRadius: 14))
    }
}

private struct SafetyBanner: View {
    @Environment(AppModel.self) private var model
    let proposals: [Proposal]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Large sweep paused", systemImage: "exclamationmark.shield")
                .font(.callout.weight(.semibold))
            Text("\(proposals.count) items (\(proposals.reduce(0) { $0 + $1.reclaimableBytes }.fileSize)) would be moved. Continue?")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Not Now") { model.pendingConfirmation = nil }
                    .buttonStyle(.glass)
                Button("Sweep") { Task { await model.apply(proposals) } }
                    .buttonStyle(.glassProminent)
            }
            .controlSize(.small)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(.orange.opacity(0.25)), in: .rect(cornerRadius: 14))
    }
}

private struct ErrorBanner: View {
    @Environment(AppModel.self) private var model
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Dismiss", systemImage: "xmark") { model.dismissError() }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
        }
        .padding(10)
        .glassEffect(in: .rect(cornerRadius: 12))
    }
}
