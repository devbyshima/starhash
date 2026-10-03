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
    /// The round glass icon button used in sheet headers (close, back,
    /// confirm, add).
    func starhashCircleButton() -> some View {
        self
            .font(.system(size: 17, weight: .semibold))
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .starhashGlass(in: Circle(), interactive: true)
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

    /// Activity's top fade: content scrolling up under the bar fades into
    /// the page colour, solid behind the bar and clearing 18pt below it,
    /// instead of the system's blur. Drawn behind `content` from the top
    /// of the screen; pair it with `starhashHidesTopEdgeEffect()` on the
    /// scroll view underneath.
    func starhashTopFade() -> some View {
        background(alignment: .top) {
            LinearGradient(
                colors: [.starhashBackground, .starhashBackground.opacity(0.85), .starhashBackground.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .padding(.bottom, -18)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
        }
    }

    /// No system scroll edge effect at the top, for a screen whose header
    /// draws its own.
    @ViewBuilder
    func starhashHidesTopEdgeEffect() -> some View {
        if #available(iOS 26.0, *) {
            scrollEdgeEffectHidden(true, for: .top)
        } else {
            self
        }
    }

    /// For a scroll view that runs under a bar at the bottom (the tab bar,
    /// Search's bar): on iOS 26 and later what scrolls beneath fades and
    /// blurs into the bar, as under any system bar, instead of showing
    /// sharp beside the glass.
    @ViewBuilder
    func starhashSoftBottomEdge() -> some View {
        if #available(iOS 26.0, *) {
            scrollEdgeEffectStyle(.soft, for: .bottom)
        } else {
            self
        }
    }

    /// The same at the top, for a scroll view under a navigation bar
    /// (Settings and its pages, the auto-verify setup, the
    /// recipient screen): what scrolls up fades and blurs under the bar, as
    /// it does under Pay's, Buy's and Activity's headers, instead of being
    /// cut off sharp.
    @ViewBuilder
    func starhashSoftTopEdge() -> some View {
        if #available(iOS 26.0, *) {
            scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            self
        }
    }
}
