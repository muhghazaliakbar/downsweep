import AppKit
import Observation
import SweepCore

enum ReviewSection: Hashable {
    case all
    case category(ProposalCategory)
    case history
}

@Observable
final class AppModel {
    var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            settings.save()
            if settings.folderPath != oldValue.folderPath { startWatching() }
            if settings.configuration != oldValue.configuration { scheduleScan() }
        }
    }

    var reviewSection: ReviewSection = .all
    /// Review list filter by Finder-style kind; `nil` shows everything. Kept across sidebar sections.
    var reviewKindFilter: FileKind?
    /// Set when automatic mode hits the safety limit; the menu bar asks before continuing.
    var pendingConfirmation: [Proposal]?

    private(set) var result: ScanResult?
    private(set) var proposals: [Proposal] = []
    private(set) var history: [HistoryEntry] = []
    private(set) var isScanning = false
    /// Live status of the running scan; `nil` when idle.
    private(set) var scanProgress: ScanProgress?
    private(set) var pausedUntil: Date?
    private(set) var lastError: String?

    /// Skipped suggestions come back on relaunch; pins are permanent.
    private var skipped: Set<URL> = []
    private let executor = FileExecutor()
    private let store = HistoryStore.applicationSupport()
    private var watcher: FolderWatcher?
    private var scanTask: Task<Void, Never>?
    private var resumeTask: Task<Void, Never>?
    private var followUpTask: Task<Void, Never>?
    @ObservationIgnored private var summaryScheduler: WeeklySummaryScheduler?

    /// Bumped to ask the always-present menu bar label to open the weekly summary window.
    var summaryWindowRequest = 0

    init() {
        settings = AppSettings.load()
        summaryScheduler = WeeklySummaryScheduler(
            history: { [unowned self] in history },
            onOpen: { [unowned self] in summaryWindowRequest += 1 }
        )
        Task { await start() }
    }

    // MARK: - Derived

    var reclaimableBytes: Int64 { proposals.reduce(0) { $0 + $1.reclaimableBytes } }

    var isPaused: Bool { pausedUntil.map { $0 > .now } ?? false }

    func proposals(in section: ReviewSection) -> [Proposal] {
        switch section {
        case .all: proposals
        case .category(let category): proposals.filter { $0.reason.category == category }
        case .history: []
        }
    }

    func bytes(in section: ReviewSection) -> Int64 {
        proposals(in: section).reduce(0) { $0 + $1.reclaimableBytes }
    }

    // MARK: - Scanning

    func start() async {
        history = await store.load()
        summaryScheduler?.reschedule()
        if DebugOptions.sendsWeeklySummaryAtLaunch { await summaryScheduler?.deliver() }
        startWatching()
        await scan()
    }

    func scan() async {
        guard !isScanning else { return }
        isScanning = true
        scanProgress = ScanProgress(phase: .listing)

        // A stream keeps updates from the background pipeline in order on the main actor.
        let (updates, continuation) = AsyncStream.makeStream(of: ScanProgress.self, bufferingPolicy: .bufferingNewest(1))
        let progressTask = Task {
            for await update in updates { scanProgress = update }
        }
        defer {
            continuation.finish()
            progressTask.cancel()
            isScanning = false
            scanProgress = nil
        }

        let folder = settings.folderURL
        let configuration = settings.configuration
        let now = DebugOptions.now
        do {
            let result = try await Task.detached(priority: .utility) {
                try await SweepPipeline.run(folder: folder, configuration: configuration, now: now) {
                    continuation.yield($0)
                }
            }.value
            self.result = result
            proposals = result.proposals.filter { !skipped.contains($0.id) }
            lastError = nil
            scheduleFollowUp(after: result)
        } catch {
            lastError = String(localized: "Couldn’t read \(folder.lastPathComponent): \(error.localizedDescription)")
            return
        }

        if settings.mode == .automatic, !isPaused, !proposals.isEmpty {
            if SafetyLimit.requiresConfirmation(proposals) {
                pendingConfirmation = proposals
            } else {
                await apply(proposals)
            }
        }
    }

    /// Coalesces bursts of folder events and settings edits into one scan.
    func scheduleScan(after delay: Duration = .seconds(1)) {
        scanTask?.cancel()
        scanTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await scan()
        }
    }

    /// Folder events alone miss two things: held-back items (too new, or still being written)
    /// becoming eligible, and lifecycle stages moving on with time. Check back for both.
    private func scheduleFollowUp(after result: ScanResult) {
        followUpTask?.cancel()
        let longest: TimeInterval = 6 * 60 * 60
        let delay = result.nextReevaluation.map { min($0.timeIntervalSince(result.finishedAt) + 1, longest) } ?? longest
        followUpTask = Task {
            try? await Task.sleep(for: .seconds(max(delay, 1)))
            guard !Task.isCancelled else { return }
            await scan()
        }
    }

    private func startWatching() {
        watcher?.stop()
        let watcher = FolderWatcher(url: settings.folderURL) { [weak self] in
            Task { @MainActor in self?.scheduleScan() }
        }
        watcher.start()
        self.watcher = watcher
    }

    // MARK: - Actions

    func apply(_ batch: [Proposal]) async {
        var applied: [HistoryEntry] = []
        var failures: [String] = []
        for proposal in batch {
            do {
                applied.append(try executor.perform(proposal, reason: proposal.reasonText))
            } catch {
                failures.append(error.localizedDescription)
            }
        }
        let handled = Set(batch.map(\.id))
        proposals.removeAll { handled.contains($0.id) }
        history.insert(contentsOf: applied.reversed(), at: 0)
        lastError = failures.first
        pendingConfirmation = nil
        try? await store.save(history)
    }

    func apply(ids: Set<URL>) async {
        await apply(proposals.filter { ids.contains($0.id) })
    }

    func skip(ids: Set<URL>) {
        skipped.formUnion(ids)
        proposals.removeAll { ids.contains($0.id) }
    }

    func pin(ids: Set<URL>) {
        settings.configuration.pinned.formUnion(ids)
        proposals.removeAll { ids.contains($0.id) }
    }

    func unpin(_ url: URL) {
        settings.configuration.pinned.remove(url)
    }

    func undo(_ entry: HistoryEntry) async {
        do {
            try executor.undo(entry)
            if let index = history.firstIndex(where: { $0.id == entry.id }) {
                history[index].undone = true
            }
            try? await store.save(history)
            // An undone item shouldn't be swept straight back up.
            skipped.insert(entry.originalURL)
            await scan()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func togglePause() {
        resumeTask?.cancel()
        guard !isPaused else {
            pausedUntil = nil
            return
        }
        let until = Date.now.addingTimeInterval(24 * 60 * 60)
        pausedUntil = until
        // Clear the state when the pause runs out, so the menu bar stops showing it.
        resumeTask = Task {
            try? await Task.sleep(for: .seconds(until.timeIntervalSinceNow))
            guard !Task.isCancelled else { return }
            pausedUntil = nil
        }
    }

    func dismissError() { lastError = nil }

    /// Called when the Weekly Summary setting changes.
    func weeklySummarySettingChanged() {
        if summaryScheduler?.isEnabled == true { summaryScheduler?.requestAuthorization() }
        summaryScheduler?.reschedule()
    }
}
