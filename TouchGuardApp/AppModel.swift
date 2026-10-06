import AppKit
import Observation
import ServiceManagement
import SwiftUI
import TouchGuardCore

/// What `AppModel` needs from the event tap; a seam for tests.
@MainActor
protocol TapControlling: AnyObject {
    var delay: TimeInterval { get set }
    var onStateChange: ((EventTapController.State) -> Void)? { get set }
    var onBlock: ((Int) -> Void)? { get set }
    func start()
    func stop()
    func resetCount()
    func checkHealth()
}

extension EventTapController: TapControlling {}

@Observable
@MainActor
final class AppModel {
    static let delayPresets = [100, 150, 200, 300, 500]
    static let delayRange = 50...1000
    static let defaultDelayMs = 200

    enum Key {
        static let delayMs = "delayMs"
        static let enabled = "enabled"
        static let hotKeyEnabled = "hotKeyEnabled"
    }

    private(set) var delayMs: Int
    private(set) var isEnabled: Bool
    private(set) var hotKeyEnabled: Bool
    private(set) var state: EventTapController.State = .paused
    private(set) var blockedClicks = 0
    private(set) var launchAtLogin = false
    private(set) var launchAtLoginError: String?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let controller: TapControlling
    @ObservationIgnored let updater = Updater()
    @ObservationIgnored private var hotKey: HotKey?
    @ObservationIgnored private var permissionWindow: NSWindow?
    @ObservationIgnored private var delayWindow: NSWindow?

    /// `makeController` gets the starting delay in seconds.
    init(defaults: UserDefaults = .standard,
         makeController: (TimeInterval) -> TapControlling = { EventTapController(delay: $0) }) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.delayMs: Self.defaultDelayMs,
            Key.enabled: true,
            Key.hotKeyEnabled: true,
        ])
        let delayMs = Self.clamp(defaults.integer(forKey: Key.delayMs))
        self.delayMs = delayMs
        isEnabled = defaults.bool(forKey: Key.enabled)
        hotKeyEnabled = defaults.bool(forKey: Key.hotKeyEnabled)
        controller = makeController(TimeInterval(delayMs) / 1000)

        controller.onStateChange = { [weak self] state in self?.stateChanged(to: state) }
        controller.onBlock = { [weak self] total in self?.blockedClicks = total }
    }

    /// Called once the app has finished launching.
    func start() {
        refreshLaunchAtLogin()
        updateHotKey()
        if isEnabled { controller.start() }
        if !Permissions.isGranted { showPermissionWindow() }
    }

    // MARK: - Status

    var statusText: String { statusText(for: state) }
    var menuBarSymbol: String { menuBarSymbol(for: state) }

    func statusText(for state: EventTapController.State) -> String {
        switch state {
        case .running: "Active, \(delayMs) ms"
        case .paused: "Paused"
        case .needsPermission:
            switch Permissions.mode {
            case .accessibility: "Needs Accessibility permission"
            case .inputMonitoringAndPostEvent: "Needs Input Monitoring permission"
            }
        case .failed: "Couldn't start the event tap"
        }
    }

    func menuBarSymbol(for state: EventTapController.State) -> String {
        switch state {
        case .running: "hand.raised"
        case .paused: "hand.raised.slash"
        case .needsPermission, .failed: "exclamationmark.triangle"
        }
    }

    func stateChanged(to newState: EventTapController.State) {
        state = newState
        switch newState {
        case .needsPermission: showPermissionWindow()
        case .running: closePermissionWindow()
        case .paused, .failed: break
        }
    }

    // MARK: - Settings

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: Key.enabled)
        if enabled { controller.start() } else { controller.stop() }
    }

    func toggleEnabled() {
        setEnabled(!isEnabled)
    }

    func setDelay(_ ms: Int) {
        delayMs = Self.clamp(ms)
        defaults.set(delayMs, forKey: Key.delayMs)
        controller.delay = TimeInterval(delayMs) / 1000
    }

    func resetBlockedClicks() {
        controller.resetCount()
        blockedClicks = 0
    }

    func setHotKeyEnabled(_ enabled: Bool) {
        hotKeyEnabled = enabled
        defaults.set(enabled, forKey: Key.hotKeyEnabled)
        updateHotKey()
    }

    private func updateHotKey() {
        if hotKeyEnabled, hotKey == nil {
            hotKey = HotKey { [weak self] in self?.toggleEnabled() }
        } else if !hotKeyEnabled {
            hotKey?.unregister()
            hotKey = nil
        }
    }

    func refreshLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLoginError = error.localizedDescription
        }
        if SMAppService.mainApp.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
        refreshLaunchAtLogin()
    }

    private static func clamp(_ ms: Int) -> Int {
        min(max(ms, delayRange.lowerBound), delayRange.upperBound)
    }

    // MARK: - Permission

    /// Called by the onboarding window as soon as it sees trust granted.
    func permissionGranted() {
        if isEnabled {
            controller.checkHealth()
        } else {
            closePermissionWindow()
        }
    }

    func showPermissionWindow() {
        permissionWindow = present(permissionWindow, title: "TouchGuard Permission") {
            PermissionView(model: self)
        }
    }

    func closePermissionWindow() {
        permissionWindow?.close()
    }

    // MARK: - Other windows

    func showCustomDelay() {
        delayWindow = present(delayWindow, title: "Custom Delay") {
            CustomDelayView(model: self)
        }
    }

    func showAbout() {
        let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        let credits = NSMutableAttributedString(
            string: "Holds back trackpad clicks for a moment after each key release, so a palm on the trackpad doesn't move the cursor while you type.\n\nBased on the original TouchGuard by SyntaxSoft (2016).\n\n",
            attributes: [.font: font, .foregroundColor: NSColor.labelColor])
        let links: [(String, URL)] = [
            ("GitHub", Links.repository),
            ("Support", Links.support),
            ("Privacy Policy", Links.privacy),
        ]
        for (index, (title, url)) in links.enumerated() {
            if index > 0 { credits.append(NSAttributedString(string: "  ·  ", attributes: [.font: font])) }
            credits.append(NSAttributedString(string: title, attributes: [.font: font, .link: url]))
        }
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        credits.addAttribute(.paragraphStyle, value: centered,
                             range: NSRange(location: 0, length: credits.length))

        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    /// Shows `existing` if there is one, otherwise a new window hosting `content`.
    private func present<Content: View>(_ existing: NSWindow?, title: String,
                                        @ViewBuilder content: () -> Content) -> NSWindow {
        let window = existing ?? {
            let window = NSWindow(contentViewController: NSHostingController(rootView: content()))
            window.title = title
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            return window
        }()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        return window
    }
}

enum Links {
    static let repository = URL(string: "https://github.com/sjhorn/TouchGuard")!
    static let support = URL(string: "https://sjhorn.github.io/TouchGuard/support")!
    static let privacy = URL(string: "https://sjhorn.github.io/TouchGuard/privacy")!
}
