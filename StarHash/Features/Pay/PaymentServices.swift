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

/// Where a payment was made, when the person allowed it. StarHash never
/// asks for location here (Settings does that); it only reads it when
/// When In Use access is already granted, and gives up after a short wait
/// so a slow fix never holds a payment back.
@MainActor
enum PaymentLocation {
    static var isAuthorized: Bool {
        switch CLLocationManager().authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: true
        default: false
        }
    }

    /// The first fix within `timeout`, or nil.
    static func current(timeout: Duration = .seconds(6)) async -> StarHashKit.Transaction.Coordinate? {
        guard isAuthorized else { return nil }
        return await withTaskGroup(of: StarHashKit.Transaction.Coordinate?.self) { group in
            group.addTask {
                do {
                    for try await update in CLLocationUpdate.liveUpdates() {
                        if let location = update.location {
                            return StarHashKit.Transaction.Coordinate(
                                latitude: location.coordinate.latitude,
                                longitude: location.coordinate.longitude
                            )
                        }
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
            return first
        }
    }
}
