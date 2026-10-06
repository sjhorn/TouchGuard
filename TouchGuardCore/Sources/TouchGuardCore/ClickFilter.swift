import Foundation

/// Pure decision logic: should a mouse button event pass or be held back?
///
/// A click is blocked while `now < blockUntil`, where `blockUntil` is pushed
/// forward on every key release. Times are seconds on any monotonic clock.
public struct ClickFilter: Sendable {
    public enum Button: Int, Sendable, CaseIterable {
        case left, right, other
    }

    public enum Event: Sendable, Equatable {
        case down(Button)
        case up(Button)
    }

    public enum Decision: Sendable, Equatable {
        case pass
        case block
    }

    /// Block window after each key release, in seconds.
    public var delay: TimeInterval
    public private(set) var blockUntil: TimeInterval = -.infinity
    /// Number of mouse-downs that were blocked (ups are not counted).
    public private(set) var blockedClicks: Int = 0
    /// Buttons whose mouse-down was passed and whose mouse-up hasn't been seen.
    private var heldButtons: Set<Button> = []

    public init(delay: TimeInterval) {
        self.delay = delay
    }

    public mutating func keyReleased(at t: TimeInterval) {
        blockUntil = t + delay
    }

    public func isBlocking(at t: TimeInterval) -> Bool {
        t < blockUntil
    }

    public mutating func decide(_ event: Event, at t: TimeInterval) -> Decision {
        switch event {
        case .down(let button):
            if isBlocking(at: t) {
                blockedClicks += 1
                return .block
            }
            heldButtons.insert(button)
            return .pass
        case .up(let button):
            // A passed down always gets its up, so drags never get stuck.
            if heldButtons.remove(button) != nil {
                return .pass
            }
            return isBlocking(at: t) ? .block : .pass
        }
    }

    public mutating func resetCount() {
        blockedClicks = 0
    }
}
