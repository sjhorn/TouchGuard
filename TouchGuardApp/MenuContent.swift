import SwiftUI

struct MenuContent: View {
    let model: AppModel

    var body: some View {
        Text(model.statusText)

        if model.state == .needsPermission {
            Button("Grant Permission…") { model.showPermissionWindow() }
        }

        Toggle("Enabled", isOn: Binding(get: { model.isEnabled }, set: { model.setEnabled($0) }))
            .keyboardShortcut(model.hotKeyEnabled ? KeyboardShortcut("t", modifiers: [.control, .option, .command]) : nil)

        Divider()

        Menu("Delay: \(model.delayMs) ms") {
            ForEach(AppModel.delayPresets, id: \.self) { ms in
                Toggle("\(ms) ms", isOn: Binding(get: { model.delayMs == ms }, set: { _ in model.setDelay(ms) }))
            }
            Divider()
            Button("Custom…") { model.showCustomDelay() }
        }

        Text("Blocked clicks: \(model.blockedClicks)")
        Button("Reset Count") { model.resetBlockedClicks() }
            .disabled(model.blockedClicks == 0)

        Divider()

        Toggle("Launch at Login", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
            .onAppear { model.refreshLaunchAtLogin() }
        if let error = model.launchAtLoginError {
            Text("Launch at login failed: \(error)")
        }
        Toggle("Global Shortcut ⌃⌥⌘T", isOn: Binding(get: { model.hotKeyEnabled }, set: { model.setHotKeyEnabled($0) }))

        Divider()

        if model.updater.isAvailable {
            Button("Check for Updates…") { model.updater.checkForUpdates() }
                .disabled(!model.updater.canCheckForUpdates)
        }
        Button("About TouchGuard") { model.showAbout() }
        Button("Quit TouchGuard") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

struct CustomDelayView: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Block clicks for \(model.delayMs) ms after each key release")
                .monospacedDigit()
            Slider(
                value: Binding(get: { Double(model.delayMs) }, set: { model.setDelay(Int($0)) }),
                in: Double(AppModel.delayRange.lowerBound)...Double(AppModel.delayRange.upperBound),
                step: 10
            ) {
                EmptyView()
            } minimumValueLabel: {
                Text("\(AppModel.delayRange.lowerBound)")
            } maximumValueLabel: {
                Text("\(AppModel.delayRange.upperBound)")
            }
            Text("Changes apply immediately. Try a longer delay if the cursor still jumps, or a shorter one if the trackpad feels slow after typing.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: 360)
    }
}
