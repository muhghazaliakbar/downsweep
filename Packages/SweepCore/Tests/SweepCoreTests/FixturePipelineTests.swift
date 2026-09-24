import Foundation
import Testing
@testable import SweepCore

/// End-to-end run over the folder made by `scripts/make-fixtures.sh`. Mounts real DMGs.
///
///     DOWNSWEEP_FIXTURES=/tmp/DownsweepFixtures swift test --filter FixturePipeline
@Suite(.enabled(if: ProcessInfo.processInfo.environment["DOWNSWEEP_FIXTURES"] != nil))
struct FixturePipelineTests {
    let folder = URL(filePath: ProcessInfo.processInfo.environment["DOWNSWEEP_FIXTURES"] ?? "/")

    @Test func sweepsFixtureFolder() async throws {
        var configuration = SweepConfiguration(rules: [
            SourceRule(domain: "github.com", destination: URL(filePath: "/tmp/Code")),
        ])
        configuration.thresholds = .default
        let result = try await SweepPipeline.run(folder: folder, configuration: configuration, now: .now.addingTimeInterval(60 * 86_400))

        for proposal in result.proposals.sorted(by: { $0.item.name < $1.item.name }) {
            print("•", proposal.item.name, "→", proposal.action, "|", proposal.reason.category)
        }

        func reason(_ name: String) -> ProposalReason? {
            result.proposals.first { $0.item.name == name }?.reason
        }
        #expect(reason("Nimbus-1.0.dmg")?.category == .stale)
        #expect(reason("Quarterly Report (1).pdf")?.category == .duplicates)
        #expect(reason("photo (1).png")?.category != .duplicates)
        #expect(reason("release-notes.zip")?.category == .sourceRules)

        let installers = result.proposals.filter { $0.reason.category == .installers }.map(\.item.fileExtension).sorted()
        #expect(installers == ["dmg", "zip"])
    }
}
