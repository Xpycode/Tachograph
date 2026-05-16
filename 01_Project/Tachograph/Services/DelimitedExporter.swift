import Foundation

/// Pure delimited-text serializer shared by TSV (clipboard) and CSV (file) exports.
///
/// Quoting strategy:
/// - When `quote` is `nil`, fields are emitted verbatim (TSV-compatible — labels with
///   embedded delimiters are treated as undefined input, matching the original
///   `ClipboardExporter` contract).
/// - When `quote` is non-`nil`, a field is wrapped in the quote character iff it
///   contains the delimiter, the quote character itself, `\n`, or `\r`. Embedded
///   quotes are escaped by doubling (RFC 4180).
///
/// The output never has a trailing line terminator.
///
/// The "App" column emits the bundle ID raw (e.g. `com.apple.Safari`) because
/// it's machine-readable, locale-stable, and joinable in a spreadsheet. The
/// display name is shown in the in-app table only.
enum DelimitedExporter {
    static let headerCells: [String] = ["Key / Button", "App", "UTC Time", "Δ (ms)", "Hold (ms)"]

    static func render(
        events: [InputEvent],
        delimiter: String,
        quote: Character?,
        lineEnding: String
    ) -> String {
        let formatter = makeFormatter()
        var lines: [String] = []
        lines.reserveCapacity(events.count + 1)

        let headerRow = headerCells
            .map { encode($0, delimiter: delimiter, quote: quote) }
            .joined(separator: delimiter)
        lines.append(headerRow)

        for event in events {
            let timestamp = formatter.string(from: event.utcTimestamp)
            let intervalCell = event.intervalMs.map(String.init) ?? ""
            // Empty string (not "—") for nil holds so downstream tooling
            // parses the numeric column cleanly — same convention as Δ (ms).
            let holdCell = event.holdMs.map(String.init) ?? ""
            let appCell = event.bundleID ?? ""
            let cells = [event.label, appCell, timestamp, intervalCell, holdCell]
                .map { encode($0, delimiter: delimiter, quote: quote) }
            lines.append(cells.joined(separator: delimiter))
        }

        return lines.joined(separator: lineEnding)
    }

    private static func encode(
        _ field: String,
        delimiter: String,
        quote: Character?
    ) -> String {
        guard let quote else { return field }

        let quoteString = String(quote)
        let needsQuoting = field.contains(delimiter)
            || field.contains(quoteString)
            || field.contains("\n")
            || field.contains("\r")

        guard needsQuoting else { return field }

        let escaped = field.replacingOccurrences(of: quoteString, with: quoteString + quoteString)
        return quoteString + escaped + quoteString
    }

    private static func makeFormatter() -> ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }
}
