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
    /// Per-key/per-button press duration in milliseconds. nil while the
    /// press is still held, or when the keyUp was swallowed by a system
    /// shortcut (Cmd+Tab etc.). Patched onto the row by
    /// CaptureViewModel.applyHold(id:ms:) when the matching keyUp arrives.
    /// Modifier rows (flagsChanged) keep this nil — their press/release
    /// semantics live in ModifierTapDetector, not the holdMs path.
    var holdMs: Int?
    /// Frontmost-app bundle ID at the moment the event fired. nil when the
    /// monitor hasn't seeded yet, or for "uncapturable" frontmost (loginwindow,
    /// screensaver — see FrontmostAppMonitor.normalize).
    let bundleID: String?

    init(
        kind: Kind,
        label: String,
        utcTimestamp: Date = Date(),
        intervalMs: Int?,
        holdMs: Int? = nil,
        bundleID: String? = nil
    ) {
        self.id = UUID()
        self.kind = kind
        self.label = label
        self.utcTimestamp = utcTimestamp
        self.intervalMs = intervalMs
        self.holdMs = holdMs
        self.bundleID = bundleID
    }
}
