import CoreGraphics
import Foundation

/// Seam for tests: owns one event tap. `handler` gets each event type and
/// returns true to let the event through.
@MainActor
protocol TapBackend: AnyObject {
    /// Creates and enables a tap. Returns false if macOS refused.
    func create(mask: CGEventMask, handler: @escaping @MainActor (CGEventType) -> Bool) -> Bool
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool)
    /// Disables and releases the tap, if there is one.
    func invalidate()
}

/// The real tap: an active CGEventTap, delivered on the main run loop.
@MainActor
final class CGEventTapBackend: TapBackend {
    /// HID for the Developer ID build. The sandboxed build uses the session
    /// tap, which the sandbox spike confirmed can drop clicks there
    /// (docs/notes/sandbox-spike.md).
    static var defaultLocation: CGEventTapLocation {
        switch Permissions.mode {
        case .accessibility: .cghidEventTap
        case .inputMonitoringAndPostEvent: .cgSessionEventTap
        }
    }

    private let location: CGEventTapLocation
    private var port: CFMachPort?
    private var source: CFRunLoopSource?
    private var handler: (@MainActor (CGEventType) -> Bool)?

    init(location: CGEventTapLocation = CGEventTapBackend.defaultLocation) {
        self.location = location
    }

    func create(mask: CGEventMask, handler: @escaping @MainActor (CGEventType) -> Bool) -> Bool {
        invalidate()
        self.handler = handler
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let port = CGEvent.tapCreate(
            tap: location,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let backend = Unmanaged<CGEventTapBackend>.fromOpaque(refcon).takeUnretainedValue()
                let pass = MainActor.assumeIsolated { backend.handler?(type) ?? true }
                return pass ? Unmanaged.passUnretained(event) : nil
            },
            userInfo: refcon
        ) else {
            self.handler = nil
            return false
        }
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        self.port = port
        source = src
        return true
    }

    var isEnabled: Bool {
        guard let port else { return false }
        return CGEvent.tapIsEnabled(tap: port)
    }

    func setEnabled(_ enabled: Bool) {
        guard let port else { return }
        CGEvent.tapEnable(tap: port, enable: enabled)
    }

    func invalidate() {
        if let port {
            CGEvent.tapEnable(tap: port, enable: false)
            CFMachPortInvalidate(port)
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        port = nil
        source = nil
        handler = nil
    }
}
