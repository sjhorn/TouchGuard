import SwiftUI
import TouchGuardCore

struct PermissionView: View {
    let model: AppModel
    @State private var granted = Self.currentGrants()
    /// Set once the person clicks Continue; after that, each newly granted
    /// permission moves straight on to asking for the next one.
    @State private var setupStarted = false
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
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(visibleRequirements.enumerated()), id: \.offset) { _, requirement in
                    checklistRow(requirement)
                }
                if visibleRequirements.contains(.listenEvents) {
                    Text("On this Mac, macOS also needs **Input Monitoring**. Click **Continue** and allow it the same way.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))

            Text("Already on but this window stays open? Remove TouchGuard from the list with −, then add it again.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("Continue") {
                    setupStarted = true
                    Task { await Permissions.continueSetup() }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 440)
        .task {
            while !Task.isCancelled {
                let now = Self.currentGrants()
                let newlyGranted = now.indices.contains { now[$0] && !granted[$0] }
                granted = now
                if Permissions.isGranted {
                    model.permissionGranted()
                } else if setupStarted && Permissions.needsRelaunchToSeeGrant {
                    // Granted in System Settings, but this process can't see it.
                    // Only after Continue: probing by creating a tap makes macOS
                    // show its permission prompt, which mustn't pop up unasked.
                    model.relaunchToApplyPermission()
                } else if newlyGranted && setupStarted {
                    // One permission just came through: ask for the next one
                    // straight away instead of waiting for another click.
                    await Permissions.continueSetup()
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private var title: LocalizedStringKey {
        switch mode {
        case .accessibility: "TouchGuard needs Accessibility permission"
        case .inputMonitoringAndPostEvent: "TouchGuard needs Accessibility permission"
        }
    }

    private var explanation: LocalizedStringKey {
        switch mode {
        case .accessibility:
            "To stop accidental trackpad taps while you type, TouchGuard needs to notice when you release a key and briefly hold back clicks. macOS only allows this for apps you've allowed under Accessibility."
        case .inputMonitoringAndPostEvent:
            "To stop accidental trackpad taps while you type, TouchGuard needs to notice when you release a key and briefly hold back clicks. macOS only allows this for apps you've allowed under Accessibility."
        }
    }

    private var steps: [LocalizedStringKey] {
        switch mode {
        case .accessibility:
            ["Click **Continue**.",
             "When macOS asks, click **Open System Settings** and turn on **TouchGuard**.",
             "This window closes by itself and blocking starts."]
        case .inputMonitoringAndPostEvent:
            ["Click **Continue**.",
             "When macOS asks, click **Open System Settings** and turn on **TouchGuard**.",
             "This window closes by itself and blocking starts."]
        }
    }

    /// Input Monitoring is usually covered by Accessibility, so its row only
    /// appears once Accessibility is granted and macOS still wants it.
    private var visibleRequirements: [PermissionRequirement] {
        Permissions.requirements.enumerated().filter { index, requirement in
            guard requirement == .listenEvents else { return true }
            let previousGranted = granted.indices.contains(index - 1) && granted[index - 1]
            let thisGranted = granted.indices.contains(index) && granted[index]
            return previousGranted && !thisGranted
        }.map(\.element)
    }

    private static func currentGrants() -> [Bool] {
        Permissions.requirements.map(\.isGranted)
    }

    @ViewBuilder
    private func checklistRow(_ requirement: PermissionRequirement) -> some View {
        let index = Permissions.requirements.firstIndex(of: requirement) ?? 0
        let isAllowed = granted.indices.contains(index) && granted[index]
        let isNext = !isAllowed && Permissions.requirements.indices
            .first(where: { !(granted.indices.contains($0) && granted[$0]) }) == index
        HStack {
            Image(systemName: isAllowed ? "checkmark.circle.fill" : (isNext ? "arrow.right.circle" : "circle"))
                .foregroundStyle(isAllowed ? AnyShapeStyle(.green) : AnyShapeStyle(.secondary))
            Text(name(of: requirement))
                .fontWeight(isNext ? .semibold : .regular)
            Spacer()
            Text(isAllowed ? "Allowed" : (isNext ? "Next" : "Waiting"))
                .foregroundStyle(.secondary)
        }
    }

    private func name(of requirement: PermissionRequirement) -> LocalizedStringKey {
        switch requirement {
        case .accessibility, .postEvents: "Accessibility"
        case .listenEvents: "Input Monitoring"
        }
    }
}
