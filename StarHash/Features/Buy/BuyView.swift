import StarHashKit
import SwiftUI

/// Buy: the codes kept on hand to dial in a tap (`USSDShortcutList`), laid
/// out as Activity lists transactions, after Keaser's Home: one card of
/// rows split by the dashed line, each its symbol on a tile, its name and
/// what it does, and the code where a transaction shows its amount. A tap
/// dials; holding a row offers Dial, Edit and Delete, and a swipe deletes
/// it. It comes with MoMo's pending approvals and cash out, MTN's Gwamon'
/// Pack and the airport's parking; the + at the top right adds one's own,
/// in Keaser's New Category sheet (`ShortcutEditor`). The menu a code opens
/// asks for the amount and the PIN, so nothing is logged in Activity.
struct BuyView: View {
    @Environment(USSDShortcutList.self) private var shortcuts

    /// The sheet open: a new code, or one being edited.
    @State private var editing: ShortcutDraft?
    /// A code's details, opened by tapping its card.
    @State private var details: USSDShortcut?
    /// What the details sheet asked for, done once it has gone: the editor
    /// opens, or the code dials, only after the sheet is down.
    @State private var afterDetails: AfterDetails?

    private enum AfterDetails {
        case edit(ShortcutDraft)
        case dial(String)
    }
    /// A code the system would not dial (the simulator, an iPad), shown in
    /// an alert so it can be dialled by hand.
    @State private var undialledCode: String?
    @State private var deletedCount = 0
    @State private var pinnedCount = 0
    /// Eight pinned already, when one more was asked for.
    @State private var pinsFull = false
    /// Arranging the pinned codes: they wiggle and follow a finger to a new
    /// place, as on the Home Screen, until Done.
    @State private var arranging = false
    /// The pinned code under the finger while arranging, where the finger
    /// is in the grid, and where on the tile it took hold.
    @State private var dragID: USSDShortcut.ID?
    @State private var dragPoint: CGPoint = .zero
    @State private var grabOffset: CGSize = .zero
    @State private var gridWidth: CGFloat = 360
    /// True while a finger is down on a tile, arranging; false again when
    /// it lifts or the drag is cancelled, which settles the tile either way.
    @GestureState private var arrangeDragActive = false
    /// Bumped as a dragged tile passes another, for a tick each time.
    @State private var reorderTicks = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // The header is a Soft Edge bar: the codes scroll under it.
        ZStack {
            if shortcuts.shortcuts.isEmpty {
                EmptyStateView(
                    symbol: "number.square",
                    title: "No Codes",
                    message: "Add a code you dial often with the + button, and it is a tap away here."
                )
                .padding(.horizontal, StarHashMetrics.screenPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            } else {
                list
                    .transition(.opacity)
            }
        }
        .starhashSoftEdgeHeader {
            PageHeader(page: .buy) { PageTitle(text: "Buy") } trailing: {
                // Done while arranging the pinned codes, + otherwise; the
                // glyph swaps in place.
                SwapGlassButton(symbol: arranging ? "checkmark" : "plus", label: arranging ? "Done" : "Add a code") {
                    if arranging {
                        withAnimation(.smooth(duration: 0.3)) { arranging = false }
                    } else {
                        editing = ShortcutDraft()
                    }
                }
            }
        }
        .starhashTabBarClearance()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.starhashBackground.ignoresSafeArea())
        .animation(.smooth(duration: 0.3), value: shortcuts.shortcuts)
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: deletedCount)
        .sensoryFeedback(.impact(weight: .medium), trigger: pinnedCount)
        .sensoryFeedback(.selection, trigger: reorderTicks)
        .sheet(item: $editing) { draft in
            ShortcutEditor(draft: draft)
        }
        .alert("Pinned is full", isPresented: $pinsFull) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You can pin up to \(USSDShortcutList.maxPinned) codes. Unpin one to make room.")
        }
        .sheet(item: $details, onDismiss: runAfterDetails) { shortcut in
            ShortcutDetailSheet(
                shortcut: shortcut,
                onEdit: {
                    afterDetails = .edit(ShortcutDraft(shortcut))
                    details = nil
                },
                onDial: {
                    afterDetails = .dial(shortcut.code)
                    details = nil
                },
                onDelete: {
                    details = nil
                    delete(shortcut)
                }
            )
        }
        .alert(
            "Can't dial on this device",
            isPresented: Binding(get: { undialledCode != nil }, set: { if !$0 { undialledCode = nil } }),
            presenting: undialledCode
        ) { code in
            Button("Copy Code") {
                UIPasteboard.general.string = code
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            Button("OK", role: .cancel) {}
        } message: { code in
            Text("Dial \(code) on your phone.")
        }
        #if DEBUG
        // -buyNew: the editor for a new code; -buyEdit: editing the first;
        // -buyDetails: the first code's details.
        .task {
            try? await Task.sleep(for: .milliseconds(600))
            if DebugLaunch.arguments.contains("-buyNew") { editing = ShortcutDraft() }
            if DebugLaunch.arguments.contains("-buyEdit"), let first = shortcuts.shortcuts.first { editing = ShortcutDraft(first) }
            if DebugLaunch.arguments.contains("-buyDetails") { details = shortcuts.shortcuts.first }
            if DebugLaunch.arguments.contains("-buyArrange"), shortcuts.pinned.count > 1 { arranging = true }
        }
        #endif
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // The pinned codes need no title: they lead the page.
                if !shortcuts.pinned.isEmpty {
                    pinnedGrid
                        .padding(.bottom, 24)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                if !shortcuts.unpinned.isEmpty {
                    sectionTitle("Your codes")
                    VStack(spacing: 10) {
                        ForEach(shortcuts.unpinned) { shortcut in
                            ShortcutItem(
                                shortcut: shortcut,
                                onOpen: { details = shortcut },
                                onDial: { dial(shortcut.code) }
                            )
                            .contextMenu {
                                Button(shortcuts.canPin ? "Pin" : "Pinned is full", systemImage: "pin") { afterMenu { pin(shortcut, true) } }
                                    .disabled(!shortcuts.canPin)
                                Button("Edit", systemImage: "pencil") { editing = ShortcutDraft(shortcut) }
                                Button(role: .destructive) { afterMenu { delete(shortcut) } } label: { DestructiveMenuLabel("Delete") }
                            }
                            .accessibilityAction(named: "Pin") { pin(shortcut, true) }
                            .accessibilityAction(named: "Delete") { delete(shortcut) }
                            .buySwipeToPin { pin(shortcut, true) }
                            .activitySwipeToDelete { delete(shortcut) }
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.9, anchor: .top).combined(with: .opacity),
                                removal: .scale(scale: 0.85).combined(with: .opacity)
                            ))
                        }
                    }
                }
            }
            .padding(.horizontal, StarHashMetrics.screenPadding)
            .padding(.top, ActivityLayout.contentTop)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        // A finger on a tile while arranging moves the tile, not the page.
        .scrollDisabled(arranging)
        .starhashSoftEdge()
        .activitySwipeActionsContainer()
        .starhashReadableScrollContent()
        .starhashTabBarFollowsScroll()
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .starhashFont(17, weight: .semibold, relativeTo: .headline)
            .foregroundStyle(Color.starhashSecondaryText)
            .accessibilityAddTraits(.isHeader)
            .padding(.leading, 16)
            .padding(.bottom, 10)
    }

    /// The pinned codes, four to a row in two rows at most, every row
    /// centred, bigger the fewer there are (`PinnedLayout`): one pinned code
    /// sits alone in the middle, and the rest slide aside and shrink as more
    /// are pinned. A tap dials at once; options open on a long press, among
    /// them Rearrange. Arranging, the tiles wiggle and the one under the
    /// finger follows it, drawn over the grid while its own place stays
    /// empty, as the others part around it.
    private var pinnedGrid: some View {
        let pinned = shortcuts.pinned
        return PinnedLayout(spacing: 10) {
            ForEach(Array(pinned.enumerated()), id: \.element.id) { index, shortcut in
                pinnedItem(shortcut, index: index)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.5).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { gridWidth = $0 }
        .coordinateSpace(.named(PinnedLayout.space))
        .overlay(alignment: .topLeading) { draggedTile(in: pinned) }
        .onChange(of: pinned.count) { _, count in
            if count < 2 { arranging = false }
        }
        .onChange(of: arrangeDragActive) { _, active in
            if !active { settleDraggedTile() }
        }
    }

    @ViewBuilder
    private func pinnedItem(_ shortcut: USSDShortcut, index: Int) -> some View {
        if arranging {
            PinnedTileFace(shortcut: shortcut)
                .modifier(Wiggle(isOn: !reduceMotion && dragID != shortcut.id, seed: index))
                // Its place stays while it is under the finger, empty; set
                // outside the wiggle, whose easing would fade it back in.
                .opacity(dragID == shortcut.id ? 0 : 1)
                .gesture(arrangeDrag(shortcut))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(shortcut.name)
                .accessibilityHint("Drag to move it")
                .accessibilityAction(named: "Move Earlier") { movePinned(shortcut, by: -1) }
                .accessibilityAction(named: "Move Later") { movePinned(shortcut, by: 1) }
        } else {
            PinnedTile(shortcut: shortcut) { dial(shortcut.code) }
                .contextMenu {
                    if shortcuts.pinned.count > 1 {
                        Button("Rearrange", systemImage: "arrow.left.arrow.right") {
                            afterMenu { withAnimation(.smooth(duration: 0.3)) { arranging = true } }
                        }
                    }
                    Button("Unpin", systemImage: "pin.slash") { afterMenu { pin(shortcut, false) } }
                    Button("Details", systemImage: "info.circle") { details = shortcut }
                    Button("Edit", systemImage: "pencil") { editing = ShortcutDraft(shortcut) }
                    Button(role: .destructive) { afterMenu { delete(shortcut) } } label: { DestructiveMenuLabel("Delete") }
                }
                .accessibilityAction(named: "Unpin") { pin(shortcut, false) }
                .accessibilityAction(named: "Move Earlier") { movePinned(shortcut, by: -1) }
                .accessibilityAction(named: "Move Later") { movePinned(shortcut, by: 1) }
                .accessibilityAction(named: "Details") { details = shortcut }
                .accessibilityAction(named: "Delete") { delete(shortcut) }
        }
    }

    /// The tile under the finger, lifted a little, over the grid.
    @ViewBuilder
    private func draggedTile(in pinned: [USSDShortcut]) -> some View {
        if let dragID, let shortcut = pinned.first(where: { $0.id == dragID }) {
            let size = PinnedLayout(spacing: 10).frames(count: pinned.count, width: gridWidth).first?.size ?? .zero
            PinnedTileFace(shortcut: shortcut)
                .frame(width: size.width, height: size.height)
                .scaleEffect(1.07)
                .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
                .position(x: dragPoint.x - grabOffset.width, y: dragPoint.y - grabOffset.height)
                .allowsHitTesting(false)
        }
    }

    /// Settles the lifted tile into its place: on release, or when the drag
    /// is cancelled.
    private func settleDraggedTile() {
        guard let dragID else { return }
        let pinned = shortcuts.pinned
        let frames = PinnedLayout(spacing: 10).frames(count: pinned.count, width: gridWidth)
        guard let index = pinned.firstIndex(where: { $0.id == dragID }), frames.indices.contains(index) else {
            self.dragID = nil
            return
        }
        let home = CGPoint(x: frames[index].midX + grabOffset.width, y: frames[index].midY + grabOffset.height)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            dragPoint = home
        } completion: {
            // The lifted copy and the tile in its place swap in one frame,
            // with no fade between them.
            var instant = SwiftUI.Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) { self.dragID = nil }
        }
    }

    /// Picks the tile up where the finger lands, keeps it under the finger,
    /// and moves it into whichever place its centre is nearest.
    private func arrangeDrag(_ shortcut: USSDShortcut) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(PinnedLayout.space))
            .updating($arrangeDragActive) { _, active, _ in active = true }
            .onChanged { value in
                let layout = PinnedLayout(spacing: 10)
                let pinned = shortcuts.pinned
                let frames = layout.frames(count: pinned.count, width: gridWidth)
                guard let index = pinned.firstIndex(where: { $0.id == shortcut.id }), frames.indices.contains(index) else { return }
                if dragID == nil {
                    let frame = frames[index]
                    grabOffset = CGSize(width: value.startLocation.x - frame.midX, height: value.startLocation.y - frame.midY)
                    dragPoint = value.location
                    dragID = shortcut.id
                    TapHaptic.play(.medium)
                    return
                }
                dragPoint = value.location
                let centre = CGPoint(x: value.location.x - grabOffset.width, y: value.location.y - grabOffset.height)
                let nearest = frames.indices.min { a, b in
                    hypot(frames[a].midX - centre.x, frames[a].midY - centre.y)
                        < hypot(frames[b].midX - centre.x, frames[b].midY - centre.y)
                }
                if let nearest, nearest != index {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        shortcuts.movePinned(shortcut.id, to: pinned[nearest].id)
                    }
                    reorderTicks += 1
                }
            }

    }

    /// VoiceOver's reordering: one place earlier or later.
    private func movePinned(_ shortcut: USSDShortcut, by step: Int) {
        let pinned = shortcuts.pinned
        guard let index = pinned.firstIndex(where: { $0.id == shortcut.id }),
              pinned.indices.contains(index + step) else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            shortcuts.movePinned(shortcut.id, to: pinned[index + step].id)
        }
    }

    /// A change asked for from a context menu, made once the menu has
    /// closed: made at once, the menu's preview would drift back to where
    /// the code no longer is while the tiles move under it.
    private func afterMenu(_ change: @escaping @MainActor () -> Void) {
        Task {
            try? await Task.sleep(for: .milliseconds(380))
            change()
        }
    }

    /// Pins or unpins; with eight pinned, a swipe to pin explains instead.
    private func pin(_ shortcut: USSDShortcut, _ isPinned: Bool) {
        var pinned = false
        // A spring, so the tiles settle into their new places.
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            pinned = shortcuts.setPinned(shortcut.id, isPinned)
        }
        if pinned {
            pinnedCount += 1
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            pinsFull = true
        }
    }

    private func runAfterDetails() {
        switch afterDetails {
        case .edit(let draft): editing = draft
        case .dial(let code): dial(code)
        case nil: break
        }
        afterDetails = nil
    }

    private func delete(_ shortcut: USSDShortcut) {
        withAnimation(.smooth(duration: 0.3)) { shortcuts.remove(shortcut.id) }
        deletedCount += 1
    }

    private func dial(_ code: String) {
        Task {
            if await !USSDDialer.dial(code) {
                undialledCode = code
            }
        }
    }
}

/// One code, on its own: a concise Total card (its symbol
/// on a tile, its name, the code) that opens its details, and beside it, apart, the button
/// that dials it, in Liquid Glass tinted the accent, so starting a code is
/// one clear thing.
private struct ShortcutItem: View {
    let shortcut: USSDShortcut
    let onOpen: () -> Void
    let onDial: () -> Void

    /// Either half held: the card and its call button press together, and
    /// a long press lifts them together into the menu, as one button.
    @State private var isPressed = false

    private let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

    var body: some View {
        HStack(spacing: 10) {
            Button {
                TapHaptic.play()
                onOpen()
            } label: {
                HStack(spacing: 14) {
                    // The symbol alone, with no tile behind it.
                    Image(systemName: shortcut.symbol ?? ShortcutSymbols.plain)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.starhashPrimaryText)
                        .frame(width: 40, height: 40)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(shortcut.name)
                            .starhashFont(17, weight: .semibold, relativeTo: .headline)
                            .foregroundStyle(Color.starhashPrimaryText)
                            .lineLimit(2)
                        Text(shortcut.code)
                            .starhashFont(14, weight: .semibold, relativeTo: .subheadline, tracking: 0)
                            .foregroundStyle(Color.starhashTertiaryText)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
                // The Total card, as the recipient screen's Total.
                .starhashTotalCard(in: shape)
                .contentShape(shape)
            }
            .buttonStyle(SharedPressButtonStyle(isPressed: $isPressed))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(shortcut.name)
            .accessibilityValue(shortcut.code)
            .accessibilityHint("Shows its details")
            .accessibilityAddTraits(.isButton)

            Button {
                TapHaptic.play(.medium)
                onDial()
            } label: {
                Image(systemName: "phone.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.callGlyph)
                    // The card's shape and height, so the two read as a pair.
                    .frame(width: 68, height: 68)
                    .contentShape(shape)
                    .background(Color.callSolidFill, in: shape)
                    .starhashGlass(in: shape, tint: .callGlassTint)
            }
            .buttonStyle(SharedPressButtonStyle(isPressed: $isPressed))
            .accessibilityLabel("Dial \(shortcut.name)")
            .accessibilityHint("Dials \(shortcut.code)")
        }
        .scaleEffect(isPressed ? 0.96 : 1)
        .opacity(isPressed ? 0.88 : 1)
        .animation(.snappy(duration: 0.18), value: isPressed)
        // The menu's preview is the whole pair.
        .contentShape(.contextMenuPreview, shape)
    }
}

/// A button that draws nothing while pressed but says so through
/// `isPressed`, so several buttons can press as one; silent, as each plays
/// its haptic when its tap lands (a long press opens a menu of its own).
private struct SharedPressButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, pressed in
                isPressed = pressed
            }
    }
}

/// A pinned code: a portrait Total card with its bare
/// symbol in the middle and its name at the foot, and nothing else. A tap dials at
/// once; its options open on a long press. The symbol and name scale with
/// the tile, sized by `PinnedLayout`.
private struct PinnedTile: View {
    let shortcut: USSDShortcut
    let onDial: () -> Void

    var body: some View {
        Button {
            TapHaptic.play(.medium)
            onDial()
        } label: {
            PinnedTileFace(shortcut: shortcut)
                .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 20, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle(pressHaptic: false))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Dial \(shortcut.name)")
        .accessibilityValue(shortcut.code)
        .accessibilityAddTraits(.isButton)
    }
}

/// What a pinned tile shows, as large as `PinnedLayout` makes it: the
/// Total card, the symbol and the name, in fixed zones.
private struct PinnedTileFace: View {
    let shortcut: USSDShortcut

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                GeometryReader { proxy in
                    let width = proxy.size.width
                    let height = proxy.size.height
                    // Both in proportion to the tile, so a lone tile
                    // (160pt wide) carries a symbol and name as big as it
                    // is, and four to a row (about 88pt) stay neat.
                    let iconSize = width * 0.3
                    let nameSize = min(20, max(13, width * 0.125))
                    // Fixed zones, the same on every tile whatever the
                    // name: the symbol centred in the upper part, in a
                    // square box so every symbol shares one centre, and
                    // the name from one line down, top-aligned, so one-
                    // and two-line names start level.
                    VStack(spacing: 0) {
                        Image(systemName: shortcut.symbol ?? ShortcutSymbols.plain)
                            .font(.system(size: iconSize, weight: .semibold))
                            .foregroundStyle(Color.starhashPrimaryText)
                            .frame(width: iconSize * 1.4, height: iconSize * 1.4)
                            .frame(maxWidth: .infinity)
                            .frame(height: height * 0.6)
                            .accessibilityHidden(true)
                        Text(shortcut.name)
                            .starhashFont(nameSize, weight: .semibold, relativeTo: .footnote)
                            .foregroundStyle(Color.starhashPrimaryText)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, width * 0.07)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                    .frame(width: width, height: height)
                }
            }
            .starhashTotalCard(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// The Home Screen's wiggle while arranging: a small rock back and forth,
/// each tile a touch out of step with the next.
private struct Wiggle: ViewModifier {
    let isOn: Bool
    let seed: Int

    /// One view whether rocking or not: swapping views would cancel the
    /// drag that turns it off.
    func body(content: Content) -> some View {
        content.phaseAnimator([false, true]) { view, phase in
            view.rotationEffect(.degrees(isOn ? (phase ? 1.6 : -1.6) : 0))
        } animation: { _ in
            .easeInOut(duration: 0.13 + Double(seed % 3) * 0.015)
        }
    }
}

/// The pinned tiles, 3:2 standing, and the fewer there are the bigger: one
/// or two are a half row wide each, three a third, and four or more a
/// quarter. Four to a row at most, the rest on a second, and every row
/// centred, so one to four sit centred in one row and five to eight make a
/// row of four over a centred row of the rest. A layout, so a change of
/// count slides and resizes each tile inside the change's animation.
struct PinnedLayout: Layout {
    var spacing: CGFloat = 10
    /// Width over height: 3:2, standing, so two wide by three tall.
    var aspect: CGFloat = 2.0 / 3.0
    /// A lone tile or two would stand too tall at half the row's width.
    var maxTileHeight: CGFloat = 240

    /// Tiles to a row at most.
    static let perRow = 4

    /// How many of the row's width each tile takes: two for one or two
    /// tiles, three for three, four from four on.
    static func sizing(for count: Int) -> Int {
        min(perRow, max(2, count))
    }

    private func metrics(width: CGFloat, count: Int) -> (tile: CGSize, rows: Int) {
        let share = Self.sizing(for: count)
        let fitted = max(0, (width - spacing * CGFloat(share - 1)) / CGFloat(share))
        let tileWidth = min(fitted, maxTileHeight * aspect)
        let tile = CGSize(width: tileWidth, height: tileWidth / aspect)
        let rows = count == 0 ? 0 : (count + Self.perRow - 1) / Self.perRow
        return (tile, rows)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 360
        let m = metrics(width: width, count: subviews.count)
        let height = CGFloat(m.rows) * m.tile.height + CGFloat(max(0, m.rows - 1)) * spacing
        return CGSize(width: width, height: height)
    }

    /// The coordinate space arranging measures the finger in.
    static let space = "pinned"

    /// Each tile's frame in a grid `width` wide, from its top left: what
    /// arranging finds the finger's place with, and the layout places by.
    func frames(count: Int, width: CGFloat) -> [CGRect] {
        let m = metrics(width: width, count: count)
        return (0..<count).map { index in
            let row = index / Self.perRow
            let column = index % Self.perRow
            let inRow = min(Self.perRow, count - row * Self.perRow)
            let rowWidth = CGFloat(inRow) * m.tile.width + CGFloat(inRow - 1) * spacing
            let x = (width - rowWidth) / 2 + CGFloat(column) * (m.tile.width + spacing)
            let y = CGFloat(row) * (m.tile.height + spacing)
            return CGRect(origin: CGPoint(x: x, y: y), size: m.tile)
        }
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = frames(count: subviews.count, width: bounds.width)
        for (index, frame) in zip(subviews.indices, frames) {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }
}

extension View {
    /// A swipe in from the left pins a code, as a swipe from the right
    /// deletes it. iOS 27 and later; the context menu pins on earlier ones.
    @ViewBuilder
    func buySwipeToPin(_ onPin: @escaping () -> Void) -> some View {
        if #available(iOS 27.0, *) {
            swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button(action: onPin) {
                    Image(systemName: "pin.fill")
                }
                .tint(Color.starhashInk)
                .accessibilityLabel("Pin")
            }
        } else {
            self
        }
    }
}

/// A code's details, after Keaser's expense details, sized to what it
/// shows: a close button, the title and Edit across the top, the code's
/// symbol and name on their own, a card with its code and note as rows,
/// then Dial and the delete button under it.
private struct ShortcutDetailSheet: View {
    let shortcut: USSDShortcut
    let onEdit: () -> Void
    let onDial: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var height: CGFloat = 440

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(spacing: 14) {
                // The symbol and name on their own, above the card.
                VStack(spacing: 10) {
                    // The symbol alone, with no tile behind it, as on Buy.
                    Image(systemName: shortcut.symbol ?? ShortcutSymbols.plain)
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(Color.sheetBrandText)
                        .frame(height: 56)
                        .accessibilityHidden(true)
                    Text(shortcut.name)
                        .font(.sheet(21, .bold, relativeTo: .title2))
                        .foregroundStyle(Color.sheetBrandText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 4)

                VStack(spacing: 0) {
                    SheetInfoRow("Code", shortcut.code)
                    if let detail = shortcut.detail {
                        SheetDivider()
                        SheetInfoRow(label: "Note") {
                            SheetValueText(text: detail)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .sheetCard()

                VStack(spacing: 10) {
                    Button(action: onDial) {
                        Label("Dial \(shortcut.code)", systemImage: "phone.fill")
                    }
                    .buttonStyle(.sheetPrimary)
                    DeleteButton("Delete Code", action: onDelete)
                }
                .padding(.top, 4)
                .padding(.bottom, 14)
            }
            .padding(.horizontal, 18)
        }
        .sheetHeight($height)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Into the home indicator's inset, as Turn Off Auto-verify's: iOS
        // adds that inset to the detent, so the detent leaves it out.
        .ignoresSafeArea(.container, edges: .bottom)
        .sheetGlass(detents: [.height(height - 4)])
    }

    /// Keaser's: close on the left, the title, Edit on the right.
    private var header: some View {
        ZStack {
            Text("Code")
                .font(.sheetLargeTitle)
                .tracking(StarHashTracking.display(32))
                .foregroundStyle(Color.sheetBrandText)
                .lineLimit(1)
                .padding(.horizontal, 80)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Button { dismiss() } label: {
                    SheetGlassGlyph(symbol: "xmark")
                }
                .buttonStyle(.hapticPlain)
                .accessibilityLabel("Close")
                Spacer()
                Button(action: onEdit) {
                    Text("Edit")
                        .font(.sheet(16, .semibold, relativeTo: .body))
                        .foregroundStyle(Color.starhashPrimaryText)
                        .padding(.horizontal, 18)
                        .frame(height: 44)
                        .contentShape(Capsule())
                        .starhashGlass(interactive: true, tint: .sheetControlTint)
                }
                .buttonStyle(.hapticPlain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }
}

/// The symbols a code can wear, chosen in the editor's grid: money, bills
/// and the places a code is dialled for.
enum ShortcutSymbols {
    /// For a code with none chosen.
    static let plain = "number"

    static let all: [String] = [
        "number", "checkmark.seal.fill", "banknote.fill", "gift.fill", "parkingsign",
        "phone.fill", "antenna.radiowaves.left.and.right", "wifi", "bolt.fill", "drop.fill",
        "tv.fill", "cart.fill", "bag.fill", "fork.knife", "car.fill",
        "bus.fill", "airplane", "fuelpump.fill", "house.fill", "building.columns.fill",
        "graduationcap.fill", "cross.case.fill", "heart.fill", "ticket.fill", "film.fill",
        "gamecontroller.fill", "creditcard.fill", "arrow.left.arrow.right", "lock.fill", "star.fill",
    ]
}

/// What the editor works on: a new code (no id) or a copy of one to change.
struct ShortcutDraft: Identifiable {
    let id = UUID()
    var editing: USSDShortcut.ID?
    var name = ""
    var code = ""
    var detail = ""
    var symbol = ShortcutSymbols.plain

    init() {}

    init(_ shortcut: USSDShortcut) {
        editing = shortcut.id
        name = shortcut.name
        code = shortcut.code
        detail = shortcut.detail ?? ""
        symbol = shortcut.symbol ?? ShortcutSymbols.plain
    }
}

/// Adds or edits a code, after Keaser's New Category, in StarHash's sheet
/// language: the title between a close button on the left and the confirm
/// button on the right, then the chosen symbol on a tile at the left with
/// the name, the code and a note as capsule fields beside it. Tapping the
/// symbol opens the grid of symbols under them, the chosen one ringed.
/// Editing, Delete Code is the sheet's big red button at the foot.
private struct ShortcutEditor: View {
    @Environment(USSDShortcutList.self) private var shortcuts
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var code: String
    @State private var detail: String
    @State private var symbol: String
    /// The content's height, so the sheet opens as tall as what it shows.
    @State private var height: CGFloat = 420
    /// The grid of symbols, shown once the big symbol is tapped.
    @State private var choosesSymbol = false
    @FocusState private var focused: Field?

    private let editing: USSDShortcut.ID?

    private enum Field { case name, code, detail }

    init(draft: ShortcutDraft) {
        editing = draft.editing
        _name = State(initialValue: draft.name)
        _code = State(initialValue: draft.code)
        _detail = State(initialValue: draft.detail)
        _symbol = State(initialValue: draft.symbol)
        #if DEBUG
        _choosesSymbol = State(initialValue: DebugLaunch.arguments.contains("-buySymbols"))
        #endif
    }

    private var validCode: String? { USSDShortcut.code(from: code) }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && validCode != nil
    }
    /// Only once the code is closed with a # and still is not one.
    private var showsCodeHint: Bool {
        !code.isEmpty && validCode == nil && code.hasSuffix("#")
    }

    var body: some View {
        // Sized to what it shows, growing as the symbols open; scrolls only
        // when that is more than the screen (the largest text sizes).
        ScrollView {
            VStack(spacing: 0) {
                header

                VStack(spacing: 14) {
                    // The symbol on the left, as tall as the three fields
                    // beside it.
                    HStack(alignment: .top, spacing: 12) {
                        symbolButton
                        fields
                    }
                    .fixedSize(horizontal: false, vertical: true)

                    if choosesSymbol {
                        symbolGrid
                            .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                    }

                    if showsCodeHint {
                        hint
                            .transition(.opacity)
                    }

                    if let editing {
                        DeleteButton("Delete Code") {
                            shortcuts.remove(editing)
                            dismiss()
                        }
                        .padding(.top, 10)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .sheetHeight($height)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .sheetGlass(detents: [.height(height + 8)])
        .animation(.smooth(duration: 0.3), value: height)
        .animation(.smooth(duration: 0.2), value: showsCodeHint)
        .onAppear { if editing == nil { focused = .name } }
    }

    /// Keaser's: the title between a close button and the confirm one, laid
    /// out as `SheetHeader` lays out its own.
    private var header: some View {
        ZStack {
            Text(editing == nil ? "New Code" : "Edit Code")
                .font(.sheetLargeTitle)
                .tracking(StarHashTracking.display(32))
                .foregroundStyle(Color.sheetBrandText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 52)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Button { dismiss() } label: {
                    SheetGlassGlyph(symbol: "xmark")
                }
                .buttonStyle(.hapticPlain)
                .accessibilityLabel("Close")
                Spacer()
                Button(action: save) {
                    SheetGlassGlyph(symbol: "checkmark")
                }
                .buttonStyle(.hapticPlain)
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.4)
                .accessibilityLabel(editing == nil ? "Add" : "Save")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    /// The chosen symbol on a tile as tall as the fields beside it, with
    /// Change under it: a tap opens the grid of symbols, another closes it.
    private var symbolButton: some View {
        Button {
            focused = nil
            withAnimation(.smooth(duration: 0.3)) { choosesSymbol.toggle() }
        } label: {
            VStack(spacing: 0) {
                Spacer(minLength: 8)
                Image(systemName: symbol)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(Color.starhashPrimaryText)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(height: 56)
                Spacer(minLength: 8)
                HStack(spacing: 4) {
                    Image(systemName: choosesSymbol ? "chevron.up" : "pencil")
                        .font(.system(size: 11, weight: .bold))
                        .contentTransition(.symbolEffect(.replace))
                    Text(choosesSymbol ? "Done" : "Change")
                        .font(.sheet(13, .semibold, relativeTo: .footnote))
                        .contentTransition(.opacity)
                }
                .foregroundStyle(Color.starhashOnInk)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(Color.starhashInk, in: Capsule())
                .padding(.bottom, 12)
            }
            .frame(width: 112)
            .frame(maxHeight: .infinity)
            .starhashContainer(.sheetSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .animation(.snappy(duration: 0.2), value: symbol)
            .animation(.snappy(duration: 0.2), value: choosesSymbol)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Symbol")
        .accessibilityHint(choosesSymbol ? "Closes the symbols" : "Opens the symbols to choose from")
    }

    private var fields: some View {
        VStack(spacing: 10) {
            capsuleField("Name", text: $name, field: .name)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.next)
                .onSubmit { focused = .code }
            capsuleField("Code, e.g. *182*7*1#", text: $code, field: .code)
                .keyboardType(.phonePad)
                .accessibilityLabel("Code")
            capsuleField("Note (optional)", text: $detail, field: .detail)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
        }
    }

    /// Only for a code that is not one: the fields and their placeholder
    /// say enough otherwise.
    private var hint: some View {
        Text("This isn't a valid code. Use only numbers, * and #, starting with * or # and ending with #.")
            .font(.sheetSubheadline)
            .foregroundStyle(Color.starhashDestructive)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
    }

    /// Keaser's field: a capsule, its text from the left beside the symbol.
    private func capsuleField(_ prompt: String, text: Binding<String>, field: Field) -> some View {
        TextField(prompt, text: text, prompt: Text(prompt).foregroundStyle(Color.sheetSecondaryText))
            .font(.sheet(17, .medium, relativeTo: .body))
            .foregroundStyle(Color.starhashPrimaryText)
            .autocorrectionDisabled()
            .focused($focused, equals: field)
            .padding(.horizontal, 18)
            .frame(minHeight: 52)
            .starhashContainer(.sheetSurface, in: Capsule())
    }

    /// Every symbol a code can wear, five to a row, in a card: a tap
    /// chooses it, and the chosen one is ringed.
    private var symbolGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 12) {
            ForEach(ShortcutSymbols.all, id: \.self) { option in
                let isChosen = option == symbol
                Button {
                    symbol = option
                    // Closes once the ring has landed on the choice.
                    Task {
                        try? await Task.sleep(for: .milliseconds(280))
                        withAnimation(.smooth(duration: 0.3)) { choosesSymbol = false }
                    }
                } label: {
                    Image(systemName: option)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Color.starhashPrimaryText)
                        .frame(width: 48, height: 48)
                        .background(Color.sheetChip.opacity(isChosen ? 1 : 0.55), in: Circle())
                        .overlay {
                            Circle()
                                .strokeBorder(Color.starhashPrimaryText, lineWidth: isChosen ? 2 : 0)
                                .padding(-4)
                        }
                        .frame(width: 56, height: 56)
                        .contentShape(Circle())
                }
                .buttonStyle(.hapticPlain)
                .accessibilityLabel(option.replacingOccurrences(of: ".fill", with: "").replacingOccurrences(of: ".", with: " "))
                .accessibilityAddTraits(isChosen ? .isSelected : [])
            }
        }
        .padding(14)
        .sheetCard()
        .animation(.snappy(duration: 0.2), value: symbol)
    }

    private func save() {
        let saved = if let editing {
            shortcuts.update(editing, name: name, code: code, detail: detail, symbol: symbol)
        } else {
            shortcuts.add(name: name, code: code, detail: detail, symbol: symbol)
        }
        guard saved else { return }
        // Played here, as the sheet goes, which a view-bound haptic would
        // not outlive.
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
