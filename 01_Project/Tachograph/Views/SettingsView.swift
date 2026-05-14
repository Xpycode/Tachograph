import SwiftUI
import AppKit
import UniformTypeIdentifiers
import KeyboardShortcuts

/// App-level Settings scene. W2-A added the "Pause/resume capture" section;
/// W2-B extends the same Form with the "App Filter" section. Match the visual
/// style: Section header + footer caption.
struct SettingsView: View {
    @Bindable var store: AppFilterStore
    /// Optional so previews and tests can omit it. Production passes the
    /// shared VM so toggling/editing the filter while capture is running
    /// pushes a fresh snapshot into the service.
    var vm: CaptureViewModel?

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

            Section {
                Toggle("Enable per-app filter", isOn: $store.enabled)
                    .onChange(of: store.enabled) { _, _ in
                        vm?.updateActiveFilter()
                    }

                if store.enabled {
                    allowedAppsList
                    addAppButton
                    Toggle("Include Tachograph itself", isOn: $store.captureOwnApp)
                        .onChange(of: store.captureOwnApp) { _, _ in
                            vm?.updateActiveFilter()
                        }
                }
            } header: {
                Text("App Filter")
            } footer: {
                Text("Only record events while one of these apps is frontmost. An empty list records everything (the filter has no effect until you add an app). The lock screen and screensaver never record.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var allowedAppsList: some View {
        if store.allowedBundleIDs.isEmpty {
            Text("No apps added yet — filter is inactive.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            ForEach(store.allowedBundleIDs, id: \.self) { bundleID in
                HStack(spacing: 10) {
                    appIcon(for: bundleID)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayName(for: bundleID))
                            .font(.subheadline)
                        Text(bundleID)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        store.removeBundleID(bundleID)
                        vm?.updateActiveFilter()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(displayName(for: bundleID))")
                }
            }
        }
    }

    private var addAppButton: some View {
        Button {
            pickApp()
        } label: {
            Label("Add app…", systemImage: "plus")
        }
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true   // .app bundles are directories
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.prompt = "Add"
        panel.message = "Choose an app to add to the capture filter"

        // Default to /Applications to short-circuit the user.
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        guard panel.runModal() == .OK, let url = panel.url else { return }
        // Resolve symlinks/aliases — NSOpenPanel may hand back an alias.
        let resolved = url.resolvingSymlinksInPath()
        guard let bundleID = Bundle(url: resolved)?.bundleIdentifier else { return }
        store.addBundleID(bundleID)
        vm?.updateActiveFilter()
    }

    private func displayName(for bundleID: String) -> String {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
           let name = app.localizedName {
            return name
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
           let name = Bundle(url: url)?.infoDictionary?["CFBundleName"] as? String {
            return name
        }
        return bundleID
    }

    private func appIcon(for bundleID: String) -> some View {
        let icon: NSImage
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            icon = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            icon = NSWorkspace.shared.icon(for: .application)
        }
        return Image(nsImage: icon)
            .resizable()
            .frame(width: 24, height: 24)
    }
}

#Preview {
    SettingsView(store: AppFilterStore())
}
