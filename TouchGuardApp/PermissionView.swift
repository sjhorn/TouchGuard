import SwiftUI
import TouchGuardCore

struct PermissionView: View {
    let model: AppModel
    @State private var isGranted = Permissions.isGranted
    private let mode = Permissions.mode

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "hand.raised.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.tint)
                Text(title)
                    .font(.title3.bold())
            }

            Text(explanation)
                .fixedSize(horizontal: false, vertical: true)

            Text("TouchGuard never reads, records or sends what you type. It only checks *that* a key was released.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(verbatim: "\(index + 1).")
                        Text(step)
                    }
                }
            }

            Text("Already on but this window stays open? Remove TouchGuard from the list with −, then add it again.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Label(isGranted ? "Permission granted" : "Waiting for permission…",
                      systemImage: isGranted ? "checkmark.circle.fill" : "clock")
                    .foregroundStyle(isGranted ? .green : .secondary)
                Spacer()
                Button("Continue") {
                    Task { await Permissions.continueSetup() }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 440)
        .task {
            while !Task.isCancelled {
                isGranted = Permissions.isGranted
                if isGranted {
                    model.permissionGranted()
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private var title: LocalizedStringKey {
        switch mode {
        case .accessibility: "TouchGuard needs Accessibility permission"
        case .inputMonitoringAndPostEvent: "TouchGuard needs your permission"
        }
    }

    private var explanation: LocalizedStringKey {
        switch mode {
        case .accessibility:
            "To stop accidental trackpad taps while you type, TouchGuard needs to notice when you release a key and briefly hold back clicks. macOS only allows this for apps you've allowed under Accessibility."
        case .inputMonitoringAndPostEvent:
            "To stop accidental trackpad taps while you type, TouchGuard needs to notice when you release a key and briefly hold back clicks. macOS only allows this for apps you've allowed under Input Monitoring and Accessibility."
        }
    }

    private var steps: [LocalizedStringKey] {
        switch mode {
        case .accessibility:
            ["Click **Continue**.",
             "When macOS asks, click **Open System Settings**.",
             "Turn on **TouchGuard** under **Accessibility**.",
             "This window closes by itself and blocking starts."]
        case .inputMonitoringAndPostEvent:
            ["Click **Continue**.",
             "When macOS asks, click **Open System Settings**.",
             "Turn on **TouchGuard** in the list (Accessibility, and Input Monitoring if asked).",
             "This window closes by itself and blocking starts."]
        }
    }
}
