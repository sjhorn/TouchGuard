# Reply to App Review: Guideline 2.1, Information Needed (2.0.0, October 2026)

Paste the block below into the reply in App Store Connect and attach `touchguard-review.mov`. The same text is also in the **Notes** field of App Review Information.

```
Hello, and thank you for reviewing TouchGuard. Here is the information you asked for.

1. SCREEN RECORDING
Attached: touchguard-review.mov, recorded on a MacBook Pro (16-inch) running macOS 27.0.1, using version 2.0.0 (build 53), the build attached to this submission. It starts with launching TouchGuard from Finder. It shows the first-launch permission window, clicking Continue, macOS's permission prompt, and turning on TouchGuard in System Settings > Privacy & Security > Device Control and Data Access (called Accessibility before macOS 27), after which TouchGuard becomes active by itself. It then shows the typical use: typing in TextEdit, a trackpad tap right after typing being ignored (the cursor does not move), a normal click working after a pause, the blocked-click count in the menu, and pausing and resuming with Control-Option-Command-T.
TouchGuard has no accounts, no login, no user-generated content and no paid content or in-app purchases.

2. PURPOSE AND AUDIENCE
TouchGuard is a small utility for Mac laptop users. While you type, the palm of your hand often brushes the trackpad, and macOS treats this as a tap: the text cursor jumps somewhere else and what you are typing lands in the wrong place. TouchGuard ignores trackpad clicks for a short, adjustable moment (200 ms by default) after each key is released, so accidental palm taps no longer move the cursor, while deliberate clicks work normally. The audience is anyone who types on a MacBook, especially people with larger hands or those who rest their palms on the laptop. It is free, has no ads, and its source code is public (MIT licence) at https://github.com/sjhorn/TouchGuard.

3. SETUP AND MAIN FEATURES
No account, login, credentials or sample files are needed.
- Open TouchGuard. It runs in the menu bar (a hand icon) and has no Dock icon.
- A window explains why it needs permission, with a checklist. Click "Continue"; in the macOS prompt, click "Open System Settings" and turn on TouchGuard under Device Control and Data Access (Accessibility before macOS 27). If macOS also requires Input Monitoring, TouchGuard asks for it next in the same way. The window closes by itself and the menu bar shows "Active, 200 ms".
- Type in any app (for example TextEdit), and tap the trackpad within a fraction of a second of releasing a key: the tap is ignored and the menu's "Blocked clicks" count goes up. A click after a short pause works normally.
- Menu: Enabled on/off (also Control-Option-Command-T from anywhere), Delay presets 100-500 ms and Custom (50-1000 ms), Blocked clicks with Reset Count, Launch at Login, and the global shortcut on/off.
Why the permissions: Accessibility (post-event access) lets TouchGuard's event tap hold back the accidental click; on Macs where macOS requires it separately, Input Monitoring lets TouchGuard notice that a key was released. TouchGuard uses only the event type: it never reads which key was pressed or what is typed, and never stores or sends any input.

4. EXTERNAL SERVICES
None. The App Store version makes no network connections and uses no third-party services, SDKs, analytics, authentication, payment or AI services. All processing happens locally on the Mac. Privacy label: Data Not Collected.

5. REGIONAL DIFFERENCES
None. TouchGuard works the same way in every region and has no region-specific features or content.

6. REGULATED INDUSTRY OR PROTECTED MATERIAL
Not applicable. TouchGuard is not in a regulated industry and contains no third-party protected material. It is an original Swift implementation by the developer, inspired by the open-source TouchGuard command-line tool by SyntaxSoft (2016), and credited in the app's About panel.

Thank you,
Scott Horn
```
