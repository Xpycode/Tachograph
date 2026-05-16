import Foundation

/// Tagged stream payload from EventTapService. Replaces the previous
/// `AsyncStream<InputEvent>` shape so the service can append rows on
/// keyDown/mouseDown and patch them on keyUp/mouseUp without needing
/// the ViewModel to reason about mutation timing.
///
/// Extending this enum is the seam W3-C uses to deliver async AX
/// element-label enrichment after a click row has already been appended.
enum EventTapMessage: Sendable {
    case append(InputEvent)
    case holdUpdate(id: UUID, holdMs: Int)
}
