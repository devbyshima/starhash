import StarHashKit
import SwiftUI

/// The side menu, laid out like X's: the owner at the top, the main pages
/// (Pay, Buy, Activity) large and bold under them, and Settings and Help
/// smaller at the bottom, under a hairline. The page showing has a filled
/// symbol. Taller than the screen (large text), it all scrolls together.
struct SideMenu: View {
    @Environment(AppRouter.self) private var router

    private static let primary: [AppTab] = [.pay, .buy, .activity]
    private static let secondary: [AppTab] = [.settings, .help]

    var body: some View {
        GeometryReader { viewport in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SideMenuProfile()
                        .padding(.bottom, 28)

                    ForEach(Self.primary) { tab in
                        row(tab, isPrimary: true)
                    }

                    Spacer(minLength: 32)

                    Rectangle()
                        .fill(Color.starhashSeparator)
                        .frame(height: 1)
                        .padding(.bottom, 12)
                        .accessibilityHidden(true)

                    ForEach(Self.secondary) { tab in
                        row(tab, isPrimary: false)
                    }
                }
                .padding(.leading, 28)
                .padding(.trailing, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)
                .frame(minHeight: viewport.size.height, alignment: .top)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
    }

    private func row(_ tab: AppTab, isPrimary: Bool) -> some View {
        let isShowing = router.selectedTab == tab
        return Button {
            router.show(tab)
        } label: {
            HStack(spacing: isPrimary ? 20 : 18) {
                Image(systemName: isShowing ? tab.selectedSymbol : tab.symbol)
                    .starhashFont(isPrimary ? 24 : 20, relativeTo: isPrimary ? .title2 : .title3)
                    .frame(width: isPrimary ? 32 : 28)
                    .accessibilityHidden(true)
                Text(tab.title)
                    .starhashFont(isPrimary ? 24 : 18, weight: isPrimary ? .bold : .regular, relativeTo: isPrimary ? .title2 : .body)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if tab == .buy {
                    Text("Soon")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.starhashSecondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.starhashInk.opacity(0.08), in: Capsule())
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color.starhashPrimaryText)
            .padding(.vertical, isPrimary ? 14 : 12)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityAddTraits(isShowing ? .isSelected : [])
    }
}

extension AppTab {
    /// The symbol for the page showing.
    var selectedSymbol: String {
        switch self {
        case .pay: "number.circle.fill"
        case .buy: "bag.fill"
        case .activity: "list.bullet.rectangle.fill"
        case .settings: "gearshape.fill"
        case .help: "questionmark.circle.fill"
        }
    }
}

/// The owner at the top of the menu: a round photo (theirs from Contacts,
/// when their number is saved there with one) or initials, then the name
/// registered on their number and the number under it. Both come from
/// onboarding; until the registered name is known, the number leads.
private struct SideMenuProfile: View {
    @AppStorage(PreferenceKey.ownerName) private var ownerName = ""
    @AppStorage(PreferenceKey.ownerNumber) private var ownerNumber = ""
    @AppStorage(PreferenceKey.enableContacts) private var enableContacts = true
    @ScaledMetric(relativeTo: .title) private var avatarSize: CGFloat = 52

    private var name: String { ownerName.trimmingCharacters(in: .whitespaces) }
    private var number: Recipient? { Recipient(input: ownerNumber).flatMap { $0.kind == .phone ? $0 : nil } }
    private var contacts: PayContacts { .shared }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            avatar
                .padding(.bottom, 14)
            Text(title)
                .starhashFont(20, weight: .bold, relativeTo: .title3)
                .foregroundStyle(Color.starhashPrimaryText)
                .lineLimit(2)
            Text(subtitle)
                .starhashFont(17, relativeTo: .body)
                .foregroundStyle(Color.starhashSecondaryText)
                .lineLimit(1)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .task(id: enableContacts) {
            if enableContacts { await contacts.loadIfAllowed() }
        }
    }

    private var title: String {
        if !name.isEmpty { return name }
        return number?.formattedDestination ?? "StarHash"
    }

    private var subtitle: String {
        if !name.isEmpty, let number { return number.formattedDestination }
        return "MTN MoMo"
    }

    @ViewBuilder
    private var avatar: some View {
        if enableContacts, let number, let contactID = contacts.photoContactID(for: number) {
            ContactPhotoTile(contactID: contactID, size: avatarSize, isCircle: true) { initials }
        } else {
            initials
        }
    }

    private var initials: some View {
        Group {
            if name.isEmpty {
                Image(systemName: "person.fill")
                    .font(.system(size: avatarSize * 0.42, weight: .semibold))
            } else {
                Text(PayContact.initials(for: name))
                    .font(.system(size: avatarSize * 0.38, weight: .semibold, design: .rounded))
            }
        }
        .foregroundStyle(Color.starhashPrimaryText)
        .frame(width: avatarSize, height: avatarSize)
        .background(Color.starhashCardRaised, in: Circle())
        .accessibilityHidden(true)
    }
}

/// Opens the side menu: the round glass button at the top left of Pay,
/// Buy and Activity.
struct SideMenuButton: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        StarHashCircleButton("line.3.horizontal", label: "Menu") {
            router.isMenuOpen = true
        }
    }
}

/// The same, as a navigation bar item, for pages in a NavigationStack
/// (Settings, Help), where the system draws the glass.
struct SideMenuToolbarItem: ToolbarContent {
    @Environment(AppRouter.self) private var router

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                router.isMenuOpen = true
            } label: {
                Image(systemName: "line.3.horizontal")
            }
            .accessibilityLabel("Menu")
        }
    }
}
