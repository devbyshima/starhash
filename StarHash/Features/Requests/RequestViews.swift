import StarHashKit
import SwiftUI

/// Request on Pay: the amount typed, then who to ask, with a note if the
/// owner wants one: Hold Near first (with Tap to Request on, on an iPhone
/// that can measure), then people nearby, then (with requests anywhere on)
/// contacts and typed numbers, each checked with the directory as it is
/// tapped, never the whole list. A tap sends it; someone not on StarHash
/// gets Share Message instead. Request in Bulk (with its flag on) asks
/// several people at once, each for their own amount, on a sheet of its
/// own.
struct RequestSheet: View {
    let amount: Int
    /// Hold Near chosen, with the note typed: Pay opens its sheet.
    var onHoldNear: (String?) -> Void = { _ in }
    /// Request in Bulk chosen, with the note typed: Pay opens its sheet.
    var onBulk: (String?) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @Environment(PeopleNearbyService.self) private var nearby
    @Environment(Owner.self) private var owner
    @FeatureFlagged(.requestsAnywhere) private var anywhereOn
    @FeatureFlagged(.tapToRequest) private var tapOn
    @FeatureFlagged(.bulkRequests) private var bulkOn
    @AppStorage(Preferences.showMyName) private var showMyName: Bool
    @State private var note = ""
    @State private var unreachable: PeopleNearby.Person?
    @State private var sentCount = 0
    @FocusState private var noteFocused: Bool

    var body: some View {
        // The title collapses to the top as the list scrolls
        // (`CollapsingSheetScroll`).
        CollapsingSheetScroll(
            title: String(starhash: "Request \(Money.format(amount))"),
            smallCaption: "Request",
            smallTitle: Money.formatWithCurrency(amount)
        ) {
                VStack(alignment: .leading, spacing: 18) {
                    TextField(text: $note, prompt: Text("What for? (optional)")) { Text("Note") }
                        .font(.sheetBody)
                        .focused($noteFocused)
                        .submitLabel(.done)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 52)
                        .sheetCard()
                        .onChange(of: note) { _, typed in
                            if typed.count > MoneyRequest.maximumNoteLength { note = String(typed.prefix(MoneyRequest.maximumNoteLength)) }
                        }

                    if let missing = NearbyRequests.missing(in: owner) {
                        RequestNotice(text: missing)
                    } else {
                        let holdsNear = tapOn && TapToRequestService.isSupported
                        if holdsNear || bulkOn {
                            // The ways to ask that open a sheet of their
                            // own, on one card.
                            VStack(spacing: 0) {
                                if holdsNear { holdNearRow }
                                if holdsNear && bulkOn { SheetDivider().padding(.leading, 70) }
                                if bulkOn { bulkRow }
                            }
                            .sheetCard()
                        }
                        // With requests anywhere, an empty nearby says
                        // nothing: the contacts below are the way.
                        if !anywhere || !nearby.found.people.isEmpty {
                            SheetSectionLabel("People Nearby")
                            people
                        }
                        if anywhere {
                            RequestAnywhereSection(amount: amount, note: note, showMyName: showMyName) { sent in
                                asked(sent.person.shownName)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
        }
        .scrollDismissesKeyboard(.immediately)
        .sheetGlass(detents: [.medium, .large])
        .unreachableAlert($unreachable)
        .sensoryFeedback(.success, trigger: sentCount)
    }

    /// Hold Near: the request held out for the next iPhone held to this
    /// one, on a sheet of its own.
    private var holdNearRow: some View {
        optionRow(
            symbol: "antenna.radiowaves.left.and.right", title: "Hold Near Their iPhone",
            hint: "Shows the request for someone to hold their iPhone to", action: onHoldNear
        )
    }

    /// Request in Bulk: several people, each asked for their own amount,
    /// on a sheet of its own.
    private var bulkRow: some View {
        optionRow(
            symbol: "person.2.fill", title: "Request in Bulk",
            hint: "Asks several people at once, each for their own amount", action: onBulk
        )
    }

    /// A way to ask that opens a sheet of its own, handed the note typed.
    private func optionRow(
        symbol: String, title: LocalizedStringKey, hint: LocalizedStringKey, action: @escaping (String?) -> Void
    ) -> some View {
        Button {
            noteFocused = false
            let typed = note.trimmingCharacters(in: .whitespacesAndNewlines)
            action(typed.isEmpty ? nil : typed)
        } label: {
            HStack(spacing: 12) {
                SheetIconCircle(symbol: symbol)
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(PickerType.rowName)
                        .foregroundStyle(Color.starhashPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 8)
                Image(symbol: "chevron.right")
                    .font(.starhash(.footnote, weight: .semibold))
                    .foregroundStyle(Color.sheetSecondaryText)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.hapticPlain)
        .accessibilityHint(Text(hint))
    }

    /// Requests through the server: both flags, as the Request button
    /// already needs People Nearby's.
    private var anywhere: Bool { anywhereOn && FeatureFlags.isOn(.peopleNearby) }

    @ViewBuilder
    private var people: some View {
        if nearby.found.people.isEmpty {
            RequestNotice(text: String(starhash: "No one nearby has StarHash open"))
        } else {
            VStack(spacing: 0) {
                ForEach(Array(nearby.found.people.enumerated()), id: \.element.id) { index, person in
                    if index > 0 { SheetDivider().padding(.leading, 70) }
                    Button { ask(person) } label: {
                        HStack(spacing: 12) {
                            PeopleNearbyTile(person: person, size: 44)
                            Text(verbatim: person.name)
                                .font(PickerType.rowName)
                                .foregroundStyle(Color.starhashPrimaryText)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            if nearby.reaching == person.id { ProgressView() }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.hapticPlain)
                    .disabled(nearby.reaching != nil)
                    .accessibilityLabel(Text("Request \(Money.format(amount)) from \(person.name)"))
                }
            }
            .sheetCard()
        }
    }

    private func ask(_ person: PeopleNearby.Person) {
        noteFocused = false
        Task {
            let photo = ProfilePhoto.shared.image != nil ? AppEnvironment.serverSync.sharedPhotoID : nil
            if await AppEnvironment.nearbyRequests.ask(person, amount: amount, note: note, owner: owner, photoID: photo) != nil {
                asked(person.firstName)
            } else {
                unreachable = person
            }
        }
    }

    private func asked(_ name: String) {
        sentCount += 1
        AccessibilityNotification.Announcement(String(starhash: "Asked \(name) for \(Money.format(amount))")).post()
        dismiss()
    }
}

/// A line on a card where a list would be: why there is nothing to tap.
struct RequestNotice: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(.sheetBody)
            .foregroundStyle(Color.sheetSecondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .sheetCard()
    }
}

/// Request's way to anyone on StarHash: a search over the owner's contacts
/// and a number typed. As it opens, the contacts' numbers are checked with
/// the directory in one go (`StarHashCloud.listed(among:)`), so the ones on
/// StarHash come first, under the search, and everyone else below them
/// with Invite, which shares StarHash's App Store page. A tap looks the
/// number up again and asks: listed with a key, through the server;
/// anyone else gets Share Message, the owner's number, the amount and the
/// note through the share sheet. If the check cannot be made, the
/// contacts are one list, as before.
private struct RequestAnywhereSection: View {
    let amount: Int
    let note: String
    let showMyName: Bool
    let onSent: (MoneyRequest) -> Void

    @Environment(Owner.self) private var owner
    @AppStorage(Preferences.enableContacts) private var enableContacts: Bool
    @State private var contacts = PayContacts.shared
    @State private var query = ""
    /// The number being looked up and asked, while it is.
    @State private var checking: String?
    /// What came of the last tap, when it was not sent.
    @State private var outcome: Outcome?
    /// The contacts' and typed numbers the directory lists, once checked;
    /// nil until then, or when the server could not be reached.
    @State private var onStarHash: Set<String>?
    /// The numbers the directory has answered for.
    @State private var checked: Set<String> = []
    @FocusState private var searchFocused: Bool

    /// Why the last one tapped was not asked.
    struct Outcome: Equatable {
        let failure: RequestsAnywhere.AskFailure
        let name: String
    }

    /// At most this many contacts at once: a search narrows them.
    private static let shownLimit = 60

    var body: some View {
        if !showMyName {
            SheetSectionLabel("Anyone on StarHash")
            RequestNotice(text: String(starhash: "Turn on Show My Name in Settings to ask people who aren't nearby"))
        } else {
            SheetSectionLabel("Anyone on StarHash")
            searchField
            if let outcome { outcomeCard(outcome) }
            let rows = rows
            if let onStarHash {
                let on = rows.filter { onStarHash.contains($0.recipient.destination) }
                let off = rows.filter { !onStarHash.contains($0.recipient.destination) }
                if !on.isEmpty { rowsCard(on, invites: false) }
                if !off.isEmpty {
                    SheetSectionLabel("Invite to StarHash")
                    rowsCard(Array(off.prefix(Self.shownLimit)), invites: true)
                }
            } else if !rows.isEmpty {
                rowsCard(Array(rows.prefix(Self.shownLimit)), invites: false)
            }
            if rows.isEmpty && !query.isEmpty {
                RequestNotice(text: String(starhash: "Type a full number to ask someone not in your contacts"))
            }
        }
    }

    /// One card of rows, each with Invite beside it when `invites`.
    private func rowsCard(_ rows: [RequestContactRow], invites: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 { SheetDivider().padding(.leading, 70) }
                HStack(spacing: 0) {
                    rowButton(row)
                    if invites {
                        ShareLink(item: inviteText) {
                            Text("Invite")
                        }
                        .buttonStyle(.starhashCapsule(height: 32, horizontalPadding: 14))
                        .padding(.trailing, 14)
                        .accessibilityLabel(Text("Invite \(row.name ?? row.recipient.formattedDestination) to StarHash"))
                    }
                }
            }
        }
        .sheetCard()
        .animation(.smooth(duration: 0.3), value: onStarHash)
    }

    /// What Invite hands the share sheet: why StarHash, and its App Store
    /// page once it is published (`DeveloperNoteLinks.appStoreID`).
    private var inviteText: String {
        if let link = DeveloperNoteLinks.appStore {
            String(starhash: "I pay with MoMo and Airtel Money on StarHash, and you can ask me for money there too. Get it on the App Store: \(link.absoluteString)")
        } else {
            String(starhash: "I pay with MoMo and Airtel Money on StarHash, and you can ask me for money there too. Look for StarHash on the App Store.")
        }
    }

    private var numbersToCheck: [String] {
        RequestContacts.numbers(query: query, contacts: contacts, enableContacts: enableContacts)
    }

    /// Checks the numbers not yet answered for: all of them as the sheet
    /// opens and the contacts load, then a number as it is typed in full.
    private func checkDirectory() async {
        let fresh = Array(Set(numbersToCheck).subtracting(checked))
        guard !fresh.isEmpty, let listed = await StarHashCloud.listed(among: fresh) else { return }
        checked.formUnion(fresh)
        withAnimation(.smooth(duration: 0.3)) {
            onStarHash = (onStarHash ?? []).union(listed)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(symbol: "magnifyingglass")
                .foregroundStyle(Color.sheetSecondaryText)
                .accessibilityHidden(true)
            TextField(text: $query, prompt: Text("Name or number")) { Text("Search contacts or type a number") }
                .font(.sheetBody)
                .focused($searchFocused)
                .keyboardType(.namePhonePad)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.search)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .sheetCard()
        .task(id: enableContacts) {
            if enableContacts { await contacts.loadIfAllowed() }
        }
        // The contacts coming in, or a number typed in full.
        .task(id: numbersToCheck.count) { await checkDirectory() }
        .onChange(of: query) { outcome = nil }
    }

    private var rows: [RequestContactRow] {
        RequestContacts.rows(query: query, owner: owner, contacts: contacts, enableContacts: enableContacts)
    }

    private func rowButton(_ row: RequestContactRow) -> some View {
        Button { ask(row) } label: {
            HStack(spacing: 12) {
                RecipientTile(tile: row.tile, size: 44, fill: .sheetChip)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: row.name ?? row.recipient.formattedDestination)
                        .font(PickerType.rowName)
                        .foregroundStyle(Color.starhashPrimaryText)
                        .lineLimit(1)
                    if row.name != nil {
                        Text(verbatim: row.recipient.formattedDestination)
                            .font(PickerType.rowDetail)
                            .foregroundStyle(Color.sheetSecondaryText)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                if checking == row.recipient.destination { ProgressView() }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.hapticPlain)
        .disabled(checking != nil)
        .accessibilityLabel(Text("Request \(Money.format(amount)) from \(row.name ?? row.recipient.formattedDestination)"))
    }

    /// Why it was not sent, with Share Message for someone StarHash cannot
    /// ask.
    private func outcomeCard(_ outcome: Outcome) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(verbatim: outcome.failure.message(name: outcome.name))
                .font(.sheetBody)
                .foregroundStyle(Color.starhashPrimaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            if outcome.failure.offersShareMessage {
                ShareLink(item: RequestContacts.shareText(amount: amount, note: note, owner: owner)) {
                    Text("Share Message")
                }
                .buttonStyle(.sheetFilled)
            }
        }
        .padding(16)
        .sheetCard()
        .transition(.opacity)
    }

    private func ask(_ row: RequestContactRow) {
        guard checking == nil else { return }
        searchFocused = false
        checking = row.recipient.destination
        Task {
            defer { checking = nil }
            let person = Recipient(name: row.name, destination: row.recipient.destination, kind: .phone)
            switch await AnywhereRequests.ask(person, amount: amount, note: note, owner: owner) {
            case .success(let sent): onSent(sent)
            case .failure(let failure): show(failure, row.firstName)
            }
        }
    }

    private func show(_ failure: RequestsAnywhere.AskFailure, _ name: String) {
        withAnimation(.smooth(duration: 0.25)) { outcome = Outcome(failure: failure, name: name) }
    }
}

/// The requests waiting for the owner, in Pay's pill (`PayPill`, on Liquid
/// Glass) ahead of anyone nearby: "JEAN ASKS FOR / 5,000 RWF" by their face,
/// turning through them while there are several. No buttons of its own:
/// Pay is already on the page. A tap opens the request's sheet, where it is
/// paid or declined, whatever way it came (nearby, the server, a touch).
struct RequestPill: View {
    let requests: [MoneyRequest]
    let onOpen: (MoneyRequest) -> Void

    var body: some View {
        PayPill(items: requests, onTap: onOpen) { request in
            PayPillLabel(text: Text("\(request.person.firstName) asks for\n\(Money.formatWithCurrency(request.amount))")) {
                RequestTile(request: request, size: PayPillMetrics.face)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(request.person.shownName) asks for \(Money.formatWithCurrency(request.amount))"))
        }
    }
}

extension Recipient {
    /// The first word of the name shown, for Pay's pill.
    @MainActor
    var firstName: String {
        shownName.split(separator: " ").first.map(String.init) ?? shownName
    }
}

/// One waiting request, with its two answers and no keypad: the request
/// already says how much. Asked of the owner, Pay dials it at once and
/// Decline says no; asked by the owner, Remind (once a day, for one that
/// went through the server), Mark as Paid (money that came some way
/// StarHash didn't see) and Cancel Request.
struct RequestAnswerSheet: View {
    let request: MoneyRequest
    @Environment(\.dismiss) private var dismiss
    @Environment(MoneyRequests.self) private var requests
    @Environment(Paying.self) private var paying
    @State private var showsSplit = false

    var body: some View {
        HeroSheet(
            caption: String(starhash: "Request"),
            title: title,
            onClose: { dismiss() }
        ) {
            TileHero { RequestTile(request: request, size: 84) }
        } actions: {
            switch request.direction {
            case .received:
                Button("Pay") { pay() }
                    .buttonStyle(.sheetPrimary)
                SheetTextButton("Decline") {
                    AnywhereRequests.decline(request)
                    dismiss()
                }
            case .sent:
                // Remind first while it can go: the likeliest next step
                // for money that hasn't come.
                if request.isRemindable {
                    RemindButton(requests: [request], style: .sheet)
                    SheetTextButton("Mark as Paid") {
                        requests.markPaid(request.id)
                        dismiss()
                    }
                } else {
                    Button("Mark as Paid") {
                        requests.markPaid(request.id)
                        dismiss()
                    }
                    .buttonStyle(.sheetPrimary)
                }
                SheetTextButton("Cancel Request", role: .destructive) {
                    AnywhereRequests.cancel(request)
                    dismiss()
                }
            }
        }
        // Locating starts now, so the payment's place is in hand at Pay.
        .onAppear { if request.direction == .received { paying.prepare() } }
        .sheet(isPresented: $showsSplit, onDismiss: {
            paying.stop()
            dismiss()
        }) {
            SplitPaymentSheet()
        }
        // No dial alert of its own: it closes as the code is dialled, and the
        // page under it (Pay, Requests) shows one the system would not dial.
    }

    /// "Ariane asks for 5,000 RWF", or "You asked Ariane for 5,000 RWF".
    private var title: String {
        let name = request.person.shownName
        let amount = Money.formatWithCurrency(request.amount)
        return request.direction == .received
            ? String(starhash: "\(name) asks for \(amount)")
            : String(starhash: "You asked \(name) for \(amount)")
    }

    /// Dials the request as Pay would: recorded, then the call prompt. In
    /// parts, when Split Large Payments says that costs less. One that came
    /// by a tap first tells the asker who is paying, before the call prompt
    /// takes StarHash from the front.
    private func pay() {
        let outcome = paying.pay(request.amount, to: request.person)
        if outcome != .refused { AppEnvironment.nearbyRequests.willPay(request, owner: AppEnvironment.owner) }
        switch outcome {
        case .dialled: dismiss()
        case .split: showsSplit = true
        case .refused: break
        }
    }
}

/// A request's person: the photo their phone shared, or their initials.
struct RequestTile: View {
    let request: MoneyRequest
    var size: CGFloat = 44
    /// Its chip's own fill, on a card the page's chip would vanish into.
    var fill: Color?
    @State private var photo: UIImage?

    var body: some View {
        RecipientTile(tile: photo.map { .image($0) } ?? .monogram(PayContact.initials(for: request.person.shownName)), size: size, fill: fill)
            .task(id: request.photoID) {
                photo = nil
                guard let id = request.photoID else { return }
                #if DEBUG
                if let sample = PeopleNearbyDebug.photo(for: id) {
                    photo = sample
                    return
                }
                #endif
                photo = await StarHashCloud.photo(id)
            }
    }
}

/// Requests, from Transactions: those asked of the owner, then those they
/// sent, each with how it stands. A waiting one opens its answers.
struct RequestsPage: View {
    @Environment(MoneyRequests.self) private var requests
    @State private var opened: MoneyRequest?
    @FeatureFlagged(.requestsAnywhere) private var anywhereOn
    @AppStorage(Preferences.enableContacts) private var enableContacts: Bool
    @State private var contacts = PayContacts.shared

    var body: some View {
        let asked = requests.requests.filter { $0.direction == .received }
        let sent = requests.sent
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if cannotTellWhoAsks {
                    // Requests from anywhere wait on the server, unread,
                    // until StarHash can tell who sent them.
                    Text("Only people in your Contacts can ask you, and StarHash can't read your Contacts now, so their requests wait.")
                        .font(.starhash(.subheadline))
                        .foregroundStyle(Color.starhashSecondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .starhashOutlinedCard()
                        .padding(.horizontal, StarHashMetrics.screenPadding)
                        .padding(.top, 16)
                }
                if !asked.isEmpty {
                    section("Asked of you", asked)
                }
                if !sent.isEmpty {
                    sentSection(sent)
                }
            }
            .padding(.bottom, 24)
            .starhashReadableWidth()
        }
        .overlay {
            if requests.requests.isEmpty {
                EmptyStateView(doodle: .transactions, title: "No Requests")
                    .padding(.horizontal, StarHashMetrics.screenPadding)
                    .allowsHitTesting(false)
            }
        }
        .starhashSoftEdge()
        .background(Color.starhashBackground.ignoresSafeArea())
        .starhashNavigationTitle(String(starhash: "Requests"))
        .sheet(item: $opened) { RequestAnswerSheet(request: $0) }
        .dialFailureAlert()
        .task(id: enableContacts) { await contacts.loadIfAllowed() }
    }

    /// Whether StarHash cannot read the owner's Contacts, so cannot tell
    /// who a request from anywhere comes from (`NearbyRequests.mayAsk`).
    private var cannotTellWhoAsks: Bool {
        anywhereOn && FeatureFlags.isOn(.peopleNearby) && !(enableContacts && contacts.access == .authorized)
    }

    /// Those the owner sent, a bulk request's people together under it.
    private func sentSection(_ list: [SentRequest]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetSectionLabel("You asked", onPage: true)
                .padding(.horizontal, 18)
                .padding(.top, 20)
                .padding(.bottom, 6)
            ForEach(list) { entry in
                switch entry {
                case .single(let request):
                    RequestRow(request: request) { opened = request }
                case .group(let group):
                    RequestGroupCard(group: group) { opened = $0 }
                }
            }
        }
    }

    private func section(_ title: String, _ list: [MoneyRequest]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetSectionLabel(title, onPage: true)
                .padding(.horizontal, 18)
                .padding(.top, 20)
                .padding(.bottom, 6)
            ForEach(list) { request in
                RequestRow(request: request) { opened = request }
            }
        }
    }
}

/// A bulk request on the Requests page: an outlined card, so its people
/// read as one, with its note (or Request in Bulk), how many were asked
/// and paid and when, how much has come in of all it asked for and a bar
/// of it, then each person as the page lists them, without the note and
/// date they share. A waiting one opens its answers.
private struct RequestGroupCard: View {
    let group: RequestGroup
    let open: (MoneyRequest) -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: StarHashMetrics.outlinedCardRadius, style: .continuous)
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)
            progress
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            SheetDivider()
            ForEach(Array(group.requests.enumerated()), id: \.element.id) { index, request in
                // Between people, from where their names start.
                if index > 0 { SheetDivider().padding(.leading, 16 + 40 + 12) }
                RequestRow(request: request, inGroup: true) { open(request) }
            }
            // Everyone still waiting, at the card's foot.
            let remindable = group.requests.filter(\.isRemindable)
            if !remindable.isEmpty {
                SheetDivider()
                RemindButton(requests: remindable, style: .card)
            }
        }
        .clipShape(shape)
        .starhashOutlinedCard(padding: EdgeInsets())
        .padding(.horizontal, StarHashMetrics.screenPadding)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: group.note ?? String(starhash: "Request in Bulk"))
                    .font(PickerType.rowName)
                    .foregroundStyle(Color.starhashPrimaryText)
                    .lineLimit(1)
                Text(verbatim: subtitle)
                    .font(PickerType.rowDetail)
                    .foregroundStyle(Color.starhashSecondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(verbatim: Money.formatWithCurrency(group.collected))
                    .font(.starhashNumber(16, weight: .semibold))
                    .foregroundStyle(Color.starhashPrimaryText)
                Text(verbatim: String(starhash: "of \(Money.format(group.asked))"))
                    .font(PickerType.rowDetail)
                    .foregroundStyle(Color.starhashSecondaryText)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: accessibilityText))
    }

    /// What has come in of all it asked for, in the accent on a hairline.
    private var progress: some View {
        let share = group.asked > 0 ? Double(group.collected) / Double(group.asked) : 0
        return Capsule()
            .fill(Color.starhashOutline)
            .frame(height: 4)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(Color.starhashInk)
                        .frame(width: proxy.size.width * min(max(share, 0), 1))
                }
            }
            .accessibilityHidden(true)
    }

    /// "3 people · 1 paid · 26 Nov".
    private var subtitle: String {
        let people = group.requests.count == 1
            ? String(starhash: "1 person")
            : String(starhash: "\(group.requests.count) people")
        let paid = String(starhash: "\(group.paidCount) paid")
        let date = group.createdAt?.formatted(.dateTime.day().month(.abbreviated).locale(.starhash))
        return [people, paid, date].compactMap { $0 }.joined(separator: " · ")
    }

    private var accessibilityText: String {
        let title = group.note ?? String(starhash: "Request in Bulk")
        let collected = String(starhash: "\(Money.formatWithCurrency(group.collected)) of \(Money.formatWithCurrency(group.asked)) collected")
        return [title, subtitle, collected].joined(separator: ", ")
    }
}

/// One request on the Requests page: the person, the amount and how it
/// stands. Only a waiting one is a button.
private struct RequestRow: View {
    let request: MoneyRequest
    /// On a bulk request's card: inside its edges, with no line of its own
    /// and without the note and date the card already gives.
    var inGroup = false
    let open: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                RequestTile(request: request, size: inGroup ? 40 : 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: request.person.shownName)
                        .font(PickerType.rowName)
                        .foregroundStyle(Color.starhashPrimaryText)
                        .lineLimit(1)
                    if !inGroup {
                        Text(verbatim: subtitle)
                            .font(PickerType.rowDetail)
                            .foregroundStyle(Color.sheetSecondaryText)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(verbatim: Money.formatWithCurrency(request.amount))
                        .font(.starhashNumber(16, weight: .semibold))
                        .foregroundStyle(Color.starhashPrimaryText)
                    Text(verbatim: status)
                        .font(PickerType.rowDetail)
                        .foregroundStyle(request.status == .waiting ? Color.starhashUrgentText : Color.starhashSecondaryText.color(scheme: colorScheme, surface: .page))
                }
            }
            .padding(.horizontal, inGroup ? 16 : 18)
            .padding(.vertical, 10)
            .overlay(alignment: .bottom) {
                if !inGroup {
                    SheetDivider().padding(.leading, 18 + 44 + 12).padding(.trailing, 18)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(HighlightRowButtonStyle())
        .disabled(request.status != .waiting)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        let date = request.createdAt.formatted(.dateTime.day().month(.abbreviated).locale(.starhash))
        return [request.note, date].compactMap { $0 }.joined(separator: " · ")
    }

    private var status: String {
        switch request.status {
        case .waiting: String(starhash: "Waiting")
        case .paid: String(starhash: "Paid")
        case .declined: String(starhash: "Declined")
        case .cancelled: String(starhash: "Cancelled")
        case .expired: String(starhash: "Expired")
        }
    }
}

/// Transactions' way to Requests: a row at the top of the list while there
/// are any, with how many wait for the owner.
struct RequestsLinkRow: View {
    @Environment(MoneyRequests.self) private var requests
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                Image(symbol: "arrow.left.arrow.right")
                    .font(.starhash(.body, weight: .semibold))
                    .foregroundStyle(Color.starhashAccentText)
                    .frame(width: 24)
                Text("Requests")
                    .font(.starhash(.body, weight: .semibold))
                    .foregroundStyle(Color.starhashPrimaryText)
                Spacer(minLength: 8)
                let waiting = requests.waitingForOwner.count
                if waiting > 0 {
                    Text(verbatim: String(starhash: "\(waiting) waiting"))
                        .font(.starhash(.subheadline))
                        .foregroundStyle(Color.starhashUrgentText)
                }
                Image(symbol: "chevron.right")
                    .font(.starhash(.footnote, weight: .semibold))
                    .foregroundStyle(Color.starhashSecondaryText)
            }
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.hapticPlain)
        // The list already sits in from the screen's edges.
        .starhashOutlinedCard()
    }
}

