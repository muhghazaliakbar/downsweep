import SwiftUI

/// Floating Liquid Glass controls for the current selection, merged into one glass shape.
struct SelectionBar: View {
    let count: Int
    let apply: () -> Void
    let pin: () -> Void
    let skip: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                Text("\(count) selected")
                    .font(.callout.weight(.medium))
                    .monospacedDigit()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .glassEffect()

                Button("Pin", systemImage: "pin", action: pin)
                    .buttonStyle(.glass)
                    .help("Never suggest these items again")

                Button("Skip", systemImage: "forward", action: skip)
                    .buttonStyle(.glass)
                    .help("Hide until next launch")

                Button("Apply", systemImage: "sparkles", action: apply)
                    .buttonStyle(.glassProminent)
                    .keyboardShortcut(.return, modifiers: .command)
            }
            .controlSize(.large)
        }
    }
}
