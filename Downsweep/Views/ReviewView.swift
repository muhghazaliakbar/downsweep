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

    @AppStorage("reviewSort") private var sort: ReviewSort = .dateAdded
    @AppStorage("reviewSortAscending") private var ascending = false
    @State private var selection: Set<URL> = []
    @State private var previewURL: URL?

    var body: some View {
        let all = model.proposals(in: section)
        let kinds = Dictionary(all.map { ($0.id, FileKind(item: $0.item)) }, uniquingKeysWith: { a, _ in a })
        let filtered = model.reviewKindFilter.map { filter in all.filter { kinds[$0.id] == filter } } ?? all
        let rows = sort.sorted(filtered, ascending: ascending)

        content(rows: rows, isSectionEmpty: all.isEmpty)
            .navigationTitle(section.title)
            .navigationSubtitle(subtitle(rows))
            .toolbar { toolbar(rows: rows, kindCounts: Dictionary(kinds.values.map { ($0, 1) }, uniquingKeysWith: +)) }
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
            .quickLookPreview($previewURL, in: rows.map(\.item.url))
            // Hidden rows shouldn't stay selected and be swept by accident.
            .onChange(of: model.reviewKindFilter) { selection.removeAll() }
    }

    @ViewBuilder
    private func content(rows: [Proposal], isSectionEmpty: Bool) -> some View {
        if isSectionEmpty {
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
        } else if rows.isEmpty, let filter = model.reviewKindFilter {
            ContentUnavailableView {
                Label("No \(filter.title)", systemImage: filter.symbol)
            } description: {
                Text("Nothing of this kind needs your attention here.")
            } actions: {
                Button("Show All Kinds") { model.reviewKindFilter = nil }
                    .buttonStyle(.glass)
            }
        } else {
            List(selection: $selection) {
                if section == .all {
                    ForEach(ProposalCategory.allCases) { category in
                        let categoryRows = rows.filter { $0.reason.category == category }
                        if !categoryRows.isEmpty {
                            Section {
                                ForEach(categoryRows, content: row)
                            } header: {
                                Label(category.title, systemImage: category.symbol)
                            }
                        }
                    }
                } else {
                    ForEach(rows, content: row)
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

    private func row(_ proposal: Proposal) -> ProposalRow {
        ProposalRow(proposal: proposal, date: sort.displayedDate(for: proposal.item))
    }

    private func subtitle(_ rows: [Proposal]) -> String {
        guard !rows.isEmpty else { return "" }
        let bytes = rows.reduce(0) { $0 + $1.reclaimableBytes }
        return String(AttributedString(localized: "^[\(rows.count) item](inflect: true) · \(bytes.fileSize)").characters)
    }

    @ToolbarContentBuilder
    private func toolbar(rows: [Proposal], kindCounts: [FileKind: Int]) -> some ToolbarContent {
        @Bindable var model = model
        ToolbarItem {
            Menu {
                Picker("Kind", selection: $model.reviewKindFilter) {
                    Label("All Kinds", systemImage: "square.grid.2x2").tag(FileKind?.none)
                    Divider()
                    ForEach(FileKind.allCases.filter { kindCounts[$0] != nil }) { kind in
                        Label("\(kind.title) (\(kindCounts[kind] ?? 0))", systemImage: kind.symbol)
                            .tag(FileKind?.some(kind))
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label(
                    model.reviewKindFilter?.title ?? String(localized: "Kind"),
                    systemImage: model.reviewKindFilter == nil
                        ? "line.3.horizontal.decrease.circle"
                        : "line.3.horizontal.decrease.circle.fill"
                )
            }
            .help("Show only one kind of item, such as images or folders")
        }
        ToolbarItem {
            Menu {
                Picker("Sort By", selection: Binding(
                    get: { sort },
                    set: { newSort in
                        sort = newSort
                        ascending = newSort.defaultAscending
                    }
                )) {
                    ForEach(ReviewSort.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.inline)
                Picker("Order", selection: $ascending) {
                    Text(sort.orderTitle(ascending: true)).tag(true)
                    Text(sort.orderTitle(ascending: false)).tag(false)
                }
                .pickerStyle(.inline)
            } label: {
                Label("Sort By", systemImage: "arrow.up.arrow.down")
            }
            .help("Sort by \(sort.title), \(sort.orderTitle(ascending: ascending))")
        }
        ToolbarSpacer(.fixed)
        ToolbarItem {
            Button("Scan Again", systemImage: "arrow.clockwise") {
                Task { await model.scan() }
            }
            .disabled(model.isScanning)
            .help("Check the folder again for new suggestions")
        }
        ToolbarSpacer(.fixed)
        ToolbarItem {
            // With a filter on, only what's shown gets swept, and the button says so.
            Button(
                model.reviewKindFilter.map { String(localized: "Sweep \($0.title)") } ?? String(localized: "Sweep All"),
                systemImage: "sparkles"
            ) {
                run { await model.apply(rows) }
            }
            .labelStyle(.titleAndIcon)
            .buttonStyle(.glassProminent)
            .disabled(rows.isEmpty)
            .help(model.reviewKindFilter == nil
                ? "Do the suggested action for every item in this list. You can undo from History."
                : "Do the suggested action for every item shown by the current filter. Hidden items aren’t touched. You can undo from History.")
        }
    }

    private func run(_ work: @escaping () async -> Void) {
        Task {
            await work()
            selection.removeAll()
        }
    }
}
