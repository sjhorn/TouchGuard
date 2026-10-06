#!/usr/bin/env bash
# Replaces the Mac (APP_DESKTOP) screenshots of an App Store version's en-US
# localization with build/appstore-screenshots/*.jpg, in file-name order.
#
#   ASC_KEY_PATH=… ASC_KEY_ID=… ASC_ISSUER_ID=… scripts/appstore-upload-screenshots.sh <appStoreVersion id>
set -euo pipefail
version=${1:?usage: $0 <appStoreVersion id>}
root=$(cd "$(dirname "$0")/.." && pwd)
asc=$root/build/asc
[[ -x $asc ]] || swiftc -O -o "$asc" "$root/scripts/asc.swift"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
json() { python3 -c "import json,sys; d=json.load(sys.stdin); print(eval(sys.argv[1]))" "$1"; }

localization=$("$asc" GET "/v1/appStoreVersions/$version/appStoreVersionLocalizations?filter[locale]=en-US" | json "d['data'][0]['id']")

# Reuse the APP_DESKTOP set, emptied, or create one.
set_id=$("$asc" GET "/v1/appStoreVersionLocalizations/$localization/appScreenshotSets?filter[screenshotDisplayType]=APP_DESKTOP" \
    | json "d['data'][0]['id'] if d['data'] else ''")
if [[ -z $set_id ]]; then
    cat > "$tmp/set.json" <<JSON
{"data":{"type":"appScreenshotSets","attributes":{"screenshotDisplayType":"APP_DESKTOP"},
 "relationships":{"appStoreVersionLocalization":{"data":{"type":"appStoreVersionLocalizations","id":"$localization"}}}}}
JSON
    set_id=$("$asc" POST /v1/appScreenshotSets "$tmp/set.json" | json "d['data']['id']")
else
    for old in $("$asc" GET "/v1/appScreenshotSets/$set_id/appScreenshots" | json "' '.join(x['id'] for x in d['data'])"); do
        "$asc" DELETE "/v1/appScreenshots/$old" >/dev/null
        echo "Deleted old screenshot $old"
    done
fi

for file in "$root"/build/appstore-screenshots/*.jpg; do
    name=$(basename "$file")
    size=$(stat -f %z "$file")
    cat > "$tmp/reserve.json" <<JSON
{"data":{"type":"appScreenshots","attributes":{"fileName":"$name","fileSize":$size},
 "relationships":{"appScreenshotSet":{"data":{"type":"appScreenshotSets","id":"$set_id"}}}}}
JSON
    "$asc" POST /v1/appScreenshots "$tmp/reserve.json" > "$tmp/reserved.json"
    shot=$(json "d['data']['id']" < "$tmp/reserved.json")
    # Upload each part to its pre-signed URL.
    python3 -c "
import json
d = json.load(open('$tmp/reserved.json'))
for op in d['data']['attributes']['uploadOperations']:
    headers = ' '.join(f\"{h['name']}={h['value']}\" for h in op['requestHeaders'])
    print(op['url'], op['offset'], op['length'], headers)
" | while read -r url offset length headers; do
        # shellcheck disable=SC2086
        "$asc" UPLOAD "$url" "$file" "$offset" "$length" $headers >/dev/null
    done
    checksum=$(md5 -q "$file")
    cat > "$tmp/commit.json" <<JSON
{"data":{"type":"appScreenshots","id":"$shot","attributes":{"uploaded":true,"sourceFileChecksum":"$checksum"}}}
JSON
    "$asc" PATCH "/v1/appScreenshots/$shot" "$tmp/commit.json" >/dev/null
    echo "Uploaded $name ($shot)"
done
