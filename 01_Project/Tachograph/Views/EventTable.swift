import SwiftUI

struct EventTable: View {
    let events: [InputEvent]

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var body: some View {
        if events.isEmpty {
            emptyState
        } else {
            table
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "keyboard")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Press Start, then type.")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Events will appear here.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var table: some View {
        ScrollViewReader { proxy in
            Table(events) {
                TableColumn("Key / Button") { event in
                    Text(event.label)
                        .font(.system(.body, design: .monospaced))
                        .id(event.id)
                }
                .width(min: 140)

                TableColumn("UTC Time") { event in
                    Text(Self.displayFormatter.string(from: event.utcTimestamp))
                        .font(.system(.body, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .width(min: 200)

                TableColumn("Δ (ms)") { event in
                    HStack {
                        Spacer()
                        Text(verbatim: event.intervalMs.map { $0.formatted(.number.grouping(.never)) } ?? "—")
                            .font(.system(.body, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(event.intervalMs == nil ? .tertiary : .primary)
                    }
                }
                .width(min: 80, ideal: 80)
            }
            .onChange(of: events.count) { _, _ in
                guard let lastID = events.last?.id else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
        }
    }
}

#Preview("With events") {
    let base = Date(timeIntervalSince1970: 1_747_166_537.103)
    let samples: [InputEvent] = [
        InputEvent(kind: .key, label: "⌘ A", utcTimestamp: base, intervalMs: nil),
        InputEvent(kind: .key, label: "Space", utcTimestamp: base.addingTimeInterval(0.138), intervalMs: 138),
        InputEvent(kind: .mouse, label: "Left Click", utcTimestamp: base.addingTimeInterval(0.899), intervalMs: 761),
        InputEvent(kind: .key, label: "Esc", utcTimestamp: base.addingTimeInterval(1.347), intervalMs: 448),
        InputEvent(kind: .modifier, label: "⌘", utcTimestamp: base.addingTimeInterval(1.902), intervalMs: 555)
    ]
    return EventTable(events: samples)
        .frame(width: 600, height: 400)
}

#Preview("Empty") {
    EventTable(events: [])
        .frame(width: 600, height: 400)
}
