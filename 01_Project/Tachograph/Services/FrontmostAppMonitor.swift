import AppKit
import Foundation

/// Caches the frontmost application's bundle ID so the `CGEventTap` C callback
/// can gate events without ever calling into AppKit on the high-frequency
/// callback thread.
///
/// AppKit's `NSWorkspace.shared.frontmostApplication` is NOT safe to read from
/// the CGEventTap callback (objc autorelease churn, undefined Swift 6
/// isolation), so we mirror the value into a `nonisolated(unsafe)` field that
/// the callback reads with a single pointer compare.
///
/// Per spec gotcha: notifications are async, so the first event after an app
/// switch can still arrive labeled under the previous bundle ID. We accept the
/// one-event slip — the alternative (reading AppKit inside the callback) is
/// worse.
@MainActor
final class FrontmostAppMonitor {
    /// Read by the CGEventTap C callback. Written only from the main actor in
    /// response to `NSWorkspace` notifications and at init time.
    ///
    /// We deliberately set this to `nil` for `loginwindow` / `ScreenSaver.Engine`
    /// so the service's filter check can treat those uniformly as "not
    /// capturing". The set of "uncapturable" bundle IDs is centralised in
    /// `Self.uncapturableBundleIDs` so the test helper can use the same list.
    nonisolated(unsafe) private(set) var currentBundleID: String?

    /// Bundle IDs treated as "not a real foreground app" — lock screen and
    /// screensaver. Capture is gated off while these own the front.
    static let uncapturableBundleIDs: Set<String> = [
        "com.apple.loginwindow",
        "com.apple.ScreenSaver.Engine"
    ]

    init() {
        // Seed with current state so callbacks see a sane value even before
        // the first didActivate notification fires.
        currentBundleID = Self.normalize(
            NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        )

        // Lives for the entire app lifetime — no observer cleanup needed,
        // process exit reclaims the registration. Storing the token would
        // force `nonisolated(unsafe)` on a non-Sendable property only so
        // that an empty `deinit` could touch it.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // `bundleIdentifier` is `String?` (Sendable). Pull it out *before*
            // hopping into MainActor.assumeIsolated so the non-Sendable
            // Notification / NSRunningApplication never crosses the boundary.
            let bundleID = (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            MainActor.assumeIsolated {
                self?.currentBundleID = Self.normalize(bundleID)
            }
        }
    }

    /// Maps "uncapturable" bundle IDs (loginwindow, screensaver) to `nil` so
    /// the filter check has exactly one "not capturing" sentinel to match
    /// against.
    private static func normalize(_ bundleID: String?) -> String? {
        guard let bundleID, !uncapturableBundleIDs.contains(bundleID) else {
            return nil
        }
        return bundleID
    }
}
