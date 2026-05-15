import XCTest
@testable import Tachograph

final class ClipboardExporterTests: XCTestCase {
    private let header = "Key / Button\tApp\tUTC Time\tΔ (ms)"
    private let isoRegex = #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$"#

    func testEmptyEventsProducesHeaderOnlyWithNoTrailingNewline() {
        let tsv = ClipboardExporter.tsv(for: [])
        XCTAssertEqual(tsv, header)
        XCTAssertFalse(tsv.hasSuffix("\n"))
    }

    func testSingleEventWithNilIntervalHasEmptyIntervalCell() {
        let date = Date(timeIntervalSince1970: 1_747_164_137.103)
        let event = InputEvent(
            kind: .key,
            label: "⌘ A",
            utcTimestamp: date,
            intervalMs: nil
        )

        let tsv = ClipboardExporter.tsv(for: [event])
        let lines = tsv.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0], header)

        let fields = lines[1].components(separatedBy: "\t")
        XCTAssertEqual(fields.count, 4)
        XCTAssertEqual(fields[0], "⌘ A")
        XCTAssertEqual(fields[1], "", "App cell empty when bundleID is nil")
        XCTAssertEqual(fields[3], "")
        XCTAssertNotNil(
            fields[2].range(of: isoRegex, options: .regularExpression),
            "Timestamp '\(fields[2])' did not match ISO 8601 UTC ms format"
        )
    }

    func testTwoEventsSecondRowShowsIntegerInterval() {
        let first = InputEvent(
            kind: .key,
            label: "⌘ A",
            utcTimestamp: Date(timeIntervalSince1970: 1_747_164_137.103),
            intervalMs: nil
        )
        let second = InputEvent(
            kind: .key,
            label: "Space",
            utcTimestamp: Date(timeIntervalSince1970: 1_747_164_137.241),
            intervalMs: 138
        )

        let tsv = ClipboardExporter.tsv(for: [first, second])
        let lines = tsv.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[0], header)

        let firstFields = lines[1].components(separatedBy: "\t")
        XCTAssertEqual(firstFields[0], "⌘ A")
        XCTAssertEqual(firstFields[3], "")

        let secondFields = lines[2].components(separatedBy: "\t")
        XCTAssertEqual(secondFields.count, 4)
        XCTAssertEqual(secondFields[0], "Space")
        XCTAssertEqual(secondFields[3], "138")
    }

    // Labels containing tab characters are undefined input per spec — the
    // exporter does not currently escape them. This test documents that
    // behavior: a tab inside `label` will split into extra TSV fields.
    func testLabelContainingTabIsNotEscaped() {
        let event = InputEvent(
            kind: .key,
            label: "Weird\tLabel",
            utcTimestamp: Date(timeIntervalSince1970: 1_747_164_137.103),
            intervalMs: 42
        )

        let tsv = ClipboardExporter.tsv(for: [event])
        let rowLine = tsv.components(separatedBy: "\n")[1]
        let fields = rowLine.components(separatedBy: "\t")
        XCTAssertEqual(fields.count, 5, "Tab inside label is currently unescaped, splitting one of the four base cells into two.")
    }

    func testIsoTimestampShapeMatchesRegex() {
        let event = InputEvent(
            kind: .mouse,
            label: "Left Click",
            utcTimestamp: Date(timeIntervalSince1970: 1_747_164_138.002),
            intervalMs: 761
        )

        let tsv = ClipboardExporter.tsv(for: [event])
        let fields = tsv.components(separatedBy: "\n")[1].components(separatedBy: "\t")
        XCTAssertNotNil(
            fields[2].range(of: isoRegex, options: .regularExpression),
            "Timestamp '\(fields[2])' did not match ISO 8601 UTC ms format"
        )
        XCTAssertTrue(fields[2].hasSuffix("Z"))
    }
}
