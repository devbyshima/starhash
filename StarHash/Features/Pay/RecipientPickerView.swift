import StarHashKit
import SwiftUI
import UIKit

/// The screen Pay pushes: who gets the money. It opens searching, the
/// keyboard up on its numbers (most payments go to a merchant code typed on
/// the spot) with letters a key away for names: a close button and the
/// search field across the top. Closing the search gives the page its back
/// button, its title and a search button instead, the field sliding out to
/// the right as the title comes in.
///
/// Below, the number or code being typed, recent recipients and contacts,
/// each under an uppercase label that stays at the top while its rows
/// scroll (in the header bar, inside the system's soft edge blur), the rows flat on the page, with the letters a search
/// matched in the accent. The total floats in a glass bar at the
/// bottom, riding up with the keyboard. All in Beam's design language and
/// Liquid Glass, like the rest of the app: round glass buttons, a glass
/// search capsule, and rows fading softly under the header and the bar.
///
/// Picking a recipient pays at once: the system's own call prompt, showing
/// the full code, is the one approval before MoMo asks for the PIN.
struct RecipientPickerView: View {
    let amount: Int
    /// Where the phone is, with Nearby on: recipients paid around here go
    /// in a Nearby section at the top.
    var nearbyFix: LocationFix?
    /// Called with the chosen recipient. The caller records, goes back and
    /// dials.
    let onPay: (Recipient) -> Void

    @Environment(StarHashStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PreferenceKey.enableContacts) private var enableContacts = true
    @AppStorage(PreferenceKey.saveRecents) private var saveRecents = true
    @AppStorage(PreferenceKey.nearbyLocation) private var nearbyEnabled = false
    /// The fix the Nearby section is built from. Taken only until the
    /// list is first touched: a section appearing above rows a finger is
    /// already on would push the wrong one under it.
    @State private var shownNearbyFix: LocationFix?
    @State private var listTouched = false
    private var places: PlaceMemory { AppEnvironment.places }
    @AppStorage(PreferenceKey.wallet) private var wallet: Recipient.Network = .mtn

    @State private var query: String
    /// The search field in the header, rather than the title.
    @State private var isSearching = true
    @State private var choosingNumberFor: PayContact?
    /// The contact whose details sheet is open, from a long press.
    @State private var detailsFor: PayContact?
    @State private var contacts = PayContacts.shared
    /// Set on the first pick, so a double tap cannot dial twice.
    @State private var hasPaid = false
    /// The height of the bar's section label, which a section's own label
    /// takes over from as it reaches the bar.
    @State private var barLabelHeight: CGFloat = 0
    /// Where each later section's own label sits on screen, so the bar can
    /// tell which ones have scrolled up into it.
    @State private var labelTops: [String: CGFloat] = [:]

    /// How far the list has scrolled under the bar (capped at 24), so the
    /// bar's label stays on the first section while the list is at rest.
    @State private var scrolledUnder: CGFloat = 0
    /// Where the list is scrolled; set only by `-payScroll` (DEBUG).
    @State private var scrollPosition = ScrollPosition()
    @FocusState private var searchFocused: Bool

    init(amount: Int, query: String = "", nearbyFix: LocationFix? = nil, onPay: @escaping (Recipient) -> Void) {
        self.amount = amount
        self.nearbyFix = nearbyFix
        self.onPay = onPay
        _query = State(initialValue: query)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if !savedMatches.isEmpty {
                    savedSection
                } else if let typed = search.typedRecipient {
                    typedSection(typed)
                }
                if !nearby.isEmpty {
                    Section {
                        ForEach(nearby, id: \.self) { recipient in
                            RecipientRow(
                                tile: tile(for: recipient),
                                title: recipient.displayName,
                                subtitle: recipient.name == nil ? kindLabel(recipient) : recipient.formattedDestination,
                                matchColor: Color.pickerMatch
                            ) { choose(recipient) }
                        }
                    } header: {
                        sectionLabel("Nearby")
                    }
                }
                if !recents.isEmpty {
                    Section {
                        ForEach(recents, id: \.self) { recipient in
                            RecipientRow(
                                tile: tile(for: recipient),
                                title: recipient.displayName,
                                subtitle: recipient.name == nil ? kindLabel(recipient) : recipient.formattedDestination,
                                match: search.nameQuery,
                                matchColor: Color.pickerMatch,
                                onLongPress: contact(for: recipient).map { found in { showDetails(for: found) } }
                            ) { choose(recipient) }
                        }
                    } header: {
                        sectionLabel("Recent")
                    }
                }
                if enableContacts { contactsSection }
            }
            .padding(.bottom, 12)
            .starhashReadableWidth()
        }
        .scrollDismissesKeyboard(.immediately)
        // A finger scrolling the list is done typing: the keyboard goes,
        // and the search with it while nothing is typed, so the list has
        // the screen. A typed search stays, its matches to scroll through.
        .onChange(of: nearbyFix, initial: true) { _, fix in
            guard !listTouched, shownNearbyFix == nil else { return }
            withAnimation(.smooth(duration: 0.3)) { shownNearbyFix = fix }
        }
        // Nor after the first moments, when a finger may be on its way to
        // a row: a fix that slow is used for the payment, not the list.
        .task {
            try? await Task.sleep(for: .seconds(2))
            listTouched = true
        }
        .onScrollPhaseChange { _, phase in
            if phase == .interacting { listTouched = true }
            guard phase == .interacting, isSearching else { return }
            if query.isEmpty {
                closeSearch()
            } else {
                searchFocused = false
            }
        }
        .scrollPosition($scrollPosition)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            min(max(geometry.contentOffset.y + geometry.contentInsets.top, 0), 24)
        } action: { _, offset in
            scrolledUnder = offset
        }
        .onChange(of: query) { labelTops = [:] }
        // Soft Edge under the header and into the total.
        .starhashSoftEdge()
        // Centred in what is left between the header and the total (or the
        // keyboard), since it is laid out inside their insets.
        .overlay {
            if showsNoMatches {
                EmptyStateView(
                    doodle: .matches,
                    title: "No Matches",
                    message: "Type a phone number or a merchant code to pay it directly."
                )
                .padding(.horizontal, StarHashMetrics.screenPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
            }
        }
        .starhashSoftEdgeHeader {
            VStack(spacing: 0) {
                header
                barLabel
            }
        }
        // Above the keyboard while it is up, above the home indicator after.
        .starhashBottomBar { totalBar }
        .background(Color.starhashBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .background(SwipeBackEnabler())
        .onAppear {
            // Up with the keyboard as the screen slides in.
            if isSearching { searchFocused = true }
        }
        .task(id: enableContacts) {
            if enableContacts { await contacts.load() }
        }
        #if DEBUG
        // -payChooser: the number chooser for the first contact with several.
        .onChange(of: contacts.contacts) { _, all in
            guard DebugLaunch.arguments.contains("-payChooser"), choosingNumberFor == nil else { return }
            if let contact = all.first(where: { $0.recipients.count > 1 && $0.name == "Pa" }) ?? all.first(where: { $0.recipients.count > 1 }) {
                showChooser(for: contact)
            }
        }
        // -payScroll <points>: the list scrolled, a label pinned.
        .task {
            guard let points = DebugLaunch.value(after: "-payScroll").flatMap(Double.init) else { return }
            try? await Task.sleep(for: .milliseconds(1200))
            // Animated, as a finger scrolls, so every label passes by.
            withAnimation(.easeInOut(duration: 1)) { scrollPosition.scrollTo(y: points) }
        }
        // -payToggleSearch: closes the search, then opens it again, to watch
        // the header's transitions.
        .task {
            guard DebugLaunch.arguments.contains("-payToggleSearch") else { return }
            try? await Task.sleep(for: .seconds(2))
            closeSearch()
            try? await Task.sleep(for: .seconds(1.5))
            openSearch()
        }
        // -payDetails <name>: the details sheet of the first contact whose
        // name contains it.
        .onChange(of: contacts.contacts) { _, all in
            guard let name = DebugLaunch.value(after: "-payDetails"), detailsFor == nil,
                  let contact = all.first(where: { $0.name.localizedStandardContains(name) }) else { return }
            showDetails(for: contact)
        }
        // -payPick <seconds>: the first recent recipient chosen after this
        // long, to record the way back to the keypad.
        .task {
            guard let seconds = PayDebug.picksAfter else { return }
            try? await Task.sleep(for: .seconds(seconds))
            if let recipient = recents.first { choose(recipient) }
        }
        // -payBrowse: the header with the title, the search closed.
        .onAppear {
            guard DebugLaunch.arguments.contains("-payBrowse") else { return }
            isSearching = false
            searchFocused = false
        }
        #endif
        .sheet(item: $detailsFor) { contact in
            ContactDetailSheet(contact: contact, amount: amount) { recipient in
                detailsFor = nil
                choose(recipient)
            }
        }
        .sheet(item: $choosingNumberFor) { contact in
            ChooseNumberSheet(contact: contact) { recipient in
                choosingNumberFor = nil
                choose(recipient)
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: hasPaid)
    }

    // MARK: Header

    /// Searching: the close button and the field. Not: the back button,
    /// the title centred on the screen and a search button. The field
    /// comes in from the right as the title goes out to the left, and the
    /// leading button's glyph turns between close and back.
    private var header: some View {
        ZStack {
            if !isSearching {
                Text("Select a recipient")
                    .font(PickerType.title)
                    .foregroundStyle(Color.starhashPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 56)
                    .accessibilityAddTraits(.isHeader)
                    .transition(.offset(x: -36).combined(with: .opacity))
            }
            // One glass container, so the buttons and the search capsule
            // melt into one another as the search opens and closes.
            StarHashGlassContainer(spacing: 10) {
                HStack(spacing: 10) {
                    SwapGlassButton(
                        symbol: isSearching ? "xmark" : "chevron.left",
                        label: isSearching ? "Close search" : "Back"
                    ) {
                        if isSearching { closeSearch() } else { dismiss() }
                    }
                    if isSearching {
                        searchField
                            .transition(.offset(x: 80).combined(with: .opacity))
                    } else {
                        Spacer(minLength: 0)
                        SwapGlassButton(symbol: "magnifyingglass", label: "Search") { openSearch() }
                            .transition(.opacity)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .starhashReadableWidth()
        .animation(.smooth(duration: 0.32), value: isSearching)
    }

    /// Beam's search bar: a glass capsule with the magnifier, the field and
    /// a clear button.
    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.title3)
                .foregroundStyle(Color.sheetSecondaryText)
                .accessibilityHidden(true)
            TextField("Search", text: $query, prompt: Text("Type anything, we'll find it").foregroundStyle(Color.sheetSecondaryText))
                .accessibilityLabel("Search name, number or merchant code")
                .focused($searchFocused)
                // Numbers first, letters on the keyboard's own ABC key:
                // one keyboard for codes, numbers and names.
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    if let typed = typedRecipient { choose(typed) }
                }
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.sheetSecondaryText)
                        .frame(width: 28, height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.hapticPlain)
                .accessibilityLabel("Clear search")
            }
        }
        .font(PickerType.search)
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .frame(maxWidth: .infinity, minHeight: 44)
        // Clear, as the header's round buttons.
        .starhashGlass(interactive: true, tint: .clear)
    }

    private func openSearch() {
        isSearching = true
        searchFocused = true
    }

    /// Closes the search: the query goes, and the keyboard with it.
    private func closeSearch() {
        query = ""
        searchFocused = false
        isSearching = false
    }

    // MARK: Section labels

    /// The sections showing, top to bottom, by their labels: the bar
    /// carries the first one's, and each later one takes over the bar as its
    /// own label scrolls up into it, so the label of the section under the
    /// bar is always the one showing, as a pinned header would be.
    private var sectionTitles: [String] {
        var titles: [String] = []
        if !savedMatches.isEmpty {
            titles.append("Saved")
        } else if let typed = search.typedRecipient {
            titles.append(typed.kind == .phone ? "Number" : "Merchant code")
        }
        if !nearby.isEmpty { titles.append("Nearby") }
        if !recents.isEmpty { titles.append("Recent") }
        if enableContacts {
            switch contacts.access {
            case .denied:
                titles.append("Contacts")
            case .notDetermined:
                if !contacts.hasLoaded { titles.append("Contacts") }
            case .authorized, .limited:
                if !contacts.hasLoaded || !matchingContacts.isEmpty || contacts.access == .limited {
                    titles.append("Contacts")
                }
            }
        }
        return titles
    }

    /// The label the bar shows: the last section whose own label has reached
    /// it, or the first section's.
    private var currentSection: String? {
        let titles = sectionTitles
        // At rest nothing has scrolled up into the bar. Not "more than zero":
        // a list at rest reads a hair off it (4e-14).
        guard scrolledUnder > 0.5 else { return titles.first }
        // A label's position is measured from the top of the list, just
        // under the bar, so it has reached the bar's own label once it is
        // that label's height above that line.
        return titles.last(where: { (labelTops[$0] ?? .infinity) <= -barLabelHeight + 1 }) ?? titles.first
    }

    /// The section label in the header bar, under the buttons, inside the
    /// soft edge so rows passing beneath it blur away.
    private var barLabel: some View {
        ZStack(alignment: .leading) {
            // Holds the height when there is no section to name.
            PickerBand(title: " ").hidden()
            if let currentSection {
                PickerBand(title: currentSection)
                    .id(currentSection)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
        }
        .clipped()
        .animation(.snappy(duration: 0.2), value: currentSection)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { barLabelHeight = $0 }
    }

    /// A section's own label in the list. The first section's lives in the
    /// bar instead; each later one scrolls up until it meets the bar's, and
    /// the bar takes it over from there.
    @ViewBuilder
    private func sectionLabel(_ title: String) -> some View {
        if title != sectionTitles.first {
            PickerBand(title: title)
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .scrollView).minY } action: { top in
                    labelTops[title] = top
                }
        }
    }

    // MARK: Picking

    private var search: RecipientSearch { RecipientSearch(query: query) }

    /// Recent recipients matching the search, less the one already at the
    /// top as an exact match. While searching, a recent number that belongs
    /// to a contact with several numbers is left to the contact's row, which
    /// offers all of them, so the person shows once.
    private var recents: [Recipient] {
        let found = matchingRecents
        guard !search.isEmpty else { return found }
        let multiNumber = matchingContactsUnfiltered.filter { $0.recipients.count > 1 }
        return found.filter { recent in
            !multiNumber.contains { contact in contact.recipients.contains { Self.same($0, recent) } }
        }
    }

    /// Contacts matching the search, less any already at the top. While
    /// searching, a contact with one number that Recent already shows is
    /// left out, so the same person or till is not listed twice.
    private var matchingContacts: [PayContact] {
        let found = matchingContactsUnfiltered
        guard !search.isEmpty else { return found }
        let shown = matchingRecents
        return found.filter { contact in
            !(contact.recipients.count == 1 && shown.contains { Self.same($0, contact.recipients[0]) })
        }
    }

    private var matchingRecents: [Recipient] {
        guard saveRecents else { return [] }
        let suggested = nearby
        return store.recentRecipients().filter { recent in
            search.matches(recent) && !isTyped(recent) && !suggested.contains { Self.same($0, recent) }
        }
    }

    /// Numbers and codes paid where the phone is now, nearest first, from
    /// the places StarHash remembered on this iPhone. Only before anything
    /// is typed: a search is looking for someone in particular.
    private var nearby: [Recipient] {
        guard nearbyEnabled, search.isEmpty, let fix = shownNearbyFix else { return [] }
        return places.suggestions(latitude: fix.latitude, longitude: fix.longitude, accuracy: fix.accuracy).map(\.recipient)
    }

    private var matchingContactsUnfiltered: [PayContact] {
        guard enableContacts else { return [] }
        return contacts.contacts.filter { search.matches($0) && !$0.recipients.contains(where: isTyped) }
    }

    /// The same number or code, whatever name each side has saved it under.
    private static func same(_ a: Recipient, _ b: Recipient) -> Bool {
        a.kind == b.kind && a.destination == b.destination
    }

    /// Saved recipients (contacts, and past recipients with a name) whose
    /// number or code is exactly the one typed. They take the top of the
    /// list in place of the bare number, so a saved till or friend is paid
    /// by name. One row per name.
    private var savedMatches: [Recipient] {
        guard search.typedRecipient != nil else { return [] }
        let past = saveRecents ? store.recentRecipients(limit: 50).filter { $0.name != nil } : []
        let saved = enableContacts ? contacts.contacts.flatMap(\.recipients) : []
        var names = Set<String>()
        return (saved + past).filter { isTyped($0) && names.insert(($0.name ?? "").lowercased()).inserted }
    }

    /// Whether `recipient` is the number or code in the search field.
    private func isTyped(_ recipient: Recipient) -> Bool {
        guard let typed = search.typedRecipient else { return false }
        return recipient.kind == typed.kind && recipient.destination == typed.destination
    }

    private var showsNoMatches: Bool {
        !search.isEmpty && search.typedRecipient == nil && recents.isEmpty && matchingContacts.isEmpty
            && contacts.access != .denied
    }

    /// What the keyboard's Search key pays: the saved recipient the typed
    /// number or code belongs to, or the number or code itself.
    private var typedRecipient: Recipient? {
        savedMatches.first ?? search.typedRecipient
    }

    // MARK: Sections

    /// The number or code being typed, when nothing saved has it: paid as
    /// typed.
    private func typedSection(_ typed: Recipient) -> some View {
        Section {
            RecipientRow(
                tile: .symbol(typed.kind == .phone ? "phone" : "storefront"),
                title: typed.formattedDestination,
                subtitle: kindLabel(typed),
                matchColor: Color.pickerMatch
            ) { choose(typed) }
        } header: {
            sectionLabel(typed.kind == .phone ? "Number" : "Merchant code")
        }
    }

    /// The saved recipients the typed number or code belongs to, by name.
    /// A contact with several numbers is paid on the one typed, with no
    /// need to choose.
    private var savedSection: some View {
        Section {
            ForEach(savedMatches, id: \.self) { recipient in
                RecipientRow(
                    tile: tile(for: recipient),
                    title: recipient.displayName,
                    subtitle: recipient.formattedDestination + " \u{00B7} " + kindLabel(recipient),
                    matchColor: Color.pickerMatch,
                    onLongPress: contact(for: recipient).map { found in { showDetails(for: found) } }
                ) { choose(recipient) }
            }
        } header: {
            sectionLabel("Saved")
        }
    }

    @ViewBuilder
    private var contactsSection: some View {
        switch contacts.access {
        case .denied:
            Section {
                ContactsAccessCard(
                    message: "Allow StarHash to see your contacts to pay them by name. They stay on your iPhone."
                )
                .padding(.horizontal, 10)
            } header: {
                sectionLabel("Contacts")
            }
        case .notDetermined:
            if !contacts.hasLoaded { loadingSection }
        case .authorized, .limited:
            if !contacts.hasLoaded {
                loadingSection
            } else if !matchingContacts.isEmpty || contacts.access == .limited {
                Section {
                    ForEach(matchingContacts) { contact in
                        RecipientRow(
                            tile: contact.hasPhoto
                                ? .photo(contactID: contact.id, fallback: .monogram(contact.initials))
                                : .monogram(contact.initials),
                            title: contact.name,
                            subtitle: contactSubtitle(contact),
                            match: search.nameQuery,
                            matchColor: Color.pickerMatch,
                            onLongPress: { showDetails(for: contact) }
                        ) { pick(contact) }
                    }
                    if contacts.access == .limited && search.isEmpty {
                        ContactsAccessCard(
                            message: "StarHash sees only the contacts you chose. You can share more in Settings."
                        )
                        .padding(.horizontal, 10)
                    }
                } header: {
                    sectionLabel("Contacts")
                }
            }
        }
    }

    /// Placeholder rows, pulsing, while the contacts are read.
    private var loadingSection: some View {
        Section {
            ForEach(0..<4, id: \.self) { _ in PickerSkeletonRow() }
        } header: {
            sectionLabel("Contacts")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading contacts")
    }

    /// The amount being paid, in a glass bar floating at the bottom,
    /// riding up with the keyboard. Paying is a tap on the number, code or
    /// person above, so the bar only states the total, large: what the
    /// iPhone's call prompt will ask to approve.
    private var totalBar: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("Total:")
                .font(PickerType.totalLabel)
                .foregroundStyle(Color.starhashPrimaryText)
                .lineLimit(1)
                // A long amount shrinks before the label does.
                .layoutPriority(1)
            Spacer(minLength: 8)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(Money.format(amount))
                    .font(PickerType.totalAmount)
                    .foregroundStyle(Color.starhashPrimaryText)
                    .monospacedDigit()
                Text(Money.currency)
                    .font(PickerType.totalCurrency)
                    .foregroundStyle(Color.sheetSecondaryText)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .frame(minHeight: 72)
        // The sheets' colours: solid white in light mode, their near-black
        // glass in dark.
        .starhashTotalCard(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .starhashReadableWidth()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Total \(Money.formatWithCurrency(amount))")
    }

    // MARK: Building blocks

    /// "0788 123 456", "Merchant code 020205", or "3 phone numbers".
    private func contactSubtitle(_ contact: PayContact) -> String {
        guard contact.recipients.count == 1 else { return "\(contact.recipients.count) phone numbers" }
        let only = contact.recipients[0]
        return only.kind == .merchant ? "Merchant code \(only.destination)" : only.formattedDestination
    }

    /// A storefront for merchants, initials for named people, a phone for
    /// bare numbers; the contact's photo over any of them when the number
    /// or code is saved in Contacts with one.
    private func tile(for recipient: Recipient) -> RecipientRow.Tile {
        .for(recipient, photoContactID: enableContacts ? contacts.photoContactID(for: recipient) : nil)
    }

    /// "MTN number", "Airtel number" or "Merchant code": which code and
    /// fee the payment gets.
    private func kindLabel(_ recipient: Recipient) -> String {
        guard let network = recipient.network else { return "Merchant code" }
        return "\(network.name) number"
    }

    private func pick(_ contact: PayContact) {
        if contact.recipients.count == 1 {
            choose(contact.recipients[0])
        } else {
            showChooser(for: contact)
        }
    }

    /// The keyboard would cover the sheet, so it goes down first and the
    /// sheet comes up once it has.
    private func showChooser(for contact: PayContact) {
        searchFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            choosingNumberFor = contact
        }
    }

    /// Like the number chooser, the details sheet waits for the keyboard
    /// to go down first.
    private func showDetails(for contact: PayContact) {
        searchFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            detailsFor = contact
        }
    }

    /// The saved contact a recent or saved recipient's number belongs to,
    /// so a long press on it opens that contact. Nil for a number or till
    /// that is not in Contacts.
    private func contact(for recipient: Recipient) -> PayContact? {
        guard enableContacts else { return nil }
        return contacts.contacts.first { $0.recipients.contains { Self.same($0, recipient) } }
    }

    private func choose(_ recipient: Recipient) {
        guard !hasPaid, recipient.isPayable else { return }
        hasPaid = true
        searchFocused = false
        onPay(recipient)
    }
}

// MARK: - Pieces

/// A section's label (Recent, Contacts and the others): uppercase, tracked
/// and grey, with nothing behind it.
private struct PickerBand: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(PickerType.section)
            .tracking(1)
            .foregroundStyle(Color.sheetSecondaryText)
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The recipient page's type, one scale for the whole page: the title as
/// every page sets it, a 17pt search and row names, 14pt detail under
/// them, the section labels, and the total with "Total:" as large as the
/// amount in the weight of its "RWF".
private enum PickerType {
    static var title: Font { .starhashPageTitle }
    static var search: Font { .sheet(17, relativeTo: .body) }
    static var section: Font { .sheet(15, .bold, relativeTo: .subheadline) }
    static var rowName: Font { .sheet(17, .semibold, relativeTo: .body) }
    static var rowDetail: Font { .sheet(14, relativeTo: .subheadline) }
    /// The amount's size in the currency's weight, so the label reads with
    /// "RWF" and the number leads.
    static var totalLabel: Font { .sheet(34, totalCurrencyWeight, relativeTo: .title) }
    static var totalAmount: Font { .sheet(34, .bold, relativeTo: .title) }
    static var totalCurrency: Font { .sheet(20, totalCurrencyWeight, relativeTo: .title3) }
    private static let totalCurrencyWeight: Font.Weight = .semibold
}

/// A row's shape while the contacts load, pulsing softly.
private struct PickerSkeletonRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dims = false

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.starhashPrimaryText.opacity(0.1))
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 7) {
                Capsule().fill(Color.starhashPrimaryText.opacity(0.1)).frame(width: 140, height: 12)
                Capsule().fill(Color.starhashPrimaryText.opacity(0.07)).frame(width: 90, height: 10)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 8)
        .opacity(dims ? 0.45 : 1)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { dims = true }
        }
    }
}

/// One tappable recipient, flat on the page: a square avatar, the name with
/// what the search matched in the accent, and a grey line under
/// it.
struct RecipientRow: View {
    indirect enum Tile {
        case monogram(String)
        case symbol(String)
        /// A contact's photo, showing `fallback` until it loads.
        case photo(contactID: String, fallback: Tile)

        /// A storefront for merchants, initials for named people, a phone
        /// for bare numbers; the photo of `photoContactID` over any of them.
        static func `for`(_ recipient: Recipient, photoContactID: String?) -> Tile {
            let plain: Tile = if recipient.kind == .merchant {
                .symbol("storefront")
            } else if let name = recipient.name {
                .monogram(PayContact.initials(for: name))
            } else {
                .symbol("phone")
            }
            guard let photoContactID else { return plain }
            return .photo(contactID: photoContactID, fallback: plain)
        }
    }

    let tile: Tile
    let title: String
    let subtitle: String
    /// Letters to mark in the title: what the search typed.
    var match: String = ""
    var matchColor: Color = .starhashPrimaryText
    /// A long press, for a row that is a saved contact: their details.
    var onLongPress: (() -> Void)?
    let action: () -> Void

    /// Set when a press is held, so the tap the button may still see when
    /// the finger lifts, however long it is held, does not pay. Only a quick
    /// tap pays. Cleared a moment after the hold ends, lifted or cancelled
    /// (the sheet it opens cancels it), once any tap from it has come.
    @State private var longPressed = false
    @State private var longPresses = 0

    /// The title with the first stretch the search matched coloured, the
    /// way the search matches: ignoring case and accents.
    private var styledTitle: AttributedString {
        var text = AttributedString(title)
        if !match.isEmpty, let range = text.range(of: match, options: [.caseInsensitive, .diacriticInsensitive]) {
            text[range].foregroundColor = matchColor
            text[range].backgroundColor = .pickerMatchBackground
        }
        return text
    }

    var body: some View {
        Button {
            // A tap only when this press was not a long one.
            if !longPressed { action() }
            longPressed = false
        } label: {
            HStack(spacing: 12) {
                RecipientTile(tile: tile, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(styledTitle)
                        .font(PickerType.rowName)
                        .foregroundStyle(Color.starhashPrimaryText)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(PickerType.rowDetail)
                        .foregroundStyle(Color.sheetSecondaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
            }
            // Flat on the page, in line with the section labels.
            .padding(.horizontal, 22)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            // On the label, inside the button: a gesture on the button
            // itself would rank below its tap and never be heard.
            .gesture(
                RowLongPress {
                    // A hold never pays, on any row: one with details opens
                    // them, one without does nothing when the finger lifts.
                    longPressed = true
                    guard let onLongPress else { return }
                    longPresses += 1
                    onLongPress()
                } onFinished: {
                    Task {
                        try? await Task.sleep(for: .milliseconds(150))
                        longPressed = false
                    }
                }
            )
        }
        // Silent on touch-down: a tap pays (which plays its own) and a long
        // press plays the one below.
        .buttonStyle(HighlightRowButtonStyle(pressHaptic: false))
        .sensoryFeedback(.impact(weight: .medium), trigger: longPresses)
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Show contact details") { onLongPress?() }
    }
}

/// A row's long press, as UIKit has it: 10pt of movement fails it, and it
/// gives way to a scroll that starts on the row, as a table row's does.
/// SwiftUI's own long press, added beside a button's tap, kept hold of the
/// drag, so the list would not scroll from a row, worst of all with the
/// keyboard up.
private struct RowLongPress: UIGestureRecognizerRepresentable {
    let onBegan: () -> Void
    let onFinished: () -> Void

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = 0.45
        recognizer.allowableMovement = 10
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        switch recognizer.state {
        case .began: onBegan()
        case .ended, .cancelled, .failed: onFinished()
        default: break
        }
    }
}

/// A recipient's initials, or a symbol for numbers and merchants, on
/// Beam's soft square chip.
struct RecipientTile: View {
    let tile: RecipientRow.Tile
    var size: CGFloat = 40
    /// The tile's fill, when the surface asks for its own (a sheet).
    var fill: Color?

    @Environment(\.starhashOnPay) private var onPay

    var body: some View {
        if case .photo(let contactID, let fallback) = tile {
            ContactPhotoTile(contactID: contactID, size: size) {
                RecipientTile(tile: fallback, size: size, fill: fill)
            }
            .accessibilityHidden(true)
        } else {
            plainTile
        }
    }

    private var plainTile: some View {
        Group {
            switch tile {
            case .monogram(let initials):
                Text(initials)
                    .font(.starhashFixed(size * 0.36, weight: .semibold))
                    .foregroundStyle(onPay ? Color.payPrimaryText : Color.starhashPrimaryText)
            case .symbol(let symbol):
                Image(systemName: symbol)
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(onPay ? Color.paySecondaryText : Color.sheetSecondaryText)
            case .photo:
                EmptyView()
            }
        }
        .frame(width: size, height: size)
        .background(fill ?? (onPay ? Color.payWash : Color.starhashPrimaryText.opacity(0.1)), in: RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// Shown in place of contacts when access is off or limited: why, and a
/// way to the app's page in Settings, the only place it can be changed.
private struct ContactsAccessCard: View {
    let message: String

    var body: some View {
        StarHashCard(fill: .starhashCard) {
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text(message)
                        .font(.starhash(.subheadline))
                        .foregroundStyle(Color.starhashSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .foregroundStyle(Color.starhashPrimaryText)
                }
                Button("Open Settings") { USSDDialer.openSettings() }
                    .buttonStyle(.starhashCapsule(height: 36, horizontalPadding: 16))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
