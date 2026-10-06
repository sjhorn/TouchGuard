import CoreGraphics
import Foundation

/// Owns the CGEventTap: creates it, feeds events through a `ClickFilter`,
/// re-enables it when macOS switches it off, and tracks the tap's permissions.
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
    private let backend: TapBackend
    private let permissions: PermissionChecking
    private var hasTap = false
    private var watchdog: Timer?

    public static let watchdogInterval: TimeInterval = 2

    static let eventMask: CGEventMask = {
        let types: [CGEventType] = [
            .keyUp,
            .leftMouseDown, .leftMouseUp,
            .rightMouseDown, .rightMouseUp,
            .otherMouseDown, .otherMouseUp,
        ]
        return types.reduce(0) { $0 | (1 << CGEventMask($1.rawValue)) }
    }()

    public convenience init(delay: TimeInterval,
                            clock: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.init(delay: delay, clock: clock, backend: CGEventTapBackend(), permissions: SystemPermissions())
    }

    init(delay: TimeInterval,
         clock: @escaping @Sendable () -> TimeInterval,
         backend: TapBackend,
         permissions: PermissionChecking) {
        self.filter = ClickFilter(delay: delay)
        self.clock = clock
        self.backend = backend
        self.permissions = permissions
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
        guard isEnabled, !hasTap else { return }
        guard permissions.isGranted else {
            state = .needsPermission
            return
        }
        let created = backend.create(mask: Self.eventMask) { [weak self] type in
            self?.handle(type: type) ?? true
        }
        guard created else {
            state = permissions.isGranted ? .failed : .needsPermission
            return
        }
        hasTap = true
        state = .running
    }

    private func teardown() {
        backend.invalidate()
        hasTap = false
    }

    private func rearm(_ reason: RearmReason) {
        guard hasTap else { return }
        backend.setEnabled(true)
        rearmCount += 1
        onRearm?(reason)
    }

    // MARK: - Event handling

    /// Returns true if the event should pass through.
    func handle(type: CGEventType) -> Bool {
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
        guard permissions.isGranted else {
            teardown()
            state = .needsPermission
            return
        }
        guard hasTap else {
            // Permission came back, or creation failed earlier: try again.
            install()
            return
        }
        if !backend.isEnabled {
            rearm(.watchdog)
            if !backend.isEnabled {
                teardown()
                install()
            }
        }
    }
}
