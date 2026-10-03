import Foundation
import StarHashKit

/// Believable transactions for previews, screenshots and the DEBUG store.
enum SampleData {
    static func transactions(now: Date = .now, calendar: Calendar = .current) -> [Transaction] {
        func day(_ offset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -offset, to: now) ?? now)
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: start) ?? start
        }
        let kigali = Transaction.Coordinate(latitude: -1.9255, longitude: 30.1080)
        return [
            Transaction(direction: .outgoing, counterparty: Recipient(name: "Pili-Pili Invest", destination: "020205", kind: .merchant), amount: 15_000, fee: 0, date: day(0, 13, 12), status: .confirmed, source: .app, reference: "1203948571", category: "restaurant", location: kigali),
            Transaction(direction: .incoming, counterparty: Recipient(name: "Ariane Ishimwe", destination: "0788123998", kind: .phone), amount: 35_000, fee: 0, date: day(0, 10, 4), status: .confirmed, source: .sms, reference: "1203940012"),
            Transaction(direction: .outgoing, counterparty: Recipient(name: "John Doe", destination: "0780123456", kind: .phone), amount: 700, fee: 20, date: day(1, 18, 40), status: .confirmed, source: .app, reference: "1203911187"),
            Transaction(direction: .outgoing, counterparty: Recipient(name: "Poivre Noir", destination: "184522", kind: .merchant), amount: 76_480, fee: 0, date: day(1, 20, 15), status: .confirmed, source: .app, reference: "1203911901", category: "restaurant"),
            Transaction(direction: .outgoing, counterparty: Recipient(name: "Simba Supermarket", destination: "009911", kind: .merchant), amount: 42_300, fee: 0, date: day(2, 17, 30), status: .confirmed, source: .sms, reference: "1203888810", category: "groceries"),
            Transaction(direction: .outgoing, counterparty: Recipient(name: "Alain (ALU)", destination: "0784950091", kind: .phone), amount: 8_000, date: day(3, 9, 5), status: .pending, source: .app),
            Transaction(direction: .outgoing, counterparty: Recipient(name: "Moto", destination: "0722497291", kind: .phone), amount: 1_500, fee: 20, date: day(4, 8, 10), status: .confirmed, source: .app, reference: "1203850021"),
            Transaction(direction: .outgoing, counterparty: Recipient(name: "Canal+ Rwanda", destination: "123456", kind: .merchant), amount: 20_000, fee: 0, date: day(6, 12, 0), status: .confirmed, source: .sms, reference: "1203801130", category: "bills"),
            Transaction(direction: .incoming, counterparty: Recipient(name: "Grace Uwase", destination: "0785550123", kind: .phone), amount: 120_000, fee: 0, date: day(9, 15, 45), status: .confirmed, source: .sms, reference: "1203755512"),
            Transaction(direction: .outgoing, counterparty: Recipient(name: "Ltd KonGeza", destination: "0785550123", kind: .phone), amount: 5_000, fee: 100, date: day(12, 11, 20), status: .confirmed, source: .app, reference: "1203700001"),
            Transaction(direction: .outgoing, counterparty: Recipient(name: "Kigali Heights Gym", destination: "556677", kind: .merchant), amount: 30_000, fee: 0, date: day(20, 7, 0), status: .confirmed, source: .app, reference: "1203600099", category: "health"),
        ]
    }

    /// Kigali Heights, where the sample's Nearby places are.
    static let kigaliHeights = Transaction.Coordinate(latitude: -1.9536, longitude: 30.0928)

    /// Visits for `-nearbyHere`: two tills a few metres apart and one
    /// across town.
    static func places(now: Date = .now) -> [PlaceMemory.Visit] {
        let here = kigaliHeights
        func north(_ metres: Double) -> Double { here.latitude + metres / 111_320 }
        return [
            .init(recipient: Recipient(name: "Pili-Pili Invest", destination: "020205", kind: .merchant), latitude: north(6), longitude: here.longitude, accuracy: 9, date: now.addingTimeInterval(-86_400)),
            .init(recipient: Recipient(name: "Pili-Pili Invest", destination: "020205", kind: .merchant), latitude: north(4), longitude: here.longitude, accuracy: 7, date: now.addingTimeInterval(-3_600)),
            .init(recipient: Recipient(name: "Kigali Heights Gym", destination: "556677", kind: .merchant), latitude: north(18), longitude: here.longitude, accuracy: 11, date: now.addingTimeInterval(-172_800)),
            .init(recipient: Recipient(name: "Simba Supermarket", destination: "009911", kind: .merchant), latitude: here.latitude + 0.02, longitude: here.longitude, accuracy: 10, date: now.addingTimeInterval(-259_200)),
        ]
    }
}
