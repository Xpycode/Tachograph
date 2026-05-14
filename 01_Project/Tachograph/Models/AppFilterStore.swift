import Foundation
import Observation

/// Persistent settings for the per-app capture filter.
///
/// `@AppStorage` doesn't bridge `[String]` cleanly, so this wraps a
/// `UserDefaults` instance manually. The `@Observable` macro makes SwiftUI
/// re-render when any of the stored values change, matching the pattern
/// already used by `CaptureViewModel`.
///
/// Persistence keys (also defined as static constants for tests):
/// - `filter.enabled` — `Bool`, default `false`
/// - `filter.allowedBundleIDs` — `[String]`, default `[]`
/// - `filter.captureOwnApp` — `Bool`, default `false`
///
/// **Empty allow-list contract:** when `enabled == true` and
/// `allowedBundleIDs` is empty, capture still records everything (matches the
/// existing pre-W2-B behaviour and avoids the "nothing recording" mystery when
/// the feature is half-configured).
@MainActor
@Observable
final class AppFilterStore {
    static let enabledKey = "filter.enabled"
    static let allowedBundleIDsKey = "filter.allowedBundleIDs"
    static let captureOwnAppKey = "filter.captureOwnApp"

    /// Injected so tests can use a private in-memory `UserDefaults(suiteName:)`
    /// and not pollute the dev box's defaults.
    @ObservationIgnored
    private let defaults: UserDefaults

    var enabled: Bool {
        didSet { defaults.set(enabled, forKey: Self.enabledKey) }
    }

    var allowedBundleIDs: [String] {
        didSet { defaults.set(allowedBundleIDs, forKey: Self.allowedBundleIDsKey) }
    }

    var captureOwnApp: Bool {
        didSet { defaults.set(captureOwnApp, forKey: Self.captureOwnAppKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.enabled = defaults.bool(forKey: Self.enabledKey)
        self.allowedBundleIDs = (defaults.array(forKey: Self.allowedBundleIDsKey) as? [String]) ?? []
        self.captureOwnApp = defaults.bool(forKey: Self.captureOwnAppKey)
    }

    func addBundleID(_ bundleID: String) {
        let trimmed = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !allowedBundleIDs.contains(trimmed) else { return }
        allowedBundleIDs.append(trimmed)
    }

    func removeBundleID(_ bundleID: String) {
        allowedBundleIDs.removeAll { $0 == bundleID }
    }

    func contains(bundleID: String) -> Bool {
        allowedBundleIDs.contains(bundleID)
    }

    /// Snapshot of allow-list for the service's lock-free callback path.
    /// Returns `nil` when the filter is disabled — the service treats `nil` as
    /// "no gating", matching pre-W2-B behaviour.
    func makeSnapshot(ownBundleID: String) -> EventTapService.FilterSnapshot? {
        guard enabled else { return nil }
        return EventTapService.FilterSnapshot(
            enabled: true,
            allowedBundleIDs: Set(allowedBundleIDs),
            captureOwnApp: captureOwnApp,
            ownBundleID: ownBundleID
        )
    }
}
