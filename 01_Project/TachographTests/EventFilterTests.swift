import XCTest
@testable import Tachograph

final class EventFilterTests: XCTestCase {
    // MARK: - Fixtures

    private let base = Date(timeIntervalSince1970: 1_747_166_537.103)

    private func sampleEvents() -> [InputEvent] {
        [
            InputEvent(kind: .key, label: "⌘ A", utcTimestamp: base, intervalMs: nil),
            InputEvent(kind: .key, label: "Space", utcTimestamp: base.addingTimeInterval(0.1), intervalMs: 100),
            InputEvent(kind: .mouse, label: "Left Click", utcTimestamp: base.addingTimeInterval(0.2), intervalMs: 100),
            InputEvent(kind: .key, label: "Esc", utcTimestamp: base.addingTimeInterval(0.3), intervalMs: 100),
            InputEvent(kind: .modifier, label: "⌘", utcTimestamp: base.addingTimeInterval(0.4), intervalMs: 100)
        ]
    }

    // MARK: - Tests

    func testEmptyQueryReturnsAllEvents() {
        let events = sampleEvents()
        let result = EventFilter.filter(events: events, query: "")
        XCTAssertEqual(result.count, events.count)
        XCTAssertEqual(result.map(\.id), events.map(\.id))
    }

    func testWhitespaceOnlyQueryReturnsAllEvents() {
        let events = sampleEvents()
        let result = EventFilter.filter(events: events, query: "   \t\n  ")
        XCTAssertEqual(result.count, events.count)
    }

    func testCaseInsensitiveMatch() {
        // Lowercase "a" should match the label "⌘ A".
        let events = sampleEvents()
        let result = EventFilter.filter(events: events, query: "a")
        let labels = result.map(\.label)
        XCTAssertTrue(labels.contains("⌘ A"), "Expected case-insensitive match on '⌘ A' for query 'a'")
        // "Space" also contains a lowercase 'a' (S-p-a-c-e); confirm match.
        XCTAssertTrue(labels.contains("Space"))
    }

    func testSymbolMatch() {
        // Typing '⌘' should match both "⌘ A" and "⌘".
        let events = sampleEvents()
        let result = EventFilter.filter(events: events, query: "⌘")
        let labels = result.map(\.label)
        XCTAssertEqual(labels.sorted(), ["⌘", "⌘ A"].sorted())
    }

    func testNoMatchReturnsEmpty() {
        let events = sampleEvents()
        let result = EventFilter.filter(events: events, query: "xyz")
        XCTAssertTrue(result.isEmpty)
    }

    func testQueryTrimsWhitespace() {
        // "  click  " should behave like "click" and match "Left Click".
        let events = sampleEvents()
        let result = EventFilter.filter(events: events, query: "  click  ")
        XCTAssertEqual(result.map(\.label), ["Left Click"])
    }

    func testEmptyEventsReturnsEmpty() {
        let result = EventFilter.filter(events: [], query: "anything")
        XCTAssertTrue(result.isEmpty)
    }

    func testSubstringInMiddle() {
        // "pac" matches "Space".
        let events = sampleEvents()
        let result = EventFilter.filter(events: events, query: "pac")
        XCTAssertEqual(result.map(\.label), ["Space"])
    }
}
