import SwiftUI
import UniformTypeIdentifiers
import KeyboardShortcuts

struct ControlsToolbar: View {
    @Bindable var vm: CaptureViewModel
    @Binding var filterText: String
    let filteredCount: Int
    let totalCount: Int
    @State private var showClearConfirm = false
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                startStopButton
                clearButton
                copyLogButton
                saveCSVButton
                filterField
                Spacer()
                statusPill
                eventCount
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial)

            Divider()

            if let message = vm.lastError {
                errorBadge(message: message)
            }
        }
        .confirmationDialog(
            "Clear \(vm.events.count) events?",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear", role: .destructive) { vm.clear() }
            Button("Cancel", role: .cancel) {}
        }
        .fileExporter(
            isPresented: $vm.isExporting,
            document: vm.makeCSVDocument(),
            contentType: .commaSeparatedText,
            defaultFilename: vm.defaultExportFilename()
        ) { result in
            vm.handleExport(result)
        }
    }

    private var startStopButton: some View {
        Group {
            switch vm.status {
            case .idle:
                Button {
                    vm.start()
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            case .capturing:
                Button {
                    vm.stop()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .help(toggleHotkeyHint)
    }

    /// Tooltip shown on hover for the Start/Stop button. Pulled from the live
    /// `KeyboardShortcuts` binding so it reflects user customisation made in
    /// the Settings scene. Falls back gracefully when no shortcut is set.
    private var toggleHotkeyHint: String {
        if let shortcut = KeyboardShortcuts.getShortcut(for: .toggleCapture) {
            return "Toggle capture (\(shortcut))"
        }
        return "Toggle capture (no hotkey set)"
    }

    private var clearButton: some View {
        Button {
            if vm.events.count > 50 {
                showClearConfirm = true
            } else {
                vm.clear()
            }
        } label: {
            Label("Clear", systemImage: "trash")
        }
        .buttonStyle(.bordered)
        .disabled(vm.events.isEmpty)
    }

    private var copyLogButton: some View {
        Button {
            vm.copyLog()
        } label: {
            Label("Copy Log", systemImage: "doc.on.clipboard")
        }
        .buttonStyle(.bordered)
        .disabled(vm.events.isEmpty)
    }

    private var saveCSVButton: some View {
        Button {
            vm.isExporting = true
        } label: {
            Label("Save CSV…", systemImage: "square.and.arrow.down")
        }
        .buttonStyle(.bordered)
        .disabled(vm.events.isEmpty)
    }

    private var filterField: some View {
        TextField("Filter…", text: $filterText)
            .textFieldStyle(.roundedBorder)
            .font(.subheadline)
            .frame(minWidth: 140, maxWidth: 220)
            .overlay(alignment: .trailing) {
                if !filterText.isEmpty {
                    Button {
                        filterText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 6)
                    .accessibilityLabel("Clear filter")
                }
            }
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(vm.status == .capturing ? Color.red : Color.gray)
                .frame(width: 8, height: 8)
                .opacity(vm.status == .capturing ? (pulse ? 0.4 : 1.0) : 1.0)
                .animation(
                    vm.status == .capturing
                        ? .easeInOut(duration: 1).repeatForever(autoreverses: true)
                        : .default,
                    value: pulse
                )

            Text(vm.status == .capturing ? "Capturing" : "Idle")
                .font(.subheadline)
                .foregroundStyle(vm.status == .capturing ? Color.red : Color.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(.quaternary.opacity(0.5))
        )
        .onAppear {
            if vm.status == .capturing { pulse = true }
        }
        .onChange(of: vm.status) { _, newValue in
            pulse = (newValue == .capturing)
        }
    }

    private var eventCount: some View {
        Group {
            if filteredCount != totalCount {
                Text("\(filteredCount.formatted(.number)) of \(totalCount.formatted(.number))")
            } else {
                Text(totalCount.formatted(.number))
            }
        }
        .font(.system(.subheadline, design: .monospaced))
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .frame(minWidth: 48, alignment: .trailing)
    }

    private func errorBadge(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.red)
                .lineLimit(2)
            Spacer()
            Button {
                vm.clearLastError()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.red.opacity(0.08))
    }
}

#Preview("Idle, empty") {
    @Previewable @State var filter = ""
    let vm = CaptureViewModel()
    return ControlsToolbar(
        vm: vm,
        filterText: $filter,
        filteredCount: 0,
        totalCount: 0
    )
    .frame(width: 720)
}

#Preview("Capturing") {
    @Previewable @State var filter = ""
    let vm = CaptureViewModel()
    return ControlsToolbar(
        vm: vm,
        filterText: $filter,
        filteredCount: 0,
        totalCount: 0
    )
    .frame(width: 720)
}
