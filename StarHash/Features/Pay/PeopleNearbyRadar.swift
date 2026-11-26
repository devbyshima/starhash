import StarHashKit
import SwiftUI

/// People Nearby, opened from Pay's pill: the whole page a sonar screen
/// (`RadarSonar`, at the owner's ask, in place of the rings it had), the
/// owner's photo in its middle and everyone nearby where they are, once
/// measured, or circling on two unseen orbits until then, their first name
/// under it. Every 1.6 seconds the photo swells, lub then dub, and a ring
/// of water rolls out, printed in dithered dots, to the edges of the page,
/// lifting each face as it passes. A tap asks that phone for its number and chooses them, so
/// the keypad becomes theirs. A still screen under Reduce Motion.
struct PeopleNearbyRadar: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PeopleNearbyService.self) private var nearby
    @Environment(TapToRequestService.self) private var tap
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onChoose: (PaymentRequest, PeopleNearby.Person) -> Void

    @State private var unreachable: PeopleNearby.Person?

    /// The two orbits: how far out, as a share of the radar's width, how
    /// many people each holds, and how long a turn takes (negative the
    /// other way round).
    private static let rings: [(reach: CGFloat, seats: Int, turn: Double)] = [
        (0.235, 3, 80),
        (0.4, 6, -110),
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

            Text(verbatim: footLine)
                .font(.starhash(.subheadline, weight: pointed == nil ? .regular : .semibold))
                .foregroundStyle(pointed == nil ? Color.paySecondaryText : Color.payPrimaryText)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
                .animation(.smooth(duration: 0.3), value: footLine)
                .padding(.horizontal, StarHashMetrics.screenPadding)
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The water fills the page, the photo and the faces at its middle;
        // the title and the line at the foot over it.
        .background { radar }
        .background(Color.starhashPayBackground.ignoresSafeArea())
        .environment(\.starhashOnPay, true)
        .environment(\.starhashGlassTint, .payGlassTint)
        .unreachableAlert($unreachable)
        // Measured while it shows: how far and which way each person is.
        .onAppear { tap.locate(people) }
        .onChange(of: people.map(\.id)) { tap.locate(people) }
        .onDisappear { tap.stopLocating() }
        // A tick as the iPhone comes to point at someone.
        .sensoryFeedback(.selection, trigger: pointed?.id) { _, now in now != nil }
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

    /// Who the iPhone points at, among those it can tell the way to.
    private var pointed: PeopleNearby.Person? {
        people.first { RadarPlacement.isPointedAt(bearing: tap.locations[$0.id]?.bearing) }
    }

    /// The line at the foot: who is pointed at and how far, or what to do.
    private var footLine: String {
        if let pointed, let distance = tap.locations[pointed.id]?.distance {
            return String(starhash: "\(pointed.firstName) is \(RadarPlacement.spoken(distance: distance)) away")
        }
        return people.isEmpty ? String(starhash: "Looking for people nearby") : String(starhash: "Tap someone to pay them")
    }

    /// The whole page: water from edge to edge, and in its middle the
    /// owner's photo with everyone nearby round it.
    private var radar: some View {
        GeometryReader { proxy in
            let page = proxy.size
            let side = min(page.width, page.height)
            let origin = Double(side) * Heartbeat.origin
            TimelineView(.animation(paused: reduceMotion)) { context in
                let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 10_000)
                ZStack {
                    Rectangle()
                        .colorEffect(ShaderLibrary.RadarSonar(
                            .float2(page), .float(time), .float(Heartbeat.period), .float(Heartbeat.speed), .float(origin),
                            .float(reduceMotion ? 0 : 1), .color(Color.radarSonar)
                        ))
                        .frame(width: page.width, height: page.height)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    ProfilePhotoView(size: side * 0.19)
                        .overlay(Circle().strokeBorder(Color.payPrimaryText.opacity(0.12), lineWidth: 1))
                        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                        // Lub, then dub.
                        .scaleEffect(reduceMotion ? 1 : Heartbeat.swell(at: time))
                    ForEach(Array(people.enumerated()), id: \.element.id) { index, person in
                        let spot = spot(for: person, at: index, side: side, time: time)
                        let nudge = reduceMotion ? 0 : CGFloat(Heartbeat.tilt(
                            at: Double(spot.radius), origin: origin, corner: Double(hypot(page.width, page.height) / 2), time: time
                        )) * 6
                        RadarFace(
                            person: person,
                            size: spot.size,
                            isReaching: nearby.reaching == person.id,
                            isDimmed: nearby.reaching != nil && nearby.reaching != person.id,
                            isPointed: pointed?.id == person.id
                        ) {
                            reach(person)
                        }
                        // Where they are, lifted outward as each ripple passes.
                        .offset(x: cos(spot.angle) * (spot.radius + nudge), y: sin(spot.angle) * (spot.radius + nudge))
                        .animation(.smooth(duration: 0.35), value: spot.isLocated)
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                    }
                }
                .frame(width: page.width, height: page.height)
            }
        }
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : .spring(duration: 0.5, bounce: 0.3), value: people.map(\.id))
        .disabled(nearby.reaching != nil)
    }

    /// Where `person` shows. Measured, at their distance (nearer the middle
    /// the closer they are, and bigger) and their bearing from the iPhone,
    /// straight up the screen being where it points; the angle measured
    /// from the right, as `cos` and `sin` take it. Not measured yet, or on
    /// an iPhone that can't, on an orbit as before, turning slowly.
    private func spot(for person: PeopleNearby.Person, at index: Int, side: CGFloat, time: Double)
        -> (radius: CGFloat, angle: CGFloat, size: CGFloat, isLocated: Bool) {
        let seat = seat(for: index, of: people.count, time: time)
        guard let placement = tap.locations[person.id], let reach = placement.reach else {
            return (side * seat.reach, seat.angle, side * (seat.ring == 0 ? 0.135 : 0.125), false)
        }
        let inner = side * 0.17
        let outer = side * 0.44
        let radius = inner + CGFloat(reach) * (outer - inner)
        let angle = placement.bearing.map { CGFloat($0) - .pi / 2 } ?? seat.angle
        return (radius, angle, side * (0.15 - 0.04 * CGFloat(reach)), true)
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

/// A person on the radar: their photo in a circle, on clear glass, with
/// their first name under it. Dimmed while another is being reached, and a
/// spinner over it while it is.
private struct RadarFace: View {
    let person: PeopleNearby.Person
    let size: CGFloat
    let isReaching: Bool
    let isDimmed: Bool
    /// The iPhone points at them: found.
    var isPointed = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                PeopleNearbyTile(person: person, size: size)
                    .clipShape(Circle())
                    .padding(3)
                    .starhashGlass(in: Circle(), tint: .clear)
                    // Found: a ring of the accent round them, and a little
                    // closer.
                    .overlay {
                        Circle()
                            .strokeBorder(Color.brandFill, lineWidth: 2.5)
                            .padding(-4)
                            .opacity(isPointed ? 1 : 0)
                    }
                    .scaleEffect(isPointed ? 1.14 : 1)
                    .animation(.spring(duration: 0.35, bounce: 0.35), value: isPointed)
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
                    // A halo of the page's colour, so the name reads over
                    // the water.
                    .shadow(color: Color.starhashPayBackground, radius: 1)
                    .shadow(color: Color.starhashPayBackground, radius: 3)
                    .shadow(color: Color.starhashPayBackground.opacity(0.8), radius: 6)
                    .frame(maxWidth: size + 24)
            }
            // The name hangs under the photo; the photo sits on the orbit.
            .padding(.top, 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .opacity(isDimmed ? 0.4 : 1)
        .accessibilityLabel(Text("Pay \(person.name)"))
    }
}

/// The radar's heartbeat: every 1.6 seconds the photo swells, lub then a
/// fainter dub, and one ring rolls out across the water from it, slowly,
/// as on a sonar screen (the owner's ask). Every ring is the same broad
/// crest at the same speed, so they come evenly spaced, softening only as
/// they leave the page. RadarSonar.metal keeps the same clock and the same
/// rings (`tilt`), so the photo swells and the faces bob as each passes.
enum Heartbeat {
    /// From one beat, and one ring, to the next.
    static let period = 1.6
    /// The photo's second, fainter swell, after the first.
    static let dub = 0.28
    /// How fast a ring rolls out, in points a second: with `period`, how
    /// far apart the rings are.
    static let speed = 95.0
    /// The photo's edge, as a share of the page's width: where rings start.
    static let origin = 0.1
    /// A ring's crest: how high and how wide, in points, as RadarSonar's.
    static let height = 14.0
    static let width = 30.0

    /// The photo's size at `time`, against its size at rest: a swell on
    /// each beat, the second smaller.
    static func swell(at time: Double) -> CGFloat {
        let phase = time.truncatingRemainder(dividingBy: period)
        func kick(_ age: Double) -> Double {
            guard age >= 0 else { return 0 }
            return min(1, age / 0.08) * exp(-age * 5.5)
        }
        return 1 + CGFloat(0.035 * kick(phase) + 0.015 * kick(phase - dub))
    }

    /// The water's tilt `distance` points from the middle at `time`, as
    /// RadarSonar works it out: rings from `origin` that soften away by
    /// `corner`, the page's farthest point.
    static func tilt(at distance: Double, origin: Double, corner: Double, time: Double) -> Double {
        // Each ring starts under the photo, so its crest leaves the photo's
        // edge on the beat, as RadarSonar has it.
        let start = origin - 2 * width
        let clock = time + (origin - start) / speed
        let beat = (clock / period).rounded(.down)
        let alive = Int(((corner - start) / (speed * period)).rounded(.up)) + 1
        var slope = 0.0
        for back in 0..<min(alive, 10) {
            let age = clock - (beat - Double(back)) * period
            let crest = start + age * speed
            let leaving = 1 - smoothstep(corner * 0.72, corner, crest)
            let x = distance - crest
            slope += -height * x / (width * width) * exp(-(x * x) / (2 * width * width)) * leaving
        }
        return slope
    }

    private static func smoothstep(_ from: Double, _ to: Double, _ x: Double) -> Double {
        let t = min(max((x - from) / (to - from), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
