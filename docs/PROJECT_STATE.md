# Project State

> **Size limit: <100 lines.** This is a digest, not an archive. Details go in session logs.

## Identity
- **Project:** Tachograph
- **One-liner:** macOS app that logs global key & mouse events to a live table with clipboard export
- **Tags:** macos, swiftui, input-monitoring, personal-tool
- **Started:** 2026-05-13

## Current Position
- **Funnel:** **v2 Wave 2 complete** — W2-A hotkey, W2-B per-app filter, W2-C app column shipped on `feature/v2-wave2`
- **Phase:** Wave 2 done, awaiting merge + Wave 3 (key-hold + heat-map) start
- **Focus:** Merge `feature/v2-wave2` → main, then start Wave 3 (W3-A key-hold; reshapes the event-tap stream)
- **Status:** build green, all tests passing, UI verified (toolbar gear, Settings sections, App column live); CFD-1/2/3 ratified
- **Last updated:** 2026-05-15

## Funnel Progress

| Funnel | Status | Gate |
|--------|--------|------|
| **v1 Define → Ship** | done | v1.0.0 notarized + published |
| **v2 Define** | done | Spec at `specs/v2-features.md` — 6 features, 3 waves |
| **v2 Plan** | done | Phased plan + cross-feature decisions ratified through CFD-3 |
| **v2 Build** | waves 1-2 done | W1 (merged), W2 (W2-A + W2-B + W2-C) on `feature/v2-wave2` ready to merge |
| **v2 Ship** | not started | — |

## v2 Wave Progress
```
[#########################################...] Wave 2 done; Wave 3 ready
```

| Wave | Status | Features | Complexity |
|------|--------|----------|------------|
| W1 (parallel) | ✅ done | CSV export + filter/search | S + S |
| W2 (sequential) | ✅ done | hotkey → per-app filter → app context column | S + S/M + S |
| W3 (sequential) | ready | key-hold duration → heat-map | M + M |

## Readiness

| Dimension | Status | Notes |
|-----------|--------|-------|
| v1 Features | ✅ done | All v1 spec features implemented + shipped |
| v2 Spec | ✅ done | `specs/v2-features.md` — 6 features across 3 waves |
| v2 Decisions | 🔶 pending user signoff | 4 cross-feature decisions logged as `[PENDING]` |
| Testing | ✅ done | 44 unit tests green from v1 |
| Docs | ✅ done | CLAUDE.md, README, both specs, decisions, sessions all current |
| Distribution (v1) | ✅ done | v1.0.0 notarized + published |

## Validation Gates
- [x] **v1 Define → Plan → Build → Ship** (all complete 2026-05-14)
- [x] **v2 Define → Plan** (spec + phased plan complete)
- [x] **v2 Wave 1 Build + Merge** — W1-A + W1-B merged 2026-05-14
- [x] **v2 Wave 2 Build** — W2-A + W2-B + W2-C on `feature/v2-wave2`, all tests green, UI verified
- [ ] **v2 Wave 2 Merge → main**
- [ ] **v2 Wave 3 Build** (W3-A key-hold + W3-B heat-map)

## Active Decisions

### v2 (pending user signoff)
- 2026-05-14: **CFD-1** — single `SettingsView.swift` shared between W2-A (hotkey) and W2-B (per-app filter). Built in W2-A, extended in W2-B.
- 2026-05-14: **CFD-2** — adopt `sindresorhus/KeyboardShortcuts` SPM (`from: "2.2.0"`). First 3rd-party dep. Carbon under the hood, *consumes* events, ships SwiftUI Recorder. ~150 LOC vs ~250 hand-rolled.
- 2026-05-14: **CFD-3** — event-tap stream stays `AsyncStream<InputEvent>` through W2-B; reshapes to `AsyncStream<EventTapMessage>` only in W3-A.
- 2026-05-14: **CFD-4** — reverse the 2026-05-13 "no key-hold" decision. New entry supersedes; pairing strategy is dictionary-of-pending-downs keyed by keyCode, drop auto-repeat, accept `nil` for chord-swallowed `keyUp`.

### v1 (shipped, historical)
- 2026-05-14: **v1.0.0 published** at https://github.com/Xpycode/Tachograph/releases/tag/v1.0.0. Notarized DMG (6.5 MB, SHA256 `e1b43de1…`), MIT-licensed, public.
- 2026-05-14: Renamed `DownKeyCounter` → **Tachograph**. Bundle ID `com.lucesumbrarum.Tachograph`. Team ID `FDMSRXXN73` (cert's `OU` field, not the CN suffix).
- 2026-05-14: `EventTapService` is `@MainActor final class`, not `actor` — see `decisions.md` for the <50ms callback budget rationale.
- 2026-05-13: macOS 15 Sequoia minimum; global capture via CGEventTap; sandbox off; session-only log.

## Blockers
*(none — Wave 2 done, Wave 3 reshapes the event-tap stream; CFD-3 already drafted)*

## Resume

**Wave 2 complete on `feature/v2-wave2` (W2-A hotkey, W2-B per-app filter, W2-C app context column, plus polish + decisions ratification commits).**

- **Next:** merge `feature/v2-wave2` to main, then start **Wave 3** — W3-A key-hold first (changes the AsyncStream payload from `InputEvent` to `EventTapMessage` per CFD-3), then W3-B heat-map view.
- **Wave 2 details:** 19 new tests (8 toggle + 11 AppFilter + new app-cell test). KeyboardShortcuts 2.4.0 SPM dep added. FrontmostAppMonitor caches frontmost via `nonisolated(unsafe)` so the C callback gates on a single pointer compare. App context (bundle ID) stamped on every event, surfaced as a 4th table column and TSV/CSV column.
- **Folder rename housekeeping**: repo folder is still `1-macOS/DownKeyCounter/` on disk. Between sessions: close terminals/editors, `mv DownKeyCounter Tachograph`, reopen Claude Code there.

---
*Updated by Claude. Source of truth for project position.*
