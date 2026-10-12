import Foundation
import Observation

#if canImport(Sparkle) && !APP_STORE
import Sparkle

/// Sparkle updates for the Developer ID build. The updater only starts when
/// the bundle has a feed URL and EdDSA public key, so local builds stay quiet.
///
/// TouchGuard lives in the menu bar, so a daily check's update window would
/// open behind other apps and go unnoticed. Sparkle shows it in front only when
/// it can (just after launch, or after the Mac was idle); otherwise the update
/// waits as an item at the top of the menu ("gentle reminders").
@Observable
@MainActor
final class Updater: NSObject, @preconcurrency SPUStandardUserDriverDelegate {  // Sparkle calls it on the main thread
    @ObservationIgnored private var controller: SPUStandardUpdaterController!
    private(set) var canCheckForUpdates = false
    /// The version of an update found by a scheduled check that is waiting
    /// for the user, shown in the menu.
    private(set) var pendingUpdateVersion: String?
    @ObservationIgnored private var observation: NSKeyValueObservation?

    let isAvailable: Bool

    init(bundle: Bundle = .main) {
        let key = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        let feed = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? ""
        let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        isAvailable = !key.isEmpty && !feed.isEmpty && !isTesting
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: isAvailable,
                                                  updaterDelegate: nil, userDriverDelegate: self)
        observation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            MainActor.assumeIsolated { self?.canCheckForUpdates = updater.canCheckForUpdates }
        }
    }

    /// Also brings a waiting update's window to the front.
    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    // MARK: SPUStandardUserDriverDelegate

    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        immediateFocus
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        if !handleShowingUpdate {
            pendingUpdateVersion = update.displayVersionString
        }
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        pendingUpdateVersion = nil
    }

    func standardUserDriverWillFinishUpdateSession() {
        pendingUpdateVersion = nil
    }
}
#else
/// App Store builds are updated by the store.
@MainActor
final class Updater {
    let isAvailable = false
    let canCheckForUpdates = false
    let pendingUpdateVersion: String? = nil
    func checkForUpdates() {}
}
#endif
