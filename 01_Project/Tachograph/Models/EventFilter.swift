import Foundation

/// Pure, case-insensitive substring filter over `InputEvent.label`.
///
/// Owned by `ContentView` (filter state is local UI state, not VM state).
/// Extracted into a static helper so it can be unit-tested without spinning
/// up SwiftUI views — see `TachographTests/EventFilterTests.swift`.
enum EventFilter {
    /// Returns `events` filtered by a case-insensitive substring match on `label`.
    ///
    /// - Empty / whitespace-only `query` → returns the full input array unchanged.
    /// - Otherwise → returns events whose `label` contains the trimmed query
    ///   (case-insensitive).
    static func filter(events: [InputEvent], query: String) -> [InputEvent] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return events }
        return events.filter { event in
            event.label.range(of: trimmed, options: .caseInsensitive) != nil
        }
    }
}
