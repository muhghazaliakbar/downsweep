import SwiftUI

/// Links shown on the About tab.
enum AboutLinks {
    static let repository = URL(string: "https://github.com/muhghazaliakbar/downsweep")!
    static let issues = URL(string: "https://github.com/muhghazaliakbar/downsweep/issues")!
    static let license = URL(string: "https://github.com/muhghazaliakbar/downsweep/blob/main/LICENSE")!
    static let releases = URL(string: "https://github.com/muhghazaliakbar/downsweep/releases")!
    static let buyMeACoffee = URL(string: "https://buymeacoffee.com/justghali.dev")!
}

struct AboutSettings: View {
    @Environment(\.openURL) private var openURL
    @Environment(Updater.self) private var updater

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return String(localized: "Version \(short) (\(build))")
    }

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)

            VStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 96, height: 96)
                    .accessibilityHidden(true)
                Text("Downsweep")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text(version)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .textSelection(.enabled)
                if updater.isAvailable {
                    UpdateControls()
                }
                Text("Keeps your Downloads folder tidy, without rules to write.\nNothing is deleted: everything goes to the Trash and can be undone.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SponsorCard { openURL(AboutLinks.buyMeACoffee) }
                .frame(maxWidth: 400)

            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    link("GitHub", systemImage: "chevron.left.forwardslash.chevron.right", url: AboutLinks.repository,
                         help: "View the source code on GitHub")
                    link("Report an Issue", systemImage: "exclamationmark.bubble", url: AboutLinks.issues,
                         help: "Report a bug or suggest a feature")
                    link("Releases", systemImage: "arrow.down.circle", url: AboutLinks.releases,
                         help: "See what’s new and download updates")
                }
            }
            .controlSize(.large)

            Spacer(minLength: 0)

            VStack(spacing: 2) {
                Text("Made by Muh Ghazali Akbar")
                Link("Open source under the MIT License", destination: AboutLinks.license)
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

    private func link(_ title: LocalizedStringKey, systemImage: String, url: URL, help: LocalizedStringKey) -> some View {
        Button(title, systemImage: systemImage) { openURL(url) }
            .buttonStyle(.glass)
            .help(help)
    }
}

/// Manual check plus the automatic-check preference, shown only in builds that can update.
private struct UpdateControls: View {
    @Environment(Updater.self) private var updater

    var body: some View {
        @Bindable var updater = updater
        HStack(spacing: 12) {
            Button("Check for Updates…") { updater.checkForUpdates() }
                .disabled(!updater.canCheckForUpdates)
            Toggle("Check automatically", isOn: $updater.automaticallyChecks)
                .toggleStyle(.checkbox)
                .help("Look for a new version on GitHub once a day")
        }
        .controlSize(.small)
    }
}

/// A card asking for support, with a button in Buy Me a Coffee's yellow so it's recognizable.
private struct SponsorCard: View {
    let action: () -> Void

    private static let coffeeYellow = Color(red: 1, green: 0.867, blue: 0)

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Enjoying Downsweep?")
                    .font(.headline)
                Text("It’s free and open source. A coffee helps keep it going.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button(action: action) {
                Label("Buy me a coffee", systemImage: "cup.and.saucer.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Self.coffeeYellow, in: .capsule)
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .help("Support Downsweep on Buy Me a Coffee (opens in your browser)")
        }
        .padding(14)
        .glassEffect(.regular.tint(Self.coffeeYellow.opacity(0.12)), in: .rect(cornerRadius: 16))
    }
}
