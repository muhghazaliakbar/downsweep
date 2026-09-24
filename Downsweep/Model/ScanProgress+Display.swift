import Foundation
import SweepCore

extension ScanProgress {
    /// Short description of the current step, e.g. "Checking installers (2 of 5)".
    var statusText: String {
        switch phase {
        case .listing where total > 0:
            String(localized: "Reading files (\(completed) of \(total))…")
        case .listing:
            String(localized: "Reading files…")
        case .inspectingInstallers where total > 0:
            String(localized: "Checking installers (\(min(completed + 1, total)) of \(total))…")
        case .inspectingInstallers:
            String(localized: "Checking installers…")
        case .findingDuplicates:
            String(localized: "Looking for duplicates…")
        case .evaluating:
            String(localized: "Preparing suggestions…")
        }
    }

    var percentText: String {
        fractionCompleted.formatted(.percent.precision(.fractionLength(0)))
    }
}
