import StarHashKit
import SwiftUI

// The pictures at the top of each onboarding page, built from SF Symbols
// and the app's own row shapes. Each plays its entrance once when its page
// appears and then rests; with Reduce Motion they start at rest. They are
// pictures, so their text uses fixed sizes: the page pins them to the
// default text size and shrinks the whole picture at accessibility sizes.

// MARK: - Page 0: sample payments

/// Three payments rise in one after another above the mark.
struct SamplePaymentsIllustration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = 0

    private let samples: [(title: String, amount: Int, symbol: String)] = [
        // Short names, so each fits beside its amount on one line.
        ("Pili-Pili", 15_000, "fork.knife"),
        ("Moto", 1_500, "scooter"),
        ("Simba", 42_300, "basket.fill"),
    ]

    var body: some View {
        let visible = reduceMotion ? samples.count : shown
        VStack(spacing: 14) {
            ForEach(samples.prefix(visible), id: \.title) { sample in
                OnboardingRow(symbol: sample.symbol, title: sample.title, trailing: Money.formatWithCurrency(sample.amount))
                    .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
            }
        }
        .frame(width: 320)
        .accessibilityHidden(true)
        .task {
            guard !reduceMotion else { return }
            for index in samples.indices {
                try? await Task.sleep(for: .milliseconds(index == 0 ? 350 : 650))
                withAnimation(.spring(duration: 0.6, bounce: 0.2)) { shown = index + 1 }
            }
        }
    }
}

// MARK: - Page 1: pay anyone

/// The amount, then a phone number and a merchant code, each with the code
/// StarHash dials for it.
struct PayAnyoneIllustration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 18) {
            Text(Money.formatWithCurrency(5_000))
                .font(.system(size: 52, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Color.starhashPrimaryText)
            VStack(spacing: 12) {
                recipient(symbol: "person.fill", title: "0788 123 456", caption: "MTN number", code: "*182*1*1*0788123456*5000#")
                recipient(symbol: "storefront.fill", title: "020205", caption: "Merchant code", code: "*182*8*1*020205*5000#")
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
        }
        .frame(width: 330)
        .accessibilityHidden(true)
        .task {
            if reduceMotion { appeared = true; return }
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.spring(duration: 0.6, bounce: 0.2)) { appeared = true }
        }
    }

    private func recipient(symbol: String, title: String, caption: String, code: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                SymbolTile(symbol: symbol, size: 42, background: OnboardingPalette.tile)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .monospacedDigit()
                    Text(caption)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.starhashSecondaryText)
                }
                Spacer(minLength: 0)
            }
            Text(code)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.starhashSecondaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(OnboardingPalette.tile, in: Capsule())
        }
        .foregroundStyle(Color.starhashPrimaryText)
        .padding(14)
        .onboardingPill(cornerRadius: StarHashMetrics.rowRadius)
    }
}

// MARK: - Page 2: contacts

/// A few contacts as the recipient picker lists them.
struct ContactsIllustration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = 0

    private let contacts: [(name: String, number: String)] = [
        ("Ariane Ishimwe", "0788 123 998"),
        ("John Doe", "0780 123 456"),
        ("Grace Uwase", "0785 550 123"),
        ("Alain (ALU)", "0784 950 091"),
    ]

    var body: some View {
        let visible = reduceMotion ? contacts.count : shown
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                Text("Type anything, we'll find it")
                Spacer()
            }
            .font(.system(size: 16))
            .foregroundStyle(Color.starhashSecondaryText)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(OnboardingPalette.tile, in: Capsule())
            .padding(14)

            ForEach(Array(contacts.prefix(visible).enumerated()), id: \.element.name) { index, contact in
                if index > 0 { StarHashRowSeparator(leading: 72) }
                HStack(spacing: 12) {
                    Text(String(contact.name.prefix(1)))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .frame(width: 44, height: 44)
                        .background(OnboardingPalette.tile, in: Circle())
                    VStack(alignment: .leading, spacing: 1) {
                        Text(contact.name)
                            .font(.system(size: 17, weight: .medium))
                        Text(contact.number)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.starhashSecondaryText)
                            .monospacedDigit()
                    }
                    Spacer(minLength: 0)
                }
                .foregroundStyle(Color.starhashPrimaryText)
                .padding(.horizontal, 14)
                .frame(height: 64)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            Spacer(minLength: 0)
        }
        .frame(width: 330, height: 330, alignment: .top)
        .onboardingPill(cornerRadius: StarHashMetrics.cardRadius)
        .accessibilityHidden(true)
        .task {
            guard !reduceMotion else { return }
            for index in contacts.indices {
                try? await Task.sleep(for: .milliseconds(index == 0 ? 300 : 180))
                withAnimation(.smooth(duration: 0.35)) { shown = index + 1 }
            }
        }
    }
}

// MARK: - Page 3: activity

/// A day of Activity: out in red, in in green, each confirmed by its SMS.
struct ActivityIllustration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var verified = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.starhashSecondaryText)
                .padding(.leading, 6)
            row(name: "Pili-Pili Invest", detail: "020205", amount: 15_000, incoming: false)
            row(name: "Ariane Ishimwe", detail: "0788 123 998", amount: 35_000, incoming: true)
            row(name: "John Doe", detail: "0780 123 456", amount: 700, incoming: false)
        }
        .frame(width: 330)
        .accessibilityHidden(true)
        .task {
            if reduceMotion { verified = true; return }
            try? await Task.sleep(for: .milliseconds(600))
            withAnimation(.spring(duration: 0.5, bounce: 0.3)) { verified = true }
        }
    }

    private func row(name: String, detail: String, amount: Int, incoming: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: incoming ? "arrow.down.left" : "arrow.up.right")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(incoming ? Color.starhashIncoming : Color.starhashDestructive)
                .frame(width: 42, height: 42)
                .background(OnboardingPalette.tile, in: RoundedRectangle(cornerRadius: 12.6, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 17, weight: .medium))
                Text(detail)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.starhashSecondaryText)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 3) {
                Text((incoming ? "+" : "") + Money.formatWithCurrency(amount))
                    .font(.system(size: 16, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(incoming ? Color.starhashIncoming : Color.starhashPrimaryText)
                Label("SMS", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.starhashSecondaryText)
                    .opacity(verified ? 1 : 0)
                    .scaleEffect(verified ? 1 : 0.6, anchor: .trailing)
            }
        }
        .foregroundStyle(Color.starhashPrimaryText)
        .padding(.horizontal, 12)
        .frame(height: 70)
        .onboardingPill(cornerRadius: StarHashMetrics.rowRadius)
    }
}

// MARK: - Page 4: ready

/// The mark over the keypad's first keys.
struct ReadyIllustration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 28) {
            StarHashMark(size: 120)
                .scaleEffect(appeared ? 1 : 0.8)
                .opacity(appeared ? 1 : 0)
            HStack(spacing: 14) {
                ForEach(["1", "2", "3"], id: \.self) { key in
                    Text(key)
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(Color.starhashPrimaryText)
                        .frame(width: 84, height: 64)
                        .onboardingPill(cornerRadius: 32)
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
        }
        .accessibilityHidden(true)
        .task {
            if reduceMotion { appeared = true; return }
            withAnimation(.spring(duration: 0.7, bounce: 0.3)) { appeared = true }
        }
    }
}

// MARK: - Shared pieces

/// A sample row: symbol tile, title and an amount.
private struct OnboardingRow: View {
    let symbol: String
    let title: String
    let trailing: String

    var body: some View {
        HStack(spacing: 13) {
            SymbolTile(symbol: symbol, size: 47, background: OnboardingPalette.tile)
            Text(title)
                .font(.system(size: 18, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(trailing)
                .font(.system(size: 18, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
        }
        .foregroundStyle(Color.starhashPrimaryText)
        .padding(.leading, 12)
        .padding(.trailing, 20)
        .frame(height: 70)
        .onboardingPill(cornerRadius: StarHashMetrics.rowRadius)
    }
}

extension View {
    /// A sample card: black sunk into the lifted page in dark mode, white on
    /// grey in light mode, with a faint rim strongest along the bottom.
    func onboardingPill(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return background(OnboardingPalette.pill, in: shape)
            .overlay(
                shape.strokeBorder(
                    LinearGradient(colors: [OnboardingPalette.pillRimTop, OnboardingPalette.pillRimBottom], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
            )
    }
}
