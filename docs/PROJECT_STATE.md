# Project State

> **Size limit: <100 lines.** This is a digest, not an archive. Details go in session logs.

## Identity
- **Project:** Tachograph
- **One-liner:** macOS app that logs global key & mouse events to a live table with clipboard export
- **Tags:** macos, swiftui, input-monitoring, personal-tool
- **Started:** 2026-05-13

## Current Position
- **Funnel:** **shipped** — v1.0.0 live on GitHub
- **Phase:** v1 complete; idle until next iteration
- **Focus:** Backlog (`docs/ideas.md`) for v1.1 when ready
- **Status:** idle — v1.0.0 published
- **Last updated:** 2026-05-14

## Funnel Progress

| Funnel | Status | Gate |
|--------|--------|------|
| **Define** | done | Spec at `specs/tachograph.md` reviewed + tightened |
| **Plan** | done | `IMPLEMENTATION_PLAN.md` — 7 waves, ~20 atomic tasks |
| **Build** | done | Waves 1–5 GREEN. Wave 6 functional AC visibly verified. |
| **Ship** | done | v1.0.0 notarized, DMG packaged, GitHub release published |

## Phase Progress
```
[####################] 100% — v1.0.0 shipped 2026-05-14
```

| Phase | Status | Tasks |
|-------|--------|-------|
| Discovery | done | ✓ |
| Planning | done | ✓ |
| Implementation | done | Waves 1–5 complete |
| Verification | done | AC #1, 2, 5, 6, 7, 8, 9, 11 visibly verified |
| Polish (Wave 7) | done | Icon, signing, notarization, DMG, README, LICENSE, GitHub release |

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
- [x] **Build → Ship**: Notarized DMG built, signed by Developer ID, stapled, Gatekeeper accepts

## Active Decisions
- 2026-05-14: **v1.0.0 published** at https://github.com/Xpycode/Tachograph/releases/tag/v1.0.0. Notarized DMG (6.5 MB, SHA256 `e1b43de1…`), MIT-licensed, public. Repo at https://github.com/Xpycode/Tachograph.
- 2026-05-14: Renamed `DownKeyCounter` → **Tachograph**. Reason: name now matches function (records input timing) rather than describing implementation (keyDown events). Atomic rename via `rename/to-tachograph` branch; 44 tests still pass; git tracks file history at 82–100% similarity.
- 2026-05-14: Bundle ID prefix corrected to `com.lucesumbrarum` per `apple-developer.md` primary prefix. Final bundle id: `com.lucesumbrarum.Tachograph`. Earlier `dev.gmkonsortium.*` was synthesized from email — wrong.
- 2026-05-14: Dev builds signed with Apple Development cert (Team ID `FDMSRXXN73`) instead of ad-hoc, so TCC Accessibility grants survive rebuilds. Gotcha logged: team ID is the cert's `OU` field, not the suffix in its CN.
- 2026-05-14: User will handle Archive + Notarize inside Xcode Organizer; Claude handles icon pipeline + DMG + release.
- 2026-05-14: `EventTapService` is `@MainActor final class`, not `actor`, to avoid Task-hop reordering of CGEventTap callbacks (see `decisions.md`).
- 2026-05-13: macOS 15 Sequoia minimum.
- 2026-05-13: Global capture via CGEventTap, sandbox off, direct distribution only.
- 2026-05-13: Δ column = inter-event interval (ms), not key-hold duration.
- 2026-05-13: Session-only log; clipboard is the only data egress.

## Blockers
*(none)*

## Resume

**Project is shipped. Next session is idle.** Open paths if/when picked back up:

- **Backlog for v1.1+**: see `docs/ideas.md` — key-hold duration column, pause hotkey, filter/search, per-app capture filter, heat-map view, CSV-to-file export, multi-session history, menu-bar mode, auto-clear timer, etc.
- **Distribution polish**: notarize the DMG itself (currently only the `.app` inside is stapled — fine for browser downloads, but airdropped DMGs may show a one-time Gatekeeper warning before launch).
- **Folder rename housekeeping**: repo folder is still `1-macOS/DownKeyCounter/` on disk. Between sessions: close terminals/editors, `mv DownKeyCounter Tachograph`, reopen Claude Code there.
- **Stale plan doc**: `IMPLEMENTATION_PLAN.md` is fully checked off — archive to `docs/sessions/` or delete.

---
*Updated by Claude. Source of truth for project position.*
