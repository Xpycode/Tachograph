import XCTest
@testable import Tachograph

/// Covers the per-app capture filter:
/// - `AppFilterStore` mutation + persistence semantics (against an isolated
///   `UserDefaults(suiteName:)` so the dev box's real defaults are untouched).
/// - `EventTapService.shouldCapture(snapshot:currentBundleID:)` decision
///   matrix — exhaustively covers the rules documented on that function.
///
/// We deliberately do NOT exercise `FrontmostAppMonitor`'s notification
/// observer here; firing real `NSWorkspace` activation notifications from a
/// test bundle isn't practical and the only logic worth testing has been
/// pulled into the pure `shouldCapture` function.
final class AppFilterTests: XCTestCase {

    // MARK: - AppFilterStore

    /// Returns a fresh `AppFilterStore` backed by an isolated `UserDefaults`
    /// suite so each test runs against a clean slate without polluting the
    /// dev box's defaults.
    @MainActor
    private func makeIsolatedStore() -> (AppFilterStore, UserDefaults) {
        let suiteName = "TachographTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (AppFilterStore(defaults: defaults), defaults)
    }

    @MainActor
    func testStoreDefaultsAreDisabledEmptyExcludeOwn() {
        let (store, _) = makeIsolatedStore()
        XCTAssertFalse(store.enabled)
        XCTAssertTrue(store.allowedBundleIDs.isEmpty)
        XCTAssertFalse(store.captureOwnApp)
    }

    @MainActor
    func testStoreAddBundleIDPersistsAndDeduplicates() {
        let (store, defaults) = makeIsolatedStore()
        store.addBundleID("com.example.A")
        store.addBundleID("com.example.B")
        store.addBundleID("com.example.A")  // duplicate, must be ignored
        XCTAssertEqual(store.allowedBundleIDs, ["com.example.A", "com.example.B"])
        XCTAssertEqual(
            defaults.array(forKey: AppFilterStore.allowedBundleIDsKey) as? [String],
            ["com.example.A", "com.example.B"]
        )
    }

    @MainActor
    func testStoreAddBundleIDIgnoresEmptyOrWhitespace() {
        let (store, _) = makeIsolatedStore()
        store.addBundleID("")
        store.addBundleID("   ")
        XCTAssertTrue(store.allowedBundleIDs.isEmpty)
    }

    @MainActor
    func testStoreRemoveBundleID() {
        let (store, _) = makeIsolatedStore()
        store.addBundleID("com.example.A")
        store.addBundleID("com.example.B")
        store.removeBundleID("com.example.A")
        XCTAssertEqual(store.allowedBundleIDs, ["com.example.B"])
        store.removeBundleID("not.present")  // no-op
        XCTAssertEqual(store.allowedBundleIDs, ["com.example.B"])
    }

    @MainActor
    func testStoreContains() {
        let (store, _) = makeIsolatedStore()
        store.addBundleID("com.example.A")
        XCTAssertTrue(store.contains(bundleID: "com.example.A"))
        XCTAssertFalse(store.contains(bundleID: "com.example.B"))
    }

    @MainActor
    func testStoreEnabledPersists() {
        let (store, defaults) = makeIsolatedStore()
        store.enabled = true
        XCTAssertTrue(defaults.bool(forKey: AppFilterStore.enabledKey))
        store.enabled = false
        XCTAssertFalse(defaults.bool(forKey: AppFilterStore.enabledKey))
    }

    @MainActor
    func testStoreCaptureOwnAppPersists() {
        let (store, defaults) = makeIsolatedStore()
        store.captureOwnApp = true
        XCTAssertTrue(defaults.bool(forKey: AppFilterStore.captureOwnAppKey))
    }

    @MainActor
    func testStoreRehydrateFromDefaults() {
        let suiteName = "TachographTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(true, forKey: AppFilterStore.enabledKey)
        defaults.set(["com.example.X", "com.example.Y"], forKey: AppFilterStore.allowedBundleIDsKey)
        defaults.set(true, forKey: AppFilterStore.captureOwnAppKey)

        let store = AppFilterStore(defaults: defaults)
        XCTAssertTrue(store.enabled)
        XCTAssertEqual(store.allowedBundleIDs, ["com.example.X", "com.example.Y"])
        XCTAssertTrue(store.captureOwnApp)
    }

    @MainActor
    func testStoreSnapshotNilWhenDisabled() {
        let (store, _) = makeIsolatedStore()
        store.enabled = false
        store.addBundleID("com.example.A")
        XCTAssertNil(store.makeSnapshot(ownBundleID: "com.tachograph"))
    }

    @MainActor
    func testStoreSnapshotMirrorsStateWhenEnabled() {
        let (store, _) = makeIsolatedStore()
        store.enabled = true
        store.captureOwnApp = true
        store.addBundleID("com.example.A")
        store.addBundleID("com.example.B")
        let snap = store.makeSnapshot(ownBundleID: "com.tachograph")
        XCTAssertNotNil(snap)
        XCTAssertTrue(snap!.enabled)
        XCTAssertTrue(snap!.captureOwnApp)
        XCTAssertEqual(snap!.ownBundleID, "com.tachograph")
        XCTAssertEqual(snap!.allowedBundleIDs, ["com.example.A", "com.example.B"])
    }

    // MARK: - EventTapService.shouldCapture decision matrix

    private func snapshot(
        enabled: Bool = true,
        allow: [String] = [],
        captureOwn: Bool = false,
        own: String = "com.tachograph"
    ) -> EventTapService.FilterSnapshot {
        EventTapService.FilterSnapshot(
            enabled: enabled,
            allowedBundleIDs: Set(allow),
            captureOwnApp: captureOwn,
            ownBundleID: own
        )
    }

    func testShouldCaptureNilSnapshotIsTrue() {
        XCTAssertTrue(EventTapService.shouldCapture(snapshot: nil, currentBundleID: "anything"))
        XCTAssertTrue(EventTapService.shouldCapture(snapshot: nil, currentBundleID: nil))
    }

    func testShouldCaptureDisabledSnapshotIsTrue() {
        let s = snapshot(enabled: false, allow: ["com.example.A"])
        XCTAssertTrue(EventTapService.shouldCapture(snapshot: s, currentBundleID: "com.unknown"))
    }

    func testShouldCaptureEmptyAllowListIsTrue() {
        let s = snapshot(enabled: true, allow: [])
        // Spec: empty allow list = capture everything (no surprise blackout).
        XCTAssertTrue(EventTapService.shouldCapture(snapshot: s, currentBundleID: "com.anything"))
        XCTAssertTrue(EventTapService.shouldCapture(snapshot: s, currentBundleID: nil))
    }

    func testShouldCaptureMatchingFrontmostIsTrue() {
        let s = snapshot(allow: ["com.example.A", "com.example.B"])
        XCTAssertTrue(EventTapService.shouldCapture(snapshot: s, currentBundleID: "com.example.A"))
        XCTAssertTrue(EventTapService.shouldCapture(snapshot: s, currentBundleID: "com.example.B"))
    }

    func testShouldCaptureNonMatchingFrontmostIsFalse() {
        let s = snapshot(allow: ["com.example.A"])
        XCTAssertFalse(EventTapService.shouldCapture(snapshot: s, currentBundleID: "com.elsewhere"))
    }

    func testShouldCaptureNilFrontmostIsFalseWhenFiltering() {
        // nil currentBundleID == loginwindow/screensaver/no frontmost. We
        // never capture in that state when a non-empty allow-list is set.
        let s = snapshot(allow: ["com.example.A"])
        XCTAssertFalse(EventTapService.shouldCapture(snapshot: s, currentBundleID: nil))
    }

    func testShouldCaptureOwnAppWithCaptureOwnFalseIsFalse() {
        let s = snapshot(allow: ["com.tachograph"], captureOwn: false, own: "com.tachograph")
        XCTAssertFalse(EventTapService.shouldCapture(snapshot: s, currentBundleID: "com.tachograph"))
    }

    func testShouldCaptureOwnAppWithCaptureOwnTrueIsTrue() {
        let s = snapshot(allow: ["com.tachograph"], captureOwn: true, own: "com.tachograph")
        XCTAssertTrue(EventTapService.shouldCapture(snapshot: s, currentBundleID: "com.tachograph"))
    }

    func testShouldCaptureOwnAppNotInAllowListWithCaptureOwnTrueStillFalse() {
        // captureOwnApp doesn't BYPASS the allow list — it only un-blocks own
        // app when it IS in the list. If own app isn't allow-listed, it stays
        // filtered out regardless of the toggle.
        let s = snapshot(allow: ["com.example.A"], captureOwn: true, own: "com.tachograph")
        XCTAssertFalse(EventTapService.shouldCapture(snapshot: s, currentBundleID: "com.tachograph"))
    }
}
