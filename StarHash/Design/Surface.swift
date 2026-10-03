import SwiftUI
import UIKit

/// What a view sits on, so one colour name can read on each: the page, a
/// light-mode sheet's deep-blue glass, or a card inside a sheet. Text on
/// the sheet's glass is white; on the page and on cards it is near black.
/// Dark mode is the same on all three. `sheetGlass` marks the sheet and
/// `sheetCard` marks its cards; everything else is on the page.
enum StarHashSurface: Int, Sendable {
    case page
    case sheet
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
    /// One colour for light mode (the page and cards), one for light mode
    /// on a sheet's deep-blue glass, and one for dark mode, resolved by the
    /// system as the appearance or the surface changes.
    init(light: Color, sheet: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark { return UIColor(dark) }
            return traits.starhashSurface == .sheet ? UIColor(sheet) : UIColor(light)
        })
    }
}
