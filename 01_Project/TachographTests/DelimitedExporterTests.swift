import XCTest
@testable import Tachograph

final class DelimitedExporterTests: XCTestCase {
    private let csvHeader = "Key / Button,UTC Time,Δ (ms)"
    private let isoRegex = #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$"#

    // MARK: - Header / empty-events

    func testEmptyEventsProducesCsvHeaderOnlyWithNoTrailingNewline() {
        let csv = renderCSV(events: [])
        XCTAssertEqual(csv, csvHeader)
        XCTAssertFalse(csv.hasSuffix("\n"))
        XCTAssertFalse(csv.hasSuffix("\r"))
    }

    func testCsvHeaderMatchesSpec() {
        let csv = renderCSV(events: [])
        XCTAssertEqual(csv, "Key / Button,UTC Time,Δ (ms)")
    }

    // MARK: - Row terminator

    func testCsvRowsAreJoinedWithCRLF() {
        let event = makeEvent(label: "Space", intervalMs: 138)
        let csv = renderCSV(events: [event])

        XCTAssertTrue(csv.contains("\r\n"), "CSV rows must be separated by CRLF")

        let lines = csv.components(separatedBy: "\r\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0], csvHeader)
        XCTAssertFalse(csv.hasSuffix("\r\n"), "No trailing newline expected")
    }

    // MARK: - Quoting rules

    func testFieldWithoutSpecialCharsIsUnquoted() {
        let event = makeEvent(label: "Space", intervalMs: 42)
        let csv = renderCSV(events: [event])
        let row = csv.components(separatedBy: "\r\n")[1]
        let cells = row.components(separatedBy: ",")

        XCTAssertEqual(cells.first, "Space")
        XCTAssertFalse(row.contains("\""), "Plain label should not be quoted")
    }

    func testLabelContainingCommaGetsQuoted() {
        let event = makeEvent(label: "a,b", intervalMs: 10)
        let csv = renderCSV(events: [event])
        let row = csv.components(separatedBy: "\r\n")[1]

        XCTAssertTrue(row.hasPrefix("\"a,b\","), "Label with comma must be wrapped in quotes; got: \(row)")
    }

    func testLabelContainingQuoteIsWrappedAndDoubled() {
        let event = makeEvent(label: "She said \"hi\"", intervalMs: 10)
        let csv = renderCSV(events: [event])
        let row = csv.components(separatedBy: "\r\n")[1]

        XCTAssertTrue(
            row.hasPrefix("\"She said \"\"hi\"\"\","),
            "Quote chars inside the field must be doubled and the whole field wrapped; got: \(row)"
        )
    }

    func testLabelContainingNewlineGetsQuoted() {
        let event = makeEvent(label: "line1\nline2", intervalMs: 10)
        let csv = renderCSV(events: [event])

        // We can't safely split by \r\n because the field itself contains \n.
        // Instead, assert the quoted form appears in the output.
        XCTAssertTrue(
            csv.contains("\"line1\nline2\""),
            "Label with embedded newline must be wrapped in quotes; got: \(csv)"
        )
    }

    func testLabelContainingCarriageReturnGetsQuoted() {
        let event = makeEvent(label: "line1\rline2", intervalMs: 10)
        let csv = renderCSV(events: [event])

        XCTAssertTrue(
            csv.contains("\"line1\rline2\""),
            "Label with embedded CR must be wrapped in quotes; got: \(csv)"
        )
    }

    // MARK: - Cell content

    func testNilIntervalRendersAsEmptyCell() {
        let event = makeEvent(label: "⌘ A", intervalMs: nil)
        let csv = renderCSV(events: [event])
        let row = csv.components(separatedBy: "\r\n")[1]
        let cells = row.components(separatedBy: ",")

        XCTAssertEqual(cells.count, 3)
        XCTAssertEqual(cells[0], "⌘ A")
        XCTAssertEqual(cells[2], "")
        XCTAssertNotNil(
            cells[1].range(of: isoRegex, options: .regularExpression),
            "Timestamp '\(cells[1])' did not match ISO 8601 UTC ms format"
        )
    }

    func testTwoEventsSecondRowShowsInterval() {
        let first = makeEvent(label: "⌘ A", intervalMs: nil)
        let second = makeEvent(label: "Space", intervalMs: 138)

        let csv = renderCSV(events: [first, second])
        let lines = csv.components(separatedBy: "\r\n")
        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[0], csvHeader)

        let secondFields = lines[2].components(separatedBy: ",")
        XCTAssertEqual(secondFields.count, 3)
        XCTAssertEqual(secondFields[0], "Space")
        XCTAssertEqual(secondFields[2], "138")
    }

    // MARK: - Helpers

    private func renderCSV(events: [InputEvent]) -> String {
        DelimitedExporter.render(
            events: events,
            delimiter: ",",
            quote: "\"",
            lineEnding: "\r\n"
        )
    }

    private func makeEvent(label: String, intervalMs: Int?) -> InputEvent {
        InputEvent(
            kind: .key,
            label: label,
            utcTimestamp: Date(timeIntervalSince1970: 1_747_164_137.103),
            intervalMs: intervalMs
        )
    }
}
