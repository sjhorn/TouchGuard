import AppKit
import ApplicationServices
import CoreGraphics

/// Which TCC permissions an active event tap needs in this process.
public enum PermissionMode: Sendable, Equatable {
    /// Unsandboxed (Developer ID) build: full Accessibility.
    case accessibility
    /// Sandboxed (App Store) build: Input Monitoring plus post-event access.
    case inputMonitoringAndPostEvent
}

/// Helpers for the TCC permissions the event tap needs. The mode is picked
/// at runtime from the sandbox, so one code path serves both builds.
public enum Permissions {
    public static var isSandboxed: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }

    public static var mode: PermissionMode {
        isSandboxed ? .inputMonitoringAndPostEvent : .accessibility
    }

    public static var isGranted: Bool {
        switch mode {
        case .accessibility: AXIsProcessTrusted()
        case .inputMonitoringAndPostEvent: CGPreflightListenEventAccess() && CGPreflightPostEventAccess()
        }
    }

    /// Shows the system prompt(s) and adds this app to the relevant list(s)
    /// in System Settings. Returns the current grant state.
    @discardableResult
    public static func request() -> Bool {
        switch mode {
        case .accessibility:
            // The literal value of kAXTrustedCheckOptionPrompt; the global is not concurrency-safe in Swift 6.
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        case .inputMonitoringAndPostEvent:
            let listen = CGRequestListenEventAccess()
            let post = CGRequestPostEventAccess()
            return listen && post
        }
    }

    /// The System Settings pane to send the user to.
    public static var settingsURL: URL {
        switch mode {
        case .accessibility:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        case .inputMonitoringAndPostEvent:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        }
    }

    public static func openSettings() {
        NSWorkspace.shared.open(settingsURL)
    }
}

/// Seam for tests: whether the tap's permissions are currently granted.
@MainActor
protocol PermissionChecking {
    var isGranted: Bool { get }
}

struct SystemPermissions: PermissionChecking {
    var isGranted: Bool { Permissions.isGranted }
}
