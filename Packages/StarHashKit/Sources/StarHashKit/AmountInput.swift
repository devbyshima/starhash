import Foundation

/// The amount typed on Pay's keypad, as whole RWF. Kept as a value with
/// pure edits so the keypad's rules (no leading zeros, a ceiling, delete
/// one digit at a time) are tested here instead of in the view.
public struct AmountInput: Hashable, Sendable {
    public enum Key: Hashable, Sendable {
        case digit(Int)
        case delete
        case clear
    }

    /// Always between 0 and `maximum`.
    public private(set) var value: Int
    public let maximum: Int

    public init(value: Int = 0, maximum: Int = Money.maximumAmount) {
        self.maximum = max(0, maximum)
        self.value = min(max(0, value), self.maximum)
    }

    /// Applies one key. Returns false when nothing changed (a digit past the
    /// ceiling, delete or clear at zero, a leading zero), so the caller can
    /// play a different haptic or none.
    @discardableResult
    public mutating func apply(_ key: Key) -> Bool {
        let old = value
        switch key {
        case .digit(let digit):
            guard (0...9).contains(digit) else { return false }
            // Multiplying first could overflow on a huge ceiling; checking
            // against (maximum - digit) / 10 never does.
            guard value <= (maximum - digit) / 10 else { return false }
            value = value * 10 + digit
        case .delete:
            value /= 10
        case .clear:
            value = 0
        }
        return value != old
    }

    public var isZero: Bool { value == 0 }
}
