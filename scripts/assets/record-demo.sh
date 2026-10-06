#!/usr/bin/env bash
# Records the App Review demo video of the running TouchGuard (App Store build).
# It types narration into a new TextEdit document and taps with synthetic
# events, which TouchGuard filters exactly like real ones. Other apps are
# hidden first, and only the rectangle around TextEdit and the menu bar's right
# half is recorded, which keeps desktop icons and widgets out of the video.
#
# Needs: Screen Recording and Accessibility for the terminal; TouchGuard active.
# Usage: scripts/assets/record-demo.sh [output.mov]   (default build/demo/touchguard-demo.mov, 50 s)
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
out=${1:-$root/build/demo/touchguard-demo.mov}
mkdir -p "$(dirname "$out")"
rm -f "$out"   # screencapture won't overwrite an existing video
driver=$root/build/demo-input
swiftc -O -o "$driver" "$root/scripts/assets/demo-input.swift"

window_x=360 window_y=160
tap_x=520 tap_y=268   # on the first line of the document

osascript <<APPLESCRIPT
tell application "TextEdit"
    activate
    make new document
end tell
delay 0.8
tell application "System Events"
    tell process "TextEdit"
        set position of front window to {$window_x, $window_y}
        set size of front window to {1200, 640}
    end tell
    set visible of every process whose visible is true and name is not "TextEdit" to false
end tell
APPLESCRIPT
sleep 1

menu() {
    osascript -e 'tell application "System Events" to tell process "TouchGuard" to click menu bar item 1 of menu bar 2' >/dev/null
    sleep "$1"
    osascript -e 'tell application "System Events" to key code 53'
    osascript -e 'tell application "TextEdit" to activate'
    sleep 0.5
}

# Start from zero blocked clicks, so the menu shows the one tap blocked in the video.
osascript <<'APPLESCRIPT' >/dev/null 2>&1 || true
tell application "System Events" to tell process "TouchGuard"
    click menu bar item 1 of menu bar 2
    delay 0.4
    click menu item "Reset Count" of menu 1 of menu bar item 1 of menu bar 2
end tell
APPLESCRIPT
osascript -e 'tell application "System Events" to key code 53' -e 'tell application "TextEdit" to activate' >/dev/null
sleep 0.5

# x,y,w,h in points: TextEdit (360…1560) plus the TouchGuard menu, from the top of the screen.
screencapture -v -k -x -V 50 -R 352,0,1290,820 "$out" &
recorder=$!
sleep 2

DEMO_STEP=typing "$driver" $tap_x $tap_y
sleep 0.5
menu 3                                   # "Blocked clicks: 1"
DEMO_STEP=hotkey "$driver" $tap_x $tap_y  # pause
sleep 0.4
menu 2.5                                 # "Paused"
DEMO_STEP=paused "$driver" $tap_x $tap_y
DEMO_STEP=hotkey "$driver" $tap_x $tap_y  # resume
sleep 0.4
menu 2.5                                 # "Active, 200 ms"

wait $recorder || { echo "error: screencapture failed" >&2; exit 1; }
[[ -s $out ]] || { echo "error: no video was written" >&2; exit 1; }
osascript -e 'tell application "TextEdit" to close front document saving no' >/dev/null 2>&1 || true
echo "Recorded $out"
