#!/usr/bin/env bash
# CI only: puts the signing certificate and keys from secrets where release.sh
# expects them, in a temporary keychain and $RUNNER_TEMP.
#
#   scripts/ci-setup-signing.sh               certificate, ASC key, Sparkle key
#   scripts/ci-setup-signing.sh --asc-key-only
#   scripts/ci-setup-signing.sh --cleanup
set -euo pipefail

: "${RUNNER_TEMP:?run this in GitHub Actions}"
keychain=$RUNNER_TEMP/signing.keychain-db

if [[ ${1:-} == --cleanup ]]; then
    security delete-keychain "$keychain" 2>/dev/null || true
    rm -f "$RUNNER_TEMP/AuthKey.p8" "$RUNNER_TEMP/sparkle_ed_key" "$RUNNER_TEMP/cert.p12"
    exit 0
fi

umask 077
printf '%s' "${ASC_KEY_P8:?}" > "$RUNNER_TEMP/AuthKey.p8"
[[ ${1:-} == --asc-key-only ]] && exit 0

printf '%s' "${SPARKLE_ED_PRIVATE_KEY:?}" > "$RUNNER_TEMP/sparkle_ed_key"

password=$(uuidgen)
printf '%s' "${DEVELOPER_ID_P12:?}" | base64 --decode > "$RUNNER_TEMP/cert.p12"
security create-keychain -p "$password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$password" "$keychain"
security import "$RUNNER_TEMP/cert.p12" -k "$keychain" -P "${DEVELOPER_ID_P12_PASSWORD:?}" \
    -T /usr/bin/codesign -T /usr/bin/security
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$password" "$keychain" >/dev/null
security list-keychains -d user -s "$keychain" $(security list-keychains -d user | tr -d '"')
rm "$RUNNER_TEMP/cert.p12"
security find-identity -v -p codesigning "$keychain"
