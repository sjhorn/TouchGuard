import AppKit
import ApplicationServices
import CoreGraphics

/// SPIKE: permission helpers for a sandboxed build, using Input Monitoring
/// (listen) and post-event access instead of full Accessibility.
public enum Accessibility {
    public static var isSandboxed: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }

    public static var canListen: Bool { CGPreflightListenEventAccess() }
    public static var canPost: Bool { CGPreflightPostEventAccess() }

    public static var isTrusted: Bool {
        canListen && canPost
    }

    @discardableResult
    public static func requestPrompt() -> Bool {
        let listen = CGRequestListenEventAccess()
        let post = CGRequestPostEventAccess()
        return listen && post
    }

    public static let settingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!

    public static func openSettings() {
        NSWorkspace.shared.open(settingsURL)
    }
}
