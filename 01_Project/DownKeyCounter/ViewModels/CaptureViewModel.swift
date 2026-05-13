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
