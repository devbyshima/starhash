import LocalAuthentication
import SwiftUI
import UIKit

extension PreferenceKey {
    /// Whether StarHash asks for Face ID (or Touch ID, or the iPhone's
    /// passcode) to open. Off until turned on in Settings, which asks for
    /// it first, as turning it off does.
    static let appLock = "appLock"
}

/// How this iPhone proves it is its owner: the biometry it has set up, or
/// its passcode alone. Names the switch in Settings and the lock's button.
enum DeviceUnlock {
    case faceID, touchID, opticID, passcode

    static var current: DeviceUnlock {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else { return .passcode }
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        default: return .passcode
        }
    }

    /// Whether the iPhone can be asked at all: a passcode, at least, is set.
    static var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    var name: String {
        switch self {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        case .opticID: "Optic ID"
        case .passcode: "Passcode"
        }
    }

    var symbol: String {
        switch self {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .opticID: "opticid"
        case .passcode: "lock.fill"
        }
    }
}

/// The app lock. With it on, StarHash opens behind the lock and asks for
/// Face ID (falling back to the passcode); back from elsewhere it asks
/// again once it has been away more than a minute, so the trip to the
/// call screen and back that every payment takes does not ask each time.
/// While it is away, the lock covers it, so the app switcher shows no
/// payments.
///
/// The lock is a window of its own over the app's, so it covers sheets
/// too, which an overlay on the app's root would not.
@MainActor
@Observable
final class AppLock {
    static let shared = AppLock()

    /// Away for longer than this, StarHash asks again.
    static let grace: TimeInterval = 60

    private(set) var isLocked: Bool
    /// Covering the app while it is away, locked or not.
    private var isShielded = false
    private var isAsking = false
    private var awaySince: Date?
    private var window: UIWindow?

    private init() {
        isLocked = Self.isOn
        #if DEBUG
        // Screenshots of other screens are not kept behind it; -locked
        // shows it.
        if DebugLaunch.arguments.contains("-locked") {
            isLocked = true
        } else if DebugLaunch.arguments.contains(where: { $0.hasPrefix("-") && !$0.hasPrefix("-NS") && !$0.hasPrefix("-Apple") && !$0.hasPrefix("-UI") }) {
            isLocked = false
        }
        #endif
    }

    static var isOn: Bool { StarHashPreferences.bool(PreferenceKey.appLock, default: false) }

    /// Follows the scene: covers the app as it goes, locks it if it was
    /// away long enough, and asks as it comes back.
    func sceneChanged(to phase: ScenePhase) {
        switch phase {
        case .background:
            guard Self.isOn else { return }
            if awaySince == nil { awaySince = .now }
            isShielded = true
        case .active:
            if let awaySince, Self.isOn, Date.now.timeIntervalSince(awaySince) > Self.grace {
                isLocked = true
            }
            awaySince = nil
            isShielded = false
            if isLocked { Task { await unlock() } }
        default:
            break
        }
        updateWindow()
    }

    /// Asks for Face ID, and opens StarHash when it is given.
    func unlock() async {
        guard isLocked, !isAsking else { return }
        isAsking = true
        defer { isAsking = false }
        #if DEBUG
        if DebugLaunch.arguments.contains("-locked") { return }
        #endif
        guard await Self.authenticate(reason: "Unlock StarHash to see your payments.") else { return }
        isLocked = false
        updateWindow()
    }

    /// Face ID, Touch ID or Optic ID, falling back to the passcode; true
    /// once the owner has proved it is them.
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }

    // MARK: Window

    private func updateWindow() {
        let covers = isLocked || isShielded
        if covers, window == nil {
            show()
        } else if !covers, let window {
            self.window = nil
            UIView.animate(withDuration: 0.3, animations: { window.alpha = 0 }, completion: { _ in
                window.isHidden = true
            })
        }
    }

    private func show() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState != .unattached })
        else { return }
        let host = UIHostingController(rootView: AppLockView(lock: self).font(.starhash(.body)))
        host.view.backgroundColor = .clear
        let window = UIWindow(windowScene: scene)
        // Over the app and the Send Ripple's window, under the keyboard.
        window.windowLevel = .normal + 2
        window.rootViewController = host
        window.isHidden = false
        self.window = window
    }
}

/// What the lock shows: StarHash's mark on the page's colour, a line on
/// why, and the button that asks for Face ID, which also asks by itself
/// as StarHash comes back.
private struct AppLockView: View {
    let lock: AppLock

    private let unlock = DeviceUnlock.current

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            StarHashMark(size: 72)
                .padding(.bottom, 26)
            Text("StarHash is Locked")
                .starhashFont(28, weight: .bold, relativeTo: .title)
                .foregroundStyle(Color.starhashPrimaryText)
                .accessibilityAddTraits(.isHeader)
            Text("Unlock with \(unlock.name) to see your payments.")
                .font(.starhash(.body))
                .foregroundStyle(Color.starhashSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
                .padding(.horizontal, 32)
            Spacer()
            if lock.isLocked {
                Button {
                    Task { await lock.unlock() }
                } label: {
                    Label("Unlock with \(unlock.name)", systemImage: unlock.symbol)
                }
                .buttonStyle(.starhashPrimary)
                .padding(.horizontal, StarHashMetrics.screenPadding)
                .padding(.bottom, 12)
                .transition(.opacity)
            }
        }
        .starhashReadableWidth(StarHashMetrics.narrowReadableWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.starhashBackground.ignoresSafeArea())
    }
}
