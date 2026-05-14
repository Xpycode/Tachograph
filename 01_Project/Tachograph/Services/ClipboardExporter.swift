import AppKit
import Foundation

enum ClipboardExporter {
    static func tsv(for events: [InputEvent]) -> String {
        DelimitedExporter.render(
            events: events,
            delimiter: "\t",
            quote: nil,
            lineEnding: "\n"
        )
    }

    static func copyToPasteboard(_ events: [InputEvent]) {
        let payload = tsv(for: events)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(payload, forType: .string)
    }
}
