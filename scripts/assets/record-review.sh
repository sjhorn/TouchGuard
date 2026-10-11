#!/usr/bin/env bash
# Records the App Review video that starts with launching TouchGuard (the App
# Store build) for the first time and shows the typical flow:
#
#   Finder → double-click TouchGuard → permission window → Open Privacy Settings
#   → (a person turns on Input Monitoring and Accessibility) → TouchGuard is
#   Active → typing in TextEdit with a tap ignored straight after typing → a
#   normal click works → menu with the blocked count → ⌃⌥⌘T pause and resume.
#
# Only the permission switches are done by hand; the script waits for them.
# Permissions for com.hornmicro.TouchGuard are reset first, so this is a real
# first launch: re-grant them for /Applications/TouchGuard.app afterwards.
#
# Needs: the display at "Looks like 1920 × 1080", Screen Recording and
# Accessibility for the terminal, and a Release build of TouchGuardMAS.
# Usage: scripts/assets/record-review.sh [output.mov]
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
out=${1:-$root/build/demo/touchguard-review.mov}
# Default: the app from the last `release.sh appstore` archive (the uploaded build).
source_app=${APP_SOURCE:-$root/build/release/appstore/TouchGuardMAS.xcarchive/Products/Applications/TouchGuard.app}
app=$HOME/Applications/TouchGuard.app
installed=/Applications/TouchGuard.app
lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
driver=$root/build/demo-input
region=352,0,1290,820   # points: Finder, TouchGuard, System Settings and TextEdit all go here

say() { printf '\033[1m==> %s\033[0m\n' "$*"; }
tg_status() {
    osascript -e 'tell application "System Events" to get name of menu bar item 1 of menu bar 2 of process "TouchGuard"' 2>/dev/null || true
}

[[ -d $source_app ]] || { echo "error: build TouchGuardMAS (Release) first" >&2; exit 1; }
system_profiler SPDisplaysDataType 2>/dev/null | grep -q "UI Looks like: 1920 x 1080" \
    || { echo "error: set the display to \"Looks like 1920 × 1080\" first" >&2; exit 1; }
mkdir -p "$(dirname "$out")"
rm -f "$out"
swiftc -O -o "$driver" "$root/scripts/assets/demo-input.swift"

say "Staging the App Store build in ~/Applications (the only registered copy)"
pkill -f "TouchGuard.app/Contents/MacOS/TouchGuard" || true
mkdir -p "$HOME/Applications"
rm -rf "$app"
ditto "$source_app" "$app"
# Move the installed (download) copy out of the way: when a permission change
# makes macOS "Quit & Reopen" TouchGuard, it relaunches by bundle ID and would
# otherwise pick /Applications/TouchGuard.app. Put back on exit, whatever happens.
stash=$root/build/stash
if [[ -d $installed ]]; then
    mkdir -p "$stash"
    rm -rf "$stash/TouchGuard.app"
    "$lsregister" -u "$installed"
    mv "$installed" "$stash/TouchGuard.app"
fi
restore() {
    pkill -f "$app/Contents/MacOS/TouchGuard" || true
    if [[ -d $stash/TouchGuard.app && ! -e $installed ]]; then
        mv "$stash/TouchGuard.app" "$installed"
        "$lsregister" -f "$installed"
        echo "Moved TouchGuard back to $installed"
    fi
    return 0
}
trap restore EXIT INT TERM
"$lsregister" -f "$app"
for service in Accessibility ListenEvent PostEvent; do
    tccutil reset "$service" com.hornmicro.TouchGuard >/dev/null
done

say "Setting the stage"
osascript <<'APPLESCRIPT'
tell application "System Settings" to if it is running then quit
tell application "Finder"
    activate
    close every Finder window
    set w to make new Finder window to (path to applications folder from user domain)
    set current view of w to list view
    set bounds of w to {420, 120, 1180, 520}
end tell
delay 1
tell application "System Events" to set visible of every process whose visible is true and name is not "Finder" to false
APPLESCRIPT
sleep 1

# Centre of the TouchGuard row in the Finder list.
# (The file list is in a split group nested inside the sidebar's split group.)
row_center=$(osascript <<'APPLESCRIPT'
tell application "System Events" to tell process "Finder"
    set theRows to rows of outline 1 of scroll area 1 of splitter group 1 of splitter group 1 of front window
    repeat with r in theRows
        if (value of text field 1 of UI element 1 of r) starts with "TouchGuard" then
            set {x, y} to position of text field 1 of UI element 1 of r
            set {w, h} to size of text field 1 of UI element 1 of r
            return ((x + w / 2) as integer as text) & " " & ((y + h / 2) as integer as text)
        end if
    end repeat
end tell
APPLESCRIPT
)
read -r row_x row_y <<< "$row_center"
[[ -n ${row_x:-} ]] || { echo "error: TouchGuard not found in the Finder window" >&2; exit 1; }

say "Recording"
screencapture -v -k -x -R "$region" "$out" &
recorder=$!
sleep 2.5

# Launch: double-click TouchGuard in Finder.
DEMO_STEP=doubleclick "$driver" "$row_x" "$row_y"

for _ in $(seq 1 20); do
    osascript -e 'tell application "System Events" to exists window "TouchGuard Permission" of process "TouchGuard"' 2>/dev/null | grep -q true && break
    sleep 0.5
done
sleep 3.5   # time to read the permission window

button_center=$(osascript <<'APPLESCRIPT'
-- SwiftUI's button has no accessible name; it's the only wide button in the window.
tell application "System Events" to tell process "TouchGuard"
    set allItems to entire contents of window "TouchGuard Permission"
    repeat with e in allItems
        if role of e is "AXButton" then
            set {w, h} to size of e
            if w > 60 then
                set {x, y} to position of e
                return ((x + w / 2) as integer as text) & " " & ((y + h / 2) as integer as text)
            end if
        end if
    end repeat
end tell
APPLESCRIPT
)
read -r button_x button_y <<< "$button_center"
[[ -n ${button_x:-} ]] || { kill -INT $recorder; wait $recorder || true; echo "error: Open Privacy Settings button not found" >&2; exit 1; }
# The window is in front but TouchGuard isn't the active app, and a first click
# on an inactive app's window only activates it. Click the title bar first.
title_center=$(osascript -e 'tell application "System Events" to tell process "TouchGuard" to tell window "TouchGuard Permission" to return (((item 1 of (get position)) + (item 1 of (get size)) / 2) as integer as text) & " " & (((item 2 of (get position)) + 14) as integer as text)')
read -r title_x title_y <<< "$title_center"
DEMO_STEP=click "$driver" "$title_x" "$title_y"
sleep 0.8
DEMO_STEP=click "$driver" "$button_x" "$button_y"

say "Waiting for the permissions to be granted by hand (up to 3 minutes)"
for _ in $(seq 1 180); do
    # Keep System Settings inside the recorded area.
    osascript -e 'tell application "System Events" to if exists process "System Settings" then tell process "System Settings" to if (count of windows) > 0 then set position of front window to {700, 60}' >/dev/null 2>&1 || true
    [[ $(tg_status) == *Active* ]] && break
    sleep 1
done
[[ $(tg_status) == *Active* ]] || { kill -INT $recorder; wait $recorder || true; echo "error: TouchGuard never became active" >&2; exit 1; }
say "TouchGuard is active: running the demo"
sleep 2.5
osascript -e 'tell application "System Settings" to quit' >/dev/null 2>&1 || true
osascript -e 'tell application "Finder" to close every Finder window' >/dev/null 2>&1 || true
sleep 1

window_x=380 window_y=160
tap_x=540 tap_y=268     # first line of the document
osascript <<APPLESCRIPT
tell application "TextEdit"
    activate
    make new document
end tell
delay 0.8
tell application "System Events" to tell process "TextEdit"
    set position of front window to {$window_x, $window_y}
    set size of front window to {1200, 600}
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

DEMO_STEP=typing "$driver" $tap_x $tap_y
sleep 0.5
menu 3                                    # "Blocked clicks: 1"
DEMO_STEP=hotkey "$driver" $tap_x $tap_y   # pause
sleep 0.4
menu 2.5                                  # "Paused"
DEMO_STEP=paused "$driver" $tap_x $tap_y
DEMO_STEP=hotkey "$driver" $tap_x $tap_y   # resume
sleep 0.4
menu 2.5                                  # "Active"
sleep 1

kill -INT $recorder
wait $recorder || true
[[ -s $out ]] || { echo "error: no video was written" >&2; exit 1; }
osascript -e 'tell application "TextEdit" to close front document saving no' >/dev/null 2>&1 || true
say "Recorded $out"
echo "Open /Applications/TouchGuard.app and re-grant Accessibility to go back to the download version."
