import AppKit
import ApplicationServices

/// Helpers for the Accessibility (TCC) permission an active event tap needs.
public enum Accessibility {
    public static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system prompt (once per process) and adds this app to the
    /// Accessibility list. Returns the current trust state.
    @discardableResult
    public static func requestPrompt() -> Bool {
        // The literal value of kAXTrustedCheckOptionPrompt; the global is not concurrency-safe in Swift 6.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    public static let settingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    public static func openSettings() {
        NSWorkspace.shared.open(settingsURL)
    }
}
