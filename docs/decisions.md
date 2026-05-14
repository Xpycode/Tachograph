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

*Template at the bottom of `docs/00_base.md` references. Add new decisions as they are made.*
