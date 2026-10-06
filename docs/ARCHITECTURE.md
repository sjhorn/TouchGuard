# Architecture

TouchGuard is small: one event tap, one pure decision function, and a menu bar UI around them.

## Event flow

```
 keyboard / trackpad
        │
        ▼
 ┌──────────────────────┐   macOS calls the tap for keyUp and mouse-button events
 │ CGEventTapBackend    │   (HID tap for Developer ID, session tap when sandboxed)
 └──────────┬───────────┘
            │ CGEventType
            ▼
 ┌──────────────────────┐   tapDisabledBy… → rearm
 │ EventTapController   │   keyUp          → filter.keyReleased(now)
 │  (main actor)        │   mouse down/up  → filter.decide(event, now)
 └──────────┬───────────┘
            ▼
 ┌──────────────────────┐   blocks a mouse-down while now < lastKeyUp + delay;
 │ ClickFilter (pure)   │   always passes the up of a down it passed
 └──────────────────────┘
            │ pass / block
            ▼
   event continues, or is dropped (callback returns nil)
```

Only the event **type** is used. Key codes and characters are never read.

## Packages and targets

| Piece | Role |
|-------|------|
| `TouchGuardCore/ClickFilter.swift` | Pure pass/block logic and the blocked-click count. No system calls. |
| `TouchGuardCore/EventTapController.swift` | Tap lifecycle: start/stop, permission state, rearming, a 2-second watchdog, callbacks (`onStateChange`, `onBlock`, `onRearm`, `onKeyRelease`). |
| `TouchGuardCore/TapBackend.swift` | `TapBackend` protocol and `CGEventTapBackend`, the only code that touches `CGEvent.tapCreate`. |
| `TouchGuardCore/Permissions.swift` | `PermissionMode` and its check, request and Settings URL. `PermissionChecking` is the seam for tests. |
| `TouchGuardApp/` | SwiftUI `MenuBarExtra`, `AppModel` (settings in `UserDefaults`, state for the UI), onboarding, Carbon hotkey, Sparkle `Updater`. Shared by both app targets. |
| `TouchGuardCLI/` | `touchguard`, a thin wrapper over `EventTapController` that keeps the 1.x options. |

## Controller states

```
            start()                   permission granted
 paused ───────────► needsPermission ───────────────────► running
   ▲                       ▲                                 │
   │ stop()                │ permission revoked (watchdog)   │
   └───────────────────────┴─────────────────────────────────┘
                     tapCreate failed → failed → retried by the watchdog
```

macOS turns taps off when a callback is too slow (`tapDisabledByTimeout`) or around secure input (`tapDisabledByUserInput`). The controller turns the tap back on at once. Every 2 seconds the watchdog checks permission and the tap. If the tap is off and won't turn back on, the watchdog recreates it.

## Two builds, one code path

| | `TouchGuard` (Developer ID) | `TouchGuardMAS` (App Store) |
|--|--|--|
| Sandbox | no | yes |
| Permission mode | `.accessibility` | `.inputMonitoringAndPostEvent` |
| Tap location | HID | session |
| Updates | Sparkle 2 | App Store |
| CLI | `Contents/Helpers/touchguard` | — |
| Compile condition | — | `APP_STORE` |

The mode is detected at runtime (`APP_SANDBOX_CONTAINER_ID`), so the same core runs in both builds. See [notes/sandbox-spike.md](notes/sandbox-spike.md) for why the sandboxed build can still drop clicks.

## Testing seams

`EventTapController` has an internal initialiser that takes a `TapBackend`, a `PermissionChecking` and a clock. The tests use fakes for all three to drive every state change without a real tap. `AppModel` takes a `UserDefaults` and a factory for a `TapControlling` controller.
