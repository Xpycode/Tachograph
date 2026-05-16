import XCTest
@testable import Tachograph

final class CaptureViewModelTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_747_164_137.0)

    func testIntervalMsNilPreviousReturnsNil() {
        XCTAssertNil(CaptureViewModel.intervalMs(from: nil, to: base))
    }

    func testIntervalMsZeroApart() {
        XCTAssertEqual(CaptureViewModel.intervalMs(from: base, to: base), 0)
    }

    func testIntervalMs138ms() {
        let current = base.addingTimeInterval(0.138)
        XCTAssertEqual(CaptureViewModel.intervalMs(from: base, to: current), 138)
    }

    func testIntervalMs1000ms() {
        let current = base.addingTimeInterval(1.0)
        XCTAssertEqual(CaptureViewModel.intervalMs(from: base, to: current), 1000)
    }

    func testIntervalMsRoundsDownAtPoint4() {
        let current = base.addingTimeInterval(0.1374)
        XCTAssertEqual(CaptureViewModel.intervalMs(from: base, to: current), 137)
    }

    func testIntervalMsRoundsUpAtPoint6() {
        let current = base.addingTimeInterval(0.1376)
        XCTAssertEqual(CaptureViewModel.intervalMs(from: base, to: current), 138)
    }

    func testIntervalMsClampsNegativeToZero() {
        let previous = base.addingTimeInterval(0.5)
        XCTAssertEqual(CaptureViewModel.intervalMs(from: previous, to: base), 0)
    }

    @MainActor
    func testInitialStateIsIdleDeniedEmpty() {
        let vm = CaptureViewModel()
        XCTAssertEqual(vm.status, .idle)
        XCTAssertEqual(vm.permissionState, .denied)
        XCTAssertTrue(vm.events.isEmpty)
        XCTAssertNil(vm.lastError)
    }

    // MARK: - W3-A applyHold patch path

    @MainActor
    func testApplyHoldUpdatesMatchingRow() {
        let vm = CaptureViewModel()
        let raw = InputEvent(kind: .key, label: "A", utcTimestamp: base, intervalMs: nil)
        vm.append(raw: raw)

        vm.applyHold(id: raw.id, ms: 420)
        XCTAssertEqual(vm.events.count, 1)
        XCTAssertEqual(vm.events[0].holdMs, 420)
    }

    @MainActor
    func testApplyHoldDropsSilentlyForUnknownId() {
        let vm = CaptureViewModel()
        let raw = InputEvent(kind: .key, label: "A", utcTimestamp: base, intervalMs: nil)
        vm.append(raw: raw)

        // Patching with a UUID that doesn't match any row is a no-op (the row
        // may have been Clear'd between down and up, or evicted by the
        // pendingDowns FIFO cap on the service side).
        vm.applyHold(id: UUID(), ms: 999)
        XCTAssertEqual(vm.events.count, 1)
        XCTAssertNil(vm.events[0].holdMs)
    }

    @MainActor
    func testApplyHoldOnlyMutatesMatchingRow() {
        let vm = CaptureViewModel()
        let first = InputEvent(kind: .key, label: "A", utcTimestamp: base, intervalMs: nil)
        let second = InputEvent(kind: .key, label: "B", utcTimestamp: base.addingTimeInterval(0.1), intervalMs: 100)
        vm.append(raw: first)
        vm.append(raw: second)

        vm.applyHold(id: second.id, ms: 250)
        XCTAssertNil(vm.events[0].holdMs, "First row must remain untouched.")
        XCTAssertEqual(vm.events[1].holdMs, 250)
    }

    @MainActor
    func testAppendPreservesRawId() {
        // The pair-and-patch flow depends on the VM keeping the id that the
        // service used when seeding pendingDowns. If append(raw:) ever minted
        // a fresh UUID again (as it did pre-W3-A), applyHold would never
        // match its target.
        let vm = CaptureViewModel()
        let raw = InputEvent(kind: .key, label: "A", utcTimestamp: base, intervalMs: nil)
        vm.append(raw: raw)
        XCTAssertEqual(vm.events.first?.id, raw.id)
    }
}
