import XCTest
@testable import DownKeyCounter

final class ModifierTapDetectorTests: XCTestCase {

    private func process(_ inputs: [ModifierTapDetector.Input]) -> [ModifierTapDetector.Modifier] {
        var detector = ModifierTapDetector()
        var emitted: [ModifierTapDetector.Modifier] = []
        for input in inputs {
            if let m = detector.process(input) {
                emitted.append(m)
            }
        }
        return emitted
    }

    func testTap_commandPressReleaseEmitsCommand() {
        let result = process([.modifierPressed(.command), .modifierReleased(.command)])
        XCTAssertEqual(result, [.command])
    }

    func testCombine_commandThenKeyDownThenReleaseEmitsNothing() {
        let result = process([.modifierPressed(.command), .keyDown, .modifierReleased(.command)])
        XCTAssertEqual(result, [])
    }

    func testTap_twoModifiersHeldThenReleasedEmitBoth() {
        let result = process([
            .modifierPressed(.command),
            .modifierPressed(.shift),
            .modifierReleased(.shift),
            .modifierReleased(.command)
        ])
        XCTAssertEqual(result, [.shift, .command])
    }

    func testCombine_twoModifiersHeldKeyDownEmitsNothing() {
        let result = process([
            .modifierPressed(.command),
            .modifierPressed(.shift),
            .keyDown,
            .modifierReleased(.shift),
            .modifierReleased(.command)
        ])
        XCTAssertEqual(result, [])
    }

    func testMixed_shiftHadKeyDownCommandReleasedFirstEmitsOnlyCommand() {
        let result = process([
            .modifierPressed(.shift),
            .modifierPressed(.command),
            .modifierReleased(.command),
            .keyDown,
            .modifierReleased(.shift)
        ])
        XCTAssertEqual(result, [.command])
    }

    func testOrphanRelease_emitsNothing() {
        let result = process([.modifierReleased(.command)])
        XCTAssertEqual(result, [])
    }

    func testIdempotentPress_doublePressThenReleaseEmitsOnce() {
        let result = process([
            .modifierPressed(.command),
            .modifierPressed(.command),
            .modifierReleased(.command)
        ])
        XCTAssertEqual(result, [.command])
    }

    func testKeyDownWithNoModifiersHeld_emitsNothing() {
        let result = process([.keyDown, .keyDown])
        XCTAssertEqual(result, [])
    }
}
