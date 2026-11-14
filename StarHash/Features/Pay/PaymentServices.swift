import CoreLocation
import StarHashKit
import SwiftUI
import UIKit

/// Every code StarHash dials goes through here: a payment (through
/// `Paying`), Buy's codes, Balance, and a code a widget or a link hands
/// over. A code the system would not dial (the simulator, an iPad without
/// calling) is kept in `undialledCode`, which Pay, the parts sheet and Buy
/// show as one alert (`dialFailureAlert()`), so it can be dialled by hand.
@MainActor
@Observable
final class Dialler {
    /// The code the system last would not dial, until the alert is closed.
    var undialledCode: String?

    func dial(_ code: String) {
        guard let url = USSD.telURL(for: code) else {
            undialledCode = code
            return
        }
        open(url, code: code)
    }

    /// A tel: link as it is, from a widget or a link.
    func open(_ url: URL, code: String? = nil) {
        #if DEBUG
        // -paySplitDialled: parts marked dialled for screenshots, with no
        // call prompt or alert over them.
        if DebugLaunch.dialsNothing { return }
        #endif
        Task {
            if await !UIApplication.shared.open(url, options: [:]) {
                undialledCode = code ?? Self.code(in: url)
            }
        }
    }

    /// The code in a tel: link, # and all.
    private static func code(in url: URL) -> String {
        let link = url.absoluteString
        let code = link.hasPrefix("tel:") ? String(link.dropFirst(4)) : link
        return code.removingPercentEncoding ?? code
    }
}

extension View {
    /// "Can't dial on this device", with the code and Copy Code, when the
    /// system would not dial one. On Pay, the parts sheet and Buy: whichever
    /// is in front shows it.
    func dialFailureAlert() -> some View {
        modifier(DialFailureAlert())
    }
}

private struct DialFailureAlert: ViewModifier {
    @Environment(Dialler.self) private var dialler

    func body(content: Content) -> some View {
        content.alert(
            "Can't dial on this device",
            isPresented: Binding(get: { dialler.undialledCode != nil }, set: { if !$0 { dialler.undialledCode = nil } }),
            presenting: dialler.undialledCode
        ) { code in
            Button("Copy Code") {
                UIPasteboard.general.string = code
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            Button("OK", role: .cancel) {}
        } message: { code in
            Text("Dial \(code) on your phone to finish.")
        }
    }
}

/// A location fix: where, and how sure (horizontal accuracy, in metres).
struct LocationFix: Equatable, Sendable {
    var latitude: Double
    var longitude: Double
    var accuracy: Double

    var coordinate: StarHashKit.Transaction.Coordinate {
        .init(latitude: latitude, longitude: longitude, accuracy: accuracy)
    }
}

extension LocationFix {
    /// `Paying`'s fix, for the recipient screen's Nearby section.
    init(_ coordinate: StarHashKit.Transaction.Coordinate) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude, accuracy: coordinate.accuracy ?? Nearby.maximumAccuracy)
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
                        if await best.offer(fix), fix.accuracy <= Nearby.maximumAccuracy, let onUsable {
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

extension PaymentLocation {
    /// `Paying`'s location: nothing without precise access, and in Debug
    /// runs with -nearbyHere, Kigali Heights at once.
    static func forPaying(_ usable: @escaping @MainActor (StarHashKit.Transaction.Coordinate) -> Void) async -> StarHashKit.Transaction.Coordinate? {
        #if DEBUG
        if let fix = DebugLaunch.nearbyFix {
            usable(fix.coordinate)
            return fix.coordinate
        }
        #endif
        guard isAuthorized else { return nil }
        return await current { fix in usable(fix.coordinate) }?.coordinate
    }
}

/// The most accurate fix seen so far, kept across the race in `current`.
private actor BestFix {
    private(set) var fix: LocationFix?

    /// Keeps `new` when it beats the best so far; true for the first one
    /// good enough for Nearby, so that is passed on once.
    func offer(_ new: LocationFix) -> Bool {
        let wasUsable = (fix?.accuracy ?? .infinity) <= Nearby.maximumAccuracy
        if fix == nil || new.accuracy < fix!.accuracy { fix = new }
        return !wasUsable && new.accuracy <= Nearby.maximumAccuracy
    }
}
