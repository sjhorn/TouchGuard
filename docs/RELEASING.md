# Releasing TouchGuard

There are two channels:

| Channel | Target | Signing | Updates | CLI |
|---------|--------|---------|---------|-----|
| Download (DMG) | `TouchGuard` | Developer ID, notarised | Sparkle 2 | included |
| Mac App Store | `TouchGuardMAS`, sandboxed (see [the sandbox spike](notes/sandbox-spike.md)) | App Store, automatic | the store | no |

Both use the bundle ID `com.hornmicro.TouchGuard` and team `ZUKW8RPUVQ`.

## One-time setup

### 1. App Store Connect API key
App Store Connect → Users and Access → Integrations → **App Store Connect API** → Team Keys → **+**.
- Name: `TouchGuard CI`. Access: **App Manager**. If automatic signing in CI can't create the Apple Distribution certificate, use **Admin** instead.
- Download `AuthKey_XXXXXXXXXX.p8`. You can only download it once.
- Note the **Key ID** and the **Issuer ID** shown above the table.

### 2. Notarisation profile (local releases)
```sh
xcrun notarytool store-credentials touchguard-notary \
  --key ~/path/AuthKey_XXXXXXXXXX.p8 --key-id XXXXXXXXXX --issuer <issuer-uuid>
```

### 3. Developer ID certificate as .p12 (CI)
Keychain Access → My Certificates → **Developer ID Application: Scott Horn (ZUKW8RPUVQ)** → right-click → Export → `devid.p12` with a strong password. Then:
```sh
base64 -i devid.p12 | pbcopy   # paste as the DEVELOPER_ID_P12 secret
```

### 4. Sparkle EdDSA keys
Build once (so Xcode fetches Sparkle), then:
```sh
build/dd/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys
```
This stores the private key in your login keychain and prints the **public** key. Put the public key in the project as `SPARKLE_PUBLIC_ED_KEY` (TouchGuard target, both configurations), then commit. To export the private key for CI:
```sh
build/dd/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys -x sparkle_private_key
cat sparkle_private_key | pbcopy && rm sparkle_private_key   # paste as SPARKLE_ED_PRIVATE_KEY
```
**Back up the private key** (e.g. in your password manager). If it's lost, existing installs can't verify any future update.

### 5. Repository secrets
GitHub → sjhorn/TouchGuard → Settings → Secrets and variables → Actions → New repository secret:

| Secret | Value |
|--------|-------|
| `DEVELOPER_ID_P12` | base64 of the .p12 (step 3) |
| `DEVELOPER_ID_P12_PASSWORD` | its password |
| `ASC_KEY_ID` | Key ID (step 1) |
| `ASC_ISSUER_ID` | Issuer ID (step 1) |
| `ASC_KEY_P8` | the full text of `AuthKey_….p8`, including the BEGIN/END lines |
| `SPARKLE_ED_PRIVATE_KEY` | the private key (step 4) |

### 6. GitHub settings
- Settings → General → Features: turn on **Issues**. It's the support channel.
- Settings → Pages: Source **Deploy from a branch**, branch `master`, folder `/docs`. Then check https://sjhorn.github.io/TouchGuard/ and `/appcast.xml`.
- Settings → Code security: turn on **Private vulnerability reporting** (used by SECURITY.md).
- Optional: ask GitHub Support to detach the fork from `thesyntaxinator/TouchGuard` so it shows up in search and gets its own network.

### 7. App Store Connect app record (store channel only)
My Apps → **+** → New App: platform macOS, name **TouchGuard** (if it's taken, see `docs/app-store/listing.md`), language English, bundle ID `com.hornmicro.TouchGuard`, SKU `touchguard`. Then:
- App Privacy → **Data Not Collected**. Privacy Policy URL: https://sjhorn.github.io/TouchGuard/privacy/
- Fill in the listing from `docs/app-store/listing.md`, the screenshots from `screenshots.md`, and the review notes and video from `review-notes.md` / `demo-video.md`.

## Making a release

1. `scripts/bump-version.sh 2.0.1`, then add a `## [2.0.1] - YYYY-MM-DD` section to `CHANGELOG.md`. It becomes the release notes and the Sparkle notes.
2. Commit to `master` by PR, then tag and push:
   ```sh
   git tag v2.0.1 && git push origin v2.0.1
   ```
3. The **Release** workflow archives the app, notarises it and the DMG, publishes the GitHub Release with the DMG, and commits the new `docs/appcast.xml` to `master`.
4. Store: Actions → **Release** → Run workflow → `appstore`. Then in App Store Connect, add the build to TestFlight and test it, and finally submit it for review.

### Locally
```sh
scripts/release.sh devid          # build/release/devid/TouchGuard-<version>.dmg, updates docs/appcast.xml
scripts/release.sh appstore       # uploads with your Xcode account
```
After a local `devid` release, upload the DMG to a GitHub Release tagged `v<version>` and commit `docs/appcast.xml`. Do it in that order, so the appcast never points to a missing file.

## Checking a release
```sh
spctl -a -vvv -t execute /Applications/TouchGuard.app   # source=Notarized Developer ID
xcrun stapler validate TouchGuard-<version>.dmg
codesign -d --entitlements - /Applications/TouchGuard.app   # no sandbox in the DMG build
```
Then, on a clean user account: download the DMG from the Release page, open it, and check that Gatekeeper shows no warning, onboarding grants permission, clicks are blocked after typing, and **Check for Updates…** says you're up to date.
