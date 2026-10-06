//
//  main.swift
//  touchguard
//
//  Command-line TouchGuard. Originally created by SyntaxSoft 2016.
//

import AppKit
import Foundation
import TouchGuardCore

/// From the Info.plist embedded in the binary (CREATE_INFOPLIST_SECTION_IN_BINARY).
let version: String = {
    let info = Bundle.main.infoDictionary
    let short = info?["CFBundleShortVersionString"] as? String ?? "dev"
    let build = info?["CFBundleVersion"] as? String
    return build.map { "\(short) (\($0))" } ?? short
}()

struct Options {
    var delay: TimeInterval = 0.2
    var debug = true
    var tapEnableMsg = false
    var tapDisableMsg = false
}

func printUsage() {
    print("""
    Usage: touchguard [-time <seconds>] [-nodebug] [-TapEnableMsg] [-TapDisableMsg] [-version] [-h]

      -time <sec>      block trackpad clicks for <sec> seconds after each key release (default 0.2)
      -nodebug         don't print any messages
      -TapEnableMsg    print a message when clicks are allowed again
      -TapDisableMsg   print a message when a key release starts blocking clicks
      -version         print the version
      -h, -help        show this help
    """)
}

func parseOptions(_ args: [String]) -> Options {
    var options = Options()
    var i = 0
    while i < args.count {
        switch args[i].lowercased() {
        case "-nodebug":
            options.debug = false
        case "-time":
            i += 1
            guard i < args.count else {
                FileHandle.standardError.write(Data("-time needs a value in seconds\n".utf8))
                exit(1)
            }
            if let value = Double(args[i]), value > 0 {
                options.delay = value
            }
        case "-version":
            print("Version \(version)")
        case "-tapenablemsg":
            options.tapEnableMsg = true
        case "-tapdisablemsg":
            options.tapDisableMsg = true
        case "-h", "-help", "--help":
            printUsage()
            exit(0)
        default:
            FileHandle.standardError.write(Data("Unknown option \(args[i]) (try -h)\n".utf8))
        }
        i += 1
    }
    return options
}

/// The app macOS will ask the user to grant Accessibility to: the terminal
/// (or other app) that launched us, not this binary.
func responsibleAppName() -> String {
    var pid = getppid()
    while pid > 1 {
        if let app = NSRunningApplication(processIdentifier: pid), let name = app.localizedName {
            return name
        }
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { break }
        pid = info.kp_eproc.e_ppid
    }
    return "your terminal app"
}

let timeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "MMM dd yyyy HH:mm:ss SSS'msec'"
    return f
}()

func log(_ message: String) {
    print("\(timeFormatter.string(from: Date())): \(message)")
}

setvbuf(stdout, nil, _IOLBF, 0)
let options = parseOptions(Array(CommandLine.arguments.dropFirst()))

guard Permissions.isGranted else {
    let app = responsibleAppName()
    FileHandle.standardError.write(Data("""
    touchguard needs Accessibility permission to see key releases and hold back trackpad clicks.
    It does not read or record what you type.

    Grant it to "\(app)" in System Settings → Privacy & Security → Accessibility,
    then quit and reopen \(app) and run touchguard again.

    """.utf8))
    Permissions.request()
    exit(1)
}

MainActor.assumeIsolated {
    let controller = EventTapController(delay: options.delay)

    if options.debug {
        print("Disable interval \(Int((options.delay * 1000).rounded())) milliSeconds")

        // Clicks ignored in the current block window; the first is logged, the rest summarised.
        var ignoredInWindow = 0
        controller.onBlock = { _ in
            if ignoredInWindow == 0 { log("Ignoring tap") }
            ignoredInWindow += 1
        }

        var windowEnd: DispatchWorkItem?
        controller.onKeyRelease = { _ in
            if windowEnd == nil, options.tapDisableMsg {
                print("Disabled tap")
            }
            windowEnd?.cancel()
            let item = DispatchWorkItem {
                windowEnd = nil
                if ignoredInWindow > 1 { print("IgnoreCount \(ignoredInWindow - 1)") }
                ignoredInWindow = 0
                if options.tapEnableMsg { print("Enabled Tap") }
            }
            windowEnd = item
            DispatchQueue.main.asyncAfter(deadline: .now() + controller.delay, execute: item)
        }

        controller.onRearm = { reason in
            log("Event tap was disabled by macOS (\(reason)); re-enabled")
        }
        controller.onStateChange = { state in
            switch state {
            case .needsPermission: log("Accessibility permission was revoked; waiting for it to come back")
            case .failed: log("Could not create the event tap; retrying")
            case .running: log("Event tap running")
            case .paused: break
            }
        }
    }

    controller.start()
    if controller.state == .failed {
        FileHandle.standardError.write(Data("Could not create the event tap.\n".utf8))
        exit(1)
    }

    // Keep the controller alive for the life of the process.
    withExtendedLifetime(controller) {
        CFRunLoopRun()
    }
}
