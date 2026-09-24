import SwiftUI
import SweepCore

enum WindowID {
    static let review = "review"
    static let onboarding = "onboarding"
    static let weeklySummary = "weekly-summary"
}

@main
struct DownsweepApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(model)
        } label: {
            MenuBarLabel(pendingCount: model.proposals.count, scanProgress: model.scanProgress, isPaused: model.isPaused)
                .modifier(WindowRequestOpener(request: model.summaryWindowRequest, windowID: WindowID.weeklySummary))
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

        Window("This Week", id: WindowID.weeklySummary) {
            WeeklySummaryView()
                .environment(model)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}

private struct MenuBarLabel: View {
    let pendingCount: Int
    let scanProgress: ScanProgress?
    let isPaused: Bool

    var body: some View {
        if isPaused, scanProgress == nil {
            // Paused wins over the pending count: nothing will be swept until it's resumed.
            Image(nsImage: MenuBarIcon.paused)
                .accessibilityLabel(Text("Downsweep: paused"))
        } else if let scanProgress {
            // Menu bar labels are rendered as static images, so progress is drawn into the icon
            // (specks light up) rather than animated with a symbol effect.
            Label {
                Text(scanProgress.percentText)
                    .monospacedDigit()
            } icon: {
                Image(nsImage: MenuBarIcon.scanning(progress: scanProgress.fractionCompleted))
            }
            .labelStyle(.titleAndIcon)
            .accessibilityLabel(Text("Downsweep: \(scanProgress.statusText)"))
        } else if pendingCount > 0 {
            Label {
                Text(pendingCount, format: .number)
                    .monospacedDigit()
            } icon: {
                Image(nsImage: MenuBarIcon.idle)
            }
            .labelStyle(.titleAndIcon)
        } else {
            Image(nsImage: MenuBarIcon.idle)
        }
    }
}

/// The menu bar label is the one view that always exists, so it opens windows asked for from
/// outside SwiftUI (such as a click on a notification).
private struct WindowRequestOpener: ViewModifier {
    @Environment(\.openWindow) private var openWindow
    let request: Int
    let windowID: String

    func body(content: Content) -> some View {
        content.onChange(of: request) {
            openWindow(id: windowID)
            NSApp.bringToFront()
        }
    }
}

extension NSApplication {
    /// Menu bar apps have no Dock icon, so windows need an explicit activation to come forward.
    func bringToFront() {
        activate()
    }
}
