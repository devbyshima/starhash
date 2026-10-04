import SwiftUI

// Liquid Glass on iOS 26 and later, a close material look-alike on iOS 18.
// Always go through these helpers instead of calling `glassEffect` directly,
// so the deployment target can stay at iOS 18.

extension View {
    /// Glass behind this view, clipped to `shape`. `tint` colours the glass
    /// (pass it with its opacity), or else the page's `starhashGlassTint`;
    /// before iOS 26 it is laid over the material.
    func starhashGlass(in shape: some Shape, interactive: Bool = false, tint: Color? = nil) -> some View {
        modifier(StarHashGlassModifier(shape: shape, interactive: interactive, tint: tint))
    }

    /// Capsule glass, the shape of every toolbar control in the reference.
    func starhashGlass(interactive: Bool = false, tint: Color? = nil) -> some View {
        starhashGlass(in: Capsule(), interactive: interactive, tint: tint)
    }

    /// The system glass button style ("Cancel", "Save", the round close
    /// button), or a translucent capsule before iOS 26.
    @ViewBuilder
    func starhashGlassButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(FallbackGlassButtonStyle())
        }
    }
}

extension EnvironmentValues {
    /// A tint for every glass shape on a page that sets one: Pay's blue
    /// would otherwise turn the glass a pale cyan.
    @Entry var starhashGlassTint: Color?
    /// On Pay's page, the blue in light mode, where the pages' greys turn
    /// muddy: views that sit on both (a recipient's tile) switch to Pay's
    /// text colours.
    @Entry var starhashOnPay = false
}

private struct StarHashGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    let interactive: Bool
    let tint: Color?

    @Environment(\.starhashGlassTint) private var pageTint

    func body(content: Content) -> some View {
        // Every page is the blue in light mode, where untinted glass turns
        // a pale cyan, so the deep-blue tint is the default.
        let tint: Color = tint ?? pageTint ?? .starhashGlassTint
        if #available(iOS 26.0, *) {
            content.glassEffect(Glass.regular.tint(tint).interactive(interactive), in: shape)
        } else {
            content
                .background(tint, in: shape)
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(Color.starhashPrimaryText.opacity(0.10), lineWidth: 0.5))
        }
    }
}

/// Groups glass shapes so they blend and morph together on iOS 26.
struct StarHashGlassContainer<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

private struct FallbackGlassButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.starhash(.body, weight: .medium))
            .foregroundStyle(isEnabled ? Color.starhashPrimaryText : Color.starhashTertiaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.starhashPrimaryText.opacity(0.10), lineWidth: 0.5))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}

extension View {
    /// The round glass icon button of a page's header (search, close,
    /// back, add, the wallet). Clear Liquid Glass, as the tab bar's.
    func starhashCircleButton() -> some View {
        self
            .font(.system(size: 17, weight: .semibold))
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .starhashGlass(in: Circle(), interactive: true, tint: .clear)
    }
}

extension View {
    /// Pins `content` under scrolling content, like a toolbar. On iOS 26 it
    /// is a safe area bar, so the system's scroll edge effect softens what
    /// scrolls beneath it; plain `safeAreaInset` content gets no such effect.
    /// Before iOS 26, give `content` its own backing.
    @ViewBuilder
    func starhashBottomBar(@ViewBuilder _ content: () -> some View) -> some View {
        if #available(iOS 26.0, *) {
            self.safeAreaBar(edge: .bottom, content: content)
        } else {
            self.safeAreaInset(edge: .bottom, content: content)
        }
    }

    // MARK: Black glass

    /// A container, as the Total card is: in light mode **white glass**,
    /// Liquid Glass over a solid `lightFill` (a white card, a sheet's pale
    /// blue card), which gives it the glass's edge and soft shadow; in dark
    /// **black glass**, the near black as Liquid Glass, a touch darker than
    /// the page with a light rim. Every card, panel and field box goes
    /// through this.
    func starhashContainer(_ lightFill: Color, in shape: some Shape) -> some View {
        modifier(ContainerSurface(lightFill: lightFill, shape: shape))
    }

    // MARK: Total card

    /// The **Total card** surface, the recipient screen's Total: solid white
    /// in light mode, the sheets' near-black glass in dark. Buy's codes and
    /// pinned tiles wear it too, and so does Balance (`interactive`), which
    /// Pay holds to the light look in dark mode as well.
    func starhashTotalCard(in shape: some Shape, interactive: Bool = false) -> some View {
        background(Color.sheetSolidFill, in: shape)
            .starhashGlass(in: shape, interactive: interactive, tint: .sheetGlassTint)
    }

    // MARK: Soft Edge

    /// **Soft Edge**, StarHash's one edge treatment: what scrolls under a
    /// bar (a navigation bar, a page's own header, the total on the
    /// recipient screen, a sheet's foot) softly fades and blurs into it, the
    /// system's own soft scroll edge, as Settings has always had. Put it on
    /// every scroll view and list. Before iOS 26, nothing.
    @ViewBuilder
    func starhashSoftEdge() -> some View {
        if #available(iOS 26.0, *) {
            scrollEdgeEffectStyle(.soft, for: .all)
        } else {
            self
        }
    }

    /// A page's own header (Activity's, Buy's, the recipient screen's) as
    /// a bar the Soft Edge runs under, as under a navigation bar: on iOS 26
    /// a safe area bar, which the scroll edge effect sees; before, a plain
    /// inset.
    @ViewBuilder
    func starhashSoftEdgeHeader(@ViewBuilder _ header: () -> some View) -> some View {
        if #available(iOS 26.0, *) {
            self.safeAreaBar(edge: .top, spacing: 0, content: header)
        } else {
            self.safeAreaInset(edge: .top, spacing: 0, content: header)
        }
    }
}

private struct ContainerSurface<S: Shape>: ViewModifier {
    let lightFill: Color
    let shape: S

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if colorScheme == .dark {
            content.starhashGlass(in: shape, tint: .blackGlassTint)
        } else {
            content
                .background(lightFill, in: shape)
                .starhashGlass(in: shape, tint: lightFill)
        }
    }
}
