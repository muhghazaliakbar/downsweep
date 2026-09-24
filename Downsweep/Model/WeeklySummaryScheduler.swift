import Foundation
import SweepCore
import UserNotifications

/// Posts the weekly summary notification on Monday morning and routes clicks on it back to the app.
///
/// A local notification's text is fixed when it's scheduled, so instead of scheduling ahead the app
/// (always running in the menu bar) waits for the due time and posts the summary then.
@MainActor
final class WeeklySummaryScheduler: NSObject, UNUserNotificationCenterDelegate {
    static let enabledKey = "weeklySummary.enabled"
    private static let lastDeliveryKey = "weeklySummary.lastDelivery"
    nonisolated private static let notificationKind = "weeklySummary"

    private let defaults: UserDefaults
    private let history: () -> [HistoryEntry]
    private let onOpen: () -> Void
    private var task: Task<Void, Never>?

    init(defaults: UserDefaults = .standard, history: @escaping () -> [HistoryEntry], onOpen: @escaping () -> Void) {
        self.defaults = defaults
        self.history = history
        self.onOpen = onOpen
        super.init()
        defaults.register(defaults: [Self.enabledKey: true])
        UNUserNotificationCenter.current().delegate = self
    }

    var isEnabled: Bool { defaults.bool(forKey: Self.enabledKey) }

    /// Waits for the next Monday 9:00 after the last summary, or posts right away if one was missed.
    func reschedule() {
        task?.cancel()
        guard isEnabled else { return }
        let last = defaults.object(forKey: Self.lastDeliveryKey) as? Date ?? {
            // First launch: count from now instead of sending a summary straight away.
            defaults.set(Date.now, forKey: Self.lastDeliveryKey)
            return .now
        }()
        let due = WeeklySummary.nextDelivery(after: last)
        task = Task {
            try? await Task.sleep(for: .seconds(max(due.timeIntervalSinceNow, 0)))
            guard !Task.isCancelled else { return }
            await deliver()
            reschedule()
        }
    }

    /// Asks for permission up front, so turning the setting on shows the system prompt right away.
    func requestAuthorization() {
        Task { _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) }
    }

    func deliver() async {
        defaults.set(Date.now, forKey: Self.lastDeliveryKey)
        let summary = WeeklySummary(history: history(), endingAt: .now)
        guard !summary.isEmpty else { return }

        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Your week in Downloads")
        content.body = summary.notificationBody
        content.userInfo = ["kind": Self.notificationKind]
        try? await center.add(UNNotificationRequest(identifier: Self.notificationKind, content: content, trigger: nil))
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// A menu bar app counts as frontmost more often than not; show the banner anyway.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.notification.request.content.userInfo["kind"] as? String == Self.notificationKind else { return }
        await MainActor.run { onOpen() }
    }
}

extension WeeklySummary {
    var notificationBody: String {
        let items = String(AttributedString(localized: "^[\(itemCount) item](inflect: true)").characters)
        return bytesFreed > 0
            ? String(localized: "Downsweep tidied \(items) and freed \(bytesFreed.fileSize). Click to see and share your week.")
            : String(localized: "Downsweep tidied \(items) in your Downloads folder. Click to see and share your week.")
    }
}
