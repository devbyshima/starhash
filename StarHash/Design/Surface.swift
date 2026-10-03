import SwiftUI
import UIKit

/// What a view sits on, so one colour name can read on each: anything
/// else, or a sheet's card, which is black in light mode. Text inside a
/// sheet card is white there; dark mode is the same on both. `sheetCard`
/// marks its content.
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
    /// One colour for light mode, one for light mode inside a sheet's
    /// black card, and one for dark mode, resolved by the system as the
    /// appearance or the surface changes.
    init(light: Color, card: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark { return UIColor(dark) }
            return traits.starhashSurface == .card ? UIColor(card) : UIColor(light)
        })
    }
}
