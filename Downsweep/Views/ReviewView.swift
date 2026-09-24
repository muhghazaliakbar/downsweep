import QuickLook
import SwiftUI
import SweepCore

struct ReviewView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            List(selection: $model.reviewSection) {
                Section("Suggestions") {
                    sidebarRow(.all)
                    ForEach(ProposalCategory.allCases) { category in
                        sidebarRow(.category(category))
                    }
                }
                Section("Activity") {
                    Label(ReviewSection.history.title, systemImage: ReviewSection.history.symbol)
                        .tag(ReviewSection.history)
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 230)
        } detail: {
            switch model.reviewSection {
            case .history:
                HistoryView()
            case let section:
                ProposalListView(section: section)
                    .id(section)
            }
        }
    }

    private func sidebarRow(_ section: ReviewSection) -> some View {
        Label(section.title, systemImage: section.symbol)
            .badge(model.proposals(in: section).count)
            .tag(section)
    }
}

private struct ProposalListView: View {
    @Environment(AppModel.self) private var model
    let section: ReviewSection

    @State private var selection: Set<URL> = []
    @State private var previewURL: URL?

    private var proposals: [Proposal] { model.proposals(in: section) }

    var body: some View {
        content
            .navigationTitle(section.title)
            .navigationSubtitle(subtitle)
            .toolbar { toolbar }
            .overlay(alignment: .bottom) {
                if !selection.isEmpty {
                    SelectionBar(
                        count: selection.count,
                        apply: { run { await model.apply(ids: selection) } },
                        pin: { model.pin(ids: selection); selection.removeAll() },
                        skip: { model.skip(ids: selection); selection.removeAll() }
                    )
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.smooth(duration: 0.3), value: selection.isEmpty)
            .quickLookPreview($previewURL, in: proposals.map(\.item.url))
    }

    @ViewBuilder
    private var content: some View {
        if proposals.isEmpty {
            ContentUnavailableView {
                Label("All Swept", systemImage: "checkmark.seal")
            } description: {
                Text("Nothing here needs your attention right now.")
            } actions: {
                Button("Scan Again", systemImage: "arrow.clockwise") {
                    Task { await model.scan() }
                }
                .buttonStyle(.glass)
                .disabled(model.isScanning)
            }
        } else {
            List(selection: $selection) {
                if section == .all {
                    ForEach(ProposalCategory.allCases) { category in
                        let rows = proposals.filter { $0.reason.category == category }
                        if !rows.isEmpty {
                            Section {
                                ForEach(rows) { ProposalRow(proposal: $0) }
                            } header: {
                                Label(category.title, systemImage: category.symbol)
                            }
                        }
                    }
                } else {
                    ForEach(proposals) { ProposalRow(proposal: $0) }
                }
            }
            .contextMenu(forSelectionType: URL.self) { ids in
                Button("Apply", systemImage: "sparkles") { run { await model.apply(ids: ids) } }
                Button("Quick Look", systemImage: "eye") { previewURL = ids.first }
                Button("Show in Finder", systemImage: "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting(Array(ids))
                }
                Divider()
                Button("Pin", systemImage: "pin") { model.pin(ids: ids) }
                Button("Skip", systemImage: "forward") { model.skip(ids: ids) }
            } primaryAction: { ids in
                previewURL = ids.first
            }
            .onKeyPress(.space) {
                previewURL = previewURL == nil ? selection.first : nil
                return .handled
            }
            // Keep the last rows readable under the floating selection bar.
            .safeAreaPadding(.bottom, selection.isEmpty ? 0 : 72)
        }
    }

    private var subtitle: String {
        proposals.isEmpty ? "" : String(AttributedString(localized: "^[\(proposals.count) item](inflect: true) · \(model.bytes(in: section).fileSize)").characters)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem {
            Button("Scan Again", systemImage: "arrow.clockwise") {
                Task { await model.scan() }
            }
            .disabled(model.isScanning)
        }
        ToolbarSpacer(.fixed)
        ToolbarItem {
            Button("Sweep All", systemImage: "sparkles") {
                run { await model.apply(proposals) }
            }
            .labelStyle(.titleAndIcon)
            .buttonStyle(.glassProminent)
            .disabled(proposals.isEmpty)
        }
    }

    private func run(_ work: @escaping () async -> Void) {
        Task {
            await work()
            selection.removeAll()
        }
    }
}
