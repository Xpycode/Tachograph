import Carbon.HIToolbox
import CoreGraphics
import XCTest
@testable import DownKeyCounter

final class KeyNameMapperTests: XCTestCase {
    func testPlainLetter() {
        XCTAssertEqual(
            KeyNameMapper.label(forKeyCode: UInt16(kVK_ANSI_A), modifiers: []),
            "A"
        )
    }

    func testLetterWithCommand() {
        XCTAssertEqual(
            KeyNameMapper.label(forKeyCode: UInt16(kVK_ANSI_A), modifiers: .maskCommand),
            "⌘ A"
        )
    }

    func testLetterWithShiftCommand() {
        XCTAssertEqual(
            KeyNameMapper.label(
                forKeyCode: UInt16(kVK_ANSI_A),
                modifiers: [.maskCommand, .maskShift]
            ),
            "⇧ ⌘ A"
        )
    }

    func testLetterWithAllStandardModifiers() {
        XCTAssertEqual(
            KeyNameMapper.label(
                forKeyCode: UInt16(kVK_ANSI_A),
                modifiers: [.maskCommand, .maskShift, .maskAlternate, .maskControl]
            ),
            "⌃ ⌥ ⇧ ⌘ A"
        )
    }

    func testDigit() {
        XCTAssertEqual(
            KeyNameMapper.label(forKeyCode: UInt16(kVK_ANSI_1), modifiers: []),
            "1"
        )
    }

    func testSpace() {
        XCTAssertEqual(
            KeyNameMapper.label(forKeyCode: UInt16(kVK_Space), modifiers: []),
            "Space"
        )
    }

    func testReturn() {
        XCTAssertEqual(
            KeyNameMapper.label(forKeyCode: UInt16(kVK_Return), modifiers: []),
            "Return"
        )
    }

    func testEscape() {
        XCTAssertEqual(
            KeyNameMapper.label(forKeyCode: UInt16(kVK_Escape), modifiers: []),
            "Esc"
        )
    }

    func testLeftArrow() {
        XCTAssertEqual(
            KeyNameMapper.label(forKeyCode: UInt16(kVK_LeftArrow), modifiers: []),
            "←"
        )
    }

    func testRightArrow() {
        XCTAssertEqual(
            KeyNameMapper.label(forKeyCode: UInt16(kVK_RightArrow), modifiers: []),
            "→"
        )
    }

    func testUpArrow() {
        XCTAssertEqual(
            KeyNameMapper.label(forKeyCode: UInt16(kVK_UpArrow), modifiers: []),
            "↑"
        )
    }

    func testDownArrow() {
        XCTAssertEqual(
            KeyNameMapper.label(forKeyCode: UInt16(kVK_DownArrow), modifiers: []),
            "↓"
        )
    }

    func testF1() {
        XCTAssertEqual(
            KeyNameMapper.label(forKeyCode: UInt16(kVK_F1), modifiers: []),
            "F1"
        )
    }

    func testF12() {
        XCTAssertEqual(
            KeyNameMapper.label(forKeyCode: UInt16(kVK_F12), modifiers: []),
            "F12"
        )
    }

    func testUnknownKeyCodeFallback() {
        XCTAssertEqual(
            KeyNameMapper.label(forKeyCode: 0xFFFF, modifiers: []),
            "Key(65535)"
        )
    }

    func testModifierOnlyCommand() {
        XCTAssertEqual(KeyNameMapper.modifierOnlyLabel(for: .maskCommand), "⌘")
    }

    func testModifierOnlyShift() {
        XCTAssertEqual(KeyNameMapper.modifierOnlyLabel(for: .maskShift), "⇧")
    }

    func testModifierOnlyAlternate() {
        XCTAssertEqual(KeyNameMapper.modifierOnlyLabel(for: .maskAlternate), "⌥")
    }

    func testModifierOnlyControl() {
        XCTAssertEqual(KeyNameMapper.modifierOnlyLabel(for: .maskControl), "⌃")
    }

    func testModifierOnlyFn() {
        XCTAssertEqual(KeyNameMapper.modifierOnlyLabel(for: .maskSecondaryFn), "fn")
    }

    func testModifierOnlyCombinedReturnsNil() {
        XCTAssertNil(
            KeyNameMapper.modifierOnlyLabel(for: [.maskCommand, .maskShift])
        )
    }

    func testModifierOnlyEmptyReturnsNil() {
        XCTAssertNil(KeyNameMapper.modifierOnlyLabel(for: []))
    }
}
