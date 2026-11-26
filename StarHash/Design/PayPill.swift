import SwiftUI

/// The pill at the top of Pay, after the owner's reference video: clear
/// Liquid Glass (every pill and toast in StarHash is, the owner's ask), it
/// grows out of a short line when there is something to show, turns to the
/// next item every few seconds while there are several (from the first
/// each time it opens), and goes back to the line when there is nothing.
/// Someone nearby (`PeopleNearbyPill`) or a request waiting for the owner
/// (`RequestPill`), which comes first: one surface for both, never a pill
/// and a card.
struct PayPill<Item: Identifiable, Label: View>: View {
    let items: [Item]
    let onTap: (Item) -> Void
    let label: (Item) -> Label

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Grown from its line into the pill.
    @State private var isOpen = false
    /// Which item it shows.
    @State private var turn = 0

    init(items: [Item], onTap: @escaping (Item) -> Void, @ViewBuilder label: @escaping (Item) -> Label) {
        self.items = items
        self.onTap = onTap
        self.label = label
    }

    private var shown: Item? {
        items.isEmpty ? nil : items[turn % items.count]
    }

    var body: some View {
        Group {
            if isOpen, let item = shown {
                Button { onTap(item) } label: {
                    label(item)
                        .id(item.id)
                        .transition(.blurReplace)
                        .padding(.leading, 5)
                        .padding(.trailing, 12)
                        .frame(height: 34)
                        .contentShape(Capsule())
                        .starhashGlass(in: Capsule(), interactive: true, tint: .clear)
                }
                .buttonStyle(PressScaleButtonStyle())
                .transition(AnyTransition.scale(scale: 0.4).combined(with: .opacity))
            } else {
                // The line it grows from, and goes back to.
                Capsule()
                    .fill(Color.payPrimaryText.opacity(0.16))
                    .frame(width: 26, height: 5)
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.5, bounce: 0.32), value: isOpen)
        .task(id: items.isEmpty) {
            // Out of the line a beat after there is something to show.
            guard !items.isEmpty else {
                isOpen = false
                return
            }
            try? await Task.sleep(for: .milliseconds(450))
            if !Task.isCancelled { isOpen = true }
        }
        .task(id: PayPillTurning(ids: items.map { AnyHashable($0.id) }, isOpen: isOpen)) {
            if !isOpen { turn = 0 }
            guard isOpen, items.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3.2))
                guard !Task.isCancelled else { return }
                withAnimation(.smooth(duration: 0.45)) { turn += 1 }
            }
        }
    }
}

/// What restarts the pill's turning: an item coming or going, or the pill
/// opening or closing.
private struct PayPillTurning: Equatable {
    var ids: [AnyHashable]
    var isOpen: Bool
}

/// The words in Pay's pill: small capitals, spaced.
struct PayPillText: View {
    let text: Text

    var body: some View {
        text
            .textCase(.uppercase)
            .font(.starhashFixed(11, weight: .semibold))
            .tracking(0.9)
            .foregroundStyle(Color.payPrimaryText)
            .lineLimit(1)
    }
}
