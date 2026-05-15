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
    private nonisolated(unsafe) var continuation: AsyncStream<InputEvent>.Continuation?
    private nonisolated(unsafe) var detector = ModifierTapDetector()
    private nonisolated(unsafe) var lastFlags: CGEventFlags = []
    private nonisolated(unsafe) var tap: CFMachPort?
    private nonisolated(unsafe) var source: CFRunLoopSource?
    private nonisolated(unsafe) var filterSnapshot: FilterSnapshot?

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

    func start() throws -> AsyncStream<InputEvent> {
        guard Self.isAccessibilityTrusted else { throw TapError.permissionDenied }
        guard tap == nil else { throw TapError.alreadyRunning }

        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue)

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

        let stream = AsyncStream<InputEvent> { continuation in
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
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let label = KeyNameMapper.label(forKeyCode: keyCode, modifiers: event.flags)
            _ = detector.process(.keyDown)
            yield(InputEvent(kind: .key, label: label, intervalMs: nil, bundleID: frontmost))

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
                    yield(InputEvent(kind: .modifier, label: label, intervalMs: nil, bundleID: frontmost))
                }
            }

        case .leftMouseDown:
            yield(InputEvent(kind: .mouse, label: "Left Click", intervalMs: nil, bundleID: frontmost))

        case .rightMouseDown:
            yield(InputEvent(kind: .mouse, label: "Right Click", intervalMs: nil, bundleID: frontmost))

        case .otherMouseDown:
            let button = event.getIntegerValueField(.mouseEventButtonNumber)
            yield(InputEvent(kind: .mouse, label: "Mouse \(button + 1)", intervalMs: nil, bundleID: frontmost))

        default:
            break
        }
    }

    private nonisolated func yield(_ event: InputEvent) {
        continuation?.yield(event)
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
