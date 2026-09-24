import Foundation

/// Where a running scan is, reported by `SweepPipeline.run` so the UI can show live status.
public struct ScanProgress: Hashable, Sendable {
    public enum Phase: Int, CaseIterable, Sendable {
        case listing
        case inspectingInstallers
        case findingDuplicates
        case evaluating
    }

    public let phase: Phase
    /// Units finished within the current phase; only meaningful when `total > 0`.
    public let completed: Int
    public let total: Int

    public init(phase: Phase, completed: Int = 0, total: Int = 0) {
        self.phase = phase
        self.completed = completed
        self.total = total
    }

    /// Progress across the whole scan, 0...1. Reading metadata (folders are sized recursively)
    /// and installer inspection (one mount per DMG) take most of the time, so they get most of the range.
    public var fractionCompleted: Double {
        let (start, end): (Double, Double) = switch phase {
        case .listing: (0, 0.5)
        case .inspectingInstallers: (0.5, 0.85)
        case .findingDuplicates: (0.85, 0.97)
        case .evaluating: (0.97, 1)
        }
        guard total > 0 else { return start }
        return start + (end - start) * min(Double(completed) / Double(total), 1)
    }
}
