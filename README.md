# DownKeyCounter

A small macOS app that watches every key press and mouse click and shows them in a live, modern table — with timestamps, inter-event intervals, and one-click clipboard export.

> Status: greenfield — see `docs/PROJECT_STATE.md` for current phase.

## Features

- Global keyboard + mouse-button capture (system-wide, not just inside the app window)
- Live table: key/button on the left, UTC timestamp + inter-event interval on the right
- Start / Stop / Clear controls in the top toolbar
- Copy full session to clipboard as TSV (paste straight into spreadsheets)
- Session-only — nothing is written to disk, nothing leaves your machine

## Requirements

- macOS 15 Sequoia or later
- Accessibility permission granted to DownKeyCounter (System Settings → Privacy & Security → Accessibility)

## Install

Coming soon — direct download from GitHub Releases (notarized DMG). No App Store version planned.

## Privacy

DownKeyCounter records every key you press while capture is running. **No log data ever leaves the app** — there's no networking code, no analytics, no disk writes. Quitting the app discards the session. Clipboard export is explicit and user-initiated.

## License

TBD.
