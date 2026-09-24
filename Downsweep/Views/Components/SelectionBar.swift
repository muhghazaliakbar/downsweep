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
                    .help("Items selected in the list. Shift- or Command-click to select more.")

                Button("Pin", systemImage: "pin", action: pin)
                    .buttonStyle(.glass)
                    .help("Keep these items where they are. Downsweep won’t suggest them again; unpin them in Settings.")

                Button("Skip", systemImage: "forward", action: skip)
                    .buttonStyle(.glass)
                    .help("Hide these suggestions for now. Nothing is changed; they come back the next time Downsweep starts.")

                Button("Apply", systemImage: "sparkles", action: apply)
                    .buttonStyle(.glassProminent)
                    .keyboardShortcut(.return, modifiers: .command)
                    .help("Do the suggested action for each selected item: move it to the Trash, move it to a folder, or tag it. You can undo from History. (⌘↩)")
            }
            .controlSize(.large)
        }
    }
}
