# Contributing to TouchGuard

Thanks for helping! Bug reports, ideas, docs fixes and pull requests are all welcome. By taking part you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).

## Reporting bugs and asking for features

Use the [issue forms](https://github.com/sjhorn/TouchGuard/issues/new/choose). For bugs, the most useful details are the TouchGuard version (About TouchGuard), where you got it (DMG, App Store or source), your macOS version and the steps to reproduce. Security problems go through [SECURITY.md](SECURITY.md), not issues.

## Development setup

You need macOS 14 or later and Xcode 16 or later (the project is set up for Xcode 27).

```sh
git clone https://github.com/sjhorn/TouchGuard.git
cd TouchGuard
open TouchGuard.xcodeproj
```

**Signing:** the project signs with the maintainer's team. To run it on your Mac, choose your own team for the `TouchGuard` target in Signing & Capabilities, or build from the command line with `DEVELOPMENT_TEAM=<your team ID>`. Don't commit that change.

**Permissions while developing:** macOS ties the Accessibility grant to the code signature. If you switch signing identities, remove TouchGuard from System Settings → Privacy & Security → Accessibility and add it again. Quit any installed copy of TouchGuard while you test your build, so two taps don't run at once.

### Schemes

| Scheme | What it builds |
|--------|----------------|
| `TouchGuard` | the download (Developer ID) app, with Sparkle and the embedded CLI. Runs the tests. |
| `TouchGuardMAS` | the sandboxed App Store app (`APP_STORE` compilation condition) |
| `TouchGuardCLI` | the `touchguard` command-line tool |
| `TouchGuardCore` | the shared Swift package |

## Tests

```sh
cd TouchGuardCore && swift test           # ClickFilter + EventTapController state machine
xcodebuild -scheme TouchGuard test         # also AppModel tests (add CODE_SIGNING_ALLOWED=NO without a team)
```

CI runs both on every pull request and builds every scheme.

## Making a change

1. Branch off `master`.
2. Keep each pull request focused on one thing. Small PRs get reviewed faster.
3. Add or update tests:
   - pass/block decisions → `ClickFilterTests`
   - tap lifecycle (start, permission, rearm, watchdog) → `EventTapControllerTests` with the fakes
   - settings and status → `AppModelTests`
4. Add a line under `## [Unreleased]` in `CHANGELOG.md` for anything users will notice. If there's no Unreleased section, add one.
5. Update the README or the support FAQ (`docs/support.md`) if behaviour changes.
6. Open the PR and fill in the template.

### Code guidelines

- Match the surrounding code: Swift 6 language mode, strict concurrency, everything tap-related on the main actor.
- The decision logic stays pure in `ClickFilter`. CoreGraphics stays behind `TapBackend`, so everything else can be tested without a real tap.
- Keep the event callback fast. macOS disables taps whose callbacks are slow.
- New user-facing strings go through SwiftUI's `LocalizedStringKey` (or `String(localized:)`) so they reach `Localizable.xcstrings`.
- See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for how the pieces fit together.

### Things that won't be merged

- Reading key codes, characters or any other content of what the user types.
- Analytics, telemetry or any network access beyond Sparkle's update check.
- Features locked behind payment in the open-source code.

## Releases

Only the maintainer makes releases. The process is in [docs/RELEASING.md](docs/RELEASING.md).

## Licence

TouchGuard is MIT-licensed. By contributing, you agree that your contribution is licensed under the [MIT License](LICENSE).
