import Testing
@testable import TouchGuardCore

struct ClickFilterTests {
    @Test func passesWhenNoKeyReleased() {
        var f = ClickFilter(delay: 0.2)
        #expect(f.decide(.down(.left), at: 10) == .pass)
        #expect(f.decide(.up(.left), at: 10.05) == .pass)
        #expect(f.blockedClicks == 0)
    }

    @Test func blocksInsideWindow() {
        var f = ClickFilter(delay: 0.2)
        f.keyReleased(at: 10)
        #expect(f.decide(.down(.left), at: 10.1) == .block)
        #expect(f.decide(.up(.left), at: 10.15) == .block)
        #expect(f.decide(.down(.right), at: 10.19) == .block)
        #expect(f.decide(.up(.right), at: 10.19) == .block)
    }

    @Test func windowBoundaryIsExclusive() {
        var f = ClickFilter(delay: 0.25)
        f.keyReleased(at: 1)
        #expect(f.decide(.down(.left), at: 1.2499) == .block)
        #expect(f.decide(.down(.left), at: 1.25) == .pass)
        #expect(f.decide(.up(.left), at: 1.3) == .pass)
    }

    @Test func laterKeyReleaseExtendsWindow() {
        var f = ClickFilter(delay: 0.2)
        f.keyReleased(at: 10)
        f.keyReleased(at: 10.15)
        #expect(f.decide(.down(.left), at: 10.3) == .block)
        #expect(f.decide(.down(.left), at: 10.36) == .pass)
    }

    @Test func passedDownAlwaysGetsItsUp() {
        var f = ClickFilter(delay: 0.2)
        #expect(f.decide(.down(.left), at: 10) == .pass)
        f.keyReleased(at: 10.5)         // key released mid-drag
        #expect(f.decide(.up(.left), at: 10.6) == .pass)
        // That down/up pair is finished; a fresh up in the window is blocked.
        #expect(f.decide(.up(.left), at: 10.61) == .block)
    }

    @Test func heldButtonsAreTrackedIndependently() {
        var f = ClickFilter(delay: 0.2)
        #expect(f.decide(.down(.left), at: 10) == .pass)
        f.keyReleased(at: 10.1)
        #expect(f.decide(.down(.right), at: 10.15) == .block)
        #expect(f.decide(.up(.right), at: 10.16) == .block)
        #expect(f.decide(.up(.left), at: 10.17) == .pass)
    }

    @Test func countsOnlyBlockedDowns() {
        var f = ClickFilter(delay: 0.2)
        f.keyReleased(at: 0)
        _ = f.decide(.down(.left), at: 0.05)
        _ = f.decide(.up(.left), at: 0.06)
        _ = f.decide(.down(.other), at: 0.07)
        _ = f.decide(.up(.other), at: 0.08)
        #expect(f.blockedClicks == 2)
        _ = f.decide(.down(.left), at: 1)   // passes, not counted
        #expect(f.blockedClicks == 2)
        f.resetCount()
        #expect(f.blockedClicks == 0)
    }

    @Test func delayChangeAppliesToNextKeyRelease() {
        var f = ClickFilter(delay: 0.2)
        f.keyReleased(at: 0)
        f.delay = 0.5
        #expect(f.decide(.down(.left), at: 0.3) == .pass)
        _ = f.decide(.up(.left), at: 0.31)
        f.keyReleased(at: 1)
        #expect(f.decide(.down(.left), at: 1.4) == .block)
        #expect(f.decide(.down(.left), at: 1.5) == .pass)
    }

    @Test func zeroDelayNeverBlocks() {
        var f = ClickFilter(delay: 0)
        f.keyReleased(at: 5)
        #expect(f.decide(.down(.left), at: 5) == .pass)
    }
}
