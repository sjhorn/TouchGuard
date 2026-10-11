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

/// One TCC permission the event tap needs.
public enum PermissionRequirement: Sendable, Equatable, CaseIterable {
    /// Full Accessibility (unsandboxed build).
    case accessibility
    /// Post-event access, listed under Accessibility (sandboxed build).
    case postEvents
    /// Input Monitoring (sandboxed build).
    case listenEvents

    public var isGranted: Bool {
        switch self {
        case .accessibility: AXIsProcessTrusted()
        case .postEvents: CGPreflightPostEventAccess()
        case .listenEvents: CGPreflightListenEventAccess()
        }
    }

    /// Asks macOS for this permission. The first time, macOS shows its own
    /// prompt (with an Open System Settings button) and lists the app in
    /// System Settings; after that it does nothing visible.
    public func request() {
        switch self {
        case .accessibility:
            // The literal value of kAXTrustedCheckOptionPrompt; the global is not concurrency-safe in Swift 6.
            _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        case .postEvents:
            _ = CGRequestPostEventAccess()
        case .listenEvents:
            _ = CGRequestListenEventAccess()
        }
    }

    /// The System Settings pane where this permission is switched on.
    public var settingsURL: URL {
        switch self {
        case .accessibility, .postEvents:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        case .listenEvents:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        }
    }
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

    /// What `mode` needs, in the order to ask for it. Post-event access comes
    /// first in the sandbox: granting it often covers listening too, so most
    /// people only see one prompt.
    public static func requirements(for mode: PermissionMode) -> [PermissionRequirement] {
        switch mode {
        case .accessibility: [.accessibility]
        case .inputMonitoringAndPostEvent: [.postEvents, .listenEvents]
        }
    }

    public static var requirements: [PermissionRequirement] { requirements(for: mode) }

    public static var isGranted: Bool {
        requirements.allSatisfy(\.isGranted)
    }

    /// The first permission still missing, if any.
    public static var nextMissing: PermissionRequirement? {
        requirements.first { !$0.isGranted }
    }

    /// Asks for the next missing permission (shows macOS's prompt the first
    /// time). Returns the current grant state.
    @discardableResult
    public static func request() -> Bool {
        nextMissing?.request()
        return isGranted
    }

    /// The System Settings pane for the next missing permission.
    public static var settingsURL: URL {
        (nextMissing ?? requirements[0]).settingsURL
    }

    public static func openSettings() {
        NSWorkspace.shared.open(settingsURL)
    }

    /// One step of onboarding: asks macOS for the next missing permission and,
    /// if macOS doesn't show its own prompt (it only does the first time),
    /// opens the right System Settings pane instead. Never both, so the
    /// prompt isn't left behind a Settings window.
    @MainActor
    public static func continueSetup() async {
        guard let next = nextMissing else { return }
        next.request()
        try? await Task.sleep(for: .milliseconds(800))
        if !isSystemPromptVisible {
            NSWorkspace.shared.open(next.settingsURL)
        }
    }

    /// Whether macOS's permission prompt ("… would like to control this
    /// computer / receive keystrokes") is on screen. It is drawn by the
    /// universalAccessAuthWarn agent; window owner names need no permission.
    static var isSystemPromptVisible: Bool {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        return windows.contains { ($0[kCGWindowOwnerName as String] as? String) == "universalAccessAuthWarn" }
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
