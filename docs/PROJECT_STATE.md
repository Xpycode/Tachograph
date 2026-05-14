# Project State

> **Size limit: <100 lines.** This is a digest, not an archive. Details go in session logs.

## Identity
- **Project:** Tachograph
- **One-liner:** macOS app that logs global key & mouse events to a live table with clipboard export
- **Tags:** macos, swiftui, input-monitoring, personal-tool
- **Started:** 2026-05-13

## Current Position
- **Funnel:** **v2 Wave 1 complete** — CSV export + filter/search shipped on `feature/v2-wave1`
- **Phase:** Wave 1 implementation done, awaiting merge + Wave 2 (Settings + hotkey) start
- **Focus:** Merge `feature/v2-wave1` → main, then start Wave 2 (W2-A hotkey, requires SPM dep)
- **Status:** build green, 60+ tests passing (added 11 in W1-A + 8 in W1-B), UI verified in running app
- **Last updated:** 2026-05-14

## Funnel Progress

| Funnel | Status | Gate |
|--------|--------|------|
| **v1 Define → Ship** | done | v1.0.0 notarized + published |
| **v2 Define** | done | Spec at `specs/v2-features.md` — 6 features, 3 waves |
| **v2 Plan** | done | Phased plan + cross-feature decisions logged as PENDING |
| **v2 Build** | wave 1 done | W1-A CSV + W1-B filter shipped on `feature/v2-wave1` |
| **v2 Ship** | not started | — |

## v2 Wave Progress
```
[##############################..............] Wave 1 done; Wave 2 ready
```

| Wave | Status | Features | Complexity |
|------|--------|----------|------------|
| W1 (parallel) | ✅ done | CSV export + filter/search | S + S |
| W2 (sequential) | ready | hotkey → per-app filter | S + S/M |
| W3 (sequential) | blocked | key-hold duration → heat-map | M + M |

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
- [x] **v2 Wave 1 Build** — W1-A + W1-B on `feature/v2-wave1`, build green, tests green, UI verified
- [ ] **v2 Wave 1 Merge → main**
- [ ] **v2 Wave 2 Build** (W2-A hotkey + W2-B per-app filter)

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
*(none — Wave 1 done, Wave 2 needs SPM dep + Settings scene; see CFD-1/CFD-2)*

## Resume

**Wave 1 complete on `feature/v2-wave1` (commits 80dd9c5 docs, 0dd79fc W1-A, 6182612 W1-B).**

- **Next:** review the branch, merge to main, then start **Wave 2** — W2-A hotkey first (needs `sindresorhus/KeyboardShortcuts` SPM dep, first 3rd-party dep — adds it to `project.yml`), then W2-B per-app filter on the shared `SettingsView`.
- **Wave 1 details:** 19 new tests (11 CSV/delimiter + 8 filter), `DelimitedExporter` extracted so TSV stays byte-identical, filter state lives in ContentView per spec, `.fileExporter` two-way-binds via stored `var isExporting` on the VM.
- **Folder rename housekeeping**: repo folder is still `1-macOS/DownKeyCounter/` on disk. Between sessions: close terminals/editors, `mv DownKeyCounter Tachograph`, reopen Claude Code there.

---
*Updated by Claude. Source of truth for project position.*
