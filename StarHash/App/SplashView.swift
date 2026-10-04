import SwiftUI

/// The launch splash, after Beam's: the StarHash mark on the page's colour
/// (which the system's launch screen already shows, so the two run on as
/// one), lit from the foot of the screen. The mark, raised in relief and
/// casting a soft shadow, springs in with no glow of its own while a
/// shimmer sweeps it, then the whole splash fades into the app. Reduce
/// Motion keeps it still and short, the relief without the shimmer.
struct SplashView: View {
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now
    @State private var appears = false

    private let markSize: CGFloat = 104

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let time = Float(timeline.date.timeIntervalSince(start))
            ZStack {
                SplashBackground()
                mark(time: time)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) { appears = true }
            Task {
                try? await Task.sleep(for: .seconds(reduceMotion ? 0.4 : 1.0))
                onFinish()
            }
        }
        .accessibilityElement()
        .accessibilityLabel("StarHash")
    }

    private func mark(time: Float) -> some View {
        RaisedMark(size: markSize)
            .modifier(SplashShimmer(size: markSize, time: time, isOn: !reduceMotion))
            // Lifted off the page.
            .shadow(color: .black.opacity(0.22), radius: 10, y: 7)
            .scaleEffect(appears ? 1 : 0.72)
            .opacity(appears ? 1 : 0)
    }
}

/// The page's colour lit from the foot of the screen: in dark mode Beam's
/// soft blue glow rising out of the bottom edge; in light mode a gradient
/// that turns the blue to white by the bottom edge, as a glow would not
/// read on the blue.
struct SplashBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color.starhashBackground
            if colorScheme == .dark {
                Circle()
                    .fill(Color.splashGlow.gradient)
                    .visualEffect { content, proxy in content.offset(y: proxy.size.height * 1.07) }
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .blur(radius: 90)
            } else {
                LinearGradient(
                    stops: [
                        .init(color: Color.splashGlow.opacity(0), location: 0.5),
                        .init(color: Color.splashGlow.opacity(0.55), location: 0.82),
                        .init(color: Color.splashGlow, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }
}

/// The StarHash mark in relief, as an emboss: its face a little lighter
/// to the top left and deeper to the bottom right, a soft bevel of light
/// along the edges that face the top left (the mark less a copy of itself
/// moved down and right) and of shade along those facing away.
private struct RaisedMark: View {
    let size: CGFloat

    var body: some View {
        let shape = StarHashMarkShape()
        let edge = size * 0.035
        ZStack {
            shape.fill(Color.starhashMarkGlyph)
            shape.fill(LinearGradient(
                colors: [.white.opacity(0.16), .clear, .black.opacity(0.24)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            bevel(shape, towards: CGSize(width: edge, height: edge), colour: .white.opacity(0.7), edge: edge)
            bevel(shape, towards: CGSize(width: -edge, height: -edge), colour: .black.opacity(0.45), edge: edge)
        }
        .frame(width: size, height: size)
    }

    /// The band along the edges facing away from `offset`, softened and
    /// kept inside the mark.
    private func bevel(_ shape: StarHashMarkShape, towards offset: CGSize, colour: Color, edge: CGFloat) -> some View {
        shape.fill(colour)
            .overlay(shape.offset(offset).fill(.black).blendMode(.destinationOut))
            .compositingGroup()
            .blur(radius: edge * 0.6)
            .mask(shape)
    }
}

/// The shimmer (SplashEffects.metal), only while motion is allowed.
private struct SplashShimmer: ViewModifier {
    let size: CGFloat
    let time: Float
    let isOn: Bool

    func body(content: Content) -> some View {
        if isOn {
            content.layerEffect(
                ShaderLibrary.splashShimmer(.float2(size, size), .float(time)),
                maxSampleOffset: .zero
            )
        } else {
            content
        }
    }
}

/// Shows the splash over the app on a cold launch, then fades it into the
/// app. The welcome and rating notes wait for it (`splashActive`), so they
/// never open over it. Debug launches that set up a screen skip it, so a
/// screenshot sees the screen; `-splash` shows it anyway.
struct SplashGate<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var showsSplash = SplashGate.showsAtLaunch

    var body: some View {
        ZStack {
            content
                .environment(\.splashActive, showsSplash)
            if showsSplash {
                SplashView {
                    withAnimation(.smooth(duration: 0.35)) { showsSplash = false }
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
    }

    private static var showsAtLaunch: Bool {
        #if DEBUG
        let arguments = DebugLaunch.arguments
        if arguments.contains("-splash") { return true }
        return !arguments.contains { $0.hasPrefix("-") && $0 != "-splash" && !$0.hasPrefix("-NS") && !$0.hasPrefix("-Apple") && !$0.hasPrefix("-UI") }
        #else
        return true
        #endif
    }
}

extension EnvironmentValues {
    /// True while the launch splash is on screen.
    @Entry var splashActive = false
}
