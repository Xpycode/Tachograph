import SwiftUI
import AppKit

struct PermissionPanel: View {
    @State private var confirmRelaunch = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("Accessibility permission needed")
                .font(.title2.bold())

            Text("Tachograph watches your input system-wide, so macOS needs your permission.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            HStack(spacing: 12) {
                Button("Open Privacy Settings") {
                    openPrivacySettings()
                }
                .buttonStyle(.borderedProminent)

                Button("I've granted it — relaunch") {
                    confirmRelaunch = true
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 4)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmationDialog(
            "Relaunch Tachograph now?",
            isPresented: $confirmRelaunch,
            titleVisibility: .visible
        ) {
            Button("Relaunch", role: .destructive) {
                relaunchApp()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("macOS requires a relaunch for the new Accessibility permission to take effect.")
        }
    }

    private func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func relaunchApp() {
        let bundleURL = Bundle.main.bundleURL
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", bundleURL.path]
        try? task.run()
        NSApp.terminate(nil)
    }
}

#Preview {
    PermissionPanel()
        .frame(width: 720, height: 520)
}
