---
title: Privacy Policy
permalink: /privacy/
---

# TouchGuard Privacy Policy

*Last updated: 6 October 2026*

TouchGuard is made by Scott Horn ("I"). This policy covers the TouchGuard app for macOS, both the version downloaded from GitHub and the Mac App Store version, and its command-line tool.

## Data I collect

**None.** TouchGuard has no analytics, no crash reporting, no advertising, no accounts and no tracking. Nothing you do in TouchGuard is sent to me or to anyone else.

## What TouchGuard does on your Mac

- To hold back clicks after typing, TouchGuard watches for key releases and mouse-button events through macOS's event tap API. That's why it asks for Accessibility (or Input Monitoring) permission.
- For key events it uses only the fact *that* a key was released, and the time. It never reads which key, never reads characters, and never records or stores keystrokes.
- It stores your settings (delay, on/off, shortcut) in its own preferences on your Mac. The blocked-click count is kept in memory only.

## Network

- **Mac App Store version:** makes no network requests.
- **Download version:** checks for updates with [Sparkle](https://sparkle-project.org). It fetches `https://sjhorn.github.io/TouchGuard/appcast.xml` from GitHub Pages (by default at most once a day) and downloads updates from GitHub Releases. Sparkle doesn't send system profile information, because TouchGuard doesn't turn that option on. GitHub, as the host, may log requests, as any web server does. See [GitHub's privacy statement](https://docs.github.com/site-policy/privacy-policies/github-general-privacy-statement).

## Children

TouchGuard collects no data from anyone, including children.

## Changes

If this policy changes, the new version will be posted here with a new date. The history is public in the [repository](https://github.com/sjhorn/TouchGuard/commits/master/docs/privacy.md).

## Contact

Questions about privacy: [open an issue](https://github.com/sjhorn/TouchGuard/issues/new) on GitHub.
