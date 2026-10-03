import Foundation
import Testing
@testable import StarHashKit

@MainActor
struct PlaceMemoryTests {
    private let shop = Recipient(name: "Simba", destination: "009911", kind: .merchant)
    private let moto = Recipient(name: nil, destination: "0722497291", kind: .phone)
    private let kiosk = Recipient(name: "Kiosk", destination: "184522", kind: .merchant)
    /// Kigali Heights.
    private let here = (lat: -1.9536, lon: 30.0928)

    /// `metres` north of `here` (about 111,320 m per degree of latitude).
    private func north(_ metres: Double) -> Double { here.lat + metres / 111_320 }

    @Test func distanceIsInMetres() {
        let d = PlaceMemory.distance(here.lat, here.lon, north(100), here.lon)
        #expect(abs(d - 100) < 1)
    }

    @Test func roughFixesAreNotKept() {
        let memory = PlaceMemory(fileURL: nil)
        #expect(!memory.record(shop, latitude: here.lat, longitude: here.lon, accuracy: 120))
        #expect(memory.visits.isEmpty)
        #expect(memory.record(shop, latitude: here.lat, longitude: here.lon, accuracy: 12))
    }

    @Test func suggestsWhatWasPaidRightHere() {
        let memory = PlaceMemory(fileURL: nil)
        memory.record(shop, latitude: here.lat, longitude: here.lon, accuracy: 10)
        let found = memory.suggestions(latitude: north(15), longitude: here.lon, accuracy: 10)
        #expect(found.map(\.recipient) == [shop])
    }

    @Test func ignoresPlacesFurtherThanTheFixesCanAccountFor() {
        let memory = PlaceMemory(fileURL: nil)
        memory.record(shop, latitude: here.lat, longitude: here.lon, accuracy: 10)
        #expect(memory.suggestions(latitude: north(120), longitude: here.lon, accuracy: 10).isEmpty)
    }

    @Test func aRoughCurrentFixSuggestsNothing() {
        let memory = PlaceMemory(fileURL: nil)
        memory.record(shop, latitude: here.lat, longitude: here.lon, accuracy: 10)
        #expect(memory.suggestions(latitude: here.lat, longitude: here.lon, accuracy: 200).isEmpty)
    }

    @Test func nearestFirstThenMostVisited() {
        let memory = PlaceMemory(fileURL: nil)
        memory.record(kiosk, latitude: north(30), longitude: here.lon, accuracy: 8)
        memory.record(shop, latitude: here.lat, longitude: here.lon, accuracy: 8)
        memory.record(moto, latitude: north(3), longitude: here.lon, accuracy: 8)
        memory.record(moto, latitude: north(4), longitude: here.lon, accuracy: 8)
        let found = memory.suggestions(latitude: here.lat, longitude: here.lon, accuracy: 8)
        // Shop and Moto are within ten metres of each other, so the more
        // visited Moto leads; the kiosk is further.
        #expect(found.map(\.recipient) == [moto, shop, kiosk])
        #expect(found.first?.visits == 2)
    }

    @Test func oneEntryPerRecipientWithItsLatestName() {
        let memory = PlaceMemory(fileURL: nil)
        memory.record(shop, latitude: here.lat, longitude: here.lon, accuracy: 10)
        var renamed = shop
        renamed.name = "Simba Supermarket"
        memory.record(renamed, latitude: north(2), longitude: here.lon, accuracy: 10)
        let found = memory.suggestions(latitude: here.lat, longitude: here.lon, accuracy: 10)
        #expect(found.count == 1)
        #expect(found.first?.recipient.name == "Simba Supermarket")
    }

    @Test func aFixFromBeforeAnEraseIsDropped() {
        let memory = PlaceMemory(fileURL: nil)
        let started = memory.generation
        memory.eraseAll()
        #expect(!memory.record(shop, latitude: here.lat, longitude: here.lon, accuracy: 10, generation: started))
        #expect(memory.visits.isEmpty)
        #expect(memory.record(shop, latitude: here.lat, longitude: here.lon, accuracy: 10, generation: memory.generation))
    }

    @Test func savedFileIsKeptOutOfBackups() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "PlaceMemoryTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "places.json")
        PlaceMemory(fileURL: url).record(shop, latitude: here.lat, longitude: here.lon, accuracy: 10)
        let values = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
    }

    @Test func savesReloadsAndErases() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "PlaceMemoryTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "places.json")

        PlaceMemory(fileURL: url).record(shop, latitude: here.lat, longitude: here.lon, accuracy: 10)
        let reloaded = PlaceMemory(fileURL: url)
        #expect(reloaded.visits.count == 1)

        reloaded.eraseAll()
        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(PlaceMemory(fileURL: url).visits.isEmpty)
    }
}
