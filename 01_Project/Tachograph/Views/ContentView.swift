import SwiftUI

struct ContentView: View {
    @Bindable var vm: CaptureViewModel
    /// Optional so the existing previews that pass only `vm` keep working.
    /// Production wires the shared instance from `TachographApp`.
    var store: AppFilterStore?
    @State private var filterText: String = ""

    var body: some View {
        Group {
            switch vm.permissionState {
            case .denied:
                PermissionPanel()
            case .granted:
                let filtered = EventFilter.filter(events: vm.events, query: filterText)
                VStack(spacing: 0) {
                    ControlsToolbar(
                        vm: vm,
                        store: store ?? vm.store,
                        filterText: $filterText,
                        filteredCount: filtered.count,
                        totalCount: vm.events.count
                    )
                    EventTable(events: filtered, filterText: filterText)
                }
            }
        }
        .frame(minWidth: 1140, minHeight: 400)
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
