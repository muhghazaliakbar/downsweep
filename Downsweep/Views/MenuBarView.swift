import SwiftUI
import SweepCore

struct MenuBarView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            summary

            if let pending = model.pendingConfirmation {
                SafetyBanner(proposals: pending)
            } else if let error = model.lastError {
                ErrorBanner(message: error)
            }

            GlassEffectContainer(spacing: 6) {
                VStack(spacing: 6) {
                    ForEach(ProposalCategory.allCases) { category in
                        CategoryTile(
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
        }
        .padding(16)
        .frame(width: 340)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.title2)
                .foregroundStyle(.tint)
                .symbolEffect(.pulse, isActive: model.isScanning)
            VStack(alignment: .leading, spacing: 0) {
                Text("Downsweep")
                    .font(.headline)
                Text(statusLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if model.isScanning {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private var statusLine: String {
        if model.isPaused { return String(localized: "Paused for 24 hours") }
        if model.isScanning { return String(localized: "Scanning \(model.settings.folderURL.lastPathComponent)…") }
        return model.settings.mode == .automatic
            ? String(localized: "Sweeping automatically")
            : String(localized: "Review mode")
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(model.reclaimableBytes.fileSize)
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.smooth, value: model.reclaimableBytes)
            Text(model.proposals.isEmpty ? "Downloads is tidy" : "ready to sweep from \(model.settings.folderURL.lastPathComponent)")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button {
                Task { await model.apply(model.proposals) }
            } label: {
                Label("Sweep All", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .disabled(model.proposals.isEmpty)

            Button {
                openReview(.all)
            } label: {
                Text("Review…")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)

            Menu {
                Button("Scan Now", systemImage: "arrow.clockwise") {
                    Task { await model.scan() }
                }
                Button(model.isPaused ? "Resume" : "Pause for 24 Hours",
                       systemImage: model.isPaused ? "play" : "pause") {
                    model.togglePause()
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
            }
            .menuIndicator(.hidden)
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .fixedSize()
        }
        .controlSize(.large)
    }

    private func openReview(_ section: ReviewSection) {
        model.reviewSection = section
        openWindow(id: WindowID.review)
        NSApp.bringToFront()
    }
}

private struct CategoryTile: View {
    let category: ProposalCategory
    let count: Int
    let bytes: Int64
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: category.symbol)
                    .font(.title3)
                    .foregroundStyle(category.tint)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(category.title)
                        .font(.body.weight(.medium))
                    Text(count == 0 ? "Nothing to do" : "^[\(count) item](inflect: true)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if bytes > 0 {
                    Text(bytes.fileSize)
                        .font(.callout)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
        .opacity(count == 0 ? 0.6 : 1)
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
