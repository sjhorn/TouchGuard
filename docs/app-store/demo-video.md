# Demo video (for App Review)

**Automated:** with TouchGuard (the App Store build) running and active, and Screen Recording and Accessibility granted to the terminal, run:

```sh
scripts/assets/record-demo.sh      # build/demo/touchguard-demo.mov, about 58 s
```

The script does the following:
- hides other apps and records only the area around TextEdit and the TouchGuard menu;
- types narration into a new TextEdit document;
- taps straight after a key release (TouchGuard ignores it), then clicks again after a pause (it works);
- shows the blocked count in the menu, pauses and resumes with ⌃⌥⌘T, and shows that a tap goes through while paused.

The input is synthetic CGEvents, which TouchGuard filters exactly like a real trackpad. `-k` draws a ring at every click, so the ignored tap is visible.

Gotchas:
- macOS opens whichever copy of `com.hornmicro.TouchGuard` Launch Services finds. Make sure only the App Store build is registered and running.
- Upload it as an App Review attachment (App Store Connect → the version → App Review Information).

The manual script it's based on follows.

---

# Demo video script (for App Review, about 60 s, screen recording)

Record with ⌘⇧5 → "Record Entire Screen", 1440×900 HiDPI. No audio is needed; use on-screen captions.

1. **0:00** A clean desktop. Caption: "TouchGuard: blocks accidental trackpad taps while typing."
2. **0:05** Launch TouchGuard from Applications. The hand icon appears in the menu bar and the permission window opens.
3. **0:10** Click **Open Privacy Settings**. Turn on TouchGuard under **Input Monitoring**, then under **Accessibility**. Caption: "TouchGuard never reads what you type."
4. **0:25** The window closes by itself. Open the menu: "Active, 200 ms".
5. **0:30** In TextEdit, type a sentence. While typing, tap the trackpad elsewhere in the text: the cursor does **not** move. Caption: "Taps right after typing are ignored."
6. **0:40** Stop typing, wait a second, then click: the cursor moves normally. Caption: "Normal clicks work as usual."
7. **0:45** Open the menu: "Blocked clicks: 3".
8. **0:50** Press ⌃⌥⌘T: the icon changes to paused. Tap while typing: the cursor moves. Press ⌃⌥⌘T again to re-enable.
9. **0:58** End.

Upload it as an attachment in App Review Information. The App Preview video slot isn't needed.
