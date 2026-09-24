import SwiftUI
import SweepCore
import UniformTypeIdentifiers

struct OnboardingView: View {
    private enum Step: Int, CaseIterable, Identifiable {
        case welcome, folder, results
        var id: Int { rawValue }
    }

    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var step: Step = .welcome
    @State private var choosingFolder = false
    @Namespace private var glassNamespace

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case .welcome: welcome
                case .folder: folder
                case .results: results
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.blurReplace)

            footer
        }
        .padding(32)
        .frame(width: 580, height: 500)
        .background(alignment: .top) {
            // A soft wash of the accent colour gives the glass something to refract.
            LinearGradient(colors: [Color.accentColor.opacity(0.28), .clear], startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
        }
        .animation(.smooth(duration: 0.35), value: step)
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result { model.settings.folderPath = url.path }
        }
    }

    // MARK: - Steps

    private var welcome: some View {
        VStack(spacing: 20) {
            HeroSymbol(name: "arrow.down")
            VStack(spacing: 8) {
                Text("Welcome to Downsweep")
                    .font(.largeTitle.weight(.bold))
                Text("Your Downloads folder, kept tidy without writing a single rule.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            VStack(alignment: .leading, spacing: 14) {
                Feature(symbol: "shippingbox", tint: .blue,
                        title: "Installers you’ve already used",
                        detail: "DMG, ZIP and PKG files whose app is already installed.")
                Feature(symbol: "plus.square.on.square", tint: .purple,
                        title: "Duplicate downloads",
                        detail: "“report (1).pdf” that’s byte-for-byte the same file.")
                Feature(symbol: "arrow.uturn.backward.circle", tint: .green,
                        title: "Nothing is ever deleted",
                        detail: "Everything goes to the Trash and can be undone.")
            }
            .padding(.top, 8)
        }
    }

    private var folder: some View {
        VStack(spacing: 20) {
            HeroSymbol(name: "folder.fill")
            VStack(spacing: 8) {
                Text("One Folder, Watched Quietly")
                    .font(.largeTitle.weight(.bold))
                Text("Downsweep only looks at the top level of this folder. macOS will ask you to allow access.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 12) {
                FileIcon(url: model.settings.folderURL)
                    .frame(width: 28, height: 28)
                Text(model.settings.folderURL.path(percentEncoded: false).replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(.body.monospaced())
                    .lineLimit(1)
                    .truncationMode(.head)
                Button("Change…") { choosingFolder = true }
                    .buttonStyle(.glass)
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .padding(.vertical, 8)
            .glassEffect()
        }
    }

    private var results: some View {
        VStack(spacing: 20) {
            if model.isScanning {
                ProgressView()
                    .controlSize(.large)
                Text("Looking through \(model.settings.folderURL.lastPathComponent)…")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            } else {
                HeroSymbol(name: model.proposals.isEmpty ? "checkmark.seal.fill" : "sparkles")
                VStack(spacing: 6) {
                    Text(model.reclaimableBytes.fileSize)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(model.proposals.isEmpty ? "Already tidy. Downsweep will keep it that way." : "can be swept right now")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                GlassEffectContainer(spacing: 10) {
                    HStack(spacing: 10) {
                        ForEach(ProposalCategory.allCases) { category in
                            let count = model.proposals(in: .category(category)).count
                            VStack(spacing: 4) {
                                Image(systemName: category.symbol)
                                    .font(.title2)
                                    .foregroundStyle(category.tint)
                                Text("\(count)")
                                    .font(.title3.weight(.semibold))
                                    .monospacedDigit()
                                Text(category.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(width: 112, height: 96)
                            .glassEffect(in: .rect(cornerRadius: 18))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            GlassEffectContainer(spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(Step.allCases) { dot in
                        Capsule()
                            .fill(dot == step ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                            .frame(width: dot == step ? 22 : 8, height: 8)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .glassEffect()
                .glassEffectID("pager", in: glassNamespace)
            }
            .accessibilityLabel("Step \(step.rawValue + 1) of \(Step.allCases.count)")

            Spacer()

            if step != .welcome {
                Button("Back") { move(-1) }
                    .buttonStyle(.glass)
            }
            primaryButton
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
        }
        .controlSize(.large)
    }

    @ViewBuilder
    private var primaryButton: some View {
        switch step {
        case .welcome:
            Button("Get Started") { move(1) }
        case .folder:
            Button("Scan Folder") {
                move(1)
                Task { await model.scan() }
            }
        case .results:
            if model.proposals.isEmpty {
                Button("Done", action: finish)
            } else {
                Button("Review Suggestions") {
                    finish()
                    model.reviewSection = .all
                    openWindow(id: WindowID.review)
                    NSApp.bringToFront()
                }
                .disabled(model.isScanning)
            }
        }
    }

    private func move(_ offset: Int) {
        step = Step(rawValue: step.rawValue + offset) ?? step
    }

    private func finish() {
        model.settings.hasCompletedOnboarding = true
        dismissWindow(id: WindowID.onboarding)
    }
}

private struct HeroSymbol: View {
    let name: String

    var body: some View {
        Image(systemName: name)
            .font(.system(size: 44, weight: .medium))
            .foregroundStyle(.tint)
            .symbolRenderingMode(.hierarchical)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: 96, height: 96)
            .glassEffect(.regular.tint(.accentColor.opacity(0.18)), in: .circle)
    }
}

private struct Feature: View {
    let symbol: String
    let tint: Color
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: 420, alignment: .leading)
    }
}
