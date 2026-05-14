import XCTest
@testable import Tachograph

/// Tests for `CaptureViewModel.toggle()` — the entry point used by the global
/// hotkey (W2-A).
///
/// Coverage notes:
/// - The `.denied` branch is fully covered; it does not touch `EventTapService`.
/// - The `.granted → start()` and `.capturing → stop()` branches are *not*
///   covered here because `EventTapService.start()` installs a real
///   `CGEventTap` against the host process. In a unit-test bundle without
///   Accessibility trust the call would fail, and even if it succeeded the
///   side effect would leak across tests. Verified manually in the running app.
/// - `HotkeyService` registration idempotency is delegated to
///   `KeyboardShortcuts.onKeyDown(for:)`, which the upstream library already
///   guarantees by replacing prior handlers for the same `Name`. Not mocked.
final class CaptureViewModelToggleTests: XCTestCase {
    @MainActor
    func testToggleWithDeniedPermissionSetsErrorAndKeepsStatusIdle() throws {
        try XCTSkipIf(
            EventTapService.isAccessibilityTrusted,
            "Skipped on Accessibility-trusted host; this test exercises the denied branch only."
        )
        let vm = CaptureViewModel()
        vm.toggle()

        XCTAssertEqual(vm.status, .idle)
        XCTAssertEqual(vm.permissionState, .denied)
        XCTAssertEqual(vm.lastError, "Accessibility permission required.")
    }

    @MainActor
    func testToggleWithDeniedPermissionDoesNotAppendEvents() throws {
        try XCTSkipIf(
            EventTapService.isAccessibilityTrusted,
            "Skipped on Accessibility-trusted host; this test exercises the denied branch only."
        )
        let vm = CaptureViewModel()
        vm.toggle()
        XCTAssertTrue(vm.events.isEmpty)
    }
}
