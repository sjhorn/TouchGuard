import SwiftUI
import TouchGuardCore

struct PermissionView: View {
    let model: AppModel
    @State private var isTrusted = Accessibility.isTrusted

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "hand.raised.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.tint)
                Text("TouchGuard needs Accessibility permission")
                    .font(.title3.bold())
            }

            Text("To stop accidental trackpad taps while you type, TouchGuard needs to notice when you release a key and briefly hold back clicks. macOS only allows this for apps you've allowed under Accessibility.")
                .fixedSize(horizontal: false, vertical: true)

            Text("TouchGuard never reads, records or sends what you type. It only checks *that* a key was released.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                Text("1. Click **Open Accessibility Settings**.")
                Text("2. Turn on **TouchGuard** in the list.")
                Text("3. This window closes by itself and blocking starts.")
            }

            Text("Already on but this window stays open? Remove TouchGuard from the list with −, then add it again.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Label(isTrusted ? "Permission granted" : "Waiting for permission…",
                      systemImage: isTrusted ? "checkmark.circle.fill" : "clock")
                    .foregroundStyle(isTrusted ? .green : .secondary)
                Spacer()
                Button("Open Accessibility Settings") {
                    Accessibility.requestPrompt()
                    Accessibility.openSettings()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 440)
        .task {
            while !Task.isCancelled {
                isTrusted = Accessibility.isTrusted
                if isTrusted {
                    model.permissionGranted()
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}
