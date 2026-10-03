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
        let tint = tint ?? pageTint
        if #available(iOS 26.0, *) {
            content.glassEffect(Glass.regular.tint(tint).interactive(interactive), in: shape)
        } else {
            content
                .background(tint ?? .clear, in: shape)
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(Color.starhashPrimaryText.opacity(0.10), lineWidth: 0.5))
        }
    }
}

/// The top fade's measurements.
enum StarHashTopFade {
    /// Below a bar that holds solid to its foot: long enough that rows
    /// visibly fade as they reach it.
    static let heldLength: CGFloat = 40
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
    ///
    /// `holdsToBottom` keeps the page colour solid down to the bar's bottom
    /// edge, for a bar with text at its foot (the recipient screen's
    /// section label) that rows would otherwise ghost through, and fades
    /// out over a longer stretch below it so the fade still shows.
    func starhashTopFade(holdsToBottom: Bool = false) -> some View {
        background(alignment: .top) {
            Group {
                if holdsToBottom {
                    VStack(spacing: 0) {
                        Color.starhashBackground
                        LinearGradient(colors: [.starhashBackground, .starhashBackground.opacity(0.85), .starhashBackground.opacity(0)], startPoint: .top, endPoint: .bottom)
                            .frame(height: StarHashTopFade.heldLength)
                    }
                } else {
                    LinearGradient(
                        colors: [.starhashBackground, .starhashBackground.opacity(0.85), .starhashBackground.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .padding(.bottom, holdsToBottom ? -StarHashTopFade.heldLength : -18)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
        }
    }

    /// The same fade under a system navigation bar, laid over a scroll view
    /// that runs beneath it: the page colour solid to the bar's foot, as on
    /// the recipient screen (at 85% the title's text let what scrolled
    /// under it ghost through), then fading out below.
    func starhashTopFadeUnderNavigationBar() -> some View {
        overlay(alignment: .top) {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    Color.starhashBackground
                        .frame(height: proxy.safeAreaInsets.top)
                    LinearGradient(
                        colors: [.starhashBackground, .starhashBackground.opacity(0.85), .starhashBackground.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: StarHashTopFade.heldLength)
                }
                .offset(y: -proxy.safeAreaInsets.top)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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
    /// (Settings, Help and their pages, the auto-verify setup, the
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
