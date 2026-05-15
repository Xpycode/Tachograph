import AppKit
import Foundation

/// Resolves a bundle ID to a human-readable app name, with a small in-memory
/// cache. Used by both `EventTable` (to show "App" cells) and `SettingsView`
/// (to label rows in the allow-list).
///
/// The cache is `@MainActor` because all callers are SwiftUI views; it survives
/// for the lifetime of the app process so repeated lookups during a long
/// capture session don't re-hit `NSWorkspace`.
@MainActor
enum AppDisplayNameLookup {
    private static var cache: [String: String] = [:]

    /// Returns a localized app name for the bundle ID, falling back to the
    /// bundle ID itself if no lookup succeeds. Returns `nil` only when the
    /// caller passed `nil` — useful so the table can render `"—"` for events
    /// that have no associated app (monitor not seeded, screensaver, etc.).
    static func displayName(for bundleID: String?) -> String? {
        guard let bundleID, !bundleID.isEmpty else { return nil }
        if let cached = cache[bundleID] { return cached }

        let resolved = resolve(bundleID)
        cache[bundleID] = resolved
        return resolved
    }

    private static func resolve(_ bundleID: String) -> String {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
           let name = app.localizedName {
            return name
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
           let name = Bundle(url: url)?.infoDictionary?["CFBundleName"] as? String {
            return name
        }
        return bundleID
    }
}
