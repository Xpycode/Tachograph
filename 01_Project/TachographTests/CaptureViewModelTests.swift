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
}
