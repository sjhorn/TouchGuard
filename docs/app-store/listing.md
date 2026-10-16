# App Store listing (Mac)

Character limits are App Store Connect's. Counts are given in brackets.

## Name (≤30)
**TouchGuard** (10)

If "TouchGuard" is taken: **TouchGuard – Palm Rejection** (27).

## Subtitle (≤30)
**Stop accidental trackpad taps** (29)

## Promotional text (≤170, can change without a review)
Tremor or unsteady hands? TouchGuard ignores trackpad taps for a moment after each key press, so an unintended touch can't move your cursor. Free and private. (158)

## Description (≤4000)

```
TouchGuard is an accessibility aid for people who touch the trackpad by accident while typing, for example because of tremor, limited fine motor control or arthritis. Each unintended tap moves the text cursor and sends your typing to the wrong place. TouchGuard ignores trackpad clicks for a short moment after each key press, so your cursor stays where you're writing.

It works like macOS's Bounce Keys, which ignores unintended repeated key presses, but for the trackpad. Deliberate clicks work normally, the pointer still moves, and you keep using your trackpad.

It lives in your menu bar, uses almost no resources, and never reads what you type.

Features:
• Ignores clicks for a short moment after each key release (50–1000 ms, default 200 ms)
• Pick a preset delay or fine-tune it with a slider; changes apply instantly
• Turn it on or off from the menu bar or with ⌃⌥⌘T from anywhere
• See how many unintended clicks it has caught
• Launch at Login
• Recovers by itself if macOS pauses it, so protection never silently stops

Private by design:
• TouchGuard only checks that a key was released, never which key or what you typed
• No analytics, no accounts, no network access
• Free and open source (MIT): github.com/sjhorn/TouchGuard

Why the Accessibility permission?
To stop an unintended click before it reaches other apps, macOS requires you to allow TouchGuard under Accessibility (and, on some Macs, Input Monitoring). A short guide on first launch takes you straight to the right setting.

Support: touchguard@hornmicro.com

Based on the original TouchGuard by SyntaxSoft (2016).
```

## Keywords (≤100, comma-separated, no spaces needed)
`accessibility,tremor,palm,rejection,trackpad,touchpad,typing,cursor,tap,click,accidental,motor` (94)

## Category
- Primary: **Utilities**
- Secondary: **Productivity**

## Other fields
- **Price:** Free. No in-app purchases in 2.0.0 (see "Monetisation" below).
- **Age rating:** 4+ (no objectionable content).
- **Copyright:** © 2026 Scott Horn
- **Support URL:** https://blog.hornmicro.com/TouchGuard/support/
- **Marketing URL:** https://blog.hornmicro.com/TouchGuard/
- **Privacy Policy URL:** https://blog.hornmicro.com/TouchGuard/privacy/
- **App Privacy label:** Data Not Collected
- **Encryption:** none (`ITSAppUsesNonExemptEncryption = NO`)

## What's New template
Short and specific, one line per change:

```
• <user-visible change>
• Fixes <problem in user's words>
```

For bug-fix-only releases: "Reliability improvements: <one concrete example>." Avoid a bare "Bug fixes".

## Monetisation (later, optional)
TouchGuard is MIT-licensed, so gating features in code doesn't work: anyone can build the unlocked version. If income is wanted later, use one of these:
- **Tip jar:** consumable IAPs ("Small/Medium/Large Tip") that unlock nothing, or
- **A small App Store price** for convenience and automatic updates, with the GitHub download staying free.

Keep any StoreKit code behind `#if APP_STORE` so the open-source/DMG build doesn't contain it.
