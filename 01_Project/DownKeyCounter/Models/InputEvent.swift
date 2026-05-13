import Foundation

struct InputEvent: Identifiable, Sendable {
    enum Kind: Sendable {
        case key
        case modifier
        case mouse
    }

    let id: UUID
    let kind: Kind
    let label: String
    let utcTimestamp: Date
    let intervalMs: Int?

    init(
        kind: Kind,
        label: String,
        utcTimestamp: Date = Date(),
        intervalMs: Int?
    ) {
        self.id = UUID()
        self.kind = kind
        self.label = label
        self.utcTimestamp = utcTimestamp
        self.intervalMs = intervalMs
    }
}
