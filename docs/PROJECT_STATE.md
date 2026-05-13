# Project State

> **Size limit: <100 lines.** This is a digest, not an archive. Details go in session logs.

## Identity
- **Project:** DownKeyCounter
- **One-liner:** macOS app that logs global key & mouse events to a live table with clipboard export
- **Tags:** macos, swiftui, input-monitoring, personal-tool
- **Started:** 2026-05-13

## Current Position
- **Funnel:** build (Waves 1–5 done) → awaits manual AC verification
- **Phase:** functional build complete; manual smoke test pending
- **Focus:** User walks AC #1–#10 checklist; capture any defects as new tasks
- **Status:** waiting for user
- **Last updated:** 2026-05-14

## Funnel Progress

| Funnel | Status | Gate |
|--------|--------|------|
| **Define** | done | Spec at `specs/down-key-counter.md` reviewed + tightened |
| **Plan** | done | `IMPLEMENTATION_PLAN.md` — 7 waves, ~20 atomic tasks |
| **Build** | mostly done | Waves 1–5 GREEN (44 tests + build), AC #11 audited clean. Manual AC #1–#10 pending. Ship prep (Wave 7) deferred. |

## Phase Progress
```
[################....] 80% — App builds, runs, tests green. Manual verification next.
```

| Phase | Status | Tasks |
|-------|--------|-------|
| Discovery | done | ✓ |
| Planning | done | ✓ |
| Implementation | done | Waves 1–5 complete |
| Verification | 🔶 active | Manual AC #1–#10 walkthrough; AC #11 done; AC #12 deferred to Wave 7 |
| Polish | ⚪ | Wave 7 (icon, signing, notarize, DMG) |

## Readiness

| Dimension | Status | Notes |
|-----------|--------|-------|
| Features | 🔶 WIP | Spec drafted; awaits review |
| UI/Polish | ⚪ — | Not started |
| Testing | ⚪ — | Not started |
| Docs | 🔶 WIP | CLAUDE.md + README.md + spec done; need icon design |
| Distribution | ⚪ — | Will need Developer ID + notarization workflow |

## Validation Gates
- [ ] **Define → Plan**: Spec reviewed, acceptance criteria signed off
- [ ] **Plan → Build**: `IMPLEMENTATION_PLAN.md` exists with atomic tasks
- [ ] **Build → Ship**: Notarized DMG builds reproducibly; accessibility-permission flow tested cold

## Active Decisions
- 2026-05-13: macOS 15 Sequoia minimum (latest SwiftUI Table APIs, personal-use Mac is current)
- 2026-05-13: Global capture via CGEventTap, sandbox off, direct distribution only (not MAS — sandbox would block global event monitoring)
- 2026-05-13: Duration column = inter-event interval (ms since previous event), not key-hold duration
- 2026-05-13: Session-only log (in-memory) — no disk persistence, clipboard export is the only way data leaves the app
- 2026-05-13: Bundle ID `dev.gmkonsortium.DownKeyCounter`

## Blockers
*(none)*

## Resume
*(no in-flight task)*

---
*Updated by Claude. Source of truth for project position.*
