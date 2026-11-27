import StarHashKit
import SwiftUI

/// Request in Bulk, from Request's sheet: several people asked at once,
/// each for an amount of their own. Everyone chosen starts at the amount
/// typed on Pay, and a tap on their amount changes it; one note goes to
/// all. Send asks them one after another as Request would (people nearby
/// over People Nearby's connection, anyone else through StarHash's
/// server), one request each under one group id (`BulkRequest`), and each
/// row then says how it went. Someone StarHash could not ask gets Share
/// Message with their own amount.
struct BulkRequestSheet: View {
    let amount: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(PeopleNearbyService.self) private var nearby
    @Environment(Owner.self) private var owner
    @Environment(MoneyRequests.self) private var requests
    @FeatureFlagged(.requestsAnywhere) private var anywhereOn
    @AppStorage(Preferences.showMyName) private var showMyName: Bool
    @AppStorage(Preferences.enableContacts) private var enableContacts: Bool
    @State private var contacts = PayContacts.shared
    @State private var bulk: BulkRequest
    @State private var note: String
    @State private var query = ""
    /// The contacts' and typed numbers the directory lists, once checked;
    /// nil until then, or when the server could not be reached.
    @State private var onStarHash: Set<String>?
    /// The numbers the directory has answered for.
    @State private var checked: Set<String> = []
    /// The contacts chosen, by pick, for their names and photos.
    @State private var chosenRows: [String: RequestContactRow] = [:]
    /// How each pick went, once Send was tapped.
    @State private var outcomes: [String: Outcome] = [:]
    @State private var phase = Phase.choosing
    @State private var sentCount = 0
    @FocusState private var focus: Field?

    enum Phase { case choosing, sending, sent }

    /// How asking one person went.
    enum Outcome: Equatable {
        case sending
        case sent
        /// Their phone nearby didn't answer: they left, or locked it.
        case unreachable
        case failed(RequestsAnywhere.AskFailure)
    }

    enum Field: Hashable {
        case note, search
        case amount(String)
    }

    /// At most this many contacts at once: a search narrows them.
    private static let shownLimit = 60

    init(amount: Int, note: String?) {
        self.amount = amount
        _bulk = State(initialValue: BulkRequest(amount: amount))
        _note = State(initialValue: note ?? "")
    }

    var body: some View {
        CollapsingSheetScroll(
            title: String(starhash: "Request in Bulk"),
            smallCaption: "Request in Bulk",
            smallTitle: Money.formatWithCurrency(bulk.total)
        ) {
            VStack(alignment: .leading, spacing: 18) {
                if phase == .choosing { noteField }
                if !bulk.picks.isEmpty { picksSection }
                if phase == .choosing { chooser }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .starhashBottomBar { bottomButton }
        .sheetGlass(detents: [.large])
        .interactiveDismissDisabled(phase == .sending)
        .sensoryFeedback(.success, trigger: sentCount)
        .animation(.smooth(duration: 0.25), value: bulk.picks)
        .animation(.smooth(duration: 0.25), value: outcomes)
        .task(id: enableContacts) {
            if enableContacts { await contacts.loadIfAllowed() }
        }
        // The contacts coming in, or a number typed in full.
        .task(id: numbersToCheck.count) { await checkDirectory() }
        #if DEBUG
        .task { await applyDebugLaunch() }
        #endif
    }

    // MARK: The note

    private var noteField: some View {
        TextField(text: $note, prompt: Text("What for? (optional)")) { Text("Note") }
            .font(.sheetBody)
            .focused($focus, equals: .note)
            .submitLabel(.done)
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .sheetCard()
            .onChange(of: note) { _, typed in
                if typed.count > MoneyRequest.maximumNoteLength { note = String(typed.prefix(MoneyRequest.maximumNoteLength)) }
            }
    }

    // MARK: Who, and how much

    /// Everyone chosen, each with their amount (a field until Send), and
    /// the total on a card of its own under them, as the parts' sheet sets
    /// its fees.
    private var picksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SheetSectionLabel(phase == .choosing ? "Amounts" : "Requests")
            VStack(spacing: 0) {
                ForEach(Array(bulk.picks.enumerated()), id: \.element.id) { index, pick in
                    if index > 0 { SheetDivider().padding(.leading, 70) }
                    pickRow(pick)
                }
            }
            .sheetCard()
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Total")
                    .font(.sheetBody)
                    .foregroundStyle(Color.starhashPrimaryText)
                Spacer(minLength: 12)
                amountText(bulk.total)
                    .contentTransition(.numericText())
            }
            // In line with the rows' faces and amounts above it.
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .sheetCard()
            .padding(.top, 6)
            .accessibilityElement(children: .combine)
        }
    }

    private func pickRow(_ pick: BulkRequest.Pick) -> some View {
        HStack(spacing: 12) {
            tile(for: pick.person)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: name(of: pick.person))
                    .font(PickerType.rowName)
                    .foregroundStyle(Color.starhashPrimaryText)
                    .lineLimit(1)
                if let outcome = outcomes[pick.id] {
                    HStack(spacing: 6) {
                        if outcome == .sending { ProgressView().controlSize(.mini) }
                        Text(verbatim: words(for: outcome, name: firstName(of: pick.person)))
                            .font(PickerType.rowDetail)
                            .foregroundStyle(color(for: outcome))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .contentTransition(.opacity)
                    }
                } else if !pick.isAskable && pick.amount > 0 {
                    Text(verbatim: String(starhash: "Up to \(Money.formatWithCurrency(Money.maximumAmount))"))
                        .font(PickerType.rowDetail)
                        .foregroundStyle(Color.starhashDestructive)
                }
            }
            Spacer(minLength: 8)
            if phase == .choosing {
                amountField(pick)
            } else {
                VStack(alignment: .trailing, spacing: 6) {
                    amountText(pick.amount)
                    if case .failed(let failure) = outcomes[pick.id], failure.offersShareMessage {
                        ShareLink(item: RequestContacts.shareText(amount: pick.amount, note: note, owner: owner)) {
                            Text("Share Message")
                        }
                        .buttonStyle(.starhashCapsule(height: 30, horizontalPadding: 12))
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .accessibilityElement(children: .contain)
    }

    /// The pick's amount as a field on a chip, a number pad when tapped.
    private func amountField(_ pick: BulkRequest.Pick) -> some View {
        let text = Binding<String>(
            get: { pick.amount == 0 ? "" : Money.format(pick.amount) },
            set: { typed in
                // Past the most StarHash asks for, so it says so, never more.
                let digits = String(typed.filter { $0.isASCII && $0.isNumber }.prefix(9))
                bulk.setAmount(Int(digits) ?? 0, for: pick.id)
            }
        )
        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            TextField(text: text, prompt: Text(verbatim: "0")) {
                Text("Amount for \(name(of: pick.person))")
            }
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .font(.starhashNumber(17, relativeTo: .body))
            .foregroundStyle(pick.isAskable ? AnyShapeStyle(Color.starhashPrimaryText) : AnyShapeStyle(Color.starhashDestructive))
            .focused($focus, equals: .amount(pick.id))
            .fixedSize()
            Text(Money.currency)
                .font(.sheet(12, relativeTo: .footnote))
                .foregroundStyle(Color.sheetSecondaryText)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 12)
        .frame(minWidth: 96, minHeight: 36, alignment: .trailing)
        .background(Capsule().fill(Color.sheetChip))
        .contentShape(Capsule())
        .onTapGesture { focus = .amount(pick.id) }
    }

    private func amountText(_ amount: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(Money.format(amount))
                .font(.starhashNumber(17, relativeTo: .body))
                .foregroundStyle(Color.starhashPrimaryText)
            Text(Money.currency)
                .font(.sheet(12, relativeTo: .footnote))
                .foregroundStyle(Color.sheetSecondaryText)
        }
        .lineLimit(1)
    }

    private func words(for outcome: Outcome, name: String) -> String {
        switch outcome {
        case .sending: String(starhash: "Sending")
        case .sent: String(starhash: "Sent")
        case .unreachable: String(starhash: "Couldn't reach their iPhone")
        case .failed(let failure): failure.message(name: name)
        }
    }

    private func color(for outcome: Outcome) -> AnyShapeStyle {
        switch outcome {
        // No green: that is for a payment confirmed, and this is only a
        // request on its way.
        case .sending, .sent: AnyShapeStyle(Color.sheetSecondaryText)
        case .unreachable, .failed: AnyShapeStyle(Color.starhashDestructive)
        }
    }

    // MARK: Choosing people

    @ViewBuilder
    private var chooser: some View {
        if let missing = NearbyRequests.missing(in: owner) {
            RequestNotice(text: missing)
        } else {
            if bulk.isFull {
                RequestNotice(text: String(starhash: "You can ask up to \(BulkRequest.maximumPeople) people at once"))
            }
            // With requests anywhere, an empty nearby says nothing: the
            // contacts below are the way.
            if !anywhere || !nearby.found.people.isEmpty {
                SheetSectionLabel("People Nearby")
                nearbyCard
            }
            if anywhere { anywhereSection }
        }
    }

    /// Requests through the server: both flags, as Request already needs
    /// People Nearby's.
    private var anywhere: Bool { anywhereOn && FeatureFlags.isOn(.peopleNearby) }

    @ViewBuilder
    private var nearbyCard: some View {
        if nearby.found.people.isEmpty {
            RequestNotice(text: String(starhash: "No one nearby has StarHash open"))
        } else {
            VStack(spacing: 0) {
                ForEach(Array(nearby.found.people.enumerated()), id: \.element.id) { index, person in
                    if index > 0 { SheetDivider().padding(.leading, 70) }
                    chooseButton(.nearby(person), name: person.name) {
                        PeopleNearbyTile(person: person, size: 44)
                    }
                }
            }
            .sheetCard()
        }
    }

    @ViewBuilder
    private var anywhereSection: some View {
        SheetSectionLabel("Anyone on StarHash")
        if !showMyName {
            RequestNotice(text: String(starhash: "Turn on Show My Name in Settings to ask people who aren't nearby"))
        } else {
            searchField
            let rows = shownRows
            if rows.isEmpty {
                RequestNotice(text: emptyText)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        if index > 0 { SheetDivider().padding(.leading, 70) }
                        let person = person(for: row)
                        chooseButton(person, name: row.shownName, detail: row.name == nil ? nil : row.recipient.formattedDestination) {
                            chosenRows[person.id] = row
                        } tile: {
                            RecipientTile(tile: row.tile, size: 44, fill: .sheetChip)
                        }
                    }
                }
                .sheetCard()
                .animation(.smooth(duration: 0.3), value: onStarHash)
            }
        }
    }

    /// Why there is no one to choose.
    private var emptyText: String {
        if !query.isEmpty { return String(starhash: "No one on StarHash matches. Type their full number") }
        return enableContacts
            ? String(starhash: "None of your contacts are on StarHash yet")
            : String(starhash: "Type the number of someone on StarHash")
    }

    /// One person to choose, with a tick once they are.
    private func chooseButton(
        _ person: BulkRequest.Person, name: String, detail: String? = nil, onChoose: @escaping () -> Void = {},
        @ViewBuilder tile: () -> some View
    ) -> some View {
        let picked = bulk.isPicked(person)
        return Button {
            focus = nil
            onChoose()
            bulk.toggle(person)
        } label: {
            HStack(spacing: 12) {
                tile()
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: name)
                        .font(PickerType.rowName)
                        .foregroundStyle(Color.starhashPrimaryText)
                        .lineLimit(1)
                    if let detail {
                        Text(verbatim: detail)
                            .font(PickerType.rowDetail)
                            .foregroundStyle(Color.sheetSecondaryText)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                Image(symbol: picked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(picked ? AnyShapeStyle(Color.starhashAccentText) : AnyShapeStyle(Color.sheetSecondaryText))
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.hapticPlain)
        .disabled(!picked && bulk.isFull)
        .accessibilityLabel(Text(verbatim: name))
        .accessibilityAddTraits(picked ? .isSelected : [])
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(symbol: "magnifyingglass")
                .foregroundStyle(Color.sheetSecondaryText)
                .accessibilityHidden(true)
            TextField(text: $query, prompt: Text("Name or number")) { Text("Search contacts or type a number") }
                .font(.sheetBody)
                .focused($focus, equals: .search)
                .keyboardType(.namePhonePad)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.search)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .sheetCard()
    }

    /// The contacts and typed number on StarHash, once the directory has
    /// said which; every one while it cannot, as Request lists them.
    private var shownRows: [RequestContactRow] {
        let rows = RequestContacts.rows(query: query, owner: owner, contacts: contacts, enableContacts: enableContacts)
        let listed = onStarHash.map { listed in rows.filter { listed.contains($0.recipient.destination) } } ?? rows
        return Array(listed.prefix(Self.shownLimit))
    }

    private var numbersToCheck: [String] {
        RequestContacts.numbers(query: query, contacts: contacts, enableContacts: enableContacts)
    }

    /// Checks the numbers not yet answered for: all of them as the sheet
    /// opens and the contacts load, then a number as it is typed in full.
    private func checkDirectory() async {
        guard anywhere, showMyName else { return }
        let fresh = Array(Set(numbersToCheck).subtracting(checked))
        guard !fresh.isEmpty, let listed = await StarHashCloud.listed(among: fresh) else { return }
        checked.formUnion(fresh)
        withAnimation(.smooth(duration: 0.3)) {
            onStarHash = (onStarHash ?? []).union(listed)
        }
    }

    private func person(for row: RequestContactRow) -> BulkRequest.Person {
        .number(Recipient(name: row.name, destination: row.recipient.destination, kind: .phone))
    }

    // MARK: A person's face and name

    @ViewBuilder
    private func tile(for person: BulkRequest.Person) -> some View {
        switch person {
        case .nearby(let found):
            PeopleNearbyTile(person: found, size: 44)
        case .number(let recipient):
            let tile = chosenRows[person.id]?.tile ?? recipient.name.map { .monogram(PayContact.initials(for: $0)) } ?? .shadow(seed: recipient.destination)
            RecipientTile(tile: tile, size: 44, fill: .sheetChip)
        }
    }

    private func name(of person: BulkRequest.Person) -> String {
        switch person {
        case .nearby(let found): found.name
        case .number(let recipient): recipient.name ?? recipient.formattedDestination
        }
    }

    private func firstName(of person: BulkRequest.Person) -> String {
        let name = name(of: person)
        return name.split(separator: " ").first.map(String.init) ?? name
    }

    // MARK: Sending

    @ViewBuilder
    private var bottomButton: some View {
        Group {
            switch phase {
            case .choosing:
                Button(sendTitle) { send() }
                    .buttonStyle(.sheetPrimary)
                    .disabled(!bulk.canSend || NearbyRequests.missing(in: owner) != nil)
            case .sending:
                Button("Sending") {}
                    .buttonStyle(.sheetPrimary)
                    .disabled(true)
            case .sent:
                Button("Done") { dismiss() }
                    .buttonStyle(.sheetPrimary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    /// "Send 3 Requests", "Send Request" for one, and "Send Requests"
    /// while no one is chosen.
    private var sendTitle: String {
        switch bulk.picks.count {
        case 0: String(starhash: "Send Requests")
        case 1: String(starhash: "Send Request")
        case let count: String(starhash: "Send \(count) Requests")
        }
    }

    /// Asks everyone chosen, one after another, under one group id. A
    /// person nearby is reached as Request reaches them, so one at a time.
    private func send() {
        guard bulk.canSend, phase == .choosing, NearbyRequests.missing(in: owner) == nil else { return }
        focus = nil
        phase = .sending
        let group = UUID()
        let picks = bulk.picks
        let note = note
        Task {
            let photo = ProfilePhoto.shared.image != nil ? AppEnvironment.serverSync.sharedPhotoID : nil
            var sent = 0
            for pick in picks {
                outcomes[pick.id] = .sending
                let outcome: Outcome
                switch pick.person {
                case .nearby(let person):
                    if let request = await AppEnvironment.nearbyRequests.ask(person, amount: pick.amount, note: note, owner: owner, photoID: photo) {
                        requests.group(request.id, in: group)
                        outcome = .sent
                    } else {
                        outcome = .unreachable
                    }
                case .number(let recipient):
                    switch await AnywhereRequests.ask(recipient, amount: pick.amount, note: note, owner: owner) {
                    case .success(let request):
                        requests.group(request.id, in: group)
                        outcome = .sent
                    case .failure(let failure):
                        outcome = .failed(failure)
                    }
                }
                if outcome == .sent { sent += 1 }
                outcomes[pick.id] = outcome
            }
            phase = .sent
            if sent > 0 {
                sentCount += 1
                AccessibilityNotification.Announcement(
                    sent == 1 ? String(starhash: "Asked 1 person") : String(starhash: "Asked \(sent) people")
                ).post()
            }
        }
    }

    // MARK: Debug

    #if DEBUG
    /// -bulkPicks <n>: the first n people nearby chosen (with
    /// -peopleNearby), -bulkAmounts <a,b,…> their amounts, and -bulkSend
    /// Send tapped a second later, for screenshots of each step.
    private func applyDebugLaunch() async {
        guard let count = DebugLaunch.value(after: "-bulkPicks").flatMap(Int.init), bulk.picks.isEmpty else { return }
        try? await Task.sleep(for: .seconds(0.5))
        for person in nearby.found.people.prefix(count) { bulk.toggle(.nearby(person)) }
        let amounts = DebugLaunch.value(after: "-bulkAmounts")?.split(separator: ",").compactMap { Int($0) } ?? []
        for (pick, amount) in zip(bulk.picks, amounts) { bulk.setAmount(amount, for: pick.id) }
        guard DebugLaunch.arguments.contains("-bulkSend") else { return }
        try? await Task.sleep(for: .seconds(1))
        send()
    }
    #endif
}
