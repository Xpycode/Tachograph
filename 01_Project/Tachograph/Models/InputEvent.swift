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
    /// Frontmost-app bundle ID at the moment the event fired. nil when the
    /// monitor hasn't seeded yet, or for "uncapturable" frontmost (loginwindow,
    /// screensaver — see FrontmostAppMonitor.normalize).
    let bundleID: String?

    init(
        kind: Kind,
        label: String,
        utcTimestamp: Date = Date(),
        intervalMs: Int?,
        bundleID: String? = nil
    ) {
        self.id = UUID()
        self.kind = kind
        self.label = label
        self.utcTimestamp = utcTimestamp
        self.intervalMs = intervalMs
        self.bundleID = bundleID
    }
}
