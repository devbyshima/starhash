import StarHashKit
import SwiftUI

/// How near the owner's iPhone is to someone else's, for Bring Phones
/// Together. The proximity work (Nearby Interaction, over People Nearby's
/// connection) fills it in: `isAvailable` where the iPhone can range,
/// `start` and `stop` as the sheet opens and closes, and `progress` while
/// it ranges. Until it does, nothing ranges and Pay dials as it always has.
@MainActor @Observable
final class HoldNear {
    static let shared = HoldNear()

    /// Whether this iPhone (and the moment) can measure the distance to
    /// another: Pay then asks to bring the phones together.
    var isAvailable = false
    /// How near the phones are, 0 apart to 1 touching, while ranging; nil
    /// before it starts or when it cannot.
    var progress: Double?
    /// Starts measuring the distance to this person's phone.
    @ObservationIgnored var start: ((PeopleNearby.Person) -> Void)?
    /// Stops measuring.
    @ObservationIgnored var stop: (() -> Void)?

    private init() {
        #if DEBUG
        // -holdNear: the distance simulated, the phones closing in over a
        // few seconds, with no iPhone that can range (the Simulator).
        if DebugLaunch.arguments.contains("-holdNear") {
            isAvailable = true
            var run: Task<Void, Never>?
            start = { [weak self] _ in
                run?.cancel()
                run = Task { @MainActor in
                    let steps = 60
                    for step in 0...steps {
                        try? await Task.sleep(for: .milliseconds(55))
                        guard !Task.isCancelled else { return }
                        // Eased in, with a little hesitation, as a hand moves.
                        let t = Double(step) / Double(steps)
                        self?.progress = min(1, t * t * (3 - 2 * t) + 0.02 * sin(t * 9))
                    }
                    self?.progress = 1
                }
            }
            stop = { [weak self] in
                run?.cancel()
                self?.progress = nil
            }
        }
        #endif
    }
}

/// Bring Phones Together, after Pay is tapped for someone chosen nearby:
/// a hero sheet over the two phones, which follow the measured distance
/// (`PhonesNodHero` with `progress`), the owner's showing "Pay Ariane" and
/// the amount. The moment they touch, light bursts from the gap, a ring
/// runs out, and the payment is dialled (the call prompt and the PIN still
/// follow, as always). Pay Without Touching dials it as Pay always has.
struct BringPhonesTogetherSheet: View {
    let person: PeopleNearby.Person
    let recipient: Recipient
    let amount: Int
    /// Dials the payment, once the sheet has gone.
    let onPay: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var paid = false
    private var holdNear: HoldNear { .shared }

    var body: some View {
        HeroSheet(
            caption: String(starhash: "Pay \(recipient.shownName)"),
            title: String(starhash: "Bring Phones Together"),
            onClose: { dismiss() }
        ) {
            PhonesNodHero(progress: holdNear.progress ?? 0, story: .touchToPay)
        } actions: {
            SheetTextButton("Pay Without Touching") { pay() }
        }
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1), trigger: paid)
        .onAppear { holdNear.start?(person) }
        .onDisappear { holdNear.stop?() }
        .onChange(of: (holdNear.progress ?? 0) >= 1) { _, touched in
            guard touched, !paid else { return }
            // Long enough for the burst and the ring to be seen.
            Task {
                try? await Task.sleep(for: .milliseconds(650))
                pay()
            }
        }
    }

    private func pay() {
        guard !paid else { return }
        paid = true
        dismiss()
        onPay()
    }
}
