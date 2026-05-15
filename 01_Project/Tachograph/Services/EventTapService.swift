import ApplicationServices
import CoreGraphics
import Foundation

@MainActor
final class EventTapService {
    enum TapError: Error, Sendable {
        case permissionDenied
        case tapCreationFailed
        case alreadyRunning
    }

    /// Lock-free snapshot of the per-app filter state. Pushed by the
    /// `CaptureViewModel` from the main actor; read by the `CGEventTap`
    /// callback on the main run loop. Treated as immutable: replacing the
    /// snapshot whole-cloth is a single pointer store, which avoids tearing
    /// without explicit synchronisation.
    struct FilterSnapshot: Sendable {
        let enabled: Bool
        let allowedBundleIDs: Set<String>
        let captureOwnApp: Bool
        let ownBundleID: String
    }

    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    // The properties below are touched only from the CGEventTap callback,
    // which runs on the main run loop (we install the source on CFRunLoopGetMain).
    // That makes them effectively main-thread confined, but Swift 6 strict
    // concurrency can't prove it through the C trampoline — hence nonisolated(unsafe).
    private nonisolated(unsafe) var continuation: AsyncStream<EventTapMessage>.Continuation?
    private nonisolated(unsafe) var detector = ModifierTapDetector()
    private nonisolated(unsafe) var lastFlags: CGEventFlags = []
    private nonisolated(unsafe) var tap: CFMachPort?
    private nonisolated(unsafe) var source: CFRunLoopSource?
    private nonisolated(unsafe) var filterSnapshot: FilterSnapshot?

    /// Pending keyDown/mouseDown entries awaiting their matching up event.
    /// Touched only from the callback (same main-runloop reasoning as above).
    /// Exposed as `nonisolated` (not `private`) so unit tests can exercise
    /// `recordDown`/`takeUp` directly without driving a real CGEventTap.
    nonisolated(unsafe) var pendingDowns: [HoldKey: (id: UUID, downNs: UInt64)] = [:]
    nonisolated(unsafe) var pendingOrder: [HoldKey] = []
    /// FIFO cap. System chords (Cmd+Tab, Cmd+Space) can swallow keyUp events,
    /// leaving orphan entries. The cap keeps memory bounded over long sessions
    /// at the cost of "forgetting" the very oldest unresolved down — its row
    /// permanently shows `holdMs = nil`, which is the same outcome it would
    /// have had with an infinite dictionary.
    nonisolated static let pendingCap = 64

    /// Constructor-injected so the callback can read the frontmost bundle ID
    /// without a `Task { await }` hop. Held strongly: in production the same
    /// instance is also kept alive by `TachographApp` + `CaptureViewModel`,
    /// but a strong ref here keeps tests that construct an `EventTapService`
    /// in isolation safe — no surprise deallocation of a default-constructed
    /// monitor.
    private nonisolated let monitor: FrontmostAppMonitor

    private nonisolated static let modifierMask: CGEventFlags = [
        .maskCommand, .maskShift, .maskControl, .maskAlternate, .maskSecondaryFn
    ]

    init(monitor: FrontmostAppMonitor = FrontmostAppMonitor()) {
        self.monitor = monitor
    }

    func start() throws -> AsyncStream<EventTapMessage> {
        guard Self.isAccessibilityTrusted else { throw TapError.permissionDenied }
        guard tap == nil else { throw TapError.alreadyRunning }

        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.rightMouseUp.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue)

        // passUnretained: the service is owned by its @MainActor caller; the tap's
        // lifetime is bounded by stop(), so we never need a retained reference here.
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let machPort = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: refcon
        ) else {
            throw TapError.tapCreationFailed
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, machPort, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: machPort, enable: true)

        self.tap = machPort
        self.source = runLoopSource
        self.detector = ModifierTapDetector()
        self.lastFlags = []
        self.pendingDowns = [:]
        self.pendingOrder = []

        let stream = AsyncStream<EventTapMessage> { continuation in
            self.continuation = continuation
        }
        return stream
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        tap = nil
        source = nil
        continuation?.finish()
        continuation = nil
        detector = ModifierTapDetector()
        lastFlags = []
        filterSnapshot = nil
        // Pending hold entries are cleared on stop — any in-flight row keeps
        // holdMs = nil rather than receiving a stale update on the next start.
        pendingDowns = [:]
        pendingOrder = []
    }

    /// Replaces the live filter snapshot used by the callback's gating check.
    /// Called from `CaptureViewModel.start()` and any time the user mutates
    /// `AppFilterStore` while capture is running. Whole-snapshot replacement
    /// keeps the callback's read lock-free — the worst case is one event
    /// recorded under the previous snapshot (matches the documented
    /// notification-timing slip for the FrontmostAppMonitor).
    func updateFilterSnapshot(_ snapshot: FilterSnapshot?) {
        self.filterSnapshot = snapshot
    }

    fileprivate nonisolated func handle(type: CGEventType, event: CGEvent) {
        // tapDisabledByTimeout / tapDisabledByUserInput require re-enabling
        // the tap to keep capture alive; otherwise the stream silently dies.
        // Per spec: keep this branch ABOVE the filter check.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return
        }

        // Snapshot + frontmost ID are both lock-free reads. Read frontmost
        // ONCE here so the same value gates the filter and stamps the
        // outgoing event — avoids a race where the decision sees app A and
        // the event records app B.
        let frontmost = monitor.currentBundleID
        guard Self.shouldCapture(
            snapshot: filterSnapshot,
            currentBundleID: frontmost
        ) else {
            return
        }

        switch type {
        case .keyDown:
            // Auto-repeat keyDowns are synthesized by the OS while a key is
            // held. Drop them entirely — both the row and the dictionary entry
            // — so a long press measures as ONE row spanning the full
            // press-to-release window rather than N rows each measuring a
            // single repeat-to-release fragment.
            if Self.isAutoRepeat(event) { return }
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let label = KeyNameMapper.label(forKeyCode: keyCode, modifiers: event.flags)
            _ = detector.process(.keyDown)
            let row = InputEvent(kind: .key, label: label, intervalMs: nil, bundleID: frontmost)
            recordDown(.key(keyCode), id: row.id, ns: event.timestamp)
            yield(.append(row))

        case .keyUp:
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            if let (id, ms) = takeUp(.key(keyCode), ns: event.timestamp) {
                yield(.holdUpdate(id: id, holdMs: ms))
            }

        case .flagsChanged:
            let current = event.flags.intersection(Self.modifierMask)
            let previous = lastFlags.intersection(Self.modifierMask)
            let pressedBits = current.subtracting(previous)
            let releasedBits = previous.subtracting(current)
            lastFlags = current

            for flag in Self.singleBitFlags(in: pressedBits) {
                guard let modifier = Self.modifier(forFlag: flag) else { continue }
                _ = detector.process(.modifierPressed(modifier))
            }
            for flag in Self.singleBitFlags(in: releasedBits) {
                guard let modifier = Self.modifier(forFlag: flag) else { continue }
                if let emitted = detector.process(.modifierReleased(modifier)),
                   let label = KeyNameMapper.modifierOnlyLabel(for: Self.flag(for: emitted)) {
                    yield(.append(InputEvent(kind: .modifier, label: label, intervalMs: nil, bundleID: frontmost)))
                }
            }

        case .leftMouseDown:
            let row = InputEvent(kind: .mouse, label: "Left Click", intervalMs: nil, bundleID: frontmost)
            recordDown(.mouseButton(0), id: row.id, ns: event.timestamp)
            yield(.append(row))

        case .leftMouseUp:
            if let (id, ms) = takeUp(.mouseButton(0), ns: event.timestamp) {
                yield(.holdUpdate(id: id, holdMs: ms))
            }

        case .rightMouseDown:
            let row = InputEvent(kind: .mouse, label: "Right Click", intervalMs: nil, bundleID: frontmost)
            recordDown(.mouseButton(1), id: row.id, ns: event.timestamp)
            yield(.append(row))

        case .rightMouseUp:
            if let (id, ms) = takeUp(.mouseButton(1), ns: event.timestamp) {
                yield(.holdUpdate(id: id, holdMs: ms))
            }

        case .otherMouseDown:
            let button = event.getIntegerValueField(.mouseEventButtonNumber)
            let row = InputEvent(kind: .mouse, label: "Mouse \(button + 1)", intervalMs: nil, bundleID: frontmost)
            recordDown(.mouseButton(button), id: row.id, ns: event.timestamp)
            yield(.append(row))

        case .otherMouseUp:
            let button = event.getIntegerValueField(.mouseEventButtonNumber)
            if let (id, ms) = takeUp(.mouseButton(button), ns: event.timestamp) {
                yield(.holdUpdate(id: id, holdMs: ms))
            }

        default:
            break
        }
    }

    private nonisolated func yield(_ message: EventTapMessage) {
        continuation?.yield(message)
    }

    /// Pure predicate for the keyDown auto-repeat filter — extracted so the
    /// drop-on-repeat decision can be unit-tested without driving a real
    /// CGEventTap.
    nonisolated static func isAutoRepeat(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.keyboardEventAutorepeat) != 0
    }

    /// Records a down event in the pending dictionary. If the key is already
    /// present (defensive — auto-repeats are filtered, so in practice this
    /// only fires on edge cases like flushed keyUps), the existing entry is
    /// replaced without touching the FIFO order. At cap, the oldest entry is
    /// evicted FIFO; its row's holdMs stays nil permanently.
    nonisolated func recordDown(_ key: HoldKey, id: UUID, ns: UInt64) {
        if pendingDowns[key] != nil {
            pendingDowns[key] = (id, ns)
            return
        }
        if pendingDowns.count >= Self.pendingCap, !pendingOrder.isEmpty {
            let oldest = pendingOrder.removeFirst()
            pendingDowns.removeValue(forKey: oldest)
        }
        pendingDowns[key] = (id, ns)
        pendingOrder.append(key)
    }

    /// Removes a pending entry and returns (id, holdMs) for the matching up
    /// event. Returns nil if no entry exists (system-chord swallowed keyUp,
    /// pendingCap eviction, or events from before the last start()).
    /// Uses `event.timestamp` for both endpoints — nanoseconds since boot,
    /// monotonic, captured by the OS at event time, immune to clock skew.
    nonisolated func takeUp(_ key: HoldKey, ns: UInt64) -> (UUID, Int)? {
        guard let entry = pendingDowns.removeValue(forKey: key) else { return nil }
        // O(n) but n ≤ pendingCap (64), so this stays well inside the <50 ms
        // callback budget.
        pendingOrder.removeAll { $0 == key }
        let nsDelta: UInt64 = ns >= entry.downNs ? ns - entry.downNs : 0
        let ms = Int(min(nsDelta / 1_000_000, UInt64(Int.max)))
        return (entry.id, ms)
    }

    /// Pure decision function for "should we record this event?" — extracted
    /// so it can be exhaustively unit-tested without a real CGEventTap.
    ///
    /// Rules (in order):
    /// 1. `nil` snapshot OR `!enabled` → capture (filter inactive).
    /// 2. Empty `allowedBundleIDs` → capture (spec: avoid the "nothing
    ///    recording" mystery when the feature is half-configured).
    /// 3. `nil` currentBundleID → don't capture (loginwindow/screensaver/no
    ///    frontmost app — the monitor maps those to `nil`).
    /// 4. currentBundleID == ownBundleID && !captureOwnApp → don't capture.
    /// 5. currentBundleID ∈ allowedBundleIDs → capture.
    /// 6. otherwise → don't capture.
    nonisolated static func shouldCapture(
        snapshot: FilterSnapshot?,
        currentBundleID: String?
    ) -> Bool {
        guard let snapshot, snapshot.enabled else { return true }
        if snapshot.allowedBundleIDs.isEmpty { return true }
        guard let currentBundleID else { return false }
        if currentBundleID == snapshot.ownBundleID && !snapshot.captureOwnApp {
            return false
        }
        return snapshot.allowedBundleIDs.contains(currentBundleID)
    }

    private nonisolated static func singleBitFlags(in flags: CGEventFlags) -> [CGEventFlags] {
        var result: [CGEventFlags] = []
        for candidate in [CGEventFlags.maskSecondaryFn, .maskControl, .maskAlternate, .maskShift, .maskCommand] {
            if flags.contains(candidate) { result.append(candidate) }
        }
        return result
    }

    private nonisolated static func modifier(forFlag flag: CGEventFlags) -> ModifierTapDetector.Modifier? {
        switch flag {
        case .maskCommand:      return .command
        case .maskShift:        return .shift
        case .maskControl:      return .control
        case .maskAlternate:    return .option
        case .maskSecondaryFn:  return .fn
        default:                return nil
        }
    }

    private nonisolated static func flag(for modifier: ModifierTapDetector.Modifier) -> CGEventFlags {
        switch modifier {
        case .command:  return .maskCommand
        case .shift:    return .maskShift
        case .control:  return .maskControl
        case .option:   return .maskAlternate
        case .fn:       return .maskSecondaryFn
        }
    }
}

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if let userInfo {
        let service = Unmanaged<EventTapService>.fromOpaque(userInfo).takeUnretainedValue()
        service.handle(type: type, event: event)
    }
    return Unmanaged.passUnretained(event)
}
