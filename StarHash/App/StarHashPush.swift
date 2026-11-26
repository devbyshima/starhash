import StarHashKit
import UIKit
import UserNotifications

/// Pushes for requests from anywhere, in a build with `STARHASH_PUSH`
/// (project.yml), which only a paid Apple team can sign. StarHash registers
/// at each launch, as Apple asks, and hands the token iOS gives to
/// `ServerSync`, which keeps it on the server under the listing's key while
/// the owner takes requests. A request sent through the server then pushes
/// "New request" and nothing more; StarHash, woken by it, trusts none of
/// it and does what Background App Refresh does: it fetches what waits and
/// says itself who asks, and for how much. Without push in the build,
/// nothing registers, and a token an earlier build sent is removed.
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

    /// A push came. In front, the request's card shows once it is fetched,
    /// so nothing is said (`willPresent` shows the push not at all).
    /// Away, the requests are fetched as Background App Refresh fetches
    /// them, with word of each, quietly, as the push made the sound; then
    /// the push's own "New request" goes, as StarHash's notification says
    /// more.
    static func receivedPush() async {
        if UIApplication.shared.applicationState == .active {
            await AnywhereRequests.sync(announce: false)
            return
        }
        let news = await AnywhereRequests.refresh(quietly: true)
        if !news.received.isEmpty { await clearDelivered() }
    }

    /// The owner tapped "New request": the request opens on Pay once it is
    /// fetched, the newest when there are several; Pay, when there is none.
    static func opened() async {
        AppEnvironment.requests.reload()
        await AnywhereRequests.sync(announce: false)
        if let newest = AppEnvironment.requests.waitingForOwner.max(by: { $0.createdAt < $1.createdAt }) {
            AppEnvironment.router.openRequest(newest.id)
        } else {
            AppEnvironment.router.show(.pay)
        }
    }

    /// Whether a notification came from StarHash's server, rather than
    /// being one StarHash made.
    nonisolated static func isPush(_ notification: UNNotification) -> Bool {
        notification.request.trigger is UNPushNotificationTrigger
    }

    /// The pushes still showing go once StarHash has what they were about:
    /// its own notifications, or its cards, say more.
    static func clearDelivered() async {
        guard isOn else { return }
        let center = UNUserNotificationCenter.current()
        let pushes = await center.deliveredNotifications().filter(isPush).map(\.request.identifier)
        if !pushes.isEmpty { center.removeDeliveredNotifications(withIdentifiers: pushes) }
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
        Task { @MainActor in
            await StarHashPush.receivedPush()
            completionHandler(.newData)
        }
    }
}
