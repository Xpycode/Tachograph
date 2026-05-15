import Foundation

/// Discriminated key for EventTapService.pendingDowns. Keyboard keycodes
/// and mouse button numbers live in different number spaces; folding them
/// into a single dictionary needs a tagged union rather than overlapping
/// integer ranges.
enum HoldKey: Hashable, Sendable {
    /// Keyboard keycode from `kCGKeyboardEventKeycode`.
    case key(UInt16)
    /// Button number from `kCGMouseEventButtonNumber` (0=left, 1=right, 2+=other).
    case mouseButton(Int64)
}
