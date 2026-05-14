# DownKeyCounter

A macOS app that logs every key press and mouse click globally with timing data, displayed in a modern table view with one-click clipboard export.

> Pointer: full Directions system at `docs/00_base.md`. Read that first when starting a session.

---

## Quick Facts

| | |
|---|---|
| Platform | macOS (native, SwiftUI) |
| Minimum OS | macOS 15 Sequoia |
| Swift | 5.10+ |
| Distribution | Direct via GitHub (notarized, **not** Mac App Store) |
| Sandbox | **Off** (required for global event monitoring) |
| Permissions | Accessibility (System Settings → Privacy & Security → Accessibility) |
| Audience | Personal use; may share via GitHub |
| Bundle ID | `dev.gmkonsortium.DownKeyCounter` |

---

## What It Does

1. Start/stop global capture of keyboard and mouse-button events.
2. Each captured event is added as a row to a live table:
   - **Left:** the key or mouse button pressed (human-readable: `⌘A`, `Space`, `Esc`, `Left Click`)
   - **Right:** UTC timestamp + **inter-event interval** (ms since the previous event)
3. Top toolbar holds the controls: Start, Stop, Clear, Copy Log.
4. Copy Log writes the full session to the clipboard as TSV (paste-friendly into spreadsheets).
5. Log is **session-only** — quitting the app discards it.

---

## Tech Stack

- **UI:** SwiftUI, `Table` for the event list
- **State:** `@MainActor @Observable` ViewModel
- **Input capture:** `CGEventTap` for global key/mouse events (requires Accessibility)
- **Threading:** ViewModel = `@MainActor`; capture service = `actor`
- **Persistence:** none (session-only); `@AppStorage` only for window prefs if needed
- **Concurrency:** Swift Concurrency (`async/await`, `AsyncStream` for event flow)

---

## Architecture

```
01_Project/DownKeyCounter/
├── DownKeyCounterApp.swift           # @main entry
├── Models/
│   └── InputEvent.swift              # struct: id, kind, label, utc, intervalMs
├── ViewModels/
│   └── CaptureViewModel.swift        # @MainActor @Observable
├── Services/
│   ├── EventTapService.swift         # actor — CGEventTap lifecycle
│   ├── KeyNameMapper.swift           # virtual keycode → "⌘A", "Space", ...
│   └── ClipboardExporter.swift       # TSV serializer + NSPasteboard write
├── Views/
│   ├── ContentView.swift             # toolbar + table
│   ├── ControlsToolbar.swift         # Start/Stop/Clear/Copy
│   └── EventTable.swift              # SwiftUI Table<InputEvent>
└── Resources/
    └── Assets.xcassets
```

Folder layout at repo root follows Directions:
- `01_Project/` — Xcode project
- `02_Design/` — icon, mockups
- `03_Screenshots/` — promo / README assets
- `04_Exports/` — DMGs (gitignored)
- `docs/` — Directions: specs, decisions, sessions

---

## Rules

### Threading
- ViewModels are `@MainActor`. Always.
- Services are `actor` **by default** — except `EventTapService`, which is `@MainActor final class` with `nonisolated(unsafe)` callback-thread state. Reason: `CGEventTapCallBack` is a C function pointer, so an actor bridge would force a `Task { await }` hop per event, reordering events and breaking the spec's <50 ms latency budget. The tap is installed on `CFRunLoopGetMain()` so callbacks already run on the main thread; main-thread confinement is enforced by the run-loop choice, not by the type system. See `docs/decisions.md` (2026-05-14 entry).
- Events cross from the service to the ViewModel via `AsyncStream<InputEvent>`.

### Error handling
- Never `try?` to swallow. If accessibility permission is missing, surface a clear UI state with a button that opens System Settings to the right pane.
- Failure to install the event tap → user-visible error row in the toolbar area, not a silent no-op.

### Security & privacy
- This app records keystrokes globally. Treat the log as sensitive even though it's in-memory only.
- Never write events to disk. Never send anywhere over network.
- Clipboard export is explicit and user-initiated only.

### macOS specifics
- App is **unsandboxed** — required for `CGEventTap` global listening.
- Activation policy: regular (dock icon + window). No menu-bar-only mode in v1.
- Accessibility permission check on launch; if missing, prompt with `AXIsProcessTrustedWithOptions`.

---

## Build Commands

```bash
# Build (Debug)
xcodebuild -project 01_Project/DownKeyCounter.xcodeproj \
           -scheme DownKeyCounter -configuration Debug build

# Clean + Build (preferred per global rules)
killall DownKeyCounter 2>/dev/null || true
xcodebuild -project 01_Project/DownKeyCounter.xcodeproj \
           -scheme DownKeyCounter clean build

# Run
open ~/Library/Developer/Xcode/DerivedData/DownKeyCounter-*/Build/Products/Debug/DownKeyCounter.app
```

---

## Dev signing

`project.yml` uses `DEVELOPMENT_TEAM=FDMSRXXN73` (the real team ID from the cert's OU, not the H56HM4MMZS suffix in its CN) + `CODE_SIGN_STYLE=Automatic`. This produces a stable Designated Requirement so macOS TCC keeps the Accessibility grant across rebuilds. Don't revert to "Sign to Run Locally" unless you want the re-grant dance back.

When something goes wrong with the grant, `tccutil reset Accessibility dev.gmkonsortium.DownKeyCounter` clears it and you re-grant once.

## Known Constraints

- `CGEventTap` only works when the host process is trusted in Accessibility. After granting, **the app must be relaunched** — macOS does not hot-swap that grant.
- Modifier-only events (pressing ⌘ alone) come through as `flagsChanged`, not `keyDown`. Handle both event types.
- Some system shortcuts (e.g. screenshot capture) may not surface as keyDown events depending on tap location (`cgSessionEventTap` vs `cgAnnotatedSessionEventTap`). Document whatever choice we make.
- Notarization requires Developer ID Application cert; see `~/.claude/apple-developer.md` for credentials.

---

## Critical Rules (Learned the Hard Way)

*(populated as we discover them)*

---

*Last updated 2026-05-13 during /setup.*
