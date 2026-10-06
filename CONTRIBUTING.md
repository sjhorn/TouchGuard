# Contributing

Thanks for helping! Issues and pull requests are welcome.

- **Bugs:** include your macOS version, TouchGuard version (About TouchGuard), whether it's the download or App Store version, and the steps to reproduce.
- **Pull requests:** branch off `master`, keep each change focused, and make sure `cd TouchGuardCore && swift test` and `xcodebuild -scheme TouchGuard test` pass. CI runs both.
- **Style:** match the surrounding code. The decision logic stays in `ClickFilter`, which is pure and tested, and the CGEventTap details stay behind `TapBackend`.
- **Privacy:** TouchGuard must never read key codes or characters, or send data anywhere. PRs that change that won't be merged.

By contributing you agree that your contribution is licensed under the MIT licence.
