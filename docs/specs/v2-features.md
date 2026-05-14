# Spec: Tachograph v2 — Feature Wave

**Status:** draft (planning complete, awaiting wave-1 implementation)
**Owner:** gm.konsortium@yahoo.dk
**Created:** 2026-05-14
**Source ideas:** `docs/ideas.md` (entries below promoted out)

---

## Scope

Six features from `docs/ideas.md` promoted into v2:

1. **Key-hold duration column** (reverses the 2026-05-13 decision)
2. **Pause/resume global hotkey**
3. **Filter / search box**
4. **Per-app capture filter** (allow list)
5. **Heat-map / histogram view**
6. **CSV export to file**

Not in v2 (still parked): rolling buffer, multi-session history, menu bar mode, sound on key press, auto-clear after N minutes.

---

## Cross-feature decisions (resolve before Wave 1)

| # | Decision | Resolution |
|---|---|---|
| CFD-1 | One Settings scene or two? | **One.** Built in Wave 2 with sections for Hotkey + App Filter. |
| CFD-2 | 3rd-party SPM dep for hotkey? | **Yes — `sindresorhus/KeyboardShortcuts`** (Carbon under the hood, *consumes* event, includes SwiftUI Recorder). First 3rd-party dep in the project. |
| CFD-3 | When does the event-tap stream change shape? | **Wave 3 only.** Per-app filter (Wave 2) lands while stream still yields `InputEvent` directly. Wave 3 converts to `AsyncStream<EventTapMessage>` for key-hold pairing. |
| CFD-4 | How to reverse the 2026-05-13 "no key-hold" decision? | Add a superseding entry to `docs/decisions.md` as part of Wave 3, documenting the chosen pairing strategy. |

Each of these gets a full entry in `docs/decisions.md` (status: pending until landed).

---

## Wave 1 — Quick wins (parallel, S)

Two isolated features, zero overlap. Land both before moving on.

### W1-A · CSV export to file

**Recommendation.** Add `Save as CSV…` as a sibling button next to `Copy Log` using SwiftUI's `.fileExporter` modifier with a `FileDocument`. Extract a shared `DelimitedExporter` so TSV stays byte-identical and CSV gets RFC 4180 quoting.

**API.** `.fileExporter` (not raw `NSSavePanel`) — declarative, no `runModal` juggling. `UTType.commaSeparatedText` for the content type.

**CSV rules.** RFC 4180 with defensive quoting:
- Quote a field iff it contains `,`, `"`, `\n`, or `\r`.
- Escape `"` → `""` inside quoted fields.
- Line ending: `\r\n` between rows (Excel-friendly).
- Header row included. No trailing newline (mirror existing TSV behaviour).

**Default filename.** `Tachograph 2026-05-14 14-32-08.csv` via `en_US_POSIX` formatter (no `:` for display safety).

**Files touched.**
- `Services/ClipboardExporter.swift` — refactor to delegate to `DelimitedExporter`; public TSV API unchanged.
- `Services/DelimitedExporter.swift` *(new)* — `static func render(events:delimiter:quote:lineEnding:) -> String` + shared ISO8601 formatter.
- `Services/CSVDocument.swift` *(new)* — `FileDocument` wrapping a `String`, `.commaSeparatedText` writable type.
- `ViewModels/CaptureViewModel.swift` — add stored `var isExporting: Bool`, `makeCSVDocument()`, `defaultExportFilename()`, `handleExport(_:)`.
- `Views/ControlsToolbar.swift` — add `saveCSVButton` + `.fileExporter` modifier bound to `vm.isExporting`.
- `TachographTests/ClipboardExporterTests.swift` — CSV quoting cases (`,`, `"`, `\n`), `""` escaping, `\r\n` rows, empty-events.

**Gotchas.**
- `isExporting` must be a stored `var` on the `@Observable` VM (not `private(set)`) so `.fileExporter`'s `isPresented:` can bind two-way.
- Don't unify line endings between TSV (`\n`) and CSV (`\r\n`) — parameterize.

**Complexity.** S. ~120 LOC.

---

### W1-B · Filter / search box

**Recommendation.** Plain `TextField` inside `ControlsToolbar` (left of `Spacer()`, after Copy Log). **Not** `.searchable` — that wrecks the material toolbar layout. Filter state lives in `ContentView` as `@State filterText: String`, passed down via binding.

**Predicate.** Case-insensitive substring on `label` only:

```swift
filterText.isEmpty
  ? events
  : events.filter { $0.label.range(of: trimmed, options: .caseInsensitive) != nil }
```

No kind chips, no time range, no aliases. Typing `⌘` already filters command-modified keys; typing `click` already matches `Left Click` / `Right Click`. Minimum useful.

**Counter.** When filter active, render `"12 of 348"` (filtered/total). When empty, render `348`.

**Auto-scroll.** Keep enabled on the filtered list. New unmatched events don't change `filtered.last?.id`, so the view stays put — desired behaviour.

**Empty filtered state.** When `events.isEmpty == false && filtered.isEmpty`, show `"No events match '<query>'."` (reuse existing emptyState shell).

**Clear button semantics.** Confirmed: Clear wipes *all* events even while filter is active. The search field's trailing X clears the filter independently. Confirmation dialog says "Clear all 348 events?" regardless of filter.

**Files touched.**
- `Views/ContentView.swift` — owns `@State filterText`; passes filtered array + counter pair down.
- `Views/ControlsToolbar.swift` — `@Binding var filterText`, TextField, "N of M" counter.
- `Views/EventTable.swift` — auto-scroll triggers on filtered `last?.id`, not bare `events.count`.

**Performance.** 10k events × substring check on short labels ≪ 1ms on Apple Silicon. `Table` virtualizes rendering. No debouncing in v1; revisit only if profiling shows jank.

**Gotchas.**
- Auto-scroll anchor must follow filtered last id, not raw events count.
- Don't let Clear button become "clear filtered" — single semantics.

**Complexity.** S. ~40 LOC across 3 files.

---

## Wave 2 — System-level surfaces (sequential, S/M)

Both add the shared `SettingsView.swift`. **Land W2-A first** (smaller, no event-tap mutation), then W2-B which extends the same Settings scene.

### W2-A · Pause/resume global hotkey

**Recommendation.** Use `sindresorhus/KeyboardShortcuts` (SPM, `from: "2.2.0"`). Uses Carbon `RegisterEventHotKey` under the hood — *consumes* the press so it doesn't leak to the focused app. Ships a SwiftUI `Recorder` view + native `UserDefaults` persistence.

**Default combo.** `⌃⌥⌘R` (Control-Option-Command-R) — four-key chord, no known system collisions, mnemonic for "Record".

**Why not the alternatives:**
- `NSEvent.addGlobalMonitorForEvents` — observe-only, can't consume. Hotkey leaks to focused app. ✗
- Upgrade existing CGEventTap to non-listenOnly — forces whole capture path through return-decision logic, risks <50ms budget. ✗
- Raw Carbon — works but reimplements what `KeyboardShortcuts` already does. ✗

**Persistence.** `KeyboardShortcuts` handles it in `UserDefaults`. Do **not** also bind via `@AppStorage` — single source of truth.

**Lifecycle.** Register at app launch unconditionally (even when capture is idle).

**Files touched.**
- `TachographApp.swift` — instantiate `HotkeyService(vm:)`, add `Settings { SettingsView(...) }` scene.
- `ViewModels/CaptureViewModel.swift` — add `func toggle()` (idle → start, capturing → stop).
- `Services/HotkeyService.swift` *(new)* — `@MainActor` wrapper around `KeyboardShortcuts.Name.toggleCapture` registration.
- `Models/HotkeyName.swift` *(new)* — `extension KeyboardShortcuts.Name { static let toggleCapture = ... }`.
- `Views/SettingsView.swift` *(new)* — Settings scene; first section: hotkey Recorder + Reset to default.
- `Views/ControlsToolbar.swift` — show the current shortcut as a hint next to Start/Stop.
- `project.yml` — SPM dep.

**Gotchas.**
- Accessibility-permission interplay: `RegisterEventHotKey` doesn't need Accessibility, but `vm.start()` does. `toggle()` must `refreshPermission()` first and surface the existing denied-state error.
- Hotkey may also appear in our own capture stream. After registering, verify; if yes, filter it in `EventTapService.handle` against the live shortcut. Document in `decisions.md`.
- Recorder UI can lose focus mid-record — pair with a "Clear" button and validate before save.

**Complexity.** S. One well-trodden dep, ~150 LOC.

---

### W2-B · Per-app capture filter

**Recommendation.** Allow-list filter at the **service** layer (before `yield`), sourced from a `FrontmostAppMonitor` that caches the frontmost bundle ID. Monitor subscribes to `NSWorkspace.didActivateApplicationNotification` and writes a `nonisolated(unsafe) var currentBundleID: String?`. The C callback reads it with one pointer compare — well inside the <50ms budget.

**Empty allow list = capture everything** (matches today's behaviour; avoids "nothing recording" mystery when feature is half-configured).

**Edge cases.**
- `loginwindow` / `ScreenSaver.Engine` / `nil` frontmost → treat as "not capturing".
- Tachograph itself frontmost → skip by default. Expose `filter.captureOwnApp` Bool for debugging.

**Notification timing slip.** Notifications are async; first event after an app switch may arrive under the previous bundle ID. Accept the one-event slip (the alternative — reading AppKit inside the C callback — risks objc autorelease churn).

**Files touched.**
- `Services/EventTapService.swift` — inject monitor + filter snapshot; gate `yield(...)` on membership.
- `Services/FrontmostAppMonitor.swift` *(new)* — `@MainActor final class`; observes `didActivateApplicationNotification`; exposes `nonisolated(unsafe) currentBundleID`.
- `Models/AppFilterStore.swift` *(new)* — `@Observable` wrapper around `UserDefaults` for `[String]` allow list + Bool toggle (`@AppStorage` doesn't bridge `[String]` cleanly).
- `ViewModels/CaptureViewModel.swift` — accept monitor + store in init; push current allow-list set into the service on `start()`; observe store changes.
- `TachographApp.swift` — wire shared `AppFilterStore` and `FrontmostAppMonitor`.
- `Views/SettingsView.swift` — add "App Filter" section: toggle + editable list (running apps + `NSOpenPanel` "Add other app…").
- `Views/ControlsToolbar.swift` — small "Filter: 2 apps" indicator + gear opening Settings via `SettingsLink`.

**Storage keys.**
- `filter.enabled` — `Bool` (default `false`).
- `filter.allowedBundleIDs` — `[String]` (default `[]`).
- `filter.captureOwnApp` — `Bool` (default `false`).

**Gotchas.**
- `frontmostApplication` returns `loginwindow` during lock/screensaver — treat as "not capturing".
- Use `frontmostApplication`, not `menuBarOwningApplication` (latter follows menu-bar owner during full-screen transitions, confusing).
- First event after an app switch may slip under previous identity — accepted.

**Complexity.** S–M. Small monitor + filter; medium because of Settings scene + picker UX.

---

## Wave 3 — Structural changes (sequential, M)

Reshape the event stream + add a new top-level view. **Land W3-A first** — it changes the stream type that W3-B will read.

### W3-A · Key-hold duration column

**Reverses 2026-05-13 decision.** New entry in `decisions.md` supersedes the original.

**Recommendation.** Add `holdMs: Int?` to `InputEvent`. On `keyDown`, emit `.append(event)` immediately with `holdMs = nil` and remember `(keyCode → (id, downTimestamp))` in a `nonisolated(unsafe)` dictionary on `EventTapService`. On `keyUp`, emit `.holdUpdate(id, holdMs)`; ViewModel mutates the existing row by id. Drop auto-repeat `keyDown`s (`keyboardEventAutorepeat != 0`) so a held key measures the full press-to-release span.

**Stream payload change.**

```swift
enum EventTapMessage: Sendable {
    case append(InputEvent)
    case holdUpdate(id: UUID, holdMs: Int)
}
```

Service yields `AsyncStream<EventTapMessage>`. ViewModel switches on the message.

**Schema diff.**

```swift
struct InputEvent {
    // existing fields...
    let holdMs: Int?    // nil = unknown / still down / not applicable
}
```

Struct stays a `Sendable` value type — mutation happens at the array slot in `CaptureViewModel`, not on the struct in place.

**Event mask additions.** `.keyUp`, `.leftMouseUp`, `.rightMouseUp`, `.otherMouseUp`. Roughly doubles callback rate; per-event work stays O(1).

**Stop while held.** Pending entries cleared on `stop()`; their rows keep `holdMs = nil` rendered as `—`.

**System-shortcut chords (Cmd+Tab etc.)** may eat the `keyUp`. Accept the stale `nil` rather than guessing an elapsed value.

**Column placement.** Fourth column, right of Δ, right-aligned monospaced, missing → `—`. Header: `Hold (ms)`. TSV/CSV: append column at end of header + each row.

**Files touched.**
- `Models/InputEvent.swift` — add `holdMs` + init default.
- `Services/EventTapService.swift` — extend mask, add `pendingDowns` dict, change stream payload, emit append/update, filter auto-repeat.
- `ViewModels/CaptureViewModel.swift` — consume tagged stream, add `applyHold(id:ms:)`.
- `Views/EventTable.swift` — 4th `TableColumn("Hold (ms)")`.
- `Services/ClipboardExporter.swift` / `DelimitedExporter.swift` — header + cell.
- `docs/decisions.md` — supersede 2026-05-13 entry with reversal + chosen pairing strategy.
- Tests for pair-emit / auto-repeat / stop-while-held / TSV column ordering.

**Gotchas.**
- Auto-repeat must be filtered on `keyDown` (each repeat is a synthesized down). Without it, the dictionary entry gets overwritten and `holdMs` measures only the last repeat-to-release.
- System chords swallow `keyUp` from a listenOnly session tap — leaves permanent pending entries. Mitigation: clear pending entries on `.flagsChanged` releases, or accept stale `nil` (recommended — fewer surprises).
- Doubling the mask doubles callback rate but per-call work is O(1) dict-write. Keep the `tapDisabledByTimeout` re-enable branch first in `handle`.

**Complexity.** M. Stream-type refactor is localized; the ViewModel boundary keeps it contained.

---

### W3-B · Heat-map / histogram view

**Recommendation.** Ship **events-per-second histogram** (primary, BarMark stacked by `kind`) + **top-15 per-key frequency** bar chart (secondary, horizontal). Reject interval distribution (redundant with timeline) and hour-of-day heatmap (session-only data rarely spans hours meaningfully). macOS `Picker(.segmented)` above content area switches between Table / Stats — `TabView` is iOS-y on macOS. Live updates driven off `vm.filteredEvents` (chart reflects filter from W1-B).

**Adaptive bucketing.** Target ~60 bars:

```swift
let span = max(1, last.utcTimestamp.timeIntervalSince(first.utcTimestamp))
let raw = span / 60
let ladder: [Double] = [1, 2, 5, 10, 15, 30, 60, 120, 300, 600, 1800, 3600]
let bucketSec = ladder.first { $0 >= raw } ?? 3600
let key = Int(event.utcTimestamp.timeIntervalSince1970 / bucketSec)
```

**Chart sketch.**

```swift
// Primary
BarMark(x: .value("Time", bucket.start, unit: .second),
        y: .value("Events", bucket.count))
    .foregroundStyle(by: .value("Kind", kind))

// Secondary (top 15)
BarMark(x: .value("Count", count),
        y: .value("Key", label))
```

**Empty state.** `ContentUnavailableView("No events yet", systemImage: "chart.bar")` — avoids degenerate Chart axis.

**Files touched.**
- `Views/ContentView.swift` — `@State Tab` enum + segmented `Picker` switching `EventTable` ↔ `StatsView`.
- `Views/StatsView.swift` *(new)* — host view with two Chart blocks + empty state.
- `Models/EventBuckets.swift` *(new, pure)* — `timeBuckets(events:)` + `keyFrequencies(events:limit:)` + bucket ladder. Unit-testable.
- `ViewModels/CaptureViewModel.swift` — expose `filteredEvents` (depends on W1-B).
- `TachographTests/EventBucketsTests.swift` — empty, single-event, span boundary, ladder transitions.

**Gotchas.**
- Empty/single-event span = 0 → division-by-zero in bucket math. Guard `span >= 1`, fall through to 1s buckets.
- Live rebinning cost: full recompute is O(n) per append. Acceptable up to ~20k events; revisit with `@State` memoization if profiling shows jank.

**Complexity.** M. Two new files, structural ContentView change, no new deps.

---

## Execution order

```
Wave 1  ──┬── W1-A CSV export        (parallel)
          └── W1-B Filter/search      (parallel)
                  │
                  ▼
Wave 2  ──── W2-A Hotkey  ──→  W2-B Per-app filter    (sequential, shared SettingsView)
                  │
                  ▼
Wave 3  ──── W3-A Key-hold  ──→  W3-B Heat-map        (sequential, stream-shape dep)
```

Total: 6 features across 3 waves. 2 × S, 3 × S/M, 1 × M.

---

## Cross-cutting risks

- **Per-app filter timing slip.** First event after app switch may carry previous bundle ID. Accepted (reading AppKit in the C callback is ruled out per <50ms budget).
- **Hotkey shows up in our own capture.** Suppress in `EventTapService.handle` against the live shortcut, or accept; decide empirically.
- **`isExporting` two-way binding** needs a stored `var` on the `@Observable` VM (Swift 6 concurrency cleanliness).
- **Heat-map degenerate domain** with 0–1 events → guard with `ContentUnavailableView`.
- **Key-hold stream type change** ripples through service + VM together; land as one atomic PR.

---

## Tests to add (per wave)

- **W1-A:** CSV quoting trigger chars, `""` escape, `\r\n` rows, header preserved, empty-events.
- **W1-B:** pure filter-predicate cases (empty, case mismatch, symbol match, no match).
- **W2-A:** hotkey wiring (handler fires `toggle`, idempotent re-registration). Visual: Recorder UI manual.
- **W2-B:** `FrontmostAppMonitor.shouldCapture` for empty / matching / non-matching list.
- **W3-A:** pair-emit, auto-repeat dropped, stop-while-held leaves nil, TSV/CSV column ordering.
- **W3-B:** bucket ladder transitions, empty events, single-event, span boundary.

---

*Reviewed by: pending user signoff. Once Wave 1 implementation begins, mark wave status here and move completed features to `docs/decisions.md` for postmortem notes if rationale changed.*
