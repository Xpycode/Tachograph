# Project State

> **Size limit: <100 lines.** This is a digest, not an archive. Details go in session logs.

## Identity
- **Project:** DownKeyCounter
- **One-liner:** macOS app that logs global key & mouse events to a live table with clipboard export
- **Tags:** macos, swiftui, input-monitoring, personal-tool
- **Started:** 2026-05-13

## Current Position
- **Funnel:** ship prep (Wave 7)
- **Phase:** functional build verified; awaiting icon + notarized archive
- **Focus:** Awaiting Kling-AI-generated app icon at `02_Design/AppIcon-1024.png`; then Xcode Archive → Distribute → Notarize, then DMG + GitHub release
- **Status:** waiting for user (icon generation)
- **Last updated:** 2026-05-14

## Funnel Progress

| Funnel | Status | Gate |
|--------|--------|------|
| **Define** | done | Spec at `specs/down-key-counter.md` reviewed + tightened |
| **Plan** | done | `IMPLEMENTATION_PLAN.md` — 7 waves, ~20 atomic tasks |
| **Build** | done | Waves 1–5 GREEN. Wave 6 functional AC #1–#9, #11 visibly verified; #3/#4/#10 trivial-remaining. |
| **Ship** | active | Wave 7: icon → archive → notarize → DMG → release |

## Phase Progress
```
[##################..] 90% — Wave 6 fixes shipped to main; ship prep underway.
```

| Phase | Status | Tasks |
|-------|--------|-------|
| Discovery | done | ✓ |
| Planning | done | ✓ |
| Implementation | done | Waves 1–5 complete |
| Verification | done | AC #1, 2, 5, 6, 7, 8, 9, 11 visibly verified; #3/#4/#10 trivial |
| Polish (Wave 7) | 🔶 active | Icon (awaiting Kling AI gen) → Archive in Xcode → DMG → GitHub release |

## Readiness

| Dimension | Status | Notes |
|-----------|--------|-------|
| Features | ✅ done | All v1 spec features implemented |
| UI/Polish | 🔶 WIP | App working; needs app icon |
| Testing | ✅ done | 44 unit tests green; manual AC walked |
| Docs | ✅ done | CLAUDE.md, README, spec, decisions, sessions all current |
| Distribution | 🔶 WIP | User will Archive + Notarize in Xcode Organizer; Developer ID Application cert needed |

## Validation Gates
- [x] **Define → Plan**: Spec reviewed + tightened (6 gaps closed 2026-05-13)
- [x] **Plan → Build**: `IMPLEMENTATION_PLAN.md` exists with 7 waves, ~20 atomic tasks
- [ ] **Build → Ship**: Awaiting notarized DMG + clean-install verification (AC #12)

## Active Decisions
- 2026-05-14: Dev builds signed with Apple Development cert (Team ID `FDMSRXXN73`) instead of ad-hoc, so TCC Accessibility grants survive rebuilds. Gotcha logged: team ID is the cert's `OU` field, not the suffix in its CN.
- 2026-05-14: User will handle Archive + Notarize inside Xcode Organizer; Claude handles icon pipeline + DMG + release.
- 2026-05-14: `EventTapService` is `@MainActor final class`, not `actor`, to avoid Task-hop reordering of CGEventTap callbacks (see `decisions.md`).
- 2026-05-13: macOS 15 Sequoia minimum.
- 2026-05-13: Global capture via CGEventTap, sandbox off, direct distribution only.
- 2026-05-13: Δ column = inter-event interval (ms), not key-hold duration.
- 2026-05-13: Session-only log; clipboard is the only data egress.
- 2026-05-13: Bundle ID `dev.gmkonsortium.DownKeyCounter`.

## Blockers
*(none — waiting on user-side icon generation, not a blocker per se)*

## Resume
**Next step on resume:** Check whether `02_Design/AppIcon-1024.png` exists. If yes → run the appiconset pipeline + wire into XcodeGen. If no → ping user about Kling AI status.

---
*Updated by Claude. Source of truth for project position.*
