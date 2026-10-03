import SwiftUI

/// The launch splash, after Beam's: the StarHash mark on the page's colour
/// (which the system's launch screen already shows, so the two run on as
/// one), with a glow rising from the foot of the screen. The mark springs
/// in with a bloom while a shimmer sweeps it, then the whole splash fades
/// into the app. Reduce Motion keeps it still and short.
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
            withAnimation(.spring(response: 0.75, dampingFraction: 0.58)) { appears = true }
            Task {
                try? await Task.sleep(for: .seconds(reduceMotion ? 0.6 : 1.9))
                onFinish()
            }
        }
        .accessibilityElement()
        .accessibilityLabel("StarHash")
    }

    private func mark(time: Float) -> some View {
        StarHashMarkShape()
            .fill(Color.starhashMarkGlyph)
            .frame(width: markSize, height: markSize)
            .modifier(SplashShimmer(size: markSize, time: time, isOn: !reduceMotion))
            .shadow(color: Color.splashGlow.opacity(appears ? 0.55 : 0), radius: appears ? 34 : 0)
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

/// The shimmer, only while motion is allowed.
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
                    withAnimation(.smooth(duration: 0.5)) { showsSplash = false }
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
