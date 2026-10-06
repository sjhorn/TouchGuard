# App Review notes (paste into "Notes" in App Store Connect)

```
TouchGuard is a small accessibility aid for laptop users: it prevents accidental trackpad taps (for example from a palm resting near the trackpad) from moving the text cursor while the user is typing.

HOW IT WORKS
TouchGuard installs a CGEventTap for key-up and mouse-button events. When a key is released, mouse-button-down events in the next 200 ms (user-configurable, 50–1000 ms) are dropped. That is the app's only function.

WHY INPUT MONITORING AND ACCESSIBILITY (POST EVENTS) ARE NEEDED
• Input Monitoring (CGRequestListenEventAccess): needed to receive key-up events, which mark the start of the short block window.
• Post-event access (CGRequestPostEventAccess): needed for the tap to be an active (filtering) tap that can drop the accidental click.
TouchGuard does not use the AXUIElement API and does not read or control other apps' UI.

PRIVACY
• Only the event TYPE is used. Key codes and characters are never read, stored or sent.
• The app makes no network requests and collects no data (privacy label: Data Not Collected).
• Source code is public: https://github.com/sjhorn/TouchGuard (see TouchGuardCore/Sources/TouchGuardCore/EventTapController.swift and TapBackend.swift).

HOW TO TEST
1. Launch TouchGuard. It appears in the menu bar (hand icon) with no Dock icon.
2. A window explains the permission. Click "Open Privacy Settings" and turn on TouchGuard under Input Monitoring and Accessibility. The window closes by itself and the icon shows "Active, 200 ms".
3. In TextEdit, type a sentence and click elsewhere in the text within a fraction of a second of releasing a key: the click is ignored and the menu's "Blocked clicks" count goes up. Clicking after a short pause works normally.
4. Menu → Enabled (or ⌃⌥⌘T) turns blocking off and on.

A demo video is attached showing these steps.

No account or login is needed.
```
