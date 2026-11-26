import StarHashKit
import SwiftUI

/// Hold Near: a request held out for the next iPhone held to this one
/// (`TapToRequestService`), on a hero sheet: the two phones nodding
/// together (`PhonesNodHero`, `.request`) follow the distance to the
/// nearest iPhone, and touch as the request goes. The screen faces the
/// person paying. Their iPhone asks them to pay; this one then follows
/// them through Pay to Paid, which comes from the owner's SMS as any
/// request's does.
///
/// Paid is the same sheet turned, not a new one (`land`): the phones give
/// way to a green disc landing where they met, as a drop lands in water.
/// Its tick draws; a ring bends the sheet outward from it and green light
/// opens behind it, with glints as the tick lands, settling to a faint halo
/// (PaidEffects.metal). The amount pops as the disc lands, and who paid
/// comes in under it. A tap on the disc plays a small part of it again.
///
/// Use Code Instead puts the owner's code with the amount in the phones'
/// place, for an iPhone that can't measure or doesn't have StarHash open,
/// and Tap Instead brings the phones back.
struct HoldNearSheet: View {
    let amount: Int
    let note: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(Owner.self) private var owner
    @Environment(MoneyRequests.self) private var requests
    @Environment(AutoVerify.self) private var autoVerify
    @Environment(TapToRequestService.self) private var tap
    @State private var showsCode = false
    /// This sheet, to the service holding its request out.
    @State private var holder = UUID()

    // MARK: The Paid moment

    /// When the payment landed: the shaders' clock.
    @State private var paidAt: Date?
    /// When the owner last tapped the disc.
    @State private var tappedAt: Date?
    /// The disc in the phones' place.
    @State private var landed = false
    /// Its tick drawn.
    @State private var ticked = false
    /// The card and the button turned to Paid.
    @State private var saysPaid = false
    /// The title turned to Paid: at once, as the disc lands, since two
    /// titles of different words crossfading over each other read as a
    /// smudge.
    @State private var paidWords = false
    /// Plays the amount's pop, and the disc's squish on a tap.
    @State private var pops = 0
    @State private var squishes = 0
    /// The shaders' frames run while this is above zero.
    @State private var running = 0
    /// Where the phones meet, where the money lands.
    @State private var landing = CGPoint.zero
    /// Where the hero and the amount sit, for the ripple's ring to run
    /// through both from where the money landed.
    @State private var heroOrigin = CGPoint.zero
    @State private var contentOrigin = CGPoint.zero
    /// The shaders drawn once, unseen, as the sheet opens: the first frame
    /// of each builds its pipeline, which would otherwise hold up the
    /// moment the money lands.
    @State private var warming = true

    private nonisolated static let space = "holdNear"
    private static let discSize: CGFloat = 96
    /// The hero's height: `PhonesNodHero`'s picture.
    private static let heroHeight: CGFloat = 196
    /// Where the phones meet in it, below its middle.
    private static let meetOffset: CGFloat = 6

    var body: some View {
        TimelineView(.animation(paused: running == 0)) { context in
            let elapsed = paidAt.map { context.date.timeIntervalSince($0) } ?? -1
            let sinceTap = tappedAt.map { context.date.timeIntervalSince($0) } ?? -1
            // The ripple bends the hero and the amount, the sheet's parts
            // drawn here: a layer effect over the whole sheet would have to
            // draw its Liquid Glass close button, which it cannot. It stays
            // on, still until the money lands (a time long past): turned on
            // at that moment, its layer was built then and the moment
            // stalled.
            let ripples = !reduceMotion
            let rippleTime = elapsed >= 0 ? elapsed : 10
            HeroSheet(caption: String(starhash: "Request"), title: title, onClose: { dismiss() }) {
                hero(sheen: sheen(elapsed: elapsed, sinceTap: sinceTap))
                    .modifier(PaidRippleEffect(origin: landing, from: heroOrigin, elapsed: rippleTime, isEnabled: ripples))
                    .onGeometryChange(for: CGPoint.self) { $0.frame(in: .named(Self.space)).origin } action: { heroOrigin = $0 }
            } content: {
                content
                    .modifier(PaidRippleEffect(origin: landing, from: contentOrigin, elapsed: rippleTime, isEnabled: ripples))
                    .onGeometryChange(for: CGPoint.self) { $0.frame(in: .named(Self.space)).origin } action: { contentOrigin = $0 }
            } actions: {
                buttons
            }
            .background {
                if paidAt != nil || warming {
                    Rectangle()
                        .colorEffect(ShaderLibrary.PaidBloom(
                            .float2(landing), .float(elapsed), .float(sinceTap), .float(Self.discSize / 2),
                            .float(0.16), .color(Color.waveConfirmed)
                        ))
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                        .transition(.opacity)
                }
            }
        }
        .coordinateSpace(.named(Self.space))
        .animation(.smooth(duration: 0.3), value: tap.hold)
        .animation(.smooth(duration: 0.3), value: showsCode)
        .onAppear {
            start()
            // A counter's iPhone stays awake while it waits.
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            tap.stopHolding(for: holder)
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: paidRequest != nil, initial: true) { _, paid in
            if paid { land() }
        }
        .task {
            await PaidShaders.prepare()
            try? await Task.sleep(for: .milliseconds(400))
            warming = false
        }
        .sensoryFeedback(.selection, trigger: showsCode)
    }

    // MARK: Hero

    /// The two phones following the distance, the owner's code in their
    /// place, or, once paid, the green disc where they met.
    private func hero(sheen: Double) -> some View {
        ZStack {
            if showsCode, !landed, let code {
                Image(uiImage: code)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                    .transition(.opacity)
            } else {
                PhonesNodHero(progress: nod, story: .request)
                    .opacity(landed ? 0 : 1)
                    .scaleEffect(landed ? 0.9 : 1)
                    .blur(radius: landed ? 8 : 0)
                    .animation(.easeOut(duration: 0.3), value: landed)
                    .transition(.opacity)
            }
            Button(action: tapDisc) {
                PaidDisc(size: Self.discSize, ticked: ticked, sheen: sheen)
            }
            .buttonStyle(.plain)
            .scaleEffect(landed ? 1 : 0.3)
            .opacity(landed ? 1 : 0)
            .keyframeAnimator(initialValue: 1.0, trigger: squishes) { content, scale in
                content.scaleEffect(scale)
            } keyframes: { _ in
                SpringKeyframe(0.86, duration: 0.09, spring: .snappy)
                SpringKeyframe(1.0, duration: 0.5, spring: .bouncy(extraBounce: 0.15))
            }
            .allowsHitTesting(landed)
            .offset(y: Self.meetOffset)
            .onGeometryChange(for: CGPoint.self) { proxy in
                let frame = proxy.frame(in: .named(Self.space))
                return CGPoint(x: frame.midX, y: frame.midY)
            } action: { landing = $0 }
        }
        .frame(height: Self.heroHeight)
    }

    /// How near the phones are drawn: the nearest iPhone's distance while
    /// the request waits, touching once it went, apart otherwise.
    private var nod: Double {
        switch tap.hold {
        case .waiting: tap.holdProgress ?? 0
        case .sent, .paying: 1
        case .declined, .notAllowed, nil: 0
        }
    }

    // MARK: Words

    private var title: String {
        if paidWords { return String(starhash: "Paid") }
        if showsCode { return String(starhash: "Scan to Pay") }
        switch tap.hold {
        case .waiting, nil: return String(starhash: "Bring Phones Together")
        case .sent: return String(starhash: "Sent to Their iPhone")
        case .paying(_, let name):
            return name.map { String(starhash: "\(Self.firstName($0)) Is Paying") } ?? String(starhash: "They're Paying")
        case .declined: return String(starhash: "They Declined")
        case .notAllowed: return String(starhash: "Nearby Interactions Is Off")
        }
    }

    /// The amount, large, and who is paying it once they tap Pay.
    private var content: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text(verbatim: Money.formatWithCurrency(amount))
                    .font(.starhashNumber(40, weight: .bold, relativeTo: .largeTitle))
                    .foregroundStyle(Color.sheetBrandText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    // Lands with the disc: a breath bigger, and back.
                    .keyframeAnimator(initialValue: 1.0, trigger: pops) { content, scale in
                        content.scaleEffect(scale)
                    } keyframes: { _ in
                        LinearKeyframe(1.0, duration: 0.12)
                        SpringKeyframe(1.05, duration: 0.14, spring: .snappy)
                        SpringKeyframe(1.0, duration: 0.5, spring: .bouncy)
                    }
            }
            .accessibilityElement(children: .combine)
            // From the moment they tap Pay, so the sheet keeps its height as
            // the money lands: only its last row turns, Waiting to the time.
            if let payingRequest {
                details(payingRequest)
                    .transition(.blurReplace)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Who is paying and from which number, then when it was paid, once
    /// the SMS says so: Waiting until then.
    private func details(_ request: MoneyRequest) -> some View {
        // Labels as catalog keys: the row looks them up.
        let last: (String, String) = if saysPaid, let paidAt = request.settledAt {
            ("Time", paidAt.formatted(.dateTime.hour().minute().locale(.starhash)))
        } else {
            ("Status", String(starhash: "Waiting"))
        }
        let rows = [("From", request.person.shownName), ("Number", request.person.formattedDestination), last]
        return VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 { SheetDivider() }
                SheetInfoRow(row.0, row.1)
                    .id(row.0)
                    .transition(.blurReplace)
            }
        }
        .padding(.horizontal, 16)
        .sheetCard()
    }

    @ViewBuilder
    private var buttons: some View {
        if saysPaid {
            Button("Done") { dismiss() }
                .buttonStyle(.sheetPrimary)
                .transition(.blurReplace)
        } else {
            switch tap.hold {
            case .declined:
                Button("Ask Again") { tap.holdAgain() }
                    .buttonStyle(.sheetPrimary)
            case .notAllowed:
                Button("Open Settings") { SettingsAppLink.open() }
                    .buttonStyle(.sheetPrimary)
                SheetTextButton("Try Again") { tap.holdAgain() }
            case .sent, .paying:
                SheetTextButton("Done") { dismiss() }
            case .waiting, nil:
                if code != nil {
                    SheetTextButton(showsCode ? "Tap Instead" : "Use Code Instead") { showsCode.toggle() }
                }
            }
        }
    }

    /// The owner's code with the amount, as Profile's carries their number,
    /// drawn for the sheet's appearance.
    private var code: UIImage? {
        guard let number = owner.defaultSIM else { return nil }
        let photo = ProfilePhoto.shared.image != nil ? AppEnvironment.serverSync.sharedPhotoID : nil
        let recipient = Recipient(name: owner.name, destination: number.destination, kind: .phone)
        // Straight on the sheet in either appearance, with nothing behind
        // it: near black in light mode, white in dark mode.
        return QRCodeImage.image(for: PaymentQR.link(for: recipient, amount: amount, photoID: photo).absoluteString, side: 540, clear: true, onDark: colorScheme == .dark)
    }

    /// The request they are paying: kept as they tapped Pay.
    private var payingRequest: MoneyRequest? {
        guard case .paying(let id, _) = tap.hold else { return nil }
        return requests.request(id: id)
    }

    /// The request, once they paid it: kept as they tapped Pay, paid by the
    /// owner's SMS.
    private var paidRequest: MoneyRequest? {
        guard case .paying(let id, _) = tap.hold, let request = requests.request(id: id), request.status == .paid else { return nil }
        return request
    }

    // MARK: Motion

    /// The money lands: the disc where the phones met, with the haptic as
    /// it reaches its size, and its tick drawn just after; the ripple and
    /// light from the same instant; the words a beat later. Done is there
    /// at once.
    private func land() {
        guard paidAt == nil else { return }
        showsCode = false
        if let paidRequest {
            AccessibilityNotification.Announcement(
                String(starhash: "Paid \(Money.formatWithCurrency(amount)) by \(paidRequest.person.shownName)")
            ).post()
        }
        guard !reduceMotion else {
            // At its end, at once: the halo at rest, nothing moving.
            paidAt = .now.addingTimeInterval(-10)
            withAnimation(.smooth(duration: 0.3)) {
                landed = true
                ticked = true
                saysPaid = true
                paidWords = true
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }
        paidAt = .now
        run(for: 1.7)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { landed = true }
        withAnimation(.easeOut(duration: 0.32).delay(0.18)) { ticked = true }
        withAnimation(.smooth(duration: 0.35).delay(0.16)) { saysPaid = true }
        pops += 1
        Task {
            try? await Task.sleep(for: .milliseconds(120))
            // The disc reaches its size: felt, and the words turn with it.
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            var instant = SwiftUI.Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) { paidWords = true }
        }
    }

    /// A tap on the disc: it squishes and springs back, its sheen crosses it
    /// again and a small ring of light goes out.
    private func tapDisc() {
        TapHaptic.play(.soft)
        squishes += 1
        guard !reduceMotion else { return }
        tappedAt = .now
        run(for: 1.1)
    }

    /// Runs the shaders' frames for `seconds`.
    private func run(for seconds: Double) {
        running += 1
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            running -= 1
        }
    }

    /// Where the disc's sheen is, 0 to 1, or 0 when it isn't crossing: as
    /// the tick lands, and again after a tap.
    private func sheen(elapsed: Double, sinceTap: Double) -> Double {
        func crossing(_ time: Double, from start: Double) -> Double {
            let progress = (time - start) / 0.45
            return progress > 0 && progress < 1 ? progress : 0
        }
        let landing = crossing(elapsed, from: 0.42)
        return landing > 0 ? landing : crossing(sinceTap, from: 0.04)
    }

    private func start() {
        guard let number = owner.defaultSIM else { return }
        let photo = ProfilePhoto.shared.image != nil ? AppEnvironment.serverSync.sharedPhotoID : nil
        tap.startHolding(.init(
            id: UUID(), name: owner.name.trimmingCharacters(in: .whitespacesAndNewlines), number: number.destination,
            photoID: photo, amount: amount, note: note
        ), for: holder)
    }

    private static func firstName(_ name: String) -> String {
        name.split(separator: " ").first.map(String.init) ?? name
    }
}

/// The Paid ripple over one part of the sheet: its ring centred on
/// `origin`, where the money landed, given in the sheet's space, and this
/// part's own top left `from` in the same space.
private struct PaidRippleEffect: ViewModifier {
    let origin: CGPoint
    let from: CGPoint
    let elapsed: Double
    let isEnabled: Bool

    func body(content: Content) -> some View {
        content.layerEffect(
            ShaderLibrary.PaidRipple(
                .float2(CGPoint(x: origin.x - from.x, y: origin.y - from.y)),
                .float(elapsed), .float(12), .float(640), .float(28)
            ),
            maxSampleOffset: CGSize(width: 12, height: 12),
            isEnabled: isEnabled
        )
    }
}

/// The green disc Paid lands as, its tick drawn by `ticked`, a band of
/// light crossing it at `sheen` (PaidDiscSheen).
private struct PaidDisc: View {
    let size: CGFloat
    let ticked: Bool
    let sheen: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.starhashConfirmed)
                .colorEffect(ShaderLibrary.PaidDiscSheen(.float2(CGSize(width: size, height: size)), .float(sheen)))
            PaidTick()
                .trim(from: 0, to: ticked ? 1 : 0)
                .stroke(Color.waveGlyph, style: StrokeStyle(lineWidth: size * 0.075, lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.4, height: size * 0.3)
                .offset(y: size * 0.01)
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
    }
}

/// A tick, drawn from its short stroke to the end of its long one.
private struct PaidTick: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

/// Compiles the Paid moment's shaders while the request waits, so the
/// moment it lands holds no frame back.
enum PaidShaders {
    static func prepare() async {
        try? await ShaderLibrary.PaidRipple(.float2(CGPoint.zero), .float(0), .float(0), .float(0), .float(1))
            .compile(as: .layerEffect)
        try? await ShaderLibrary.PaidBloom(
            .float2(CGPoint.zero), .float(0), .float(0), .float(1), .float(0), .color(.clear)
        ).compile(as: .colorEffect)
        try? await ShaderLibrary.PaidDiscSheen(.float2(CGPoint.zero), .float(0)).compile(as: .colorEffect)
    }
}
