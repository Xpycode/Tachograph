import Foundation
import Observation

@MainActor
@Observable
final class CaptureViewModel {
    enum Status: Sendable { case idle, capturing }
    enum PermissionState: Sendable { case granted, denied }

    private(set) var events: [InputEvent] = []
    private(set) var status: Status = .idle
    private(set) var permissionState: PermissionState = .denied
    private(set) var lastError: String?

    /// Two-way binding target for SwiftUI's `.fileExporter(isPresented:)`. Must
    /// remain a stored, settable `var` — `private(set)` would block the binding.
    var isExporting: Bool = false

    private let service: EventTapService
    private var consumeTask: Task<Void, Never>?
    private var lastTimestamp: Date?

    init(service: EventTapService = EventTapService()) {
        self.service = service
    }

    func refreshPermission() {
        permissionState = EventTapService.isAccessibilityTrusted ? .granted : .denied
    }

    func start() {
        guard permissionState == .granted, status != .capturing else { return }
        lastError = nil
        let stream: AsyncStream<InputEvent>
        do {
            stream = try service.start()
        } catch {
            lastError = String(describing: error)
            return
        }
        status = .capturing
        consumeTask = Task { @MainActor [weak self] in
            for await raw in stream {
                guard let self else { break }
                self.append(raw: raw)
            }
        }
    }

    func stop() {
        consumeTask?.cancel()
        consumeTask = nil
        service.stop()
        status = .idle
    }

    /// Toggles capture state. Invoked by the global hotkey as well as any
    /// future programmatic callers. Refreshes accessibility permission first
    /// so a denied state surfaces the existing error rather than silently
    /// no-op'ing — `start()` would otherwise just `guard` past.
    func toggle() {
        refreshPermission()
        guard permissionState == .granted else {
            lastError = "Accessibility permission required."
            return
        }
        switch status {
        case .idle:
            start()
        case .capturing:
            stop()
        }
    }

    func clear() {
        events.removeAll()
        lastTimestamp = nil
    }

    func copyLog() {
        ClipboardExporter.copyToPasteboard(events)
    }

    func clearLastError() {
        lastError = nil
    }

    func makeCSVDocument() -> CSVDocument {
        let csv = DelimitedExporter.render(
            events: events,
            delimiter: ",",
            quote: "\"",
            lineEnding: "\r\n"
        )
        return CSVDocument(text: csv)
    }

    /// Default filename suggested to `.fileExporter` — no extension (the system
    /// appends `.csv`), no `:` (display-safe on macOS). Uses local timezone so
    /// the suggested name matches the user's wall clock; `en_US_POSIX` locale
    /// keeps the digits stable across user locales.
    func defaultExportFilename() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        return "Tachograph \(formatter.string(from: Date()))"
    }

    func handleExport(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            lastError = nil
        case .failure(let error):
            // CocoaError(.userCancelled) is delivered as a thrown error on
            // older builds in some seeds; tolerate by suppressing the standard
            // cancellation case. Everything else surfaces in the error badge.
            if let cocoa = error as? CocoaError, cocoa.code == .userCancelled {
                return
            }
            lastError = "Export failed: \(error.localizedDescription)"
        }
    }

    nonisolated static func intervalMs(from previous: Date?, to current: Date) -> Int? {
        guard let previous else { return nil }
        let ms = (current.timeIntervalSince(previous) * 1000.0).rounded()
        return max(0, Int(ms))
    }

    private func append(raw: InputEvent) {
        let interval = Self.intervalMs(from: lastTimestamp, to: raw.utcTimestamp)
        let event = InputEvent(
            kind: raw.kind,
            label: raw.label,
            utcTimestamp: raw.utcTimestamp,
            intervalMs: interval
        )
        events.append(event)
        lastTimestamp = raw.utcTimestamp
    }
}
