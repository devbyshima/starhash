import StarHashKit
import SwiftUI

/// People Nearby, opened from Pay's pill, after the owner's reference
/// (Ijwi's Bluetooth screen): the owner's photo in the middle of two full
/// rings that pulse, each growing a little and coming back to its size,
/// the outer a beat after the inner, and everyone nearby as their photo
/// circling on the rings' edges, the inner ring one way and the outer the
/// other, their first name under it. A tap asks that phone for its number
/// and chooses them, so the keypad becomes theirs. Still under Reduce
/// Motion.
struct PeopleNearbyRadar: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PeopleNearbyService.self) private var nearby
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onChoose: (PaymentRequest, PeopleNearby.Person) -> Void

    @State private var unreachable: PeopleNearby.Person?

    /// The two rings: how far out, as a share of the radar's width, how
    /// many people each holds, and how long a turn takes (negative the
    /// other way round).
    private static let rings: [(reach: CGFloat, seats: Int, turn: Double)] = [
        (0.235, 3, 40),
        (0.43, 6, -56),
    ]

    private var people: [PeopleNearby.Person] {
        Array(nearby.found.people.prefix(Self.rings.reduce(0) { $0 + $1.seats }))
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                PageTitle(text: "People Nearby")
                HStack {
                    StarHashCircleButton("xmark", label: "Close") { dismiss() }
                    Spacer()
                }
            }
            .frame(minHeight: 44)
            .padding(.horizontal, StarHashMetrics.screenPadding)

            Spacer(minLength: 12)
            radar
            Spacer(minLength: 12)

            Text(people.isEmpty ? "Looking for people nearby" : "Tap someone to pay them")
                .font(.starhash(.subheadline))
                .foregroundStyle(Color.paySecondaryText)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
                .animation(.smooth(duration: 0.3), value: people.isEmpty)
                .padding(.horizontal, StarHashMetrics.screenPadding)
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.starhashPayBackground.ignoresSafeArea())
        .environment(\.starhashOnPay, true)
        .environment(\.starhashGlassTint, .payGlassTint)
        .unreachableAlert($unreachable)
        #if DEBUG
        // -peopleNearbyPick <seconds>: the first person tapped after this
        // long, to record the keypad becoming theirs.
        .task {
            guard let delay = DebugLaunch.value(after: "-peopleNearbyPick").flatMap(Double.init) else { return }
            try? await Task.sleep(for: .seconds(delay))
            if let first = people.first { reach(first) }
        }
        #endif
    }

    private var radar: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            TimelineView(.animation(paused: reduceMotion)) { context in
                let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 10_000)
                ZStack {
                    // The outer ring under the inner, so where they overlap
                    // reads deeper.
                    ForEach(Self.rings.indices.reversed(), id: \.self) { index in
                        RadarRing(radius: side * Self.rings[index].reach, scale: Self.pulse(ring: index, at: time))
                    }
                    ProfilePhotoView(size: side * 0.19)
                        .overlay(Circle().strokeBorder(Color.payPrimaryText.opacity(0.12), lineWidth: 1))
                        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                    ForEach(Array(people.enumerated()), id: \.element.id) { index, person in
                        let seat = seat(for: index, of: people.count, time: time)
                        RadarFace(
                            person: person,
                            size: side * (seat.ring == 0 ? 0.135 : 0.125),
                            isReaching: nearby.reaching == person.id,
                            isDimmed: nearby.reaching != nil && nearby.reaching != person.id
                        ) {
                            reach(person)
                        }
                        // On the ring's edge, wherever its pulse has it.
                        .offset(
                            x: cos(seat.angle) * side * seat.reach * Self.pulse(ring: seat.ring, at: time),
                            y: sin(seat.angle) * side * seat.reach * Self.pulse(ring: seat.ring, at: time)
                        )
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                    }
                }
                .frame(width: side, height: side)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 400)
        .padding(.horizontal, 8)
        .animation(reduceMotion ? nil : .spring(duration: 0.5, bounce: 0.3), value: people.map(\.id))
        .disabled(nearby.reaching != nil)
    }

    /// How big a ring is at `time`, against its size at rest: every 2.4
    /// seconds it grows by a few points and eases back, the outer ring a
    /// quarter second after the inner, so the pulse runs outward, then
    /// rests.
    private static func pulse(ring: Int, at time: Double) -> CGFloat {
        let period = 2.4
        let phase = (time - Double(ring) * 0.25).truncatingRemainder(dividingBy: period) / period
        let wrapped = phase < 0 ? phase + 1 : phase
        guard wrapped < 0.5 else { return 1 }
        let swell = (1 - cos(2 * .pi * wrapped / 0.5)) / 2
        return 1 + CGFloat(swell) * (ring == 0 ? 0.08 : 0.06)
    }

    /// Where the person at `index` sits: the inner ring first, spread
    /// evenly round it, turning with the clock.
    private func seat(for index: Int, of count: Int, time: Double) -> (ring: Int, reach: CGFloat, angle: CGFloat) {
        var first = 0
        for (ring, spec) in Self.rings.enumerated() {
            let seated = min(spec.seats, max(0, count - first))
            if index < first + spec.seats {
                let slot = index - first
                // The outer ring starts half a seat round, so its people
                // sit between the inner ring's.
                let start = -Double.pi / 2 + (ring == 0 ? 0 : Double.pi / Double(max(seated, 1)))
                let angle = start + 2 * .pi * Double(slot) / Double(max(seated, 1)) + 2 * .pi * time / spec.turn
                return (ring, spec.reach, CGFloat(angle))
            }
            first += spec.seats
        }
        return (0, Self.rings[0].reach, 0)
    }

    private func reach(_ person: PeopleNearby.Person) {
        Task {
            if let recipient = await nearby.reach(person) {
                onChoose(PaymentRequest(recipient: recipient, photoID: person.photoID, isStarHashCode: true), person)
                dismiss()
            } else {
                unreachable = person
            }
        }
    }
}

/// One of the radar's rings: a full disc, faint, with a fine edge, at
/// `scale` of its size as it pulses.
private struct RadarRing: View {
    let radius: CGFloat
    let scale: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let fill = colorScheme == .dark ? 0.06 : 0.04
        Circle()
            .fill(Color.payPrimaryText.opacity(fill))
            .overlay(Circle().strokeBorder(Color.payPrimaryText.opacity(0.1), lineWidth: 1))
            .frame(width: radius * 2, height: radius * 2)
            .scaleEffect(scale)
            .allowsHitTesting(false)
    }
}

/// A person on the radar: their photo in a circle, on clear glass, with
/// their first name under it. Dimmed while another is being reached, and a
/// spinner over it while it is.
private struct RadarFace: View {
    let person: PeopleNearby.Person
    let size: CGFloat
    let isReaching: Bool
    let isDimmed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                PeopleNearbyTile(person: person, size: size)
                    .clipShape(Circle())
                    .padding(3)
                    .starhashGlass(in: Circle(), tint: .clear)
                    .overlay {
                        if isReaching {
                            Circle().fill(.black.opacity(0.35)).padding(3)
                            ProgressView().tint(.white)
                        }
                    }
                Text(verbatim: person.firstName)
                    .font(.starhash(.caption, weight: .semibold))
                    .foregroundStyle(Color.payPrimaryText)
                    .lineLimit(1)
                    .frame(maxWidth: size + 24)
            }
            // The name hangs under the photo; the photo sits on the ring.
            .padding(.top, 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .opacity(isDimmed ? 0.4 : 1)
        .accessibilityLabel(Text("Pay \(person.name)"))
    }
}
