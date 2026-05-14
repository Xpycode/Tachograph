# Project State

> **Size limit: <100 lines.** This is a digest, not an archive. Details go in session logs.

## Identity
- **Project:** Tachograph
- **One-liner:** macOS app that logs global key & mouse events to a live table with clipboard export
- **Tags:** macos, swiftui, input-monitoring, personal-tool
- **Started:** 2026-05-13

## Current Position
- **Funnel:** **v2 planning complete** — v1.0.0 shipped, v2 spec drafted
- **Phase:** v2 plan ready; awaiting user approval to begin Wave 1
- **Focus:** Wave 1 implementation (CSV export + filter/search, parallel, S complexity)
- **Status:** planning done — `docs/specs/v2-features.md` written, 4 cross-feature decisions logged as PENDING
- **Last updated:** 2026-05-14

## Funnel Progress

| Funnel | Status | Gate |
|--------|--------|------|
| **v1 Define → Ship** | done | v1.0.0 notarized + published |
| **v2 Define** | done | Spec at `specs/v2-features.md` — 6 features, 3 waves |
| **v2 Plan** | done | Phased plan + cross-feature decisions logged as PENDING |
| **v2 Build** | not started | Awaiting user approval to start Wave 1 |
| **v2 Ship** | not started | — |

## v2 Wave Progress
```
[####################........................] v2 plan complete; Wave 1 ready to start
```

| Wave | Status | Features | Complexity |
|------|--------|----------|------------|
| W1 (parallel) | ready | CSV export + filter/search | S + S |
| W2 (sequential) | blocked | hotkey → per-app filter | S + S/M |
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
- [ ] **v2 Plan → Build** — gated on user approval of 4 cross-feature decisions

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
*(none — Wave 1 ready to start on user approval)*

## Resume

**v2 planning complete; awaiting user signoff to begin Wave 1.**

- **If approving:** start **Wave 1** — CSV export (`W1-A`) + filter/search (`W1-B`) in parallel. Both S complexity, isolated to UI + exporter layers, no capture-pipeline risk.
- **If reshaping:** revisit cross-feature decisions in `decisions.md` (CFD-1..4) or per-feature shape in `docs/specs/v2-features.md`.
- **Folder rename housekeeping**: repo folder is still `1-macOS/DownKeyCounter/` on disk. Between sessions: close terminals/editors, `mv DownKeyCounter Tachograph`, reopen Claude Code there.
- **Stale plan doc**: `IMPLEMENTATION_PLAN.md` from v1 is fully checked off — archive or delete before v2 planning artifacts proliferate.

---
*Updated by Claude. Source of truth for project position.*
