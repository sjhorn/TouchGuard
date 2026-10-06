#!/usr/bin/env bash
# Builds a release of TouchGuard. Works locally and in GitHub Actions.
#
#   scripts/release.sh devid [version]     notarised DMG + Sparkle appcast entry
#   scripts/release.sh appstore [version]  archive TouchGuardMAS and upload it to App Store Connect
#
# [version] defaults to MARKETING_VERSION in the project. The build number is
# the commit count, so every release from a later commit sorts higher.
#
# Authentication (notarytool, App Store upload):
#   - If ASC_KEY_PATH, ASC_KEY_ID and ASC_ISSUER_ID are set, the App Store
#     Connect API key is used (CI).
#   - Otherwise notarytool uses the keychain profile $NOTARY_PROFILE
#     (default touchguard-notary), and the App Store upload uses the Xcode account.
#
# Sparkle signing: SPARKLE_ED_KEY_FILE (a file holding the private EdDSA key)
# if set, otherwise sign_update reads the key from the login keychain.
set -euo pipefail

mode=${1:-}
[[ $mode == devid || $mode == appstore ]] || { sed -n '2,20p' "$0"; exit 1; }

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

project=TouchGuard.xcodeproj
team=ZUKW8RPUVQ
out=build/release
derived=$out/DerivedData-$mode  # separate per channel, so no build products are shared
repo_url=https://github.com/sjhorn/TouchGuard

project_version=$(sed -nE 's/.*MARKETING_VERSION = ([^;]+);/\1/p' "$project/project.pbxproj" | head -1)
version=${2:-$project_version}
if [[ $version != "$project_version" ]]; then
    echo "warning: building $version but the project says $project_version (run scripts/bump-version.sh $version)" >&2
fi
build_number=$(git rev-list --count HEAD)

step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

asc_auth_xcodebuild=()
notary_auth=(--keychain-profile "${NOTARY_PROFILE:-touchguard-notary}")
if [[ -n ${ASC_KEY_PATH:-} ]]; then
    : "${ASC_KEY_ID:?ASC_KEY_ID must be set with ASC_KEY_PATH}" "${ASC_ISSUER_ID:?ASC_ISSUER_ID must be set with ASC_KEY_PATH}"
    asc_auth_xcodebuild=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
    notary_auth=(--key "$ASC_KEY_PATH" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID")
fi

rm -rf "$out/$mode"
mkdir -p "$out/$mode"

# MARK: - Developer ID

release_devid() {
    local archive=$out/devid/TouchGuard.xcarchive
    local export_dir=$out/devid/export
    local app=$export_dir/TouchGuard.app
    local dmg=$out/devid/TouchGuard-$version.dmg

    step "Archiving TouchGuard $version ($build_number)"
    xcodebuild archive \
        -project "$project" -scheme TouchGuard -configuration Release \
        -archivePath "$archive" -derivedDataPath "$derived" \
        MARKETING_VERSION="$version" CURRENT_PROJECT_VERSION="$build_number" \
        CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Developer ID Application" DEVELOPMENT_TEAM="$team" \
        OTHER_CODE_SIGN_FLAGS=--timestamp \
        ${SPARKLE_PUBLIC_ED_KEY:+SPARKLE_PUBLIC_ED_KEY="$SPARKLE_PUBLIC_ED_KEY"} \
        | xcbeautify_or_cat

    local info=$archive/Products/Applications/TouchGuard.app/Contents/Info.plist
    if [[ -z $(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$info" 2>/dev/null) ]]; then
        echo "error: SUPublicEDKey is empty. Set SPARKLE_PUBLIC_ED_KEY in the project (see docs/RELEASING.md)." >&2
        exit 1
    fi

    step "Exporting with Developer ID"
    xcodebuild -exportArchive -archivePath "$archive" -exportPath "$export_dir" \
        -exportOptionsPlist scripts/ExportOptions-DeveloperID.plist | xcbeautify_or_cat

    step "Notarising the app"
    local zip=$out/devid/TouchGuard-notarize.zip
    ditto -c -k --keepParent "$app" "$zip"
    xcrun notarytool submit "$zip" "${notary_auth[@]}" --wait
    xcrun stapler staple "$app"
    rm "$zip"

    step "Building the DMG"
    local staging=$out/devid/dmg
    mkdir -p "$staging"
    ditto "$app" "$staging/TouchGuard.app"
    ln -s /Applications "$staging/Applications"
    hdiutil create -volname "TouchGuard" -srcfolder "$staging" -fs HFS+ -format UDZO -ov "$dmg"
    rm -rf "$staging"
    codesign --sign "Developer ID Application" --timestamp "$dmg"

    step "Notarising the DMG"
    xcrun notarytool submit "$dmg" "${notary_auth[@]}" --wait
    xcrun stapler staple "$dmg"

    step "Verifying"
    codesign --verify --deep --strict --verbose=2 "$app"
    if [[ $(sandbox_entitlement "$app") == true ]]; then
        echo "error: the Developer ID build is sandboxed" >&2; exit 1
    fi
    # Capture first: grep -q can exit before codesign finishes writing, and the
    # SIGPIPE then fails the pipeline under pipefail.
    local signature_info
    signature_info=$(codesign -d --verbose=2 "$app" 2>&1)
    [[ $signature_info == *"(runtime)"* ]] || { echo "error: hardened runtime is off" >&2; exit 1; }
    xcrun stapler validate "$app"
    xcrun stapler validate "$dmg"
    spctl -a -vvv -t execute "$app"
    spctl -a -vvv -t open --context context:primary-signature "$dmg"

    step "Signing the update for Sparkle"
    local sign_update
    sign_update=$(find "$derived/SourcePackages/artifacts" -path '*/bin/sign_update' -type f | head -1)
    [[ -x $sign_update ]] || { echo "error: Sparkle's sign_update wasn't found" >&2; exit 1; }
    local signature
    if [[ -n ${SPARKLE_ED_KEY_FILE:-} ]]; then
        signature=$("$sign_update" --ed-key-file "$SPARKLE_ED_KEY_FILE" "$dmg")
    else
        signature=$("$sign_update" "$dmg")
    fi

    step "Updating docs/appcast.xml"
    python3 scripts/update_appcast.py \
        --appcast docs/appcast.xml --changelog CHANGELOG.md \
        --version "$version" --build "$build_number" \
        --url "$repo_url/releases/download/v$version/TouchGuard-$version.dmg" \
        --signature "$signature" --min-system 14.0

    step "Done"
    echo "DMG:     $dmg"
    echo "Appcast: docs/appcast.xml (commit it to master once the GitHub Release is published)"
}

# MARK: - App Store

release_appstore() {
    local archive=$out/appstore/TouchGuardMAS.xcarchive

    step "Archiving TouchGuardMAS $version ($build_number)"
    xcodebuild archive \
        -project "$project" -scheme TouchGuardMAS -configuration Release \
        -archivePath "$archive" -derivedDataPath "$derived" \
        MARKETING_VERSION="$version" CURRENT_PROJECT_VERSION="$build_number" \
        -allowProvisioningUpdates ${asc_auth_xcodebuild[@]+"${asc_auth_xcodebuild[@]}"} | xcbeautify_or_cat

    [[ $(sandbox_entitlement "$archive/Products/Applications/TouchGuard.app") == true ]] \
        || { echo "error: the App Store build isn't sandboxed" >&2; exit 1; }

    step "Uploading to App Store Connect"
    xcodebuild -exportArchive -archivePath "$archive" -exportPath "$out/appstore/export" \
        -exportOptionsPlist scripts/ExportOptions-AppStore.plist \
        -allowProvisioningUpdates ${asc_auth_xcodebuild[@]+"${asc_auth_xcodebuild[@]}"} | xcbeautify_or_cat

    step "Done: build $build_number is processing in App Store Connect"
}

# Prints true or false (false if the entitlement is missing).
sandbox_entitlement() {
    local plist
    plist=$(mktemp)
    codesign -d --entitlements :- "$1" 2>/dev/null >"$plist"
    /usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' "$plist" 2>/dev/null || echo false
    rm -f "$plist"
}

xcbeautify_or_cat() {
    if command -v xcbeautify >/dev/null; then xcbeautify; else cat; fi
}

"release_$mode"
