import CoreGraphics
import Foundation

/// Owns the CGEventTap: creates it, feeds events through a `ClickFilter`,
/// re-enables it when macOS switches it off, and tracks Accessibility trust.
///
/// Everything happens on the main thread; the tap's run loop source is added
/// to the main run loop, so the C callback is delivered there too.
@MainActor
public final class EventTapController {
    public enum State: Sendable, Equatable {
        case running
        case paused
        case needsPermission
        case failed
    }

    public enum RearmReason: Sendable, Equatable {
        /// macOS disabled the tap because the callback was too slow.
        case timeout
        /// macOS disabled the tap because of user input (e.g. secure input).
        case userInput
        /// The watchdog found the tap disabled without being told.
        case watchdog
    }

    public private(set) var state: State = .paused {
        didSet { if state != oldValue { onStateChange?(state) } }
    }

    /// Whether the user wants clicks to be guarded.
    public private(set) var isEnabled = false

    public var delay: TimeInterval {
        get { filter.delay }
        set { filter.delay = newValue }
    }

    public var blockedClicks: Int { filter.blockedClicks }
    public private(set) var rearmCount = 0

    public var onStateChange: ((State) -> Void)?
    /// Called for each blocked mouse-down, with the new total.
    public var onBlock: ((Int) -> Void)?
    public var onRearm: ((RearmReason) -> Void)?
    /// Called on every key release, with the time (on `clock`) the block window ends.
    public var onKeyRelease: ((TimeInterval) -> Void)?

    public let clock: @Sendable () -> TimeInterval

    private var filter: ClickFilter
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var watchdog: Timer?

    public static let watchdogInterval: TimeInterval = 2

    private static let eventMask: CGEventMask = {
        let types: [CGEventType] = [
            .keyUp,
            .leftMouseDown, .leftMouseUp,
            .rightMouseDown, .rightMouseUp,
            .otherMouseDown, .otherMouseUp,
        ]
        return types.reduce(0) { $0 | (1 << CGEventMask($1.rawValue)) }
    }()

    public init(delay: TimeInterval,
                clock: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.filter = ClickFilter(delay: delay)
        self.clock = clock
    }

    // MARK: - Public control

    public func start() {
        isEnabled = true
        startWatchdog()
        install()
    }

    public func stop() {
        isEnabled = false
        stopWatchdog()
        teardown()
        state = .paused
    }

    public func resetCount() {
        filter.resetCount()
    }

    // MARK: - Tap lifecycle

    private func install() {
        guard isEnabled, tap == nil else { return }
        guard Accessibility.isTrusted else {
            state = .needsPermission
            return
        }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let port = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: Self.eventMask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let controller = Unmanaged<EventTapController>.fromOpaque(refcon).takeUnretainedValue()
                let pass = MainActor.assumeIsolated { controller.handle(type: type, event: event) }
                return pass ? Unmanaged.passUnretained(event) : nil
            },
            userInfo: refcon
        ) else {
            state = Accessibility.isTrusted ? .failed : .needsPermission
            return
        }
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        tap = port
        source = src
        state = .running
    }

    private func teardown() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        tap = nil
        source = nil
    }

    private func rearm(_ reason: RearmReason) {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
        rearmCount += 1
        onRearm?(reason)
    }

    // MARK: - Event handling

    /// Returns true if the event should pass through.
    private func handle(type: CGEventType, event: CGEvent) -> Bool {
        let now = clock()
        switch type {
        case .tapDisabledByTimeout:
            rearm(.timeout)
            return true
        case .tapDisabledByUserInput:
            rearm(.userInput)
            return true
        case .keyUp:
            filter.keyReleased(at: now)
            onKeyRelease?(filter.blockUntil)
            return true
        default:
            guard let mouse = Self.mouseEvent(for: type) else { return true }
            let before = filter.blockedClicks
            let decision = filter.decide(mouse, at: now)
            if filter.blockedClicks != before {
                onBlock?(filter.blockedClicks)
            }
            return decision == .pass
        }
    }

    private static func mouseEvent(for type: CGEventType) -> ClickFilter.Event? {
        switch type {
        case .leftMouseDown: .down(.left)
        case .leftMouseUp: .up(.left)
        case .rightMouseDown: .down(.right)
        case .rightMouseUp: .up(.right)
        case .otherMouseDown: .down(.other)
        case .otherMouseUp: .up(.other)
        default: nil
        }
    }

    // MARK: - Watchdog

    private func startWatchdog() {
        guard watchdog == nil else { return }
        let timer = Timer(timeInterval: Self.watchdogInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkHealth() }
        }
        RunLoop.main.add(timer, forMode: .common)
        watchdog = timer
    }

    private func stopWatchdog() {
        watchdog?.invalidate()
        watchdog = nil
    }

    /// Runs every `watchdogInterval` while enabled.
    public func checkHealth() {
        guard isEnabled else { return }
        guard Accessibility.isTrusted else {
            teardown()
            state = .needsPermission
            return
        }
        guard let tap else {
            // Trust came back, or creation failed earlier: try again.
            install()
            return
        }
        if !CGEvent.tapIsEnabled(tap: tap) {
            rearm(.watchdog)
            if !CGEvent.tapIsEnabled(tap: tap) {
                teardown()
                install()
            }
        }
    }
}
