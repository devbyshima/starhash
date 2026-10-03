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

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(page: .buy) { PageTitle(text: "Buy") } trailing: {
                SwapGlassButton(symbol: "plus", label: "Add a code") {
                    editing = ShortcutDraft()
                }
            }

            if shortcuts.shortcuts.isEmpty {
                EmptyStateView(
                    symbol: "number.square",
                    title: "No Codes",
                    message: "Add a code you dial often with the + button, and it is a tap away here.",
                    style: .large
                )
                .padding(.horizontal, StarHashMetrics.screenPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            } else {
                list
                    .transition(.opacity)
            }
        }
        .starhashTabBarClearance()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.starhashBackground.ignoresSafeArea())
        .animation(.smooth(duration: 0.3), value: shortcuts.shortcuts)
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: deletedCount)
        .sensoryFeedback(.impact(weight: .medium), trigger: pinnedCount)
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
        }
        #endif
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if !shortcuts.pinned.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        sectionTitle("Pinned")
                        pinnedGrid
                    }
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
                                Button("Dial \(shortcut.code)", systemImage: "phone.arrow.up.right") { dial(shortcut.code) }
                                Button(shortcuts.canPin ? "Pin" : "Pinned is full", systemImage: "pin") { afterMenu { pin(shortcut, true) } }
                                    .disabled(!shortcuts.canPin)
                                Button("Edit", systemImage: "pencil") { editing = ShortcutDraft(shortcut) }
                                Button("Delete", systemImage: "trash", role: .destructive) { afterMenu { delete(shortcut) } }
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
    /// are pinned. A tap dials at once;
    /// options open on a long press.
    private var pinnedGrid: some View {
        PinnedLayout(spacing: 10) {
            ForEach(shortcuts.pinned) { shortcut in
                PinnedTile(shortcut: shortcut) { dial(shortcut.code) }
                    .contextMenu {
                        Button("Unpin", systemImage: "pin.slash") { afterMenu { pin(shortcut, false) } }
                        Button("Details", systemImage: "info.circle") { details = shortcut }
                        Button("Edit", systemImage: "pencil") { editing = ShortcutDraft(shortcut) }
                        Button("Delete", systemImage: "trash", role: .destructive) { afterMenu { delete(shortcut) } }
                    }
                    .accessibilityAction(named: "Unpin") { pin(shortcut, false) }
                    .accessibilityAction(named: "Details") { details = shortcut }
                    .accessibilityAction(named: "Delete") { delete(shortcut) }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.5).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
            }
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

/// One code, on its own: a concise card of clear Liquid Glass (its symbol
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
                // Clear Liquid Glass, as the tab bar's: the page shows
                // through the card.
                .starhashGlass(in: shape, tint: .clear)
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
                    .foregroundStyle(Color.starhashOnInk)
                    // The card's shape and height, so the two read as a pair.
                    .frame(width: 68, height: 68)
                    .contentShape(shape)
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

/// A pinned code: a portrait tile of clear Liquid Glass with its bare
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
            // As large as `PinnedLayout` makes it.
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    GeometryReader { proxy in
                        let width = proxy.size.width
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            // The symbol alone, with no tile behind it, sized
                            // with the tile.
                            Image(systemName: shortcut.symbol ?? ShortcutSymbols.plain)
                                .font(.system(size: min(40, width * 0.26), weight: .semibold))
                                .foregroundStyle(Color.starhashPrimaryText)
                                .accessibilityHidden(true)
                            Spacer(minLength: 0)
                            Text(shortcut.name)
                                .starhashFont(width < 110 ? 13 : (width < 140 ? 15 : 17), weight: .semibold, relativeTo: .footnote)
                                .foregroundStyle(Color.starhashPrimaryText)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                                .padding(.horizontal, 8)
                                .padding(.bottom, width < 110 ? 10 : (width < 140 ? 14 : 18))
                        }
                        .frame(width: width, height: proxy.size.height)
                    }
                }
                .starhashGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous), tint: .clear)
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

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let m = metrics(width: bounds.width, count: subviews.count)
        for index in subviews.indices {
            let row = index / Self.perRow
            let column = index % Self.perRow
            let inRow = min(Self.perRow, subviews.count - row * Self.perRow)
            let rowWidth = CGFloat(inRow) * m.tile.width + CGFloat(inRow - 1) * spacing
            let x = bounds.minX + (bounds.width - rowWidth) / 2 + CGFloat(column) * (m.tile.width + spacing)
            let y = bounds.minY + CGFloat(row) * (m.tile.height + spacing)
            subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(m.tile))
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
/// then Dial and, in red under it, Delete Code.
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
                    SymbolTile(symbol: shortcut.symbol ?? ShortcutSymbols.plain, size: 64, background: .sheetSurface)
                    Text(shortcut.name)
                        .font(.sheet(21, .bold, relativeTo: .title2))
                        .foregroundStyle(Color.starhashPrimaryText)
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

                VStack(spacing: 4) {
                    Button(action: onDial) {
                        Label("Dial \(shortcut.code)", systemImage: "phone.fill")
                    }
                    .buttonStyle(.sheetPrimary)
                    SheetTextButton("Delete Code", role: .destructive, action: onDelete)
                }
                .padding(.top, 4)
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
                .foregroundStyle(Color.starhashPrimaryText)
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
                        .starhashGlass(interactive: true)
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
/// button on the right, the chosen symbol large on its tile, and the name,
/// the code and a note as capsule fields. Tapping the symbol opens the grid
/// of symbols to choose from, the chosen one ringed. Editing, Delete Code
/// sits at the foot.
private struct ShortcutEditor: View {
    @Environment(USSDShortcutList.self) private var shortcuts
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var code: String
    @State private var detail: String
    @State private var symbol: String
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
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 16) {
                    preview
                    if choosesSymbol {
                        symbolGrid
                            .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                    }
                    fields
                    if let editing {
                        SheetTextButton("Delete Code", role: .destructive) {
                            shortcuts.remove(editing)
                            dismiss()
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .sheetGlass(detents: [.large])
        .onAppear { if editing == nil { focused = .name } }
    }

    /// Keaser's: the title between a close button and the confirm one, laid
    /// out as `SheetHeader` lays out its own.
    private var header: some View {
        ZStack {
            Text(editing == nil ? "New Code" : "Edit Code")
                .font(.sheetLargeTitle)
                .tracking(StarHashTracking.display(32))
                .foregroundStyle(Color.starhashPrimaryText)
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

    /// The chosen symbol, large on its tile, as Keaser shows a category's,
    /// with a pencil on its corner: a tap opens the grid to change it, and
    /// another closes it.
    private var preview: some View {
        Button {
            focused = nil
            withAnimation(.smooth(duration: 0.3)) { choosesSymbol.toggle() }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Color.starhashPrimaryText)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 88, height: 88)
                .background(Color.sheetSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: choosesSymbol ? "chevron.up" : "pencil")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.starhashOnInk)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 28, height: 28)
                        .background(Color.starhashInk, in: Circle())
                        .overlay(Circle().strokeBorder(Color.sheetGlassTint, lineWidth: 2))
                        .offset(x: 6, y: 6)
                }
                .animation(.snappy(duration: 0.2), value: symbol)
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
            capsuleField("Code, such as *182*7*1#", text: $code, field: .code)
                .keyboardType(.phonePad)
                .accessibilityLabel("Code")
            capsuleField("Note (optional)", text: $detail, field: .detail)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)

            Text(showsCodeHint ? "This isn't a valid code. Use only numbers, * and #, starting with * or # and ending with #." : "Type the code exactly as you would dial it. It must start with * or # and end with #.")
                .font(.sheetSubheadline)
                .foregroundStyle(showsCodeHint ? Color.starhashDestructive : Color.sheetSecondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
                .animation(.smooth(duration: 0.2), value: showsCodeHint)
        }
    }

    /// Keaser's field: a capsule the width of the sheet, its text centred.
    private func capsuleField(_ prompt: String, text: Binding<String>, field: Field) -> some View {
        TextField(prompt, text: text, prompt: Text(prompt).foregroundStyle(Color.sheetSecondaryText))
            .font(.sheet(17, .medium, relativeTo: .body))
            .foregroundStyle(Color.starhashPrimaryText)
            .multilineTextAlignment(.center)
            .autocorrectionDisabled()
            .focused($focused, equals: field)
            .padding(.horizontal, 20)
            .frame(minHeight: 52)
            .background(Color.sheetSurface, in: Capsule())
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
