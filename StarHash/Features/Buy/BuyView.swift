import StarHashKit
import SwiftUI

/// Buy: the codes kept on hand to dial in a tap (`USSDShortcutList`). It
/// comes with MoMo's pending approvals and cash out, MTN's Gwamon' Pack and
/// the airport's parking, and the + at the top right adds the person's own.
/// Each card shows its code, so a tap is never a surprise; holding one
/// edits or deletes it. The wallet or service's own prompts take the
/// amount and the PIN, so nothing is logged in Activity.
struct BuyView: View {
    @Environment(USSDShortcutList.self) private var shortcuts

    /// The sheet open: a new code, or one being edited.
    @State private var editing: ShortcutDraft?
    /// A code the system would not dial (the simulator, an iPad), shown in
    /// an alert so it can be dialled by hand.
    @State private var undialledCode: String?

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
            } else {
                list
            }
        }
        .starhashTabBarClearance()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.starhashBackground.ignoresSafeArea())
        .animation(.smooth(duration: 0.3), value: shortcuts.shortcuts)
        .sheet(item: $editing) { draft in
            ShortcutEditor(draft: draft)
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
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(shortcuts.shortcuts) { shortcut in
                    ShortcutCard(shortcut: shortcut) { dial(shortcut.code) }
                        .contextMenu {
                            Button("Edit", systemImage: "pencil") { editing = ShortcutDraft(shortcut) }
                            Button("Delete", systemImage: "trash", role: .destructive) { shortcuts.remove(shortcut.id) }
                        }
                        .accessibilityAction(named: "Edit") { editing = ShortcutDraft(shortcut) }
                        .accessibilityAction(named: "Delete") { shortcuts.remove(shortcut.id) }
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
                Text("Each opens its menu in your phone's dialler, which asks for the amount and your PIN; nothing is paid until you confirm there. Hold a code to edit or delete it.")
                    .starhashFont(13.5, weight: .medium, relativeTo: .footnote)
                    .foregroundStyle(Color.starhashSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
            }
            .padding(.horizontal, StarHashMetrics.screenPadding)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .starhashReadableWidth(StarHashMetrics.narrowReadableWidth)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .starhashTabBarFollowsScroll()
    }

    private func dial(_ code: String) {
        Task {
            if await !USSDDialer.dial(code) {
                undialledCode = code
            }
        }
    }
}

/// One code: its symbol on a tile, its name, what it does (for the ones
/// StarHash comes with) and the code itself, in a card the width of the
/// page. The whole card is the button.
private struct ShortcutCard: View {
    let shortcut: USSDShortcut
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                SymbolTile(symbol: shortcut.symbol ?? "number", size: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text(shortcut.name)
                        .starhashFont(18, weight: .bold, relativeTo: .headline)
                        .foregroundStyle(Color.starhashPrimaryText)
                        .lineLimit(2)
                    Text(shortcut.detail ?? shortcut.code)
                        .starhashFont(14, weight: .medium, relativeTo: .subheadline)
                        .foregroundStyle(Color.starhashTertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 6) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.starhashTertiaryText)
                    // The code under the arrow, unless it is already the
                    // card's second line.
                    if shortcut.detail != nil {
                        Text(shortcut.code)
                            .starhashFont(13, weight: .medium, relativeTo: .footnote)
                            .foregroundStyle(Color.starhashTertiaryText)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.starhashCard, in: RoundedRectangle(cornerRadius: StarHashMetrics.cardRadius, style: .continuous))
            .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: StarHashMetrics.cardRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: StarHashMetrics.cardRadius, style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(shortcut.name)
        .accessibilityValue(shortcut.detail ?? "")
        .accessibilityHint("Dials \(shortcut.code)")
        .accessibilityAddTraits(.isButton)
    }
}

/// What the editor works on: a new code (no id) or a copy of one to change.
struct ShortcutDraft: Identifiable {
    let id = UUID()
    var editing: USSDShortcut.ID?
    var name = ""
    var code = ""

    init() {}

    init(_ shortcut: USSDShortcut) {
        editing = shortcut.id
        name = shortcut.name
        code = shortcut.code
    }
}

/// Adds or edits a code, in Beam's sheet language: the title, a card with
/// the name and the code, a line on what a code looks like, and Add (or
/// Save) once both are right; Delete under it when editing.
private struct ShortcutEditor: View {
    @Environment(USSDShortcutList.self) private var shortcuts
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var code: String
    @State private var height: CGFloat = 420
    @FocusState private var focused: Field?

    private let editing: USSDShortcut.ID?

    private enum Field { case name, code }

    init(draft: ShortcutDraft) {
        editing = draft.editing
        _name = State(initialValue: draft.name)
        _code = State(initialValue: draft.code)
    }

    private var validCode: String? { USSDShortcut.code(from: code) }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && validCode != nil
    }
    /// Only once something is typed, and not while it could still become a
    /// code (no closing # yet).
    private var showsCodeHint: Bool {
        !code.isEmpty && validCode == nil && code.hasSuffix("#")
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(editing == nil ? "Add a Code" : "Edit Code")

            VStack(spacing: 14) {
                VStack(spacing: 0) {
                    field("Name", text: $name, prompt: "Pending approvals", field: .name)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.next)
                        .onSubmit { focused = .code }
                    SheetDivider()
                    field("Code", text: $code, prompt: "*182*7*1#", field: .code)
                        .keyboardType(.phonePad)
                }
                .padding(.horizontal, 16)
                .sheetCard()

                Text(showsCodeHint ? "A code starts with * or #, ends with #, and has only digits, * and # in between." : "Starts with * or # and ends with #, as you would dial it.")
                    .font(.sheetSubheadline)
                    .foregroundStyle(showsCodeHint ? Color.starhashDestructive : Color.sheetSecondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .animation(.smooth(duration: 0.2), value: showsCodeHint)

                VStack(spacing: 4) {
                    Button(editing == nil ? "Add" : "Save", action: save)
                        .buttonStyle(.sheetPrimary)
                        .disabled(!canSave)
                    if let editing {
                        SheetTextButton("Delete Code", role: .destructive) {
                            shortcuts.remove(editing)
                            dismiss()
                        }
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
        }
        .sheetHeight($height)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheetGlass(detents: [.height(height + 8)])
        .onAppear { focused = editing == nil ? .name : nil }
    }

    private func field(_ label: String, text: Binding<String>, prompt: String, field: Field) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.sheetBody)
                .foregroundStyle(Color.starhashPrimaryText)
                .frame(width: 56, alignment: .leading)
            TextField(label, text: text, prompt: Text(prompt).foregroundStyle(Color.sheetSecondaryText))
                .font(.sheetBody)
                .foregroundStyle(Color.starhashPrimaryText)
                .autocorrectionDisabled()
                .focused($focused, equals: field)
        }
        .frame(minHeight: 50)
    }

    private func save() {
        let saved = if let editing {
            shortcuts.update(editing, name: name, code: code)
        } else {
            shortcuts.add(name: name, code: code)
        }
        guard saved else { return }
        // Played here, as the sheet goes, which a view-bound haptic would
        // not outlive.
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
