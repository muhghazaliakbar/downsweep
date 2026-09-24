import SwiftUI
import SweepCore

/// A content-layer row. Glass is reserved for controls floating above content, so rows stay plain.
struct ProposalRow: View {
    let proposal: Proposal

    var body: some View {
        HStack(spacing: 12) {
            FileIcon(url: proposal.item.url)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(proposal.item.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(proposal.reasonText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            if let host = proposal.item.primarySourceHost {
                Text(host)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: .capsule)
            }

            Label(proposal.actionTitle, systemImage: proposal.actionSymbol)
                .font(.caption)
                .foregroundStyle(proposal.reason.category.tint)
                .frame(minWidth: 110, alignment: .leading)

            Text(proposal.item.size.fileSize)
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 70, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
