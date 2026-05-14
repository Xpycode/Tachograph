# Project State

> **Size limit: <100 lines.** This is a digest, not an archive. Details go in session logs.

## Identity
- **Project:** Tachograph
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
| **Define** | done | Spec at `specs/tachograph.md` reviewed + tightened |
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
**Next steps on resume:**
1. User: re-grant Accessibility for `com.lucesumbrarum.Tachograph` (one-time after the rename — new bundle id, fresh TCC entry).
2. User: Product → Archive in Xcode (scheme `Tachograph`) → Distribute App → Developer ID → Notarize. Export the notarized `.app` to `04_Exports/v1.0.0/`.
3. Claude: package signed DMG via `hdiutil`, draft GitHub v1.0.0 release notes, verify mount + first-launch on a clean account if available.
4. (Optional follow-up) User: rename repo folder `1-macOS/DownKeyCounter/` → `1-macOS/Tachograph/` between sessions to match.

---
*Updated by Claude. Source of truth for project position.*
