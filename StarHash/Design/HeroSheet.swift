import SwiftUI

// The hero sheet, after the owner's reference (iOS's Share Wallpaper sheet,
// "Bring iPhones Together"): a round close button on the left and a small
// title centred at the top, a picture, a bold title and a grey line under
// it, both centred, and one capsule button at the foot. No grabber: the
// close button says how to leave. The sheets that explain one thing (People
// Nearby's intro, a request, the voice line, Show My Name) are built on it;
// the rest keep SheetKit's large title.

/// A hero sheet: `hero` over `title` and `message`, then `content` (a card,
/// when the sheet has more to show), then `actions`. Sized to what it holds.
/// `onClose` nil leaves the close button out, for a sheet only an answer
/// closes.
struct HeroSheet<Hero: View, Content: View, Actions: View>: View {
    let caption: String
    let title: String
    let message: String?
    let onClose: (() -> Void)?
    /// What VoiceOver calls the close button: "Not Now" where closing is
    /// an answer.
    let closeLabel: String
    let hero: Hero
    let content: Content
    let actions: Actions

    @State private var height: CGFloat = 480

    init(
        caption: String,
        title: String,
        message: String? = nil,
        onClose: (() -> Void)? = nil,
        closeLabel: String = "Close",
        @ViewBuilder hero: () -> Hero,
        @ViewBuilder content: () -> Content,
        @ViewBuilder actions: () -> Actions
    ) {
        self.caption = caption
        self.title = title
        self.message = message
        self.onClose = onClose
        self.closeLabel = closeLabel
        self.hero = hero()
        self.content = content()
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: 0) {
            HeroSheetBar(caption: caption, onClose: onClose, closeLabel: closeLabel)

            hero
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(catalog: title)
                    .font(.sheet(24, .bold, relativeTo: .title2))
                    .tracking(StarHashTracking.display(24))
                    .foregroundStyle(Color.sheetBrandText)
                    .accessibilityAddTraits(.isHeader)
                if let message {
                    Text(catalog: message)
                        .font(.sheetCallout)
                        .lineSpacing(2)
                        .foregroundStyle(Color.sheetSecondaryText)
                }
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 28)

            content
                .padding(.horizontal, 18)
                .padding(.top, 20)

            VStack(spacing: 6) { actions }
                .padding(.horizontal, 18)
                .padding(.top, 24)
                .padding(.bottom, 16)
        }
        .sheetHeight($height)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.container, edges: .bottom)
        .sheetGlass(detents: [.height(height - 4)], dragIndicator: .hidden)
    }
}

extension HeroSheet where Content == EmptyView {
    init(
        caption: String,
        title: String,
        message: String? = nil,
        onClose: (() -> Void)? = nil,
        closeLabel: String = "Close",
        @ViewBuilder hero: () -> Hero,
        @ViewBuilder actions: () -> Actions
    ) {
        self.init(caption: caption, title: title, message: message, onClose: onClose, closeLabel: closeLabel, hero: hero, content: { EmptyView() }, actions: actions)
    }
}

/// The hero sheet's top: the close button on the left, the caption centred.
struct HeroSheetBar: View {
    let caption: String
    var onClose: (() -> Void)?
    var closeLabel = "Close"

    var body: some View {
        ZStack {
            Text(catalog: caption)
                .font(.sheetHeadline)
                .foregroundStyle(Color.sheetBrandText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 56)
            HStack {
                if let onClose { SheetCloseButton(label: closeLabel, action: onClose) }
                Spacer()
            }
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }
}

/// The small round glass close button at a hero sheet's top left: a grey
/// cross on the sheet's chip glass, 32pt, in a 44pt place to tap.
struct SheetCloseButton: View {
    var label = "Close"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(symbol: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.sheetSecondaryText)
                .frame(width: 32, height: 32)
                .starhashGlass(in: Circle(), interactive: true, tint: .sheetControlTint)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.hapticPlain)
        .accessibilityLabel(Text(catalog: label))
    }
}

// MARK: Pictures

/// Two phones nodding together, after the owner's reference, each showing
/// what the interaction does on it. Looping: the other phone, upside down
/// above, tips toward the owner's and comes down until the two nearly
/// touch; light leaks from the gap between them (`NearbyField`, a Metal
/// shader), a ring runs out and a band of light sweeps both screens. On
/// both, Pay's pill grows out of its line ("Ariane is nearby", and the
/// owner on theirs); then on the owner's the pill is tapped and the keypad
/// becomes theirs, a face over "Pay Ariane". Then the other phone lifts
/// away and dims, and it starts over. Still, together and lit, with the
/// pill open, under Reduce Motion.
///
/// Given `progress`, it follows that instead of looping: 0 the phones
/// apart and dim, 1 touching and lit, the pill growing as they close in
/// and, at the touch, a burst, the ring and the sweep, and the step that
/// follows. Hold Near drives it with the distance an iPhone that can range
/// measures (with `story` `.request`); nil keeps the loop.
struct PhonesNodHero: View {
    /// What the two screens show happening.
    enum Story {
        /// People Nearby: the pill on both, then the owner's keypad
        /// becomes the other person's.
        case pay
        /// Hold Near: the owner asks; the request reaches the other phone
        /// as its pill, which opens into theirs to pay.
        case request
        /// Bring Phones Together: the owner's keypad already theirs, "Pay
        /// Ariane" and the amount; at the touch the call prompt comes up
        /// on it, while theirs shows the owner's pill.
        case touchToPay
    }

    /// How near the phones are, 0 apart to 1 touching, or nil to loop.
    let progress: Double?
    let story: Story

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Bumped each time the phones come to touch, for the burst.
    @State private var touches = 0

    init(progress: Double? = nil, story: Story = .pay) {
        self.progress = progress
        self.story = story
    }

    private static let phone = CGSize(width: 84, height: 182)
    private static let canvas = CGSize(width: 280, height: 196)
    /// Where the phones meet: the gap between them, nodded in.
    private static let meet: CGFloat = 104
    /// How far the other phone lifts, and tips, when apart.
    private static let apartLift: CGFloat = 30
    private static let apartTilt: Double = 48
    /// How lit the screens are when apart.
    private static let apartLight: Double = 0.12

    /// `-nodProgress` (DEBUG): every nod hero follows a sweep of distances.
    private static var sweeps: Bool {
        #if DEBUG
        DebugLaunch.arguments.contains("-nodProgress")
        #else
        false
        #endif
    }

    var body: some View {
        // The shader's silk drifts on the clock; nothing moves under
        // Reduce Motion.
        TimelineView(.animation(paused: reduceMotion)) { context in
            let seconds = context.date.timeIntervalSinceReferenceDate
            let time = reduceMotion ? 0 : seconds.truncatingRemainder(dividingBy: 1000)
            if let progress {
                followed(min(max(progress, 0), 1), time: time)
            } else if Self.sweeps {
                // -nodProgress: apart to touching, a hold, and back.
                let phase = seconds.truncatingRemainder(dividingBy: 5)
                followed(phase < 2 ? phase / 2 : phase < 3 ? 1 : max(0, (5 - phase) / 2), time: time)
            } else if reduceMotion {
                picture(Nod.together, time: 0)
            } else {
                looping(time: time)
            }
        }
    }

    /// The interaction over and over, about four seconds a turn: apart, the
    /// nod in and the touch, the pill, the tap, and apart again.
    private func looping(time: Double) -> some View {
        KeyframeAnimator(initialValue: Nod.apart, repeating: true) { nod in
            picture(nod, time: time)
        } keyframes: { _ in
            KeyframeTrack(\.lift) {
                LinearKeyframe(Self.apartLift, duration: 0.5)
                // The nod: down past where it rests, then back.
                SpringKeyframe(-3, duration: 0.45, spring: .snappy(duration: 0.4))
                SpringKeyframe(0, duration: 0.35, spring: .smooth(duration: 0.35))
                LinearKeyframe(0, duration: 1.8)
                SpringKeyframe(Self.apartLift, duration: 0.7, spring: .smooth(duration: 0.6))
                LinearKeyframe(Self.apartLift, duration: 0.1)
            }
            KeyframeTrack(\.tilt) {
                LinearKeyframe(Self.apartTilt, duration: 0.5)
                SpringKeyframe(-4, duration: 0.45, spring: .snappy(duration: 0.4))
                SpringKeyframe(0, duration: 0.35, spring: .smooth(duration: 0.35))
                LinearKeyframe(0, duration: 1.8)
                SpringKeyframe(Self.apartTilt, duration: 0.7, spring: .smooth(duration: 0.6))
                LinearKeyframe(Self.apartTilt, duration: 0.1)
            }
            KeyframeTrack(\.light) {
                LinearKeyframe(Self.apartLight, duration: 0.5)
                CubicKeyframe(1, duration: 0.45)
                LinearKeyframe(1, duration: 2.15)
                CubicKeyframe(Self.apartLight, duration: 0.6)
                LinearKeyframe(Self.apartLight, duration: 0.2)
            }
            // The touch, as the nod lands: the burst, the ring, the sweep.
            KeyframeTrack(\.flash) {
                LinearKeyframe(0, duration: 0.88)
                CubicKeyframe(1, duration: 0.1)
                CubicKeyframe(0, duration: 0.7)
                LinearKeyframe(0, duration: 2.22)
            }
            KeyframeTrack(\.ripple) {
                LinearKeyframe(0, duration: 0.9)
                LinearKeyframe(1, duration: 1.3)
                LinearKeyframe(1, duration: 1.7)
            }
            KeyframeTrack(\.wave) {
                LinearKeyframe(0, duration: 0.92)
                CubicKeyframe(1, duration: 0.9)
                LinearKeyframe(1, duration: 2.08)
            }
            // The pill grows out of its line once they are together...
            KeyframeTrack(\.pill) {
                LinearKeyframe(0, duration: 1.2)
                SpringKeyframe(1, duration: 0.5, spring: .bouncy(duration: 0.5, extraBounce: 0.1))
                LinearKeyframe(1, duration: 1.5)
                CubicKeyframe(0, duration: 0.3)
                LinearKeyframe(0, duration: 0.4)
            }
            // ...and is tapped: the keypad becomes theirs.
            KeyframeTrack(\.acted) {
                LinearKeyframe(0, duration: 2.2)
                SpringKeyframe(1, duration: 0.4, spring: .smooth(duration: 0.35))
                LinearKeyframe(1, duration: 0.7)
                CubicKeyframe(0, duration: 0.3)
                LinearKeyframe(0, duration: 0.3)
            }
        }
    }

    /// The phones where `progress` puts them, eased between readings so a
    /// distance that jitters does not, and the touch as they meet.
    private func followed(_ progress: Double, time: Double) -> some View {
        let touching = progress >= 1
        let apart = 1 - progress
        return KeyframeAnimator(initialValue: Touch(), trigger: touches) { touch in
            picture(Nod(
                lift: Self.apartLift * apart,
                tilt: Self.apartTilt * apart,
                // The light comes late, as the phones close in, so halfway
                // still reads as apart.
                light: Self.apartLight + (1 - Self.apartLight) * progress * progress,
                flash: touch.flash,
                ripple: touch.ripple,
                wave: touch.wave,
                pill: Self.smoothstep(0.55, 0.92, progress),
                acted: touching ? 1 : 0
            ), time: time)
        } keyframes: { _ in
            KeyframeTrack(\.flash) {
                MoveKeyframe(0)
                CubicKeyframe(1, duration: 0.1)
                CubicKeyframe(0, duration: 0.7)
            }
            KeyframeTrack(\.ripple) {
                MoveKeyframe(0)
                LinearKeyframe(1, duration: 1.3)
            }
            KeyframeTrack(\.wave) {
                MoveKeyframe(0)
                CubicKeyframe(1, duration: 0.9)
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: progress)
        .animation(reduceMotion ? nil : .smooth(duration: 0.4), value: touching)
        .onChange(of: touching) { _, touching in
            if touching, !reduceMotion { touches += 1 }
        }
    }

    private static func smoothstep(_ from: Double, _ to: Double, _ x: Double) -> Double {
        let t = min(max((x - from) / (to - from), 0), 1)
        return t * t * (3 - 2 * t)
    }

    private struct Nod {
        /// How far the other phone has lifted away, in points.
        var lift: CGFloat
        /// How far it has tipped back, in degrees.
        var tilt: Double
        /// How lit the two screens are, 0 to 1.
        var light: Double
        /// The burst at the touch, 0 to 1.
        var flash: Double = 0
        /// The ring's run out from the touch, 0 to 1 (none at either end).
        var ripple: Double = 0
        /// The band of light's run down the screens, 0 to 1.
        var wave: Double = 0
        /// Pay's pill, 0 its line to 1 open.
        var pill: Double = 0
        /// The step the pill leads to (the keypad theirs), 0 to 1.
        var acted: Double = 0

        static let apart = Nod(lift: 30, tilt: 48, light: 0.12)
        static let together = Nod(lift: 0, tilt: 0, light: 1, pill: 1)
    }

    /// The touch's three lights, played once each time the phones meet.
    private struct Touch {
        var flash: Double = 0
        var ripple: Double = 0
        var wave: Double = 0
    }

    private func picture(_ nod: Nod, time: Double) -> some View {
        let phone = Self.phone
        let canvas = Self.canvas
        // Who shows what: on Pay, both show the pill and the owner's goes
        // on to the keypad; on a request, only theirs, which goes on; on a
        // touch to pay, the owner's is already theirs and the call prompt
        // comes up at the touch.
        let mine: MiniScreen.Step
        let theirs: MiniScreen.Step
        switch story {
        case .pay:
            mine = .init(pill: nod.pill, acted: nod.acted)
            theirs = .init(pill: nod.pill, acted: 0)
        case .request:
            mine = .init(pill: 0, acted: 0)
            theirs = .init(pill: nod.pill, acted: nod.acted)
        case .touchToPay:
            mine = .init(pill: 0, acted: 1, prompt: nod.acted)
            theirs = .init(pill: nod.pill, acted: 0)
        }
        return ZStack(alignment: .top) {
            // Theirs, upside down, its top toward the owner's.
            MiniPhone(light: nod.light, wave: nod.wave, step: theirs, face: .theirs, story: story)
                .frame(width: phone.width, height: phone.height)
                .rotationEffect(.degrees(180))
                .rotation3DEffect(.degrees(nod.tilt), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.55)
                .offset(y: Self.meet - 4 - phone.height - nod.lift)

            // The owner's.
            MiniPhone(light: nod.light, wave: nod.wave, step: mine, face: .mine, story: story)
                .frame(width: phone.width, height: phone.height)
                .offset(y: Self.meet + 4)
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .top)
        // In from the top, and out toward the title: faded, never cut.
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.2),
                    .init(color: .black, location: 0.66),
                    .init(color: .clear, location: 0.98),
                ],
                startPoint: .top, endPoint: .bottom
            )
        }
        .frame(maxWidth: .infinity)
        // The light, the sheet's whole width, fading out before its edges.
        .background {
            GeometryReader { proxy in
                NearbyFieldLayer(
                    size: proxy.size,
                    meet: CGPoint(x: proxy.size.width / 2, y: Self.meet),
                    time: time,
                    light: nod.light,
                    ripple: nod.ripple,
                    flash: nod.flash
                )
            }
        }
    }
}

/// The light behind the phones, drawn by `NearbyField`. Its light eases
/// when Hold Near's distance changes, as the phones do: a shader's
/// arguments do not animate by themselves.
private struct NearbyFieldLayer: View, Animatable {
    let size: CGSize
    let meet: CGPoint
    let time: Double
    var light: Double
    let ripple: Double
    let flash: Double

    @Environment(\.colorScheme) private var colorScheme

    var animatableData: Double {
        get { light }
        set { light = newValue }
    }

    var body: some View {
        let dark = colorScheme == .dark
        Rectangle()
            .fill(.white)
            .colorEffect(ShaderLibrary.NearbyField(
                .float2(size),
                .float2(meet),
                .float(time),
                .float(light),
                .float(ripple),
                .float(flash),
                // White light on #101010; a soft shade on white, where light
                // would not show.
                .float(dark ? 0.9 : 0.2),
                .color(dark ? .white : .black)
            ))
            .allowsHitTesting(false)
    }
}

/// A phone, drawn small: its frame, its screen lit from its top edge by
/// `light` and swept by the touch's band of light, the island, and on the
/// screen a small Pay showing its step of the interaction.
private struct MiniPhone: View {
    var light: Double
    var wave: Double
    var step: MiniScreen.Step
    var face: MiniScreen.Face
    var story: PhonesNodHero.Story

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let radius = size.width * 0.22
            let screen = CGSize(width: size.width - 6, height: size.height - 6)
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.heroPhoneFrame)
                ZStack(alignment: .top) {
                    LinearGradient(colors: [.heroScreenTop, .heroScreenBottom], startPoint: .top, endPoint: .bottom)
                    // The light from the other phone, strongest at the edge
                    // nearest it.
                    LinearGradient(colors: [.heroScreenLit, .heroScreenLit.opacity(0)], startPoint: .top, endPoint: .center)
                        .opacity(light)
                    MiniScreen(width: screen.width, step: step, face: face, story: story)
                        .opacity(0.5 + 0.5 * light)
                }
                .frame(width: screen.width, height: screen.height)
                .clipShape(RoundedRectangle(cornerRadius: radius - 3, style: .continuous))
                .colorEffect(ShaderLibrary.NearbyScreenWave(.float2(screen), .float(wave)))
                .padding(3)
                Capsule()
                    .fill(.black)
                    .frame(width: size.width * 0.3, height: size.width * 0.085)
                    .padding(.top, size.width * 0.07)
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.heroPhoneEdge, lineWidth: 1)
            }
        }
    }
}

/// Pay, drawn small on a phone's screen, at its step of the interaction:
/// the pill growing out of its line, then, once it is tapped, a face over
/// "Pay Ariane" where the pill was, and the amount under it.
private struct MiniScreen: View {
    struct Step {
        /// The pill, 0 its line to 1 open.
        var pill: Double
        /// The keypad theirs (or the request open), 0 to 1.
        var acted: Double
        /// The call prompt over it, 0 to 1: the payment dialled.
        var prompt: Double = 0
    }

    /// Whose phone: whose face its pill shows is the other's.
    enum Face {
        case mine
        case theirs
    }

    let width: CGFloat
    let step: Step
    let face: Face
    let story: PhonesNodHero.Story

    var body: some View {
        let w = width
        let pill = step.pill
        let acted = step.acted
        ZStack(alignment: .top) {
            // The pill, growing out of its line, gone into the face once
            // tapped.
            Capsule()
                .fill(Color.heroInk.opacity(0.1 + 0.08 * pill))
                .overlay {
                    Capsule().strokeBorder(Color.heroInk.opacity(0.16 * pill), lineWidth: 0.5)
                }
                .frame(width: w * (0.16 + 0.52 * pill), height: w * (0.035 + 0.09 * pill))
                .overlay(alignment: .leading) {
                    HStack(spacing: w * 0.03) {
                        RoundedRectangle(cornerRadius: w * 0.022, style: .continuous)
                            .fill(faceFill)
                            .frame(width: w * 0.078, height: w * 0.078)
                        Capsule()
                            .fill(Color.heroInk.opacity(0.6))
                            .frame(width: w * (story == .request && face == .theirs ? 0.36 : 0.3), height: w * 0.024)
                    }
                    .padding(.leading, w * 0.022)
                    .opacity(max(0, pill * 2 - 1))
                }
                .scaleEffect(1 - 0.3 * acted)
                .opacity(1 - acted)
                .padding(.top, w * 0.25)

            // Theirs now: a face over "Pay Ariane".
            VStack(spacing: w * 0.035) {
                RoundedRectangle(cornerRadius: w * 0.045, style: .continuous)
                    .fill(faceFill)
                    .frame(width: w * 0.16, height: w * 0.16)
                Capsule()
                    .fill(Color.heroInk.opacity(0.6))
                    .frame(width: w * 0.3, height: w * 0.026)
            }
            .scaleEffect(0.6 + 0.4 * acted, anchor: .top)
            .opacity(acted)
            .padding(.top, w * 0.21)

            // The amount, moving down to make room.
            Text(verbatim: "5,000")
                .font(.starhashFixed(w * 0.18, weight: .bold))
                .foregroundStyle(Color.heroInk.opacity(0.85))
                .padding(.top, w * (0.48 + 0.12 * acted))

            // The keys, three rows of dots, out of sight as the phone fades.
            VStack(spacing: w * 0.11) {
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: w * 0.2) {
                        ForEach(0..<3, id: \.self) { _ in
                            Circle().fill(Color.heroInk.opacity(0.4)).frame(width: w * 0.05, height: w * 0.05)
                        }
                    }
                }
            }
            .padding(.top, w * 0.98)

            // The call prompt the payment brings up, over the amount.
            VStack(spacing: w * 0.045) {
                Capsule()
                    .fill(Color.heroInk.opacity(0.7))
                    .frame(width: w * 0.36, height: w * 0.028)
                Capsule()
                    .fill(Color.heroInk.opacity(0.35))
                    .frame(width: w * 0.5, height: w * 0.022)
                HStack(spacing: w * 0.04) {
                    Capsule().fill(Color.heroInk.opacity(0.18))
                    Capsule().fill(Color.heroInk.opacity(0.55))
                }
                .frame(width: w * 0.62, height: w * 0.09)
            }
            .padding(.vertical, w * 0.07)
            .frame(width: w * 0.78)
            .background(Color.heroPrompt, in: RoundedRectangle(cornerRadius: w * 0.1, style: .continuous))
            .shadow(color: .black.opacity(0.18 * step.prompt), radius: w * 0.06, y: w * 0.02)
            .scaleEffect(0.82 + 0.18 * step.prompt)
            .opacity(step.prompt)
            .padding(.top, w * 0.5)
        }
        .frame(width: w, alignment: .top)
        .accessibilityHidden(true)
    }

    /// A face: the other person's, or the owner's on their phone, a shade
    /// apart so the two read as two people.
    private var faceFill: LinearGradient {
        let top = face == .mine ? Color.heroInk.opacity(0.5) : Color.heroInk.opacity(0.32)
        return LinearGradient(colors: [top, Color.heroInk.opacity(0.18)], startPoint: .top, endPoint: .bottom)
    }
}

/// A symbol in a soft round well with the hero's glow behind it, for a hero
/// sheet with no picture of its own.
struct SymbolHero: View {
    let symbol: String

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color.heroGlow, .clear], center: .center, startRadius: 0, endRadius: 90))
                .frame(width: 180, height: 180)
            Image(symbol: symbol)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(Color.starhashPrimaryText)
                .frame(width: 84, height: 84)
                .background(Circle().fill(Color.sheetChip))
        }
        .frame(height: 168)
    }
}

/// A person's tile, large, with the hero's glow behind it.
struct TileHero<Tile: View>: View {
    @ViewBuilder var tile: Tile

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color.heroGlow, .clear], center: .center, startRadius: 0, endRadius: 90))
                .frame(width: 180, height: 180)
            tile
        }
        .frame(height: 168)
    }
}

extension Color {
    /// The soft light behind a hero: a faint shade on white, a faint light
    /// on #101010.
    static let heroGlow = Color(light: .black.opacity(0.07), dark: .white.opacity(0.16))
    static let heroPhoneFrame = Color(light: Color(white: 0.09), dark: Color(white: 0.05))
    static let heroPhoneEdge = Color(light: Color(white: 0.55), dark: Color(white: 0.42))
    static let heroScreenTop = Color(light: Color(white: 0.80), dark: Color(white: 0.30))
    static let heroScreenBottom = Color(light: Color(white: 0.62), dark: Color(white: 0.17))
    static let heroScreenLit = Color(light: .white, dark: Color(white: 0.92))
    /// What is drawn on a small phone's screen.
    static let heroInk = Color(light: .black, dark: .white)
    /// The call prompt on a small phone's screen.
    static let heroPrompt = Color(light: Color(white: 0.94), dark: Color(white: 0.24))
}
