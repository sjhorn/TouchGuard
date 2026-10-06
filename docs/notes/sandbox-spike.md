# Sandbox spike: can an active event tap drop clicks in the App Sandbox?

*6 October 2026, macOS 26 (Darwin 25.6), branch `spike/sandbox` (commit e48c900)*

## Question
Mac App Store apps must be sandboxed, and sandboxed apps can't use full Accessibility (`AXIsProcessTrusted`). Apple documents that `CGEventTap` works in the sandbox with Input Monitoring (`CGRequestListenEventAccess`) and post-event access (`CGRequestPostEventAccess`). It doesn't say whether an **active** tap (`.defaultTap`) can **drop** mouse events there, which is what TouchGuard needs.

## Setup
- The app was built with `com.apple.security.app-sandbox = true` and the separate bundle ID `com.hornmicro.TouchGuard.spike`, so its TCC entries don't touch the real app.
- Permission check: `CGPreflightListenEventAccess() && CGPreflightPostEventAccess()`. The request calls both `CGRequest…` functions.
- `CGEvent.tapCreate(.defaultTap, .headInsertEventTap)` for key-up and mouse-button events. A menu toggle switched between `.cghidEventTap` and `.cgSessionEventTap`.
- Diagnostics in the menu: sandbox, listen and post status, key-ups seen, rearm count, tap creation errors.

## Result: works
After granting Input Monitoring and Accessibility (post events), the diagnostics read `sandboxed=true listen=true post=true`. With the **session** tap:
- Key-ups reach the tap (the counter went up).
- Taps right after a key release are **dropped**, and the blocked-click count goes up.
- After typing into a password field (secure input, in Chrome) and returning to TextEdit, blocking still worked. No rearm was counted: secure input kept key events from the tap but didn't disable it.

It's unclear whether the **HID** tap worked on its own. Key-ups weren't watched before switching to the session tap, and the unified log didn't keep the spike's messages.

## Decision
- Ship both channels. `TouchGuardMAS` is sandboxed and uses the `.inputMonitoringAndPostEvent` permission mode.
- The sandboxed build uses the **session** tap, the location confirmed here (`CGEventTapBackend.defaultLocation`). The Developer ID build keeps the HID tap.
- App Review may still question the permission use. `docs/app-store/review-notes.md` explains it, and the Developer ID DMG is the guaranteed channel.

## Follow-ups
- Re-test on the TestFlight build. Production signing and a fresh TCC state may behave differently from a development build.
- Optionally confirm the HID tap under the sandbox. If it works, it would catch events slightly earlier, but the session tap is good enough for this purpose.
