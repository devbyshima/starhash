import SwiftUI
import UIKit

// A press is felt the moment it is made: every StarHash button style plays
// an impact as the button goes down (none when disabled, since a disabled
// button never reports a press). The weight follows the button: medium for
// the large ones (Pay, Balance, Continue, a sheet's button, Delete All
// Data), light for the small round glass ones and rows. Page changes have
// their own (`NavigationHaptics`), and a few results their own too (a
// payment dialled, a code copied).

extension View {
    /// An impact of `weight` as `isPressed` turns true.
    func starhashPressHaptic(_ isPressed: Bool, weight: SensoryFeedback.Weight = .medium) -> some View {
        sensoryFeedback(trigger: isPressed) { _, pressed in
            pressed ? .impact(weight: weight) : nil
        }
    }
}

/// `.plain`, with the press haptic: for buttons that draw their own look,
/// such as the round glass ones.
struct HapticPlainButtonStyle: ButtonStyle {
    /// nil plays nothing, for a button whose action plays its own.
    var weight: SensoryFeedback.Weight? = .light

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .sensoryFeedback(trigger: configuration.isPressed) { _, pressed in
                guard pressed, let weight else { return nil }
                return .impact(weight: weight)
            }
    }
}

/// A tap felt once it lands, for a button that also opens a menu on a long
/// press: a press haptic there would play on touch-down and then again as
/// the menu opens. Its style leaves the press silent; its action plays this.
@MainActor
enum TapHaptic {
    static func play(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

extension ButtonStyle where Self == HapticPlainButtonStyle {
    /// A plain button that taps lightly as it goes down.
    static var hapticPlain: HapticPlainButtonStyle { HapticPlainButtonStyle() }
}
