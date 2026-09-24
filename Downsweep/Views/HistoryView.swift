import SwiftUI
import SweepCore

struct HistoryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.history.isEmpty {
                ContentUnavailableView(
                    "No Activity Yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Everything Downsweep moves shows up here, and can be undone while it’s still in the Trash.")
                )
            } else {
                Table(model.history) {
                    TableColumn("File") { entry in
                        HStack(spacing: 8) {
                            FileIcon(url: entry.resultURL ?? entry.originalURL)
                                .frame(width: 20, height: 20)
                            Text(entry.originalURL.lastPathComponent)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .strikethrough(entry.undone, color: .secondary)
                        }
                    }
                    .width(min: 200, ideal: 280)

                    TableColumn("Action") { entry in
                        Label(entry.kind.title, systemImage: entry.kind.symbol)
                            .foregroundStyle(.secondary)
                    }
                    .width(ideal: 130)

                    TableColumn("Reason") { entry in
                        Text(entry.reason)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    TableColumn("When") { entry in
                        Text(entry.date, format: .relative(presentation: .named))
                            .foregroundStyle(.secondary)
                    }
                    .width(ideal: 110)

                    TableColumn("") { entry in
                        if entry.undone {
                            Text("Undone")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else {
                            Button("Undo") {
                                Task { await model.undo(entry) }
                            }
                            .buttonStyle(.glass)
                            .controlSize(.small)
                        }
                    }
                    .width(70)
                }
            }
        }
        .navigationTitle("History")
        .navigationSubtitle(freedSummary)
    }

    private var freedSummary: String {
        let freed = model.history.filter { !$0.undone && $0.kind != .tag }.reduce(0) { $0 + $1.bytes }
        return freed > 0 ? String(localized: "\(freed.fileSize) freed") : ""
    }
}
