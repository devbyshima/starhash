import Contacts
import CoreLocation
import UIKit

/// Asks for Contacts access. Used by onboarding's Contacts page and the
/// Enable contacts switch. Returns whether StarHash may read contacts
/// (limited access counts).
@MainActor
enum SettingsContactsAccess {
    static var isAllowed: Bool {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized, .limited: true
        default: false
        }
    }

    static var isUndetermined: Bool {
        CNContactStore.authorizationStatus(for: .contacts) == .notDetermined
    }

    @discardableResult
    static func request() async -> Bool {
        guard isUndetermined else { return isAllowed }
        let store = CNContactStore()
        _ = try? await store.requestAccess(for: .contacts)
        return isAllowed
    }
}

/// Asks for when-in-use location, for the Nearby switch. Core Location
/// answers through its delegate, so the request waits for that callback.
@MainActor
final class SettingsLocationAccess: NSObject, @preconcurrency CLLocationManagerDelegate {
    static let shared = SettingsLocationAccess()

    private let manager = CLLocationManager()
    private var waiting: [CheckedContinuation<Bool, Never>] = []

    private override init() {
        super.init()
        manager.delegate = self
    }

    var isAllowed: Bool {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: true
        default: false
        }
    }

    /// True once the user allows it. Asks only the first time; after a
    /// refusal only the Settings app can change it, so it returns false.
    func request() async -> Bool {
        guard manager.authorizationStatus == .notDetermined else { return isAllowed }
        return await withCheckedContinuation { continuation in
            waiting.append(continuation)
            manager.requestWhenInUseAuthorization()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager.authorizationStatus != .notDetermined else { return }
        let allowed = isAllowed
        let resumed = waiting
        waiting.removeAll()
        resumed.forEach { $0.resume(returning: allowed) }
    }
}

/// StarHash's page in the Settings app, where a refused permission can be
/// turned back on.
@MainActor
enum SettingsAppLink {
    static func open() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    /// Straight to StarHash's notifications there.
    static func openNotifications() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
