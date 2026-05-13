import AppKit
import Foundation

enum ClipboardExporter {
    private static let header = "Key / Button\tUTC Time\tΔ (ms)"

    static func tsv(for events: [InputEvent]) -> String {
        let formatter = makeFormatter()
        var lines: [String] = [header]
        lines.reserveCapacity(events.count + 1)
        for event in events {
            let timestamp = formatter.string(from: event.utcTimestamp)
            let intervalCell = event.intervalMs.map(String.init) ?? ""
            lines.append("\(event.label)\t\(timestamp)\t\(intervalCell)")
        }
        return lines.joined(separator: "\n")
    }

    static func copyToPasteboard(_ events: [InputEvent]) {
        let payload = tsv(for: events)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(payload, forType: .string)
    }

    private static func makeFormatter() -> ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }
}
