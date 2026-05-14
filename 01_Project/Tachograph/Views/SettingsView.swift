import SwiftUI
import KeyboardShortcuts

/// App-level Settings scene. W2-A populates only the "Pause/resume capture"
/// section; W2-B will extend this view with an "App Filter" section.
struct SettingsView: View {
    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Hotkey:", name: .toggleCapture)

                HStack {
                    Spacer()
                    Button("Reset to default") {
                        KeyboardShortcuts.reset(.toggleCapture)
                    }
                }
            } header: {
                Text("Pause/resume capture")
            } footer: {
                Text("Press this combo from anywhere to start or stop capture. Requires Accessibility permission for capture itself, not for the hotkey.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    SettingsView()
}
