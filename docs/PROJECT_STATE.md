# Project State

> **Size limit: <100 lines.** This is a digest, not an archive. Details go in session logs.

## Identity
- **Project:** Tachograph
- **One-liner:** macOS app that logs global key & mouse events to a live table with clipboard export
- **Tags:** macos, swiftui, input-monitoring, personal-tool
- **Started:** 2026-05-13

## Current Position
- **Funnel:** **v2 Wave 3 in progress** — W3-A key-hold + Hold (ms) column shipped on `feature/v2-wave3` (pending UI smoke + merge)
- **Phase:** W3-A code + tests complete, awaiting manual hold-time smoke test + merge
- **Focus:** Verify W3-A manually (hold a key, check Hold column reads ~1000 ms after 1 s release), then merge `feature/v2-wave3` to main, then start W3-B (heat-map)
- **Status:** build green, 97 tests passing (+13 from W3-A); CFD-1/2/3/4 ratified; auto-repeats now drop (one row per held key, not one per OS repeat — user-visible change)
- **Last updated:** 2026-05-16

## Funnel Progress

| Funnel | Status | Gate |
|--------|--------|------|
| **v1 Define → Ship** | done | v1.0.0 notarized + published |
| **v2 Define** | done | Spec at `specs/v2-features.md` — 6 features, 3 waves |
| **v2 Plan** | done | Phased plan + cross-feature decisions ratified through CFD-3 |
| **v2 Build** | waves 1-2 merged, W3-A built | W1 + W2 merged; W3-A code + tests on `feature/v2-wave3` |
| **v2 Ship** | not started | — |

## v2 Wave Progress
```
[##############################################......] W1+W2 merged; W3-A built (A/3); W3-B, W3-C queued
```

| Wave | Status | Features | Complexity |
|------|--------|----------|------------|
| W1 (parallel) | ✅ done | CSV export + filter/search | S + S |
| W2 (sequential) | ✅ done | hotkey → per-app filter → app context column | S + S/M + S |
| W3 (sequential) | 🔶 in progress | ✅ key-hold (W3-A) → heat-map (W3-B) → mouse coords + AX (W3-C) | M + M + M |

## Readiness

| Dimension | Status | Notes |
|-----------|--------|-------|
| v1 Features | ✅ done | All v1 spec features implemented + shipped |
| v2 Spec | ✅ done | `specs/v2-features.md` — 8 features across 3 waves (W2-C, W3-C added mid-wave) |
| v2 Decisions | ✅ ratified | CFD-1/2/3/4 all ratified; W3-A's reversal supersedes 2026-05-13 |
| Testing | ✅ green | 97 unit tests passing (+13 from W3-A; was 84) |
| Docs | ✅ done | CLAUDE.md, README, both specs, decisions, sessions all current |
| Distribution (v1) | ✅ done | v1.0.0 notarized + published |

## Validation Gates
- [x] **v1 Define → Plan → Build → Ship** (all complete 2026-05-14)
- [x] **v2 Define → Plan** (spec + phased plan complete)
- [x] **v2 Wave 1 Build + Merge** — W1-A + W1-B merged 2026-05-14
- [x] **v2 Wave 2 Build + Merge** — W2-A + W2-B + W2-C merged
- [x] **v2 Wave 3-A Build** — code + tests on `feature/v2-wave3`, 97 tests green
- [ ] **v2 Wave 3-A Manual smoke + Merge → main**
- [ ] **v2 Wave 3-B Build** (heat-map)
- [ ] **v2 Wave 3-C Build** (mouse coords + AX element)

## Active Decisions

### v2 (ratified)
- 2026-05-14: **CFD-1** — single `SettingsView.swift` shared between W2-A (hotkey) and W2-B (per-app filter). Built in W2-A, extended in W2-B. *Ratified 2026-05-15.*
- 2026-05-14: **CFD-2** — adopt `sindresorhus/KeyboardShortcuts` SPM (`from: "2.2.0"`). First 3rd-party dep. Carbon under the hood, *consumes* events, ships SwiftUI Recorder. ~150 LOC vs ~250 hand-rolled. *Ratified 2026-05-15.*
- 2026-05-14: **CFD-3** — event-tap stream stays `AsyncStream<InputEvent>` through W2-B; reshapes to `AsyncStream<EventTapMessage>` in W3-A. *Ratified 2026-05-15 (W2-B); further ratified 2026-05-16 (W3-A reshape landed).*
- 2026-05-14: **CFD-4** — reverse the 2026-05-13 "no key-hold" decision. Pairing strategy: dictionary keyed by `HoldKey` (key+mouse), pendingCap=64 FIFO, drop auto-repeat, accept `nil` for chord-swallowed `keyUp`, use `event.timestamp` ns for both endpoints. *Ratified 2026-05-16.*

### v1 (shipped, historical)
- 2026-05-14: **v1.0.0 published** at https://github.com/Xpycode/Tachograph/releases/tag/v1.0.0. Notarized DMG (6.5 MB, SHA256 `e1b43de1…`), MIT-licensed, public.
- 2026-05-14: Renamed `DownKeyCounter` → **Tachograph**. Bundle ID `com.lucesumbrarum.Tachograph`. Team ID `FDMSRXXN73` (cert's `OU` field, not the CN suffix).
- 2026-05-14: `EventTapService` is `@MainActor final class`, not `actor` — see `decisions.md` for the <50ms callback budget rationale.
- 2026-05-13: macOS 15 Sequoia minimum; global capture via CGEventTap; sandbox off; session-only log.

## Blockers
*(none — W3-A code complete, awaiting manual hold-time smoke test before merge)*

## Resume

**W3-A built on `feature/v2-wave3` — 5 commits, 97 tests green, awaiting manual smoke before merge to main.**

- **Next:** manually verify holdMs by holding a key (~1 s release → Hold column should read ~1000). Also confirm system-chord-swallowed keyUp (Cmd+Tab) leaves the row at `—` rather than guessing. Then merge `feature/v2-wave3` with `--no-ff`. *Don't delete the branch* — W3-B and W3-C continue on it.
- **W3-B next** (heat-map): plan at `IMPLEMENTATION_PLAN-w3b.md`. Two Charts in a Stats tab segmented from Events; pure `EventBuckets` helpers; promotes `filterText` from `ContentView.@State` to VM.
- **W3-C after that** (mouse coords + AX): plan at `IMPLEMENTATION_PLAN-w3c.md`. Piggybacks on W3-A's `EventTapMessage` enum by adding `.elementHint(id, role, title?)`. Uses existing Accessibility TCC — no new permission.
- **W3-A details to carry forward:** auto-repeat keyDowns now drop entirely (one held key = one row); `event.timestamp` (UInt64 ns) drives Hold math; pendingDowns dict capped at 64 FIFO; `InputEvent.init` gained an optional `id:` param for the patch-by-id flow.
- **Folder rename housekeeping:** repo folder is still `1-macOS/DownKeyCounter/` on disk. Between sessions: close terminals/editors, `mv DownKeyCounter Tachograph`, reopen Claude Code there.

---
*Updated by Claude. Source of truth for project position.*
