// Drives the App Review demo: types narration into the frontmost app and taps
// at a point straight after a key release, then again after a pause.
// The events are real CGEvents, so TouchGuard filters them exactly as it would
// a palm on the trackpad.
//
// Usage: DEMO_STEP=typing|hotkey|paused demo-input <tapX> <tapY>   (screen points, top-left origin)
import CoreGraphics
import Foundation

let args = CommandLine.arguments
guard args.count == 3, let x = Double(args[1]), let y = Double(args[2]) else {
    FileHandle.standardError.write(Data("usage: demo-input <tapX> <tapY>\n".utf8)); exit(1)
}
let tapPoint = CGPoint(x: x, y: y)
let source = CGEventSource(stateID: .hidSystemState)

func pause(_ seconds: Double) { Thread.sleep(forTimeInterval: seconds) }

func type(_ text: String, perKey: Double = 0.045) {
    for character in text {
        var utf16 = Array(String(character).utf16)
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: down)!
            event.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
            event.flags = []
            event.post(tap: .cghidEventTap)
            pause(down ? 0.01 : perKey)
        }
    }
}

func key(_ code: CGKeyCode, flags: CGEventFlags = []) {
    for down in [true, false] {
        let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down)!
        event.flags = flags
        event.post(tap: .cghidEventTap)
        pause(0.03)
    }
}

/// Tells the system no modifier is held any more (after a ⌃⌥⌘ shortcut), so the
/// following synthetic events aren't treated as ⌃⌥⌘-typing and ⌃-clicks.
func releaseModifiers() {
    let event = CGEvent(source: source)!
    event.type = .flagsChanged
    event.flags = []
    event.post(tap: .cghidEventTap)
    pause(0.05)
}

func move(to point: CGPoint, steps: Int = 25, duration: Double = 0.5) {
    let start = CGEvent(source: nil)?.location ?? point
    for i in 1...steps {
        let t = Double(i) / Double(steps)
        let p = CGPoint(x: start.x + (point.x - start.x) * t, y: start.y + (point.y - start.y) * t)
        CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
        pause(duration / Double(steps))
    }
}

func click(at point: CGPoint) {
    for type in [CGEventType.leftMouseDown, .leftMouseUp] {
        let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left)!
        event.flags = []
        event.post(tap: .cghidEventTap)
        pause(0.04)
    }
}

let mode = ProcessInfo.processInfo.environment["DEMO_STEP"] ?? "all"

if mode == "all" || mode == "typing" {
    type("TouchGuard holds back trackpad taps for a moment after each key release.\n\n")
    pause(0.6)
    type("Watch: while typing, a palm brushes the trackpad")
    // Park the pointer near the target first, so the blocked tap is easy to follow.
    move(to: CGPoint(x: tapPoint.x - 120, y: tapPoint.y + 60), duration: 0.4)
    type("…")
    move(to: tapPoint, duration: 0.12)
    click(at: tapPoint)          // ~150 ms after the last key release: blocked
    pause(0.8)
    type(" the tap was ignored, the cursor stayed here.\n\n")
    pause(1.2)
    type("Pause for a moment, and clicks work normally:")
    pause(1.2)
    move(to: tapPoint, duration: 0.5)
    pause(0.5)
    click(at: tapPoint)          // well after the window: passes, caret moves
    pause(1.5)
    key(124, flags: .maskCommand) // ⌘→ end of line, so later typing doesn't land mid-text
    key(125, flags: .maskCommand) // ⌘↓ end of document
}

if mode == "hotkey" {
    key(17, flags: [.maskControl, .maskAlternate, .maskCommand]) // ⌃⌥⌘T
    releaseModifiers()
}

if mode == "paused" {
    type("\n\nWith TouchGuard paused (⌃⌥⌘T), the same tap goes through")
    move(to: tapPoint, duration: 0.12)
    click(at: tapPoint)          // straight after typing, but not blocked while paused
    pause(1.5)
    key(125, flags: .maskCommand)
    type("\n\nPress ⌃⌥⌘T again to resume. TouchGuard never reads what you type.")
}
