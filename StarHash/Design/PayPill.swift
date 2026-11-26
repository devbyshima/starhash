import SwiftUI

/// The pill at the top of Pay, after the owner's reference video: clear
/// Liquid Glass (every pill and toast in StarHash is, the owner's ask), as
/// tall as the round buttons beside it, a round face by two lines of small
/// spaced capitals ("RENATA IS / NEARBY"). It grows out of a short line when
/// there is something to show, line and pill one shape, the words growing
/// with it out of a blur, as in the reference. It turns to the next item
/// every few seconds while there are several (from the first each time it
/// opens), and goes back to the line when there is nothing. Someone nearby
/// (`PeopleNearbyPill`) or a request waiting for the owner (`RequestPill`),
/// which comes first: one surface for both, never a pill and a card.
struct PayPill<Item: Identifiable, Label: View>: View {
    let items: [Item]
    let onTap: (Item) -> Void
    let label: (Item) -> Label

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Grown from its line into the pill.
    @State private var isOpen = false
    /// Which item it shows.
    @State private var turn = 0
    /// How wide the pill is around what it shows, measured.
    @State private var width: CGFloat?

    init(items: [Item], onTap: @escaping (Item) -> Void, @ViewBuilder label: @escaping (Item) -> Label) {
        self.items = items
        self.onTap = onTap
        self.label = label
    }

    private var shown: Item? {
        items.isEmpty ? nil : items[turn % items.count]
    }

    var body: some View {
        let open = isOpen && shown != nil && width != nil
        Button {
            if let shown { onTap(shown) }
        } label: {
            // One capsule, the line and the pill: its size is what moves.
            Color.clear
                .frame(
                    width: open ? width ?? PayPillMetrics.line.width : PayPillMetrics.line.width,
                    height: open ? PayPillMetrics.height : PayPillMetrics.line.height
                )
                .overlay {
                    ZStack {
                        if let item = shown {
                            label(item)
                                .padding(.leading, PayPillMetrics.leading)
                                .padding(.trailing, PayPillMetrics.trailing)
                                .frame(height: PayPillMetrics.height)
                                .fixedSize()
                                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { resize(to: $0) }
                                .id(item.id)
                                .transition(.blurReplace)
                        }
                    }
                    // Grows with the pill, from the line's height to its
                    // own, out of a blur, as in the reference.
                    .scaleEffect(open || reduceMotion ? 1 : PayPillMetrics.line.height / PayPillMetrics.height)
                    .blur(radius: open ? 0 : 2)
                    .opacity(open ? 1 : 0)
                }
                // The line: a mark on the page until the glass opens.
                .background(Color.payPrimaryText.opacity(open ? 0 : 0.16), in: Capsule())
                .contentShape(Capsule())
                .starhashGlass(in: Capsule(), interactive: true, tint: .clear)
        }
        .buttonStyle(PressScaleButtonStyle())
        // The line sits where the pill's middle will be, level with the
        // round buttons, so the pill grows out of it every way at once.
        .frame(height: PayPillMetrics.height)
        .allowsHitTesting(open)
        .accessibilityHidden(!open)
        // The reference's curve: eases out of the line and into the pill,
        // half a second, without a bounce.
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .easeInOut(duration: 0.5), value: isOpen)
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

    /// The pill takes the width of what it shows: at once while it is a
    /// line, and with the words as they turn once open.
    private func resize(to newWidth: CGFloat) {
        guard newWidth != width else { return }
        if isOpen, width != nil {
            withAnimation(.smooth(duration: 0.45)) { width = newWidth }
        } else {
            width = newWidth
        }
    }
}

/// Pay's pill measured off the reference video.
enum PayPillMetrics {
    /// As tall as the round buttons beside it.
    static let height: CGFloat = 44
    /// The line it grows from, and goes back to.
    static let line = CGSize(width: 46, height: 5)
    /// The face, and the space around it on the left (the same as above and
    /// below it).
    static let face: CGFloat = 28
    static let leading: CGFloat = 8
    /// Between the face and the words.
    static let spacing: CGFloat = 8
    /// After the words: more than before the face, as in the reference.
    static let trailing: CGFloat = 22
}

/// What restarts the pill's turning: an item coming or going, or the pill
/// opening or closing.
private struct PayPillTurning: Equatable {
    var ids: [AnyHashable]
    var isOpen: Bool
}

/// What Pay's pill shows: a round face by its words.
struct PayPillLabel<Face: View>: View {
    let text: Text
    /// The mark that someone is nearby, on the face's corner.
    var showsNearby = false
    @ViewBuilder var face: Face

    var body: some View {
        HStack(spacing: PayPillMetrics.spacing) {
            face
                .frame(width: PayPillMetrics.face, height: PayPillMetrics.face)
                .clipShape(Circle())
                .overlay(alignment: .bottomTrailing) {
                    if showsNearby {
                        NearbyBadge().offset(x: 2, y: 2)
                    }
                }
            PayPillText(text: text)
        }
    }
}

/// The words in Pay's pill, as in the reference: small spaced capitals in a
/// monospaced face, on two lines ("RENATA IS / NEARBY"), where the string
/// breaks them.
struct PayPillText: View {
    let text: Text

    var body: some View {
        text
            .textCase(.uppercase)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(0.6)
            .lineSpacing(-1)
            .multilineTextAlignment(.leading)
            .foregroundStyle(Color.payPrimaryText)
            .lineLimit(2)
            .fixedSize()
    }
}

/// The mark on the face of someone nearby, as in the reference: waves
/// around a dot, open at the foot, on a disc of the page's colour that
/// parts it from the photo.
struct NearbyBadge: View {
    var body: some View {
        ZStack {
            Circle().fill(Color.starhashPayBackground)
            wave(diameter: 9, lineWidth: 1.6)
            wave(diameter: 4.5, lineWidth: 1.1)
            Circle()
                .fill(Color.payPrimaryText)
                .frame(width: 2, height: 2)
        }
        .frame(width: 12, height: 12)
        .accessibilityHidden(true)
    }

    /// A ring with a gap at the bottom.
    private func wave(diameter: CGFloat, lineWidth: CGFloat) -> some View {
        Circle()
            .trim(from: 0, to: 0.8)
            .stroke(Color.payPrimaryText, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            // The trim starts at three o'clock and runs clockwise: turned so
            // its gap centres on six.
            .rotationEffect(.degrees(126))
            .frame(width: diameter, height: diameter)
    }
}
