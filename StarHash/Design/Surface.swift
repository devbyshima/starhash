import SwiftUI
import UIKit

/// What a view sits on, so one colour name can read on either: the blue
/// page, or a white card or pale sheet. In light mode text on the page is
/// white and text on a card is near black; dark mode is the same on both.
/// Cards and sheets say so with `.starhashSurface(.card)`; everything else
/// is on the page.
enum StarHashSurface: Int, Sendable {
    case page
    case card
}

/// The surface as a UIKit trait, so `Color(uiColor:)` providers can read
/// it as they resolve, and bridged to SwiftUI's environment.
struct StarHashSurfaceTrait: UITraitDefinition {
    static let defaultValue = StarHashSurface.page
    static let affectsColorAppearance = true
}

extension UITraitCollection {
    var starhashSurface: StarHashSurface { self[StarHashSurfaceTrait.self] }
}

extension UIMutableTraits {
    var starhashSurface: StarHashSurface {
        get { self[StarHashSurfaceTrait.self] }
        set { self[StarHashSurfaceTrait.self] = newValue }
    }
}

private struct StarHashSurfaceKey: UITraitBridgedEnvironmentKey {
    static let defaultValue = StarHashSurface.page

    static func read(from traitCollection: UITraitCollection) -> StarHashSurface {
        traitCollection.starhashSurface
    }

    static func write(to mutableTraits: inout any UIMutableTraits, value: StarHashSurface) {
        mutableTraits.starhashSurface = value
    }
}

extension EnvironmentValues {
    var starhashSurface: StarHashSurface {
        get { self[StarHashSurfaceKey.self] }
        set { self[StarHashSurfaceKey.self] = newValue }
    }
}

extension View {
    /// Marks this view and everything in it as sitting on `surface`.
    func starhashSurface(_ surface: StarHashSurface) -> some View {
        environment(\.starhashSurface, surface)
    }
}

extension Color {
    /// One colour for light mode on the page, one for light mode on a card
    /// or sheet, and one for dark mode, resolved by the system as the
    /// appearance or the surface changes.
    init(page: Color, card: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark { return UIColor(dark) }
            return traits.starhashSurface == .card ? UIColor(card) : UIColor(page)
        })
    }
}
