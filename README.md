# TouchGuard

Blocks trackpad clicks for a short moment after each key release, so a palm brushing the trackpad while you type doesn't count as a tap and send the cursor somewhere else.

TouchGuard comes as a **menu bar app** and a **command-line tool** (`touchguard`). Both use the same Swift core.

Originally written by SyntaxSoft in 2016 ([thesyntaxinator/TouchGuard](https://github.com/thesyntaxinator/TouchGuard)).

## Requirements

- macOS 14 or later
- Xcode 16 or later to build (the project is set up for Xcode 27)

## Menu bar app

Build and run the `TouchGuard` scheme in Xcode, or:

```sh
xcodebuild -scheme TouchGuard -configuration Release -derivedDataPath build/DD build
open build/DD/Build/Products/Release/TouchGuard.app
```

TouchGuard runs only in the menu bar and has no Dock icon. The menu bar icon shows its state:

| Icon | Meaning |
|------|---------|
| ✋ `hand.raised` | Active: clicks are held back after typing |
| `hand.raised.slash` | Paused |
| ⚠️ `exclamationmark.triangle` | Needs Accessibility permission, or the event tap couldn't start |

The menu has:

- the current status, e.g. "Active, 200 ms"
- **Enabled**, to turn blocking on or off (also **⌃⌥⌘T** from anywhere)
- **Delay** presets (100–500 ms) and **Custom…**, a slider from 50 to 1000 ms. Changes apply straight away.
- **Blocked clicks**, a count of the clicks held back, with **Reset Count**
- **Launch at Login**
- **Global Shortcut ⌃⌥⌘T**, to turn the hotkey on or off
- About, Quit

Settings are remembered between launches. The default delay is 200 ms.

### Permission

TouchGuard needs **Accessibility** permission (System Settings → Privacy & Security → Accessibility) so it can see key releases and hold back clicks. It never reads, records or sends what you type. On first launch a window explains this and has a button that opens the right Settings page. Once you turn TouchGuard on, the window closes by itself and blocking starts. If the permission is removed later, the window comes back.

No `sudo` or administrator rights are needed.

> **Building it yourself:** macOS ties the Accessibility grant to the app's code signature. The project signs with a fixed "Apple Development" identity (team set in `DEVELOPMENT_TEAM`), so the grant survives rebuilds. If you change the team or switch to ad-hoc signing, expect to grant permission again. If TouchGuard is listed as allowed but the window won't go away, remove it from the list with **−** and add it again.

### Reliability

macOS sometimes switches event taps off, for example when a callback is slow or around secure text input such as password fields. TouchGuard turns its tap back on at once when that happens. A watchdog also checks every 2 seconds, so blocking doesn't silently stop the way it could in older versions.

## Command-line tool

Build the `TouchGuardCLI` scheme. It produces a `touchguard` binary:

```sh
xcodebuild -scheme TouchGuardCLI -configuration Release -derivedDataPath build/DD build
build/DD/Build/Products/Release/touchguard -time 0.2
```

| Option | Meaning |
|--------|---------|
| `-time <sec>` | Block clicks for this many seconds after each key release (default `0.2`) |
| `-nodebug` | Print nothing |
| `-TapEnableMsg` | Print a message when clicks are allowed again |
| `-TapDisableMsg` | Print a message when a key release starts blocking |
| `-version` | Print the version |
| `-h` | Show help |

For the CLI, the Accessibility permission belongs to the app you run it from (Terminal, iTerm, …). If that app isn't allowed, `touchguard` names it, opens the system prompt, and exits with status 1. Allow it, restart the terminal app, and run `touchguard` again. Keep the terminal open while you want TouchGuard running. For something that keeps running and starts at login, use the menu bar app.

## Project layout

```
TouchGuard.xcodeproj    app target "TouchGuard" and CLI target "TouchGuardCLI"
TouchGuardCore/         Swift package shared by both targets
  ClickFilter           the pure pass/block decision logic
  EventTapController    CGEventTap lifecycle, re-enabling and watchdog
  Accessibility         permission check, prompt and Settings link
TouchGuardApp/          SwiftUI menu bar app
TouchGuardCLI/          command-line tool
```

To run the core tests:

```sh
cd TouchGuardCore && swift test
```

## Support

Open an issue on the original project [here](https://github.com/thesyntaxinator/TouchGuard/issues).
