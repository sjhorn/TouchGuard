# Screenshots

**How they're made:** 2× captures of the **App Store build** (no "Check for Updates…") are kept in `docs/app-store/captures/`. Then:

```sh
swift scripts/assets/make-appstore-screenshots.swift     # build/appstore-screenshots/*.jpg, 2880×1800, no alpha
ASC_KEY_PATH=… ASC_KEY_ID=… ASC_ISSUER_ID=… scripts/appstore-upload-screenshots.sh <appStoreVersion id>
```

The upload replaces the version's Mac screenshots.

To retake the captures, switch the display to a Retina "Looks like" mode. Run the App Store build (`TouchGuardMAS`), open the window or menu, and capture just that window with `screencapture -o -l <window id>`.

---

# Screenshot checklist

Mac screenshots must be 16:10 at one of 1280×800, 1440×900, 2560×1600 or 2880×1800 (PNG or JPEG, no alpha). Use **2880×1800**. 1–10 screenshots.

Take them on a clean desktop with a neutral wallpaper, light mode, and a few in dark mode. Add a one-line caption in large type above each one, matching the listing's tone.

1. **"Stop accidental trackpad taps"**: the menu open from the menu bar icon, showing "Active, 200 ms", Enabled, Delay, and Blocked clicks: 12.
2. **"Your cursor stays put while you type"**: TextEdit mid-sentence, with a palm-on-trackpad overlay illustration and the cursor unchanged.
3. **"Tune the delay"**: the Custom Delay window with the slider.
4. **"Private by design"**: the onboarding window ("never reads, records or sends what you type").
5. **"On or off in a keystroke"**: the menu with the ⌃⌥⌘T shortcut highlighted.
6. (Optional) the same as 1, in dark mode.

Make a screenshot by setting the display to 1440×900 (HiDPI) and using ⌘⇧4, then Space, to click the window. Or capture the full screen with ⌘⇧3 and crop to 2880×1800.

Also needed: the **App icon** (from the asset catalog, 1024×1024 is generated automatically).
