import XCTest
import CoreGraphics
@testable import Tachograph

/// W3-A: pair-and-patch hold tracking. These tests exercise the
/// `recordDown` / `takeUp` dictionary helpers and the `isAutoRepeat`
/// predicate directly — they're the smallest verifiable units of the
/// callback-path logic, and the full CGEventTap loop is impractical to
/// stand up in a unit test.
final class EventTapServiceTests: XCTestCase {
    // MARK: - recordDown / takeUp pairing

    @MainActor
    func testRecordDownThenTakeUpReturnsIdAndDelta() {
        let service = EventTapService()
        let id = UUID()
        service.recordDown(.key(0x00), id: id, ns: 1_000_000_000)

        let result = service.takeUp(.key(0x00), ns: 1_500_000_000)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.0, id)
        XCTAssertEqual(result?.1, 500)
    }

    @MainActor
    func testTakeUpReturnsNilForUnpairedKey() {
        let service = EventTapService()
        let result = service.takeUp(.key(0x42), ns: 1_000_000_000)
        XCTAssertNil(result, "No prior recordDown for this key — takeUp must return nil.")
    }

    @MainActor
    func testTakeUpClampsReorderedTimestampsToZero() {
        // Defensive: if the OS ever delivers a keyUp with an earlier timestamp
        // than the matching keyDown, we clamp to 0 rather than overflowing
        // unsigned subtraction into a huge ms value.
        let service = EventTapService()
        let id = UUID()
        service.recordDown(.key(0x00), id: id, ns: 1_000_000_000)

        let result = service.takeUp(.key(0x00), ns: 500_000_000)
        XCTAssertEqual(result?.1, 0)
    }

    @MainActor
    func testRecordDownReplacesEntryWithoutDoublingFifo() {
        // Auto-repeats are filtered before recordDown is called, but if a
        // second down ever lands on a still-pending key (edge case), the
        // entry is replaced and the FIFO is not duplicated — otherwise the
        // cap test would over-count.
        let service = EventTapService()
        let firstID = UUID()
        let secondID = UUID()
        service.recordDown(.key(0x00), id: firstID, ns: 1_000_000_000)
        service.recordDown(.key(0x00), id: secondID, ns: 2_000_000_000)

        XCTAssertEqual(service.pendingDowns.count, 1)
        XCTAssertEqual(service.pendingOrder.count, 1)

        let result = service.takeUp(.key(0x00), ns: 2_500_000_000)
        XCTAssertEqual(result?.0, secondID, "Second down's id wins.")
        XCTAssertEqual(result?.1, 500)
    }

    @MainActor
    func testTakeUpClearsBothDictAndFifo() {
        let service = EventTapService()
        service.recordDown(.key(0x10), id: UUID(), ns: 1_000_000_000)
        XCTAssertEqual(service.pendingDowns.count, 1)
        XCTAssertEqual(service.pendingOrder.count, 1)

        _ = service.takeUp(.key(0x10), ns: 1_100_000_000)
        XCTAssertEqual(service.pendingDowns.count, 0)
        XCTAssertEqual(service.pendingOrder.count, 0)
    }

    @MainActor
    func testMouseAndKeyShareTheSameDictionary() {
        // .key(0) and .mouseButton(0) live in different discriminator cases
        // so the dict treats them as distinct.
        let service = EventTapService()
        let keyID = UUID()
        let mouseID = UUID()
        service.recordDown(.key(0), id: keyID, ns: 1_000_000_000)
        service.recordDown(.mouseButton(0), id: mouseID, ns: 1_000_000_000)
        XCTAssertEqual(service.pendingDowns.count, 2)

        XCTAssertEqual(service.takeUp(.key(0), ns: 1_100_000_000)?.0, keyID)
        XCTAssertEqual(service.takeUp(.mouseButton(0), ns: 1_100_000_000)?.0, mouseID)
    }

    // MARK: - Pending-downs cap (FIFO eviction)

    @MainActor
    func testPendingCapEvictsOldestEntriesFIFO() {
        let service = EventTapService()
        let total = EventTapService.pendingCap + 6  // 70 with the default cap of 64

        for i in 0..<total {
            service.recordDown(
                .key(UInt16(i)),
                id: UUID(),
                ns: UInt64(i) * 1_000_000_000
            )
        }

        XCTAssertEqual(service.pendingDowns.count, EventTapService.pendingCap)
        XCTAssertEqual(service.pendingOrder.count, EventTapService.pendingCap)

        // First `total - cap` should be evicted.
        for i in 0..<(total - EventTapService.pendingCap) {
            XCTAssertNil(
                service.pendingDowns[.key(UInt16(i))],
                "Key \(i) should have been FIFO-evicted (oldest)."
            )
        }
        // Newest cap-worth should still be pending.
        for i in (total - EventTapService.pendingCap)..<total {
            XCTAssertNotNil(
                service.pendingDowns[.key(UInt16(i))],
                "Key \(i) should still be pending (within cap window)."
            )
        }
    }

    // MARK: - isAutoRepeat predicate

    @MainActor
    func testIsAutoRepeatFalseForFreshKeyDown() {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else {
            return XCTFail("Could not synthesize CGEvent for test.")
        }
        XCTAssertFalse(EventTapService.isAutoRepeat(event))
    }

    @MainActor
    func testIsAutoRepeatTrueWhenAutorepeatFieldSet() {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else {
            return XCTFail("Could not synthesize CGEvent for test.")
        }
        event.setIntegerValueField(.keyboardEventAutorepeat, value: 1)
        XCTAssertTrue(EventTapService.isAutoRepeat(event))
    }
}
