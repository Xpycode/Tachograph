import SwiftUI

@main
struct TachographApp: App {
    @State private var vm: CaptureViewModel
    @State private var hotkey: HotkeyService
    @State private var store: AppFilterStore

    init() {
        // Shared singletons live on TachographApp so toolbar + Settings see
        // the same `AppFilterStore`, and the EventTapService + Settings agree
        // on which app is frontmost.
        let monitor = FrontmostAppMonitor()
        let store = AppFilterStore()
        let vm = CaptureViewModel(monitor: monitor, store: store)
        self._vm = State(initialValue: vm)
        self._hotkey = State(initialValue: HotkeyService(vm: vm))
        self._store = State(initialValue: store)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(vm: vm, store: store)
                .task { hotkey.register() }
        }
        .defaultSize(width: 1180, height: 560)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .pasteboard) {
                Button("Copy Log") {
                    vm.copyLog()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(vm.events.isEmpty)
            }
        }

        Settings {
            SettingsView(store: store, vm: vm)
        }
        .windowResizability(.contentSize)
    }
}
