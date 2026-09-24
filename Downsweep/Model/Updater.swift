import AppKit
import Combine
import Observation
import Sparkle

/// Sparkle's updater. It only starts when the build carries a public signing key (`SUPublicEDKey`
/// in `Config/Info.plist`), so debug builds and unsigned test builds never check for updates.
///
/// The only network access Downsweep makes: fetching the appcast from GitHub Releases, and the
/// update itself when the person accepts it.
@Observable
@MainActor
final class Updater {
    @ObservationIgnored private let controller: SPUStandardUpdaterController?
    @ObservationIgnored private var subscription: AnyCancellable?

    private(set) var canCheckForUpdates = false

    var automaticallyChecks: Bool {
        didSet { controller?.updater.automaticallyChecksForUpdates = automaticallyChecks }
    }

    var isAvailable: Bool { controller != nil }

    init() {
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        guard !key.isEmpty else {
            controller = nil
            automaticallyChecks = false
            return
        }
        let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        self.controller = controller
        automaticallyChecks = controller.updater.automaticallyChecksForUpdates
        subscription = controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.canCheckForUpdates = $0 }
    }

    func checkForUpdates() {
        NSApp.bringToFront()
        controller?.checkForUpdates(nil)
    }
}
