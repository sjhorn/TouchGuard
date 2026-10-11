# Changelog

All notable changes are listed here. Versions follow [Semantic Versioning](https://semver.org).

## [Unreleased]

### Fixed
- On first launch, the permission window could open behind the app TouchGuard was launched from (for example Finder), so it was easy to miss. It now always opens in front.
- Clicking the permission window's button opened System Settings and macOS's own permission prompt at the same time, leaving the prompt stranded behind Settings. The button is now **Continue**: it asks for one permission at a time and opens System Settings only if macOS doesn't show its prompt.
- In the Mac App Store version, switching on a permission in System Settings wasn't noticed until TouchGuard was restarted, so the permission window waited forever. TouchGuard now notices straight away and restarts itself once to apply it.

### Changed
- The permission window shows a checklist of the permissions TouchGuard needs and asks for the next one by itself.

## [2.0.0] - 2026-10-06

A rewrite in Swift, with a menu bar app.

### Added
- Menu bar app with an on/off toggle, delay presets and a custom delay slider (50–1000 ms), a blocked-click counter, Launch at Login and a global shortcut (⌃⌥⌘T).
- First-launch onboarding that explains the permission and closes by itself once it's granted.
- Automatic updates with Sparkle in the download version.
- Developer ID signed and notarised DMG, and a sandboxed Mac App Store version.
- Shows when another app's secure input (a password field, a password manager or a terminal's Secure Keyboard Entry) stops TouchGuard from seeing typing, with a link to the fix.
- Diagnostic logging (`log stream --predicate 'subsystem == "com.hornmicro.TouchGuard"'`). It records event types only, never which keys.
- Privacy manifest. TouchGuard collects no data.

### Changed
- Needs Accessibility permission instead of `sudo`.
- The event tap is turned back on at once when macOS disables it, and a watchdog checks it every 2 seconds. Blocking no longer stops silently. If the permission is removed while it's running, the tap is removed instead of stalling input.
- A drag that started before you typed always gets its mouse-up, so it can't get stuck.
- The command-line tool keeps the 1.x options (`-time`, `-nodebug`, `-TapEnableMsg`, `-TapDisableMsg`, `-version`) and is included in the app at `Contents/Helpers/touchguard`.
- Requires macOS 14 or later.

### Removed
- The C implementation. It's kept in history under the tag `legacy-final`.

## [1.4] - 2020

The last release of the original TouchGuard by SyntaxSoft: a command-line tool run with `sudo`.

[2.0.0]: https://github.com/sjhorn/TouchGuard/compare/1.4...v2.0.0
[1.4]: https://github.com/sjhorn/TouchGuard/releases/tag/1.4
