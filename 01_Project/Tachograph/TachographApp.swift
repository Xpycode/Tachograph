import SwiftUI

@main
struct TachographApp: App {
    @State private var vm: CaptureViewModel
    @State private var hotkey: HotkeyService

    init() {
        let vm = CaptureViewModel()
        self._vm = State(initialValue: vm)
        self._hotkey = State(initialValue: HotkeyService(vm: vm))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(vm: vm)
                .task { hotkey.register() }
        }
        .defaultSize(width: 1040, height: 560)
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
            SettingsView()
        }
    }
}
