import StarHashKit
import UIKit
import UserNotifications

/// Pushes for requests from anywhere, in a build with `STARHASH_PUSH`
/// (project.yml), which only a paid Apple team can sign. StarHash registers
/// at each launch, as Apple asks, and hands the token iOS gives to
/// `ServerSync`, which keeps it on the server under the listing's key while
/// the owner takes requests. A request sent through the server then pushes
/// "New request" with the request still sealed: StarHash's Notification
/// Service Extension (`StarHashPushService`) opens it, from what the app
/// shares through its Keychain (`PushKeychain`), to say who asks and for
/// how much. StarHash, woken by the push, trusts none of it and does what
/// Background App Refresh does: it fetches what waits. Without push in the
/// build, nothing registers, and a token an earlier build sent is removed.
@MainActor
enum StarHashPush {
    /// Whether this build has push, as project.yml says in Info.plist.
    static let isOn = Bundle.main.object(forInfoDictionaryKey: "StarHashPush") as? String == "YES"

    /// At launch: iOS answers with the token (`received(deviceToken:)`), or
    /// with an error, when nothing changes. No permission is asked here:
    /// the push shows only as Notifications allow.
    static func register() {
        guard isOn else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    static func received(deviceToken: Data) {
        guard isOn else { return }
        AppEnvironment.serverSync.pushTokenReceived(PushToken(deviceToken: deviceToken, sandbox: isSandbox))
    }

    /// Which APNs this build's tokens belong to: the sandbox's in the
    /// Simulator and in a build Xcode signed for development, production's
    /// in TestFlight and the App Store, which carry no profile.
    private static var isSandbox: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        PushToken.isSandbox(
            provisioningProfile: Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision")
                .flatMap { try? Data(contentsOf: $0) }
        )
        #endif
    }

    /// A push came, for request `pushed`. In front, the request's card
    /// shows once it is fetched, so nothing is said (`willPresent` shows the
    /// push not at all). Away, the requests are fetched as Background App
    /// Refresh fetches them, with word of each, quietly, as the push made
    /// the sound; but not of `pushed`, which the push itself shows, opened
    /// by the extension. Only where the extension could not open it, so the
    /// push says just "New request", and StarHash took it in, does
    /// StarHash's own notification take the push's place.
    static func receivedPush(for pushed: UUID?) async {
        if UIApplication.shared.applicationState == .active {
            await AnywhereRequests.sync(announce: false)
            return
        }
        let news = await AnywhereRequests.refresh(quietly: true, skipping: pushed)
        guard let pushed, let request = news.received.first(where: { $0.id == pushed }) else { return }
        let unopened = await deliveredPushes().filter { notification in
            let userInfo = notification.request.content.userInfo
            return userInfo["request"] == nil && PushedRequest.Sealed(userInfo: userInfo)?.id == pushed
        }
        guard !unopened.isEmpty else { return }
        await StarHashNotifications.shared.announce(.init(received: [request]), quietly: true)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: unopened.map(\.request.identifier))
    }

    /// The owner tapped the push: its request opens on Pay once it is
    /// fetched (`request`, when the extension opened it), else the newest
    /// waiting; Pay, when none is.
    static func opened(request: UUID?) async {
        AppEnvironment.requests.reload()
        await AnywhereRequests.sync(announce: false)
        let waiting = AppEnvironment.requests.waitingForOwner
        if let id = request, waiting.contains(where: { $0.id == id }) {
            AppEnvironment.router.openRequest(id)
        } else if let newest = waiting.max(by: { $0.createdAt < $1.createdAt }) {
            AppEnvironment.router.openRequest(newest.id)
        } else {
            AppEnvironment.router.show(.pay)
        }
    }

    /// What the extension needs of the app's choices, through the Keychain:
    /// the language chosen in StarHash, whether amounts show on the Lock
    /// Screen, whether Contacts may be read, and the server. Written as
    /// StarHash comes and goes, and as one of them changes.
    static func shareSettings() {
        guard isOn else { return }
        PushKeychain.write(.init(
            language: StarHashLanguage.locale.identifier,
            showsAmounts: Preferences.showsAmounts.value(),
            contacts: Preferences.enableContacts.value(),
            server: StarHashCloud.baseURL
        ))
    }

    /// Whether a notification came from StarHash's server, rather than
    /// being one StarHash made.
    nonisolated static func isPush(_ notification: UNNotification) -> Bool {
        notification.request.trigger is UNPushNotificationTrigger
    }

    /// Pushes that say only "New request" go once StarHash is open: its
    /// cards say more. One the extension opened stays, as StarHash's own
    /// notification of a request would.
    static func clearUnopened() async {
        guard isOn else { return }
        let unopened = await deliveredPushes().filter { $0.request.content.userInfo["request"] == nil }
        if !unopened.isEmpty {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: unopened.map(\.request.identifier))
        }
    }

    private static func deliveredPushes() async -> [UNNotification] {
        await UNUserNotificationCenter.current().deliveredNotifications().filter(isPush)
    }
}

/// iOS's side of push: the token, and a push while StarHash is away. In the
/// completion-handler form, on the main actor, as StarHash answers every
/// notification (`NotificationResponder`).
extension StarHashAppDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        StarHashPush.register()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        StarHashPush.received(deviceToken: deviceToken)
    }

    /// No token this launch (no network, say): requests still come when
    /// StarHash opens, and the token is asked for again at the next launch.
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {}

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let pushed = PushedRequest.Sealed(userInfo: userInfo)?.id
        Task { @MainActor in
            await StarHashPush.receivedPush(for: pushed)
            completionHandler(.newData)
        }
    }
}
