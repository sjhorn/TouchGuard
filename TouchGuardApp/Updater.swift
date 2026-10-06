import Foundation
import Observation

#if canImport(Sparkle) && !APP_STORE
import Sparkle

/// Sparkle updates for the Developer ID build. The updater only starts when
/// the bundle has a feed URL and EdDSA public key, so local builds stay quiet.
@Observable
@MainActor
final class Updater {
    @ObservationIgnored private let controller: SPUStandardUpdaterController
    private(set) var canCheckForUpdates = false
    @ObservationIgnored private var observation: NSKeyValueObservation?

    let isAvailable: Bool

    init(bundle: Bundle = .main) {
        let key = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        let feed = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? ""
        let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        isAvailable = !key.isEmpty && !feed.isEmpty && !isTesting
        controller = SPUStandardUpdaterController(startingUpdater: isAvailable,
                                                  updaterDelegate: nil, userDriverDelegate: nil)
        observation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            MainActor.assumeIsolated { self?.canCheckForUpdates = updater.canCheckForUpdates }
        }
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
#else
/// App Store builds are updated by the store.
@MainActor
final class Updater {
    let isAvailable = false
    let canCheckForUpdates = false
    func checkForUpdates() {}
}
#endif
