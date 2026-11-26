import BackgroundTasks
import StarHashKit
import SwiftUI

/// Requests to and from anyone on StarHash, through the server: when they
/// are fetched (StarHash coming to the front, and Background App Refresh
/// while it is away), the word StarHash gives of what came, and the owner's
/// answers on their way back. What a request says, who may ask, and how
/// the server hears how it ended are StarHashKit's `RequestsAnywhere`.
///
/// No push: that needs the paid Apple team. A request reaches the owner the
/// next time StarHash opens, or when iOS next gives it a moment in the
/// background.
@MainActor
enum AnywhereRequests {
    /// Background App Refresh's task, as Info.plist permits it.
    static let refreshTask = "com.devbyshima.starhash.requests"

    /// Whether requests go through the server: both flags, and Show My Name
    /// on (a number finds an iPhone through it), or requests the server
    /// still has to hear about.
    static var isOn: Bool {
        guard FeatureFlags.requestsAnywhere else { return false }
        return Preferences.showMyName.value() || AppEnvironment.requests.requests.contains(where: \.isAnywhere)
    }

    /// Takes in what waits on the server, and tells it what it has to
    /// hear. With `announce`, a notification for each request asked of the
    /// owner and each of theirs declined: StarHash was away, so nothing on
    /// screen would show them.
    static func sync(announce: Bool) async {
        guard isOn else { return }
        let news = await AppEnvironment.requestsAnywhere.sync()
        if announce { await StarHashNotifications.shared.announce(news) }
    }

    /// The owner declined: the asker hears over People Nearby's connection
    /// while it is open, and through the server whenever it carried the
    /// request.
    static func decline(_ request: MoneyRequest) {
        AppEnvironment.nearbyRequests.decline(request)
    }

    /// The owner took back a request they sent: through the server, the
    /// other's card goes too. One sent nearby whose server copy is still on
    /// its way is closed there once it lands (`RequestsAnywhere.carry`).
    static func cancel(_ request: MoneyRequest) {
        AppEnvironment.requests.cancel(request.id)
        guard request.isAnywhere else { return }
        Task { await AppEnvironment.requestsAnywhere.report() }
    }

    /// Asks iOS for a moment in the background, a quarter of an hour on at
    /// the soonest; iOS chooses when, from how StarHash is used.
    static func scheduleRefresh() {
        guard isOn else { return }
        let request = BGAppRefreshTaskRequest(identifier: refreshTask)
        request.earliestBeginDate = .now.addingTimeInterval(15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Background App Refresh: the requests settled from what the SMS
    /// brought meanwhile, then the server's, with word of what came; then
    /// the next refresh asked for.
    static func refresh() async {
        let store = AppEnvironment.store
        store.reloadFromDisk()
        AppEnvironment.requests.reload()
        AppEnvironment.requests.settle(with: store.transactions)
        await sync(announce: true)
        scheduleRefresh()
    }
}

/// Requests settle from the transactions (`MoneyRequests.settle`): each
/// time they change, and each time StarHash comes to the front, when a
/// week may have passed. Requests through the server are fetched as it
/// comes to the front, and the server hears how they ended.
struct RequestsSync: ViewModifier {
    @Environment(StarHashStore.self) private var store
    @Environment(MoneyRequests.self) private var requests
    @Environment(\.scenePhase) private var scenePhase
    @FeatureFlagged(.peopleNearby) private var peopleNearbyOn
    @FeatureFlagged(.requestsAnywhere) private var anywhereOn
    @AppStorage(Preferences.showMyName) private var showMyName: Bool

    func body(content: Content) -> some View {
        content
            // Listening for requests from people nearby starts with the app.
            .onAppear { _ = AppEnvironment.nearbyRequests }
            .onChange(of: store.transactions, initial: true) { _, transactions in
                requests.settle(with: transactions)
                // One the owner sent, now paid: the server closes it, so
                // the two may ask each other again.
                if AnywhereRequests.isOn { Task { await AppEnvironment.requestsAnywhere.report() } }
            }
            // At launch, and as either flag or Show My Name turns on.
            .task(id: "\(peopleNearbyOn)|\(anywhereOn)|\(showMyName)") {
                await AnywhereRequests.sync(announce: false)
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    requests.reload()
                    requests.settle(with: store.transactions)
                    Task { await AnywhereRequests.sync(announce: false) }
                case .background:
                    AnywhereRequests.scheduleRefresh()
                default:
                    break
                }
            }
    }
}
