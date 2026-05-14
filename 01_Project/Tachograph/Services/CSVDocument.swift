import SwiftUI
import UniformTypeIdentifiers

/// `FileDocument` wrapping a pre-rendered CSV string for `.fileExporter`.
///
/// Read configuration is intentionally empty — this document only writes. Held
/// as a plain value type so it stays `nonisolated`-friendly (Swift 6 strict
/// concurrency: `FileDocument.init(configuration:)` is `nonisolated`).
struct CSVDocument: FileDocument {
    static let readableContentTypes: [UTType] = []
    static let writableContentTypes: [UTType] = [.commaSeparatedText]

    let text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        // Not used — write-only document.
        throw CocoaError(.fileReadUnsupportedScheme)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(text.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}
