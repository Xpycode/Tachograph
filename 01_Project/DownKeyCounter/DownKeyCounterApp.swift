import SwiftUI

@main
struct DownKeyCounterApp: App {
    @State private var vm = CaptureViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(vm: vm)
        }
        .defaultSize(width: 720, height: 520)
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
    }
}
