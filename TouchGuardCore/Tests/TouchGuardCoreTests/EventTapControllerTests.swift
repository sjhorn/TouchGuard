import CoreGraphics
import Foundation
import Testing
@testable import TouchGuardCore

@MainActor
final class FakeBackend: TapBackend {
    var createCount = 0
    var invalidateCount = 0
    var failCreate = false
    /// When false, `setEnabled(true)` has no effect (a rearm that doesn't take).
    var rearmWorks = true
    private(set) var isEnabled = false
    private var handler: (@MainActor (CGEventType) -> Bool)?

    var hasTap: Bool { handler != nil }

    func create(mask: CGEventMask, handler: @escaping @MainActor (CGEventType) -> Bool) -> Bool {
        createCount += 1
        guard !failCreate else { return false }
        self.handler = handler
        isEnabled = true
        return true
    }

    func setEnabled(_ enabled: Bool) {
        if enabled && !rearmWorks { return }
        isEnabled = enabled
    }

    func invalidate() {
        if handler != nil { invalidateCount += 1 }
        handler = nil
        isEnabled = false
    }

    /// macOS switching the tap off behind our back.
    func disableBySystem() {
        isEnabled = false
    }

    /// Delivers an event; returns true if it passed.
    func send(_ type: CGEventType) -> Bool {
        handler?(type) ?? true
    }
}

@MainActor
final class FakePermissions: PermissionChecking {
    var isGranted = true
}

final class FakeClock: @unchecked Sendable {
    var now: TimeInterval = 100
}

@MainActor
struct EventTapControllerTests {
    let backend = FakeBackend()
    let permissions = FakePermissions()
    let clock = FakeClock()

    func makeController(delay: TimeInterval = 0.2) -> EventTapController {
        let clock = self.clock
        return EventTapController(delay: delay, clock: { clock.now },
                                  backend: backend, permissions: permissions)
    }

    @Test func startRuns() {
        let c = makeController()
        var states: [EventTapController.State] = []
        c.onStateChange = { states.append($0) }
        c.start()
        #expect(c.state == .running)
        #expect(c.isEnabled)
        #expect(backend.createCount == 1)
        #expect(states == [.running])
        c.stop()
    }

    @Test func needsPermissionUntilGrantedThenRuns() {
        permissions.isGranted = false
        let c = makeController()
        c.start()
        #expect(c.state == .needsPermission)
        #expect(backend.createCount == 0)

        c.checkHealth()
        #expect(c.state == .needsPermission)

        permissions.isGranted = true
        c.checkHealth()
        #expect(c.state == .running)
        #expect(backend.createCount == 1)
        c.stop()
    }

    @Test func failedCreateIsRetriedByWatchdog() {
        backend.failCreate = true
        let c = makeController()
        c.start()
        #expect(c.state == .failed)

        backend.failCreate = false
        c.checkHealth()
        #expect(c.state == .running)
        #expect(backend.createCount == 2)
        c.stop()
    }

    @Test(arguments: [
        (CGEventType.tapDisabledByTimeout, EventTapController.RearmReason.timeout),
        (CGEventType.tapDisabledByUserInput, EventTapController.RearmReason.userInput),
    ])
    func disabledTapIsRearmedAndCounted(type: CGEventType, reason: EventTapController.RearmReason) {
        let c = makeController()
        var reasons: [EventTapController.RearmReason] = []
        c.onRearm = { reasons.append($0) }
        c.start()

        backend.disableBySystem()
        #expect(backend.send(type))
        #expect(backend.isEnabled)
        #expect(c.rearmCount == 1)
        #expect(reasons == [reason])
        #expect(backend.createCount == 1)
        c.stop()
    }

    @Test(arguments: [CGEventType.tapDisabledByTimeout, .tapDisabledByUserInput])
    func disabledAfterRevokeTearsDownInsteadOfRearming(type: CGEventType) {
        let c = makeController()
        var reasons: [EventTapController.RearmReason] = []
        c.onRearm = { reasons.append($0) }
        c.start()

        permissions.isGranted = false
        backend.disableBySystem()
        #expect(backend.send(type))
        #expect(reasons.isEmpty)
        #expect(!backend.hasTap)
        #expect(!backend.isEnabled)
        #expect(c.state == .needsPermission)

        permissions.isGranted = true
        c.checkHealth()
        #expect(c.state == .running)
        #expect(backend.createCount == 2)
        c.stop()
    }

    @Test func rearmLoopBacksOffUntilWatchdog() {
        let c = makeController()
        c.start()

        // Three disables in quick succession are rearmed…
        for i in 0..<EventTapController.rearmLoopLimit {
            clock.now = 100 + Double(i)
            backend.disableBySystem()
            _ = backend.send(.tapDisabledByTimeout)
            #expect(backend.isEnabled)
        }
        // …the next one within the window removes the tap.
        clock.now = 104
        backend.disableBySystem()
        _ = backend.send(.tapDisabledByTimeout)
        #expect(c.rearmCount == EventTapController.rearmLoopLimit)
        #expect(!backend.hasTap)
        #expect(c.state == .failed)

        // The watchdog brings it back.
        c.checkHealth()
        #expect(c.state == .running)
        #expect(backend.createCount == 2)
        c.stop()
    }

    @Test func occasionalDisablesKeepRearming() {
        let c = makeController()
        c.start()
        for i in 0..<10 {
            clock.now = 100 + Double(i) * EventTapController.rearmLoopWindow / 2
            backend.disableBySystem()
            _ = backend.send(.tapDisabledByUserInput)
        }
        #expect(c.rearmCount == 10)
        #expect(backend.createCount == 1)
        #expect(c.state == .running)
        c.stop()
    }

    @Test func watchdogRearmsSilentlyDisabledTap() {
        let c = makeController()
        var reasons: [EventTapController.RearmReason] = []
        c.onRearm = { reasons.append($0) }
        c.start()

        backend.disableBySystem()
        c.checkHealth()
        #expect(backend.isEnabled)
        #expect(reasons == [.watchdog])
        #expect(backend.createCount == 1)
        c.stop()
    }

    @Test func watchdogRecreatesTapWhenRearmFails() {
        let c = makeController()
        c.start()

        backend.rearmWorks = false
        backend.disableBySystem()
        c.checkHealth()
        #expect(backend.invalidateCount == 1)
        #expect(backend.createCount == 2)
        #expect(backend.isEnabled)
        #expect(c.state == .running)
        c.stop()
    }

    @Test func healthyTapIsLeftAlone() {
        let c = makeController()
        c.start()
        c.checkHealth()
        #expect(c.rearmCount == 0)
        #expect(backend.createCount == 1)
        c.stop()
    }

    @Test func revokedMidRunTearsDown() {
        let c = makeController()
        c.start()
        permissions.isGranted = false
        c.checkHealth()
        #expect(c.state == .needsPermission)
        #expect(!backend.hasTap)
        #expect(backend.invalidateCount == 1)
        #expect(c.isEnabled)
        c.stop()
    }

    @Test func stopPausesAndReleasesTap() {
        let c = makeController()
        c.start()
        c.stop()
        #expect(c.state == .paused)
        #expect(!c.isEnabled)
        #expect(!backend.hasTap)

        // The watchdog does nothing while stopped.
        c.checkHealth()
        #expect(backend.createCount == 1)
    }

    @Test func blocksClicksAfterKeyUpAndReportsOnlyBlockedDowns() {
        let c = makeController(delay: 0.2)
        var blocks: [Int] = []
        var releases: [TimeInterval] = []
        c.onBlock = { blocks.append($0) }
        c.onKeyRelease = { releases.append($0) }
        c.start()

        // Before typing, clicks pass and nothing is reported.
        #expect(backend.send(.leftMouseDown))
        #expect(backend.send(.leftMouseUp))

        #expect(backend.send(.keyUp))
        #expect(releases == [100.2])

        clock.now = 100.1
        #expect(!backend.send(.leftMouseDown))
        #expect(!backend.send(.leftMouseUp))
        #expect(!backend.send(.rightMouseDown))
        #expect(blocks == [1, 2])
        #expect(c.blockedClicks == 2)

        clock.now = 100.3
        #expect(backend.send(.otherMouseDown))
        #expect(backend.send(.otherMouseUp))
        #expect(blocks == [1, 2])

        // Event types outside the mask pass untouched.
        #expect(backend.send(.mouseMoved))

        c.resetCount()
        #expect(c.blockedClicks == 0)
        c.stop()
    }

    @Test func delayChangeAppliesToNextWindow() {
        let c = makeController(delay: 0.2)
        c.start()
        c.delay = 0.5
        _ = backend.send(.keyUp)
        clock.now = 100.4
        #expect(!backend.send(.leftMouseDown))
        c.stop()
    }
}
