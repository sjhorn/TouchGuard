import Foundation
import Testing
import TouchGuardCore
@testable import TouchGuard

@MainActor
final class FakeController: TapControlling {
    var delay: TimeInterval
    var onStateChange: ((EventTapController.State) -> Void)?
    var onBlock: ((Int) -> Void)?
    var startCount = 0
    var stopCount = 0
    var resetCount_ = 0

    init(delay: TimeInterval) { self.delay = delay }

    func start() { startCount += 1 }
    func stop() { stopCount += 1 }
    func resetCount() { resetCount_ += 1 }
    func checkHealth() {}
}

@MainActor
@Suite(.serialized)
final class AppModelTests {
    let suiteName = "TouchGuardTests.\(UUID().uuidString)"
    let defaults: UserDefaults
    var controller: FakeController?

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
    }

    deinit {
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    var secureInput = false

    func makeModel() -> AppModel {
        AppModel(defaults: defaults, makeController: { delay in
            let fake = FakeController(delay: delay)
            self.controller = fake
            return fake
        }, isSecureInputEnabled: { [unowned self] in self.secureInput })
    }

    @Test func registersDefaults() {
        let model = makeModel()
        #expect(model.delayMs == 200)
        #expect(model.isEnabled)
        #expect(model.hotKeyEnabled)
        #expect(controller?.delay == 0.2)
    }

    @Test func loadsStoredValues() {
        defaults.set(350, forKey: AppModel.Key.delayMs)
        defaults.set(false, forKey: AppModel.Key.enabled)
        let model = makeModel()
        #expect(model.delayMs == 350)
        #expect(!model.isEnabled)
        #expect(controller?.delay == 0.35)
    }

    @Test func clampsStoredDelay() {
        defaults.set(5, forKey: AppModel.Key.delayMs)
        #expect(makeModel().delayMs == 50)
        defaults.set(99_999, forKey: AppModel.Key.delayMs)
        #expect(makeModel().delayMs == 1000)
    }

    @Test(arguments: [(10, 50), (50, 50), (300, 300), (1000, 1000), (5000, 1000)])
    func setDelayClampsAndPersists(input: Int, expected: Int) {
        let model = makeModel()
        model.setDelay(input)
        #expect(model.delayMs == expected)
        #expect(defaults.integer(forKey: AppModel.Key.delayMs) == expected)
        #expect(controller?.delay == TimeInterval(expected) / 1000)
    }

    @Test func toggleEnabledStartsAndStopsController() {
        let model = makeModel()
        model.setEnabled(false)
        #expect(!model.isEnabled)
        #expect(controller?.stopCount == 1)
        #expect(!defaults.bool(forKey: AppModel.Key.enabled))

        model.toggleEnabled()
        #expect(model.isEnabled)
        #expect(controller?.startCount == 1)
        #expect(defaults.bool(forKey: AppModel.Key.enabled))
    }

    @Test func hotKeyOnOffPersists() {
        let model = makeModel()
        model.setHotKeyEnabled(false)
        #expect(!model.hotKeyEnabled)
        #expect(!defaults.bool(forKey: AppModel.Key.hotKeyEnabled))
        model.setHotKeyEnabled(true)
        #expect(model.hotKeyEnabled)
        #expect(defaults.bool(forKey: AppModel.Key.hotKeyEnabled))
        model.setHotKeyEnabled(false)
    }

    @Test func blockedClicksFollowControllerAndReset() {
        let model = makeModel()
        controller?.onBlock?(3)
        #expect(model.blockedClicks == 3)
        model.resetBlockedClicks()
        #expect(model.blockedClicks == 0)
        #expect(controller?.resetCount_ == 1)
    }

    @Test func statusTextAndSymbolPerState() {
        let model = makeModel()
        #expect(model.statusText == "Paused")
        #expect(model.menuBarSymbol == "hand.raised.slash")

        model.stateChanged(to: .running)
        #expect(model.statusText == "Active, 200 ms")
        #expect(model.menuBarSymbol == "hand.raised")

        model.setDelay(150)
        #expect(model.statusText == "Active, 150 ms")

        model.stateChanged(to: .failed)
        #expect(model.statusText == "Couldn't start the event tap")
        #expect(model.menuBarSymbol == "exclamationmark.triangle")

        model.stateChanged(to: .paused)
        #expect(model.statusText == "Paused")
    }

    @Test func needsPermissionStatusMatchesMode() {
        let model = makeModel()
        // Going through stateChanged(to: .needsPermission) would open the onboarding window.
        let expected = switch Permissions.mode {
        case .accessibility: "Needs Accessibility permission"
        case .inputMonitoringAndPostEvent: "Needs Input Monitoring permission"
        }
        #expect(model.statusText(for: .needsPermission) == expected)
        #expect(model.menuBarSymbol(for: .needsPermission) == "exclamationmark.triangle")
    }

    @Test func secureInputShowsInStatusOnlyWhileRunning() {
        let model = makeModel()
        model.stateChanged(to: .running)
        secureInput = true
        model.checkSecureInput()
        #expect(model.secureInputActive)
        #expect(model.statusText == "Not blocking: secure input is on")
        #expect(model.menuBarSymbol == "lock")

        model.stateChanged(to: .paused)
        #expect(model.statusText == "Paused")

        model.stateChanged(to: .running)
        secureInput = false
        model.checkSecureInput()
        #expect(!model.secureInputActive)
        #expect(model.statusText == "Active, 200 ms")
        #expect(model.menuBarSymbol == "hand.raised")
    }
}
