# Spec: DownKeyCounter v1

**Status:** draft (awaiting user review)
**Owner:** gm.konsortium@yahoo.dk
**Created:** 2026-05-13

---

## Problem

I want to watch and measure my own input activity over a session — every key I press and every mouse click — laid out in a clean, modern table with timestamps. No app currently shows this in a way I find readable, and I'd like to copy the log out to analyze in a spreadsheet.

## Goals

- See every key/mouse-button press live as it happens, anywhere on macOS.
- Get UTC timestamp + inter-event interval for each event.
- Copy the full session log to the clipboard with one click, in a paste-friendly format.
- Keep the entire session in memory only — nothing on disk.

## Non-Goals (v1)

- Recording key-up events / hold durations.
- Recording mouse movement or scroll.
- Recording text content of typed input distinct from per-key events (no "typed phrase" reconstruction beyond the key list itself).
- Multi-session history, search, filtering.
- Heatmaps, charts, or any visualization beyond the table.
- Menu-bar-only mode.

---

## User Stories

1. **Start measuring** — As a user, I click **Start** in the top toolbar and the app begins capturing system-wide input. The button turns into **Stop**.
2. **See events appear** — As I press keys (or click) in any app, rows append to the table in real time.
3. **Pause** — I click **Stop** and capture halts; existing rows remain.
4. **Clear** — I click **Clear** to wipe the table back to empty (with a confirm if there are >50 rows).
5. **Copy** — I click **Copy Log** and the full table is on my clipboard as TSV, ready to paste into Numbers / Excel.
6. **First-run permission** — On first launch, the app explains it needs Accessibility permission and offers a button that opens the right System Settings pane.

---

## UI

### Layout

```
┌──────────────────────────────────────────────────────────┐
│  ▶ Start    ⏹ Stop    🗑 Clear    📋 Copy Log    ⚙       │ ← toolbar (top pane)
├──────────────────────────────────────────────────────────┤
│  Key / Button          │ UTC Time              │ Δ (ms)  │ ← table header
├──────────────────────────────────────────────────────────┤
│  ⌘ A                   │ 2026-05-13 19:42:17.103 │   —    │
│  Space                 │ 2026-05-13 19:42:17.241 │  138   │
│  Left Click            │ 2026-05-13 19:42:18.002 │  761   │
│  Esc                   │ 2026-05-13 19:42:18.450 │  448   │
│  ...                   │                         │        │
└──────────────────────────────────────────────────────────┘
```

- Top toolbar: Start (or Stop), Clear, Copy Log. Status pill shows one of: **Idle** (tap installed, capture not running), **Capturing** (tap emitting).
- When Accessibility permission is missing, the toolbar is **hidden** and the permission panel takes over the entire window content — no "Permission needed" pill duplicates the panel.
- Table: SwiftUI `Table<InputEvent>` with 3 columns.
- Resizable window, default ~720×520. Remember size/position via `@AppStorage`.

### Key formatting

| Input | Label |
|-------|-------|
| `A` with no modifiers | `A` |
| `A` with ⌘ | `⌘ A` |
| `A` with ⇧⌘ | `⇧ ⌘ A` |
| Spacebar | `Space` |
| Arrow keys | `←` `→` `↑` `↓` |
| Modifier alone (e.g. press ⌘) | `⌘` |
| Function keys | `F1`–`F20` |
| Left mouse click | `Left Click` |
| Right mouse click | `Right Click` |
| Middle / extra mouse buttons | `Mouse 3`, `Mouse 4`, ... |

### Empty state

When the table is empty (just launched or after Clear): centered hint — "Press Start, then type. Events will appear here."

### Permission-needed state

When the event tap can't install: replace the entire window content with a centered panel:
> **Accessibility permission needed**
> DownKeyCounter watches your input system-wide, so macOS needs your permission.
> [ Open Privacy Settings ] [ I've granted it — relaunch ]

**Permission flow rules:**
- On launch, evaluate `AXIsProcessTrusted()`. If `false`, show the panel.
- **Open Privacy Settings** opens the URL `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`.
- **"I've granted it — relaunch"** calls `NSApplication.shared.terminate(_:)` after a brief confirm — macOS does not hot-swap the Accessibility grant for an already-running process, so a fresh launch is required for the tap to install successfully.
- We do **not** offer a soft "Recheck" button in v1, because a recheck that returns trusted=true while the tap still fails is more confusing than helpful.

---

## Data Model

```swift
struct InputEvent: Identifiable, Sendable {
    let id: UUID
    let kind: Kind          // .key / .modifier / .mouse
    let label: String       // "⌘ A", "Space", "Left Click"
    let utcTimestamp: Date  // capture time
    let intervalMs: Int?    // nil for the first event of a session
}

enum Kind { case key, modifier, mouse }
```

### Event emission rules (single source of truth for what produces a row)

| Source CGEvent | Emit a row? | Label rule |
|----------------|-------------|------------|
| `keyDown` | Yes, exactly one | Build label from current modifier flags + the key. ⌘+A → `⌘ A`. ⇧+⌘+A → `⇧ ⌘ A`. |
| `keyUp` | **No** | Ignored in v1. |
| `flagsChanged` — modifier pressed | No (yet) | Buffer this modifier as "pending tap". |
| `flagsChanged` — modifier released, no `keyDown` happened while it was held | Yes, one row | Label is just the modifier glyph: `⌘`, `⇧`, `⌥`, `⌃`, `fn`. |
| `flagsChanged` — modifier released, but a `keyDown` did happen while it was held | No | The `keyDown` row already represents this gesture (with the modifier baked into its label). |
| `leftMouseDown` / `rightMouseDown` / `otherMouseDown` | Yes, one row | `Left Click`, `Right Click`, `Mouse N` (N from `mouseButtonNumber` + 1). |
| `mouseUp`, `mouseMoved`, `scrollWheel`, anything else | **No** | Ignored in v1. |

**Modifier ordering inside a combined label:** `fn ⌃ ⌥ ⇧ ⌘` (matches Apple HIG ordering). Space-separated.

### Event tap configuration

- Location: `cgSessionEventTap` (per-session, current user). Not HID-level — we don't need pre-session events.
- Insertion: `kCGHeadInsertEventTap`.
- Options: `kCGEventTapOptionListenOnly` — we observe and never modify or swallow events.
- Event mask: `keyDown | flagsChanged | leftMouseDown | rightMouseDown | otherMouseDown`.
- Run loop: dedicated background thread or `CFRunLoop` attached to a non-main mode; the callback hops to the actor that drains the `AsyncStream<InputEvent>`.

## Clipboard Format (TSV)

```
Key / Button<TAB>UTC Time<TAB>Δ (ms)
⌘ A<TAB>2026-05-13T19:42:17.103Z<TAB>
Space<TAB>2026-05-13T19:42:17.241Z<TAB>138
Left Click<TAB>2026-05-13T19:42:18.002Z<TAB>761
```

- ISO 8601 with milliseconds, always UTC (Z suffix).
- TSV (not CSV) so labels containing commas don't break.
- First row is a header.

---

## Performance / Scale

v1 stores all events in a single in-memory `[InputEvent]` and renders via SwiftUI `Table`. Empirical comfort zone is ~10k rows; long fast-typing sessions (~50k+ events) may slow scrolling and clipboard export.

- **v1 stance:** no row cap, no virtualization. The user is responsible for clearing long sessions.
- **Mitigation if it becomes a problem:** add a "rolling buffer" preference (keep last N events) in v1.x. Parked in `docs/ideas.md`.
- The append path runs on `@MainActor` via `AsyncStream` consumption — keep per-event work minimal to avoid stalling the UI during burst input.

---

## Acceptance Criteria

A v1 release ships when **all** of these hold:

1. **Capture works system-wide.** Pressing keys in any other app (Safari, Mail, Terminal) adds rows to the DownKeyCounter table within ~50 ms.
2. **Start/Stop is symmetric.** Clicking Stop halts new rows immediately; clicking Start resumes; rows already in the table are preserved.
3. **Clear clears.** Clear empties the table. If >50 rows are present, a confirm dialog asks first.
4. **Copy Log produces valid TSV.** Pasting into Numbers/Excel produces three columns with the same content as the on-screen table. Header row is included.
5. **Modifier handling.** Pressing ⌘ then C while ⌘ is held produces exactly one row, labeled `⌘ C`. Pressing and releasing ⌘ alone (no other key in between) produces one row labeled `⌘`. Pressing ⌘+⇧+A in any order produces one row `⇧ ⌘ A` (Apple-ordering, space-separated). Releasing modifiers after a combined keyDown does **not** produce additional rows.
6. **Timestamps are UTC ISO 8601 with ms.** No locale-dependent formatting in the data; on-screen display may use a friendlier form.
7. **Interval column.** First event of a session shows `—`. Every subsequent event shows the integer millisecond delta from the previous event.
8. **Permission UX.** Launching without Accessibility shows the permission panel, not a broken-looking empty table. The "Open Privacy Settings" button opens the correct pane. After granting and relaunching, capture works on next Start.
9. **Mouse buttons.** Left, right, middle, and at least two extra mouse buttons (Mouse 3, Mouse 4) produce rows with correct labels.
10. **Quit discards log.** Quit → relaunch → table is empty. No JSON or other file is written to `~/Library/Application Support/DownKeyCounter` or anywhere else.
11. **No network — auditable.** All of the following hold in Release: (a) the app does **not** declare `com.apple.security.network.client` in its entitlements; (b) no source file imports `URLSession`, `Network`, `CFNetwork`, `WebKit`, or `OSLog` remote sinks; (c) a final code-review checklist item before shipping confirms zero outbound calls.
12. **Notarized build runs from a fresh user account.** Install the DMG on a clean macOS 15 user, grant Accessibility, capture works.

---

## Open Questions

- (none currently — pending user review of this spec)

## Out-of-Scope Ideas (parked → `docs/ideas.md`)

- Key-hold duration column.
- Filter / search.
- Pause hotkey (start/stop without mouse).
- Per-app capture filter ("only capture while Safari is frontmost").
- Heat-map view.
- CSV export to file.
- Multi-session history.

---

*Reviewed by: pending. Once accepted, run `/plan` to generate `IMPLEMENTATION_PLAN.md`.*
