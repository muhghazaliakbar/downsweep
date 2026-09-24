import Foundation

/// Developer switches, read from launch arguments (e.g. `-DebugClockOffsetDays 60`).
/// Compiled out of Release builds.
enum DebugOptions {
    /// Pretends the current date is this many days ahead, so fresh fixtures look stale.
    static var clockOffsetDays: Double {
        #if DEBUG
        UserDefaults.standard.double(forKey: "DebugClockOffsetDays")
        #else
        0
        #endif
    }

    /// Opens the Review window at launch.
    static var opensReviewAtLaunch: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "DebugOpenReview")
        #else
        false
        #endif
    }

    /// Posts the weekly summary notification right after launch.
    static var sendsWeeklySummaryAtLaunch: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "DebugWeeklySummary")
        #else
        false
        #endif
    }

    static var now: Date { .now.addingTimeInterval(clockOffsetDays * 86_400) }
}
