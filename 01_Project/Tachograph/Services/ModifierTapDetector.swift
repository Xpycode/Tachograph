struct ModifierTapDetector: Sendable {
    enum Modifier: CaseIterable, Sendable {
        case fn, control, option, shift, command
    }

    enum Input: Sendable {
        case modifierPressed(Modifier)
        case modifierReleased(Modifier)
        case keyDown
    }

    private var heldWithCombine: [Modifier: Bool] = [:]

    mutating func process(_ input: Input) -> Modifier? {
        switch input {
        case .modifierPressed(let m):
            heldWithCombine[m] = false
            return nil
        case .modifierReleased(let m):
            guard let combined = heldWithCombine.removeValue(forKey: m) else {
                return nil
            }
            return combined ? nil : m
        case .keyDown:
            for key in heldWithCombine.keys {
                heldWithCombine[key] = true
            }
            return nil
        }
    }
}
