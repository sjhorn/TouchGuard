# Changelog

All notable changes are listed here. Versions follow [Semantic Versioning](https://semver.org).

## [2.0.0] - Unreleased

A rewrite in Swift, with a menu bar app.

### Added
- Menu bar app with an on/off toggle, delay presets and a custom delay slider (50–1000 ms), a blocked-click counter, Launch at Login and a global shortcut (⌃⌥⌘T).
- First-launch onboarding that explains the permission and closes by itself once it's granted.
- Automatic updates with Sparkle in the download version.
- Developer ID signed and notarised DMG.
- Privacy manifest. TouchGuard collects no data.

### Changed
- Needs Accessibility permission instead of `sudo`.
- The event tap is turned back on at once when macOS disables it, and a watchdog checks it every 2 seconds. Blocking no longer stops silently.
- A drag that started before you typed always gets its mouse-up, so it can't get stuck.
- The command-line tool keeps the 1.x options (`-time`, `-nodebug`, `-TapEnableMsg`, `-TapDisableMsg`, `-version`) and is included in the app at `Contents/Helpers/touchguard`.
- Requires macOS 14 or later.

### Removed
- The C implementation. It's kept in history under the tag `legacy-final`.

## [1.4] - 2020

The last release of the original TouchGuard by SyntaxSoft: a command-line tool run with `sudo`.

[2.0.0]: https://github.com/sjhorn/TouchGuard/compare/1.4...v2.0.0
[1.4]: https://github.com/sjhorn/TouchGuard/releases/tag/1.4
