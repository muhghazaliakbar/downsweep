import Foundation
import Synchronization
import Testing
@testable import SweepCore

struct ScanProgressTests {
    @Test func fractionStaysWithinPhaseRanges() {
        #expect(ScanProgress(phase: .listing).fractionCompleted == 0)
        #expect(ScanProgress(phase: .listing, completed: 1, total: 2).fractionCompleted == 0.25)
        #expect(ScanProgress(phase: .inspectingInstallers, completed: 0, total: 4).fractionCompleted == 0.5)
        #expect(abs(ScanProgress(phase: .inspectingInstallers, completed: 2, total: 4).fractionCompleted - 0.675) < 1e-9)
        #expect(abs(ScanProgress(phase: .inspectingInstallers, completed: 9, total: 4).fractionCompleted - 0.85) < 1e-9)
        #expect(ScanProgress(phase: .evaluating).fractionCompleted == 0.97)
    }

    @Test func pipelineReportsPhasesInOrder() async throws {
        let folder = URL.temporaryDirectory.appending(path: "ScanProgressTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data("a".utf8).write(to: folder.appending(path: "notes.txt"))

        let reported = Mutex<[ScanProgress]>([])
        let configuration = SweepConfiguration(detectInstallers: true, detectDuplicates: true)
        _ = try await SweepPipeline.run(folder: folder, configuration: configuration) { update in
            reported.withLock { $0.append(update) }
        }

        let updates = reported.withLock { $0 }
        #expect(updates.map(\.phase) == [.listing, .listing, .inspectingInstallers, .findingDuplicates, .evaluating])
        #expect(updates.map(\.fractionCompleted) == updates.map(\.fractionCompleted).sorted())
    }
}
