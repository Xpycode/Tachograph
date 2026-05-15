import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Global hotkey that toggles capture between idle and capturing.
    /// Default combo is `⌃⌥⌘R` ("R" for Record). The `KeyboardShortcuts`
    /// library persists user overrides in `UserDefaults` automatically —
    /// do not also bind this via `@AppStorage` (single source of truth).
    static let toggleCapture = Self(
        "toggleCapture",
        default: .init(.r, modifiers: [.control, .option, .command])
    )
}
