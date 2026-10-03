import CoreLocation
import StarHashKit
import UIKit

/// Hands a USSD code to the phone app. MoMo then asks for the PIN on the
/// carrier's own screen; StarHash never sees it.
@MainActor
enum USSDDialer {
    /// False when the system would not open the tel: link: the simulator,
    /// an iPad without calling, or a code the system refused.
    static func dial(_ code: String) async -> Bool {
        guard let url = USSD.telURL(for: code) else { return false }
        return await UIApplication.shared.open(url, options: [:])
    }

    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

/// A location fix: where, and how sure (horizontal accuracy, in metres).
struct LocationFix: Equatable, Sendable {
    var latitude: Double
    var longitude: Double
    var accuracy: Double

    var coordinate: StarHashKit.Transaction.Coordinate {
        .init(latitude: latitude, longitude: longitude)
    }
}

/// Where the person is while paying, for Nearby: the payment's place, and
/// the recipients paid around here. StarHash never asks for location here
/// (Settings does that); it only reads it when When In Use access is
/// already granted, and gives up after a short wait so a slow fix never
/// holds a payment back. Precise location only: an approximate one is
/// kilometres wide and could not tell one till from the next.
@MainActor
enum PaymentLocation {
    static var isAuthorized: Bool {
        let manager = CLLocationManager()
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return manager.accuracyAuthorization == .fullAccuracy
        default: return false
        }
    }

    /// The best fix within `timeout`: it returns as soon as one is within
    /// `goal` metres, otherwise the most accurate seen. Nil without access
    /// or without any fix. `onUsable` hears the first fix good enough for
    /// Nearby, so the picker need not wait for the best one.
    static func current(
        timeout: Duration = .seconds(8), goal: Double = 15,
        onUsable: (@MainActor @Sendable (LocationFix) -> Void)? = nil
    ) async -> LocationFix? {
        guard isAuthorized else { return nil }
        return await withTaskGroup(of: LocationFix?.self) { group in
            let best = BestFix()
            group.addTask {
                do {
                    for try await update in CLLocationUpdate.liveUpdates(.otherNavigation) {
                        // A cached fix from before can be anywhere the
                        // phone was; only a fresh one says where it is.
                        guard let location = update.location, location.horizontalAccuracy >= 0,
                              abs(location.timestamp.timeIntervalSinceNow) < 10 else { continue }
                        let fix = LocationFix(
                            latitude: location.coordinate.latitude,
                            longitude: location.coordinate.longitude,
                            accuracy: location.horizontalAccuracy
                        )
                        if await best.offer(fix), fix.accuracy <= PlaceMemory.Visit.maximumAccuracy, let onUsable {
                            await onUsable(fix)
                        }
                        if fix.accuracy <= goal { return fix }
                    }
                } catch {}
                return nil
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            if let first { return first }
            return await best.fix
        }
    }
}

/// The most accurate fix seen so far, kept across the race in `current`.
private actor BestFix {
    private(set) var fix: LocationFix?

    /// Keeps `new` when it beats the best so far; true for the first one
    /// good enough for Nearby, so that is passed on once.
    func offer(_ new: LocationFix) -> Bool {
        let wasUsable = (fix?.accuracy ?? .infinity) <= PlaceMemory.Visit.maximumAccuracy
        if fix == nil || new.accuracy < fix!.accuracy { fix = new }
        return !wasUsable && new.accuracy <= PlaceMemory.Visit.maximumAccuracy
    }
}
