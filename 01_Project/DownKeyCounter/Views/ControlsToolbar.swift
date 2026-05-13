import SwiftUI

struct ControlsToolbar: View {
    @Bindable var vm: CaptureViewModel
    @State private var showClearConfirm = false
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                startStopButton
                clearButton
                copyLogButton
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
        Text(vm.events.count.formatted(.number))
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
    let vm = CaptureViewModel()
    return ControlsToolbar(vm: vm)
        .frame(width: 720)
}

#Preview("Capturing") {
    let vm = CaptureViewModel()
    return ControlsToolbar(vm: vm)
        .frame(width: 720)
}
