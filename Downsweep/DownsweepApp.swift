import SwiftUI

enum WindowID {
    static let review = "review"
    static let onboarding = "onboarding"
}

@main
struct DownsweepApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(model)
        } label: {
            MenuBarLabel(pendingCount: model.proposals.count)
        }
        .menuBarExtraStyle(.window)

        Window("Review", id: WindowID.review) {
            ReviewView()
                .environment(model)
                .frame(minWidth: 780, minHeight: 480)
        }
        .defaultSize(width: 960, height: 620)
        .defaultLaunchBehavior(DebugOptions.opensReviewAtLaunch ? .presented : .suppressed)

        Window("Welcome to Downsweep", id: WindowID.onboarding) {
            OnboardingView()
                .environment(model)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(model.settings.hasCompletedOnboarding ? .suppressed : .presented)

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}

private struct MenuBarLabel: View {
    let pendingCount: Int

    var body: some View {
        if pendingCount > 0 {
            Label("\(pendingCount)", systemImage: "arrow.down.circle.fill")
                .labelStyle(.titleAndIcon)
        } else {
            Image(systemName: "arrow.down.circle")
        }
    }
}

extension NSApplication {
    /// Menu bar apps have no Dock icon, so windows need an explicit activation to come forward.
    func bringToFront() {
        activate()
    }
}
