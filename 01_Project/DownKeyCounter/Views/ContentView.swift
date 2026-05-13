import SwiftUI

struct ContentView: View {
    @Bindable var vm: CaptureViewModel

    var body: some View {
        Group {
            switch vm.permissionState {
            case .denied:
                PermissionPanel()
            case .granted:
                VStack(spacing: 0) {
                    ControlsToolbar(vm: vm)
                    EventTable(events: vm.events)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .task {
            vm.refreshPermission()
        }
    }
}

#Preview("granted, idle, empty") {
    let vm = CaptureViewModel()
    return ContentView(vm: vm)
        .frame(width: 720, height: 520)
}

#Preview("denied") {
    let vm = CaptureViewModel()
    return ContentView(vm: vm)
        .frame(width: 720, height: 520)
}
