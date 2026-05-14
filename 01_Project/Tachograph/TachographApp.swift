import SwiftUI

@main
struct TachographApp: App {
    @State private var vm = CaptureViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(vm: vm)
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
    }
}
