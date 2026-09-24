import Foundation
import Testing
@testable import SweepCore

private let now = Date(timeIntervalSince1970: 1_790_000_000)

private func daysAgo(_ days: Double) -> Date { now.addingTimeInterval(-days * 86_400) }

private func item(
    _ name: String,
    added: Double = 60,
    used: Double? = nil,
    size: Int64 = 1_000,
    modified: Date? = nil,
    from: [String] = []
) -> DownloadItem {
    DownloadItem(
        url: URL(filePath: "/Users/test/Downloads/\(name)"),
        size: size,
        dateAdded: daysAgo(added),
        lastUsed: used.map(daysAgo),
        contentModified: modified,
        whereFroms: from.compactMap(URL.init(string:))
    )
}

private let figma = AppBundleInfo(bundleID: "com.figma.Desktop", name: "Figma", version: "125.1")
private let installedFigma = URL(filePath: "/Applications/Figma.app")

@Suite struct LifecycleTests {
    @Test(arguments: [
        (1.0, nil as Double?, LifecycleStage.new),
        (20, 5, .active),
        (20, nil, .idle),
        (35, nil, .stale),
        (50, nil, .expired),
        (50, 2, .active),
    ])
    func stages(added: Double, used: Double?, expected: LifecycleStage) {
        #expect(Lifecycle.stage(for: item("a.pdf", added: added, used: used), now: now) == expected)
    }

    @Test func missingDatesAreUnknown() {
        let undated = DownloadItem(url: URL(filePath: "/tmp/x"), size: 1, dateAdded: nil)
        #expect(Lifecycle.stage(for: undated, now: now) == .unknown)
    }
}

@Suite struct PolicyEngineTests {
    @Test func pinnedItemsAreNeverTouched() {
        let file = item("Figma.dmg")
        let context = PolicyContext(
            pinned: [file.url],
            installerStatus: [file.url: .installed(InstallerMatch(installer: figma, installedVersion: "126.0", installedURL: installedFigma))],
            now: now
        )
        #expect(PolicyEngine.proposal(for: file, context: context) == nil)
    }

    @Test func installedInstallerGoesToTrashEvenWhenNew() throws {
        let file = item("Figma.dmg", added: 0.5)
        let match = InstallerMatch(installer: figma, installedVersion: "126.0", installedURL: installedFigma)
        let context = PolicyContext(installerStatus: [file.url: .installed(match)], now: now)
        let proposal = try #require(PolicyEngine.proposal(for: file, context: context))
        #expect(proposal.action == .moveToTrash)
        #expect(proposal.reason == .installerAlreadyInstalled(match))
    }

    @Test func freshDownloadsGetAGracePeriod() {
        let file = item("Figma.dmg", added: 0.01)
        let match = InstallerMatch(installer: figma, installedVersion: "126.0", installedURL: installedFigma)
        let context = PolicyContext(installerStatus: [file.url: .installed(match)], now: now)
        #expect(PolicyEngine.proposal(for: file, context: context) == nil)
    }

    @Test func newerInstallerIsTaggedNotTrashed() throws {
        let file = item("Figma.dmg", added: 90)
        let match = InstallerMatch(installer: figma, installedVersion: "100.0", installedURL: installedFigma)
        let context = PolicyContext(installerStatus: [file.url: .newerThanInstalled(match)], now: now)
        let proposal = try #require(PolicyEngine.proposal(for: file, context: context))
        #expect(proposal.action == .tag(PolicyEngine.staleTag))
    }

    @Test func sourceRuleMovesMatchingFiles() throws {
        let destination = URL(filePath: "/Users/test/Documents/Attachments")
        let rule = SourceRule(domain: "*.google.com", destination: destination)
        let file = item("invoice.pdf", added: 5, from: [
            "https://mail-attachment.googleusercontent.com/x",
            "https://mail.google.com/mail/u/0/",
        ])
        let proposal = try #require(PolicyEngine.proposal(for: file, context: PolicyContext(rules: [rule], now: now)))
        #expect(proposal.action == .move(to: destination))
    }

    @Test func sourceRuleRespectsExtensionsAndNewItems() {
        let rule = SourceRule(domain: "github.com", extensions: ["zip"], destination: URL(filePath: "/tmp"))
        let pdf = item("notes.pdf", added: 5, from: ["https://github.com/a/b"])
        let fresh = item("repo.zip", added: 1, from: ["https://github.com/a/b"])
        let context = PolicyContext(rules: [rule], now: now)
        #expect(PolicyEngine.proposal(for: pdf, context: context) == nil)
        #expect(PolicyEngine.proposal(for: fresh, context: context) == nil)
    }

    @Test func duplicatesBeatLifecycle() throws {
        let original = item("report.pdf", added: 50)
        let copy = item("report (1).pdf", added: 45)
        let context = PolicyContext(duplicates: [copy.url: original.url], now: now)
        let proposal = try #require(PolicyEngine.proposal(for: copy, context: context))
        #expect(proposal.reason == .duplicate(original: original.url))
    }

    @Test func partialDownloadsAreSkipped() {
        #expect(PolicyEngine.proposal(for: item("movie.mkv.crdownload", added: 90), context: PolicyContext(now: now)) == nil)
    }

    @Test func safetyLimitTripsOnCountAndSize() {
        let many = (0..<51).map { Proposal(item: item("f\($0).zip"), action: .moveToTrash, reason: .expired(idleDays: 60)) }
        let huge = [Proposal(item: item("vm.iso", size: 11_000_000_000), action: .moveToTrash, reason: .expired(idleDays: 60))]
        let tags = (0..<80).map { Proposal(item: item("t\($0).txt"), action: .tag("Stale"), reason: .stale(idleDays: 35)) }
        #expect(SafetyLimit.requiresConfirmation(many))
        #expect(SafetyLimit.requiresConfirmation(huge))
        #expect(!SafetyLimit.requiresConfirmation(tags))
    }
}

@Suite struct InstallerParsingTests {
    @Test(arguments: [
        ("2.10.1", "2.9", false),
        ("1.0", "1.0.0", false),
        ("125.1 (431)", "126", true),
        ("3", "3.0.1", true),
    ])
    func versionOrdering(left: String, right: String, leftIsOlder: Bool) {
        #expect((AppVersion(left) < AppVersion(right)) == leftIsOlder)
    }

    @Test func statusComparesAgainstIndex() {
        let index = InstalledAppIndex(entries: [.init(url: installedFigma, info: AppBundleInfo(bundleID: figma.bundleID, name: "Figma", version: "124.0"))])
        let inspector = InstallerInspector(index: index)
        guard case .newerThanInstalled = inspector.status(for: figma) else {
            Issue.record("expected newerThanInstalled")
            return
        }
        guard case .notInstalled = inspector.status(for: AppBundleInfo(bundleID: "x.y", name: "Y", version: "1")) else {
            Issue.record("expected notInstalled")
            return
        }
    }

    @Test func zipListingPicksShallowestApp() {
        let listing = """
        __MACOSX/Foo.app/Contents/Info.plist
        Foo.app/Contents/Frameworks/Bar.framework/Helper.app/Contents/Info.plist
        Foo.app/Contents/Info.plist
        """
        #expect(InstallerInspector.infoPlistEntry(inZipListing: listing) == "Foo.app/Contents/Info.plist")
    }

    @Test func packageInfoFindsTopLevelApp() throws {
        let xml = """
        <pkg-info identifier="com.example.pkg" version="2.0">
          <bundle id="com.example.helper" CFBundleShortVersionString="9" path="./Example.app/Contents/Helpers/Helper.app"/>
          <bundle id="com.example.app" CFBundleShortVersionString="2.4.0" path="./Example.app"/>
        </pkg-info>
        """
        let info = try #require(InstallerInspector.appBundle(fromPackageInfo: Data(xml.utf8)))
        #expect(info == AppBundleInfo(bundleID: "com.example.app", name: "Example", version: "2.4.0"))
    }

    @Test func attachPlistMountPoints() throws {
        let plist: [String: Any] = ["system-entities": [["dev-entry": "/dev/disk4"], ["mount-point": "/private/tmp/x/Figma"]]]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        #expect(InstallerInspector.mountPoints(fromAttachOutput: data) == [URL(filePath: "/private/tmp/x/Figma", directoryHint: .isDirectory)])
    }
}

@Suite struct DuplicateFinderTests {
    @Test(arguments: [("report (2).pdf", "report"), ("report-3.pdf", "report"), ("report.pdf", "report"), ("2024-10.csv", "2024")])
    func baseNames(file: String, base: String) {
        #expect(DuplicateFinder.baseName(of: URL(filePath: "/d/\(file)")) == base)
    }

    @Test func keepsOldestAndRequiresMatchingHash() {
        let original = item("report.pdf", added: 10, size: 500)
        let copy = item("report (1).pdf", added: 5, size: 500)
        let different = item("report (2).pdf", added: 4, size: 500)
        let hashes = [original.url: "a", copy.url: "a", different.url: "b"]
        let result = DuplicateFinder.duplicates(in: [copy, different, original]) { hashes[$0]! }
        #expect(result == [copy.url: original.url])
    }
}

@Suite struct FileExecutorTests {
    let folder: URL

    init() throws {
        folder = FileManager.default.temporaryDirectory.appending(path: "DownsweepTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    private func makeFile(_ name: String) throws -> DownloadItem {
        let url = folder.appending(path: name)
        try Data("hello".utf8).write(to: url)
        return try #require(MetadataReader.item(at: url))
    }

    @Test func moveResolvesConflictsAndUndoes() throws {
        let destination = folder.appending(path: "Sorted")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try Data().write(to: destination.appending(path: "a.txt"))

        let file = try makeFile("a.txt")
        let proposal = Proposal(item: file, action: .move(to: destination), reason: .stale(idleDays: 40))
        let entry = try FileExecutor().perform(proposal, reason: "test")
        #expect(entry.resultURL?.lastPathComponent == "a 2.txt")

        try FileExecutor().undo(entry)
        #expect(FileManager.default.fileExists(atPath: file.url.path))
    }

    @Test func tagAndUntag() throws {
        let file = try makeFile("b.txt")
        let entry = try FileExecutor().perform(Proposal(item: file, action: .tag("Stale"), reason: .stale(idleDays: 40)), reason: "test")
        #expect(FileExecutor.tags(of: file.url).contains("Stale"))
        try FileExecutor().undo(entry)
        #expect(!FileExecutor.tags(of: file.url).contains("Stale"))
    }

    @Test func refusesChangedFiles() throws {
        let file = try makeFile("c.txt")
        try Data(repeating: 1, count: 100_000).write(to: file.url)
        #expect(throws: ExecutorError.itemChanged(file.url)) {
            try FileExecutor().perform(Proposal(item: file, action: .tag("Stale"), reason: .stale(idleDays: 40)), reason: "test")
        }
    }

    @Test func refusesFoldersChangedInside() throws {
        let url = folder.appending(path: "unpacking")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let scanned = try #require(MetadataReader.item(at: url))
        // Something lands inside after the scan, e.g. an archive still being extracted.
        let later = url.appending(path: "part.bin")
        try Data([1]).write(to: later)
        try FileManager.default.setAttributes([.modificationDate: Date.now.addingTimeInterval(5)], ofItemAtPath: later.path)
        #expect(throws: ExecutorError.itemChanged(url)) {
            try FileExecutor().perform(Proposal(item: scanned, action: .tag("Stale"), reason: .stale(idleDays: 40)), reason: "test")
        }
    }

    @Test func historyRoundTripsAndPrunes() async throws {
        let store = HistoryStore(fileURL: folder.appending(path: "history.json"))
        let fresh = HistoryEntry(date: now, kind: .tag, originalURL: folder, resultURL: nil, bytes: 0, reason: "r")
        let old = HistoryEntry(date: daysAgo(120), kind: .tag, originalURL: folder, resultURL: nil, bytes: 0, reason: "r")
        try await store.save([fresh, old], now: now)
        #expect(await store.load() == [fresh])
    }
}

@Suite struct SettleTests {
    @Test func itemStillBeingWrittenIsLeftAlone() {
        // Old enough to expire, but its content changed 30 seconds ago (e.g. unpacking into a folder).
        let busy = item("export", added: 90, modified: now.addingTimeInterval(-30))
        #expect(PolicyEngine.proposal(for: busy, context: PolicyContext(now: now)) == nil)

        let settled = item("export", added: 90, modified: now.addingTimeInterval(-PolicyEngine.settleInterval))
        #expect(PolicyEngine.proposal(for: settled, context: PolicyContext(now: now)) != nil)
    }

    @Test func nextReevaluationIsWhenTheFirstHeldBackItemBecomesEligible() {
        let fresh = item("fresh.pdf", added: 0.5 / 24) // added 30 minutes ago → eligible in 30
        let busy = item("busy.zip", added: 90, modified: now.addingTimeInterval(-60)) // settles in 60 s
        let old = item("old.pdf", added: 90)
        let context = PolicyContext(now: now)

        #expect(PolicyEngine.nextReevaluation(for: [fresh, busy, old], context: context)
            == now.addingTimeInterval(PolicyEngine.settleInterval - 60))
        #expect(PolicyEngine.nextReevaluation(for: [fresh, old], context: context)
            == fresh.dateAdded!.addingTimeInterval(PolicyEngine.gracePeriod))
        #expect(PolicyEngine.nextReevaluation(for: [old], context: context) == nil)
    }
}

