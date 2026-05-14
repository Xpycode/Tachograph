# Decisions Log

This file tracks the WHY behind technical and design decisions for Tachograph.

---

## 2026-05-13 — Global capture scope (system-wide, not app-only)

**Context:** The app needs to log keystrokes and clicks for a measurement/timing tool. App-focused capture would only see events while Tachograph has keyboard focus.

**Options considered:**
1. **App-focused only** — capture via SwiftUI `.onKeyPress` / NSResponder while window is key. No special permissions. Can be sandboxed and MAS-distributable.
2. **Global (system-wide)** — capture via `CGEventTap`. Requires Accessibility permission and unsandboxed app. Cannot ship to MAS.

**Decision:** Global capture (option 2).

**Rationale:** The user explicitly wants to measure activity across whatever app they're using; the table is the *reading surface*, not the focused app. App-focused capture would defeat the purpose.

**Consequences:**
- App must run unsandboxed → ineligible for Mac App Store → direct GitHub distribution only (acceptable per user).
- Needs Accessibility prompt + first-run guidance ("open System Settings → Privacy & Security → Accessibility").
- Notarization required for Developer ID distribution.

---

## 2026-05-13 — Duration column = inter-event interval (not key-hold duration)

**Context:** User asked for "how long it was when it was pressed" alongside each event.

**Options considered:**
1. **Key-hold duration** — measure `keyDown → keyUp` per key. Conceptually accurate to "how long it was pressed" but produces a row only on key-up, which delays UI feedback and gets messy when modifiers overlap.
2. **Inter-event interval** — milliseconds since the previous event. Captured at `keyDown` instantly.
3. **Both columns** — more data, wider table.

**Decision:** Inter-event interval (option 2).

**Rationale:** User confirmed "Time since previous event" in /setup interview. Simpler model: one row per event, all data known at insert time, no pending state machine.

**Consequences:**
- First row always shows interval = 0 (or "—") since there is no previous event.
- We capture `keyDown`/`mouseDown` only; key-up events are ignored for v1. (Can be added later as a separate column.)

---

## 2026-05-13 — Session-only log (no disk persistence)

**Context:** Where does the log live? Disk-backed sessions vs in-memory only.

**Options considered:**
1. **Session-only** — log lives in RAM, gone on quit; clipboard export is the only way out.
2. **Auto-persist to JSON in Application Support** — sessions browsable across launches.
3. **Optional save** — session-only by default, "Save Log…" menu writes user-chosen file.

**Decision:** Session-only (option 1).

**Rationale:**
- Matches user's "simple app" framing and start/stop measuring mental model.
- Strong privacy posture: a keystroke logger writing to disk by default is an attractive target.
- Clipboard export covers the actual "I want this data" workflow.

**Consequences:**
- No sessions browser UI to build.
- If we later want history, it becomes a feature decision (opt-in toggle), not a default.

---

## 2026-05-14 — EventTapService is `@MainActor final class`, not `actor`

**Context:** CLAUDE.md's default rule is "services that own external state are `actor`." During Wave 3 implementation we hit a concrete cost.

**Problem:** `CGEventTapCallBack` is a C function pointer — it cannot capture context and runs synchronously on whichever thread owns the run loop the tap is installed on. To call into an `actor` from a C callback, you must wrap the work in `Task { await actor.handle(...) }`. That introduces three real problems:

1. **Reordering:** rapid events queue independently as tasks; Swift Concurrency makes no ordering guarantees between unrelated tasks. Keystrokes could appear out of order.
2. **Latency:** every keystroke pays a task-creation + actor-hop cost. Spec AC #1 budgets <50 ms; this puts that at risk under burst input.
3. **Backpressure:** tasks could accumulate during fast typing if the actor is busy.

**Options considered:**
1. `actor` + `Task { await }` per event — natural but suffers all three problems above.
2. `actor` + a `nonisolated` synchronous `handle(_:)` that touches only `Sendable` state — possible, but the callback needs to mutate `ModifierTapDetector`, `lastFlags`, and the continuation, so we'd be passing `Sendable` snapshots through a serial dispatch queue. Reimplements actor manually.
3. **`@MainActor final class` with `nonisolated(unsafe)` callback-thread state** — install the tap on `CFRunLoopGetMain()`, mark the callback-touched properties `nonisolated(unsafe)`, accept that the type system can't prove main-thread confinement but the run-loop choice enforces it at runtime.

**Decision:** Option 3.

**Rationale:**
- The tap callback already runs on whatever run loop you attach to; installing on the main run loop gives us a serial main-thread context for free.
- No reordering, no extra latency, no queuing — the callback yields directly into the `AsyncStream`, which is `Sendable`-safe.
- `nonisolated(unsafe)` is the documented Swift 6 escape hatch for exactly this case (state proven safe by something other than actor isolation).

**Consequences:**
- Heavy work in the callback would block the main thread — we keep the callback minimal (classify event, look up label, yield). That's enforced by code review, not the type system.
- If we ever want to move capture off the main thread (e.g. to reduce UI-stall risk during burst typing), we move to a dedicated thread + run loop and the `nonisolated(unsafe)` reasoning still holds.
- `CLAUDE.md`'s threading section updated to call out this exception explicitly.

---

## 2026-05-13 — Minimum macOS 15 Sequoia

**Context:** Pick a deployment target.

**Decision:** macOS 15 Sequoia.

**Rationale:** Personal tool, user's Mac is current; freer hand with the latest SwiftUI Table APIs (column customization, observable integration) and modern `@Observable` macro.

**Consequences:** Anyone on macOS 14 or earlier can't run the app. Acceptable per "no MAS, mostly personal."

---

## 2026-05-14 — v2: Single Settings scene shared across features [PENDING]

**Status:** pending — finalize on Wave 2 landing.

**Context:** Both *Pause/resume hotkey* (W2-A) and *Per-app filter* (W2-B) need a place to live. Two independent windows would be wasteful and SwiftUI's `Settings { }` scene is the standard macOS pattern.

**Decision:** One `SettingsView.swift` with two sections (Hotkey, App Filter). Built in W2-A, extended in W2-B.

**Rationale:** Standard macOS UX (single `⌘,` window); avoids duplicating `SettingsLink` plumbing; lets future features (e.g. rolling buffer, auto-clear) plug in as additional sections.

**Consequences:** W2-A and W2-B are sequential (W2-A first), sharing the same file. Other waves don't depend on Settings.

---

## 2026-05-14 — v2: Adopt `sindresorhus/KeyboardShortcuts` SPM dependency [PENDING]

**Status:** pending — first 3rd-party dep in the project.

**Context:** W2-A (pause/resume hotkey) needs a global hotkey that *consumes* the event (so it doesn't leak to the focused app). Options compared:

| Option | Consumes? | Maintained? | LOC to integrate |
|---|---|---|---|
| `NSEvent.addGlobalMonitorForEvents` | No | ✓ | ~50 (but disqualifying) |
| Upgrade existing CGEventTap to non-listenOnly | Yes | ✓ | ~200 + risks <50ms budget |
| Raw `Carbon/HIToolbox` `RegisterEventHotKey` | Yes | ✓ | ~250 + custom recorder UI |
| `sindresorhus/KeyboardShortcuts` SPM (~2.2.x) | Yes (Carbon under the hood) | ✓ active | ~150 incl. Recorder UI |

**Decision:** Adopt `KeyboardShortcuts`. Pin `from: "2.2.0"`.

**Rationale:** Smallest glue layer (~150 LOC); ships SwiftUI `Recorder` view; native `UserDefaults` persistence under its own key prefix; actively maintained Swift-first package. Avoids reimplementing what's already battle-tested. The "first 3rd-party dep" bar is real but the saved code far exceeds the dep cost.

**Consequences:**
- `project.yml` gains an SPM ref; `Package.resolved` joins source control.
- Persistence is the package's UserDefaults — do **not** also bind via `@AppStorage` for the combo. Single source of truth.
- Default combo: **`⌃⌥⌘R`** (Control-Option-Command-R). Four-key chord, no system collisions, mnemonic for "Record".

---

## 2026-05-14 — v2: Event-tap stream type changes only in Wave 3 [PENDING]

**Status:** pending — applies when W3-A lands.

**Context:** W3-A (key-hold duration) needs the service to emit two kinds of messages: append-row and update-row-by-id. Today the service yields `AsyncStream<InputEvent>`. W2-B (per-app filter) also touches the service, but only to gate `yield(...)` on bundle-ID membership.

**Decision:** Per-app filter (W2-B) lands while the stream still yields `InputEvent` directly. The shape change to `AsyncStream<EventTapMessage>` happens only in W3-A.

**Rationale:** Keeps W2-B's change surface minimal (one guard in `handle`). Avoids forcing a stream-type refactor through a wave that doesn't benefit from it.

**Consequences:**
- W3-A's PR is the only one that touches both `EventTapService` and `CaptureViewModel.append(raw:)` at the same time.
- `EventTapMessage` enum will be `Sendable` and exhaustive: `.append(InputEvent) | .holdUpdate(id: UUID, holdMs: Int)`.
- Per-app filter's allow-list gate runs *before* yield regardless of message kind, so it composes cleanly with W3-A.

---

## 2026-05-14 — v2: Reverse the 2026-05-13 "no key-hold" decision [PENDING]

**Status:** pending — supersedes the 2026-05-13 "Duration column = inter-event interval (not key-hold duration)" entry above when W3-A lands.

**Context:** The 2026-05-13 decision deferred key-hold duration in favour of inter-event interval, citing the "messy state machine" of keyDown→keyUp pairing. The user now wants both columns: Δ (ms) stays for inter-event timing, **Hold (ms)** adds for per-key press duration.

**Decision:** Adopt the dictionary-pairing approach for W3-A. On `keyDown`, emit a row immediately with `holdMs = nil` and record `(keyCode → (rowID, downTimestamp))` in a `nonisolated(unsafe)` dictionary on `EventTapService`. On `keyUp`, emit `.holdUpdate(id, holdMs)`; ViewModel mutates the existing row by id. Auto-repeat `keyDown`s (`keyboardEventAutorepeat != 0`) are dropped so a held key measures the full press-to-release span. Rows still pending at `stop()` keep `holdMs = nil` ("—").

**Rationale:**
- The original concern was that emit-on-keyUp delays UI feedback; pairing strategy (emit on keyDown, patch on keyUp) sidesteps that — the row appears instantly, the hold figure fills in when known.
- Doubling the event mask (adding keyUp variants) doubles callback rate but per-call work stays O(1) dict ops; <50ms budget unchanged.
- System-chord-swallowed `keyUp` (Cmd+Tab, Cmd+Space) leaves a permanent pending entry. We accept stale `holdMs = nil` rather than guessing an elapsed value — fewer surprises in the data.

**Consequences:**
- `InputEvent` gains optional `holdMs: Int?`.
- Stream payload becomes `EventTapMessage` (see CFD-3).
- 4th table column "Hold (ms)" right of Δ. TSV/CSV header gains the column.
- The 2026-05-13 entry stays in the log (history is history) but is annotated as "Superseded by 2026-05-14 v2 entry."

---

*Template at the bottom of `docs/00_base.md` references. Add new decisions as they are made.*
