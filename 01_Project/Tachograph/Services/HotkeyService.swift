import Foundation
import KeyboardShortcuts

/// Wires the global toggle-capture hotkey to the `CaptureViewModel`.
///
/// `KeyboardShortcuts` uses Carbon's `RegisterEventHotKey` under the hood,
/// which consumes the key event so it does not leak to the focused app.
/// The handler closure is invoked on the main actor.
@MainActor
final class HotkeyService {
    /// Held weakly so the service can be owned by `TachographApp` alongside
    /// the VM without forming a retain cycle.
    private weak var vm: CaptureViewModel?

    init(vm: CaptureViewModel) {
        self.vm = vm
    }

    /// Registers the toggle-capture handler. Safe to call multiple times:
    /// `KeyboardShortcuts.onKeyDown(for:)` replaces any prior handler bound
    /// to the same name, so re-registration is idempotent.
    func register() {
        KeyboardShortcuts.onKeyDown(for: .toggleCapture) { [weak self] in
            self?.vm?.toggle()
        }
    }
}
