# Reply to App Review: Guidelines 2.4.5 and 1.5 (2.0.0, October 2026)

Review of 13 October 2026, submission 3694cfcf-9c41-4d04-88e6-5af655c69273.

Before replying:
1. Check that the support page shows the email address: <https://touchguard.hornmicro.com/support/>, and that mail to touchguard@hornmicro.com arrives.
2. Change the URLs in App Store Connect to the new domain: **Support URL** and **Marketing URL** (on the version page) and **Privacy Policy URL** (App Privacy). The values are in [listing.md](listing.md).
3. Replace the **Description** in App Store Connect with the one in [listing.md](listing.md). The text can be edited because the version was rejected.
4. Paste the block below into the reply in App Store Connect, then resubmit the same build (53).

```
Hello, and thank you for the review.

GUIDELINE 1.5 - SUPPORT URL
The support page at https://touchguard.hornmicro.com/support/ now opens with a Contact section that gives a support email address (touchguard@hornmicro.com) as well as GitHub Issues, followed by answers to common questions. Before, it only offered GitHub Issues, which needs a GitHub account; I'm sorry about that.

GUIDELINE 2.4.5 - ACCESSIBILITY
I believe TouchGuard uses Accessibility for an accessibility purpose, and I'd be grateful if you'd reconsider with the following in mind.

What TouchGuard does: it ignores trackpad clicks and taps for a short, adjustable moment (200 ms by default) after a key is released. This prevents unintended touches from moving the text cursor while the user is typing. That is its only function.

Who it is for: people who can't reliably keep their hands off the trackpad while typing. This includes people with tremor (for example essential tremor or Parkinson's disease), limited fine motor control, arthritis, or other conditions that make hand position hard to control. For them, every unintended touch moves the cursor and sends their typing to the wrong place, and correcting it is slow and tiring. TouchGuard removes that barrier to typing on a Mac laptop.

It is an input accommodation in the same family as macOS's own accessibility features:
- Keyboard > Bounce Keys ignores unintended repeated key presses within a set delay. TouchGuard does the same for unintended trackpad touches after typing.
- Pointer Control > "Ignore built-in trackpad when mouse or wireless trackpad is present" stops unintended trackpad input, but only when another pointing device is attached and only by turning the trackpad off entirely. TouchGuard lets people keep using the trackpad.

Why Accessibility is the only option: to stop an unintended click, TouchGuard must hold it back before it reaches other apps. macOS allows that only through an active event tap, and an active event tap requires the Accessibility (post-event) permission. Input Monitoring alone allows only a listen-only tap, which can see a click but cannot stop it. There is no other API for this.

How narrowly it uses the permission:
- It does not use the AXUIElement API, and it never reads or controls any other app's interface.
- It reads only the event type (a key was released, a button was pressed). It never reads which key was pressed or what was typed, and it stores and sends nothing. The App Store build makes no network connections.
- The full source is public: https://github.com/sjhorn/TouchGuard

I've updated the description to say plainly who TouchGuard is for. If you still find that this use isn't permitted, I'd appreciate knowing which part falls outside accessibility purposes, and I will file an enhancement request in Feedback Assistant for a permission that lets apps filter pointer input without full Accessibility.

Thank you,
Scott Horn
```

## Feedback Assistant request

File this whatever the outcome (Feedback Assistant → macOS → New Feedback → "Suggestion"), and add the FB number to the reply if Apple asks for it.

**Title:** Allow a sandboxed app to filter (drop) pointer events without the Accessibility permission

```
An active CGEventTap that drops pointer events requires the Accessibility (post-event) permission. Input Monitoring only allows a listen-only tap.

Apps that suppress unintended input, such as palm rejection for people with tremor or limited motor control, only need to drop mouse-button events shortly after a key-up. They don't need to synthesise events or use AXUIElement. Because the only permission available is Accessibility, App Review rejects these apps under guideline 2.4.5.

Request: a narrower permission (for example "Input Filtering") that lets an app drop or delay pointer events it receives through an event tap, without posting events or controlling other apps. Or an API in the input stack, similar to Bounce Keys, for a timed pointer-suppression window after typing.

Example app: TouchGuard, https://github.com/sjhorn/TouchGuard (App Store submission 3694cfcf-9c41-4d04-88e6-5af655c69273).
```
