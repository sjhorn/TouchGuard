# Security

TouchGuard runs with Accessibility (or Input Monitoring) permission, so security reports matter.

## Reporting a vulnerability

Please **don't** open a public issue. Use GitHub's private reporting instead: [Report a vulnerability](https://github.com/sjhorn/TouchGuard/security/advisories/new). You should get a reply within a week.

## Supported versions

Only the latest 2.x release gets fixes.

## What TouchGuard does with its permission

- It installs one event tap for key-up and mouse-button events.
- For key events it uses only the event type: it never reads the key code or characters.
- It decides whether a click passes, keeps a count of blocked clicks in memory, and stores nothing else.
- Its only network request is the Sparkle update check in the download version, over HTTPS, with updates verified by an EdDSA signature and Apple's notarisation.
