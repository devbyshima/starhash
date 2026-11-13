import Foundation
import Testing
@testable import StarHashKit

/// ServerSync, through its interface only: a server in memory, a fixed key,
/// settings of its own and the time handed in.
@MainActor
@Suite struct ServerSyncTests {
    /// StarHash's server in memory: what it was sent, and how it answers.
    @MainActor
    final class FakeServer: ServerSync.Server {
        /// The next answers to photo sends, in order; then each is taken.
        var photoAnswers: [ServerSync.PhotoAnswer] = []
        var takesListings = true
        var countsPings = true
        private(set) var photos: [(data: Data?, id: UUID)] = []
        private(set) var listings: [ServerSync.Listing?] = []
        private(set) var pings: [String] = []

        func sendPhoto(_ data: Data?, id: UUID, key: String) async -> ServerSync.PhotoAnswer {
            photos.append((data, id))
            return photoAnswers.isEmpty ? .taken : photoAnswers.removeFirst()
        }

        func sendListing(_ listing: ServerSync.Listing?, key: String) async -> Bool {
            listings.append(listing)
            return takesListings
        }

        func ping(installID: String, version: String) async -> Bool {
            pings.append(installID)
            return countsPings
        }
    }

    /// The owner's photo, as the app keeps it.
    @MainActor
    final class PhotoBox {
        var data: Data?
    }

    @MainActor
    final class Rig {
        let suite = "ServerSyncTests-\(UUID().uuidString)"
        let defaults: UserDefaults
        let server = FakeServer()
        let owner: Owner
        let photo = PhotoBox()
        let sync: ServerSync

        init(listed: Bool = true, isSimulator: Bool = false) {
            defaults = UserDefaults(suiteName: suite)!
            defaults.removePersistentDomain(forName: suite)
            owner = Owner(defaults: defaults)
            if listed {
                owner.setName("Shima Serein")
                _ = owner.setNumber("0788123456")
            }
            let photo = photo
            sync = ServerSync(
                server: server, key: { "key" }, owner: owner, photo: { photo.data }, hasPhoto: { photo.data != nil },
                defaults: defaults, version: "1.1.0", isSimulator: isSimulator
            )
        }

        /// Delete All Data's wipe of the settings and the owner.
        func wipe() {
            defaults.removePersistentDomain(forName: suite)
            owner.reload()
        }
    }

    private let jpeg = Data([0xFF, 0xD8, 0xFF])
    private let noon = Date(timeIntervalSince1970: 1_794_571_200) // 2026-11-13, 14:00 in Kigali

    // MARK: The photo

    @Test func aPhotoChangeSendsThePhoto() async throws {
        let rig = Rig()
        rig.photo.data = jpeg
        rig.sync.photoChanged()
        await rig.sync.settle()
        let sent = try #require(rig.server.photos.first)
        #expect(sent.data == jpeg && sent.id == rig.sync.sharedPhotoID)
        // Taken: coming back to the front sends nothing more.
        rig.sync.wake(at: noon)
        await rig.sync.settle()
        #expect(rig.server.photos.count == 1)
    }

    @Test func aPhotoTheServerDidNotTakeGoesAgainOnWake() async {
        let rig = Rig()
        rig.server.photoAnswers = [.failed]
        rig.photo.data = jpeg
        rig.sync.photoChanged()
        await rig.sync.settle()
        rig.sync.wake(at: noon)
        await rig.sync.settle()
        #expect(rig.server.photos.count == 2)
        rig.sync.wake(at: noon)
        await rig.sync.settle()
        #expect(rig.server.photos.count == 2)
    }

    @Test func anIdHeldUnderAnotherKeyIsReplacedAndTheListingFollows() async throws {
        let rig = Rig()
        rig.server.photoAnswers = [.notYours]
        rig.photo.data = jpeg
        rig.sync.photoChanged()
        await rig.sync.settle()
        #expect(rig.server.photos.count == 2)
        let first = rig.server.photos[0].id, second = rig.server.photos[1].id
        #expect(first != second)
        #expect(rig.sync.sharedPhotoID == second)
        #expect(rig.server.listings.last??.photo == second)
    }

    @Test func removingThePhotoDeletesIt() async throws {
        let rig = Rig()
        rig.photo.data = jpeg
        rig.sync.photoChanged()
        await rig.sync.settle()
        rig.photo.data = nil
        rig.sync.photoChanged()
        await rig.sync.settle()
        let last = try #require(rig.server.photos.last)
        #expect(last.data == nil && last.id == rig.server.photos[0].id)
        #expect(rig.sync.sharedPhotoID == nil)
    }

    // MARK: Show My Name

    @Test func theListingIsSentOnceWhenItChanges() async throws {
        let rig = Rig()
        rig.sync.ownerChanged(at: noon)
        await rig.sync.settle()
        rig.sync.ownerChanged(at: noon)
        await rig.sync.settle()
        #expect(rig.server.listings.count == 1)
        let listing = try #require(rig.server.listings[0])
        #expect(listing.numbers == ["0788123456"] && listing.name == "Shima Serein" && listing.photo == nil)
        rig.owner.setName("Shima")
        rig.sync.ownerChanged(at: noon)
        await rig.sync.settle()
        #expect(rig.server.listings.last??.name == "Shima")
    }

    @Test func theListingGoesAgainAfterAWeek() async {
        let rig = Rig()
        rig.sync.ownerChanged(at: noon)
        await rig.sync.settle()
        rig.sync.ownerChanged(at: noon.addingTimeInterval(6 * 86_400))
        await rig.sync.settle()
        #expect(rig.server.listings.count == 1)
        rig.sync.ownerChanged(at: noon.addingTimeInterval(8 * 86_400))
        await rig.sync.settle()
        #expect(rig.server.listings.count == 2)
    }

    @Test func showMyNameOffClearsTheListing() async {
        let rig = Rig()
        rig.sync.ownerChanged(at: noon)
        await rig.sync.settle()
        rig.defaults.set(false, forKey: Preferences.showMyName.key)
        rig.sync.ownerChanged(at: noon)
        await rig.sync.settle()
        #expect(rig.server.listings.count == 2)
        #expect(rig.server.listings.last! == nil)
    }

    @Test func nothingIsSentForAnOwnerNeverListed() async {
        let rig = Rig(listed: false)
        rig.sync.ownerChanged(at: noon)
        await rig.sync.settle()
        #expect(rig.server.listings.isEmpty)
    }

    @Test func aChangeWhileTheListingIsOnItsWayGoesAfterIt() async {
        let rig = Rig()
        rig.sync.ownerChanged(at: noon)
        rig.owner.setName("Shima")
        rig.sync.ownerChanged(at: noon)
        await rig.sync.settle()
        #expect(rig.server.listings.map { $0?.name } == ["Shima Serein", "Shima"])
    }

    @Test func aListingTheServerDidNotTakeGoesAgain() async {
        let rig = Rig()
        rig.server.takesListings = false
        rig.sync.ownerChanged(at: noon)
        await rig.sync.settle()
        rig.server.takesListings = true
        rig.sync.ownerChanged(at: noon)
        await rig.sync.settle()
        rig.sync.ownerChanged(at: noon)
        await rig.sync.settle()
        #expect(rig.server.listings.count == 2)
    }

    @Test func onlyRwandanMobileNumbersAreListed() async {
        let rig = Rig(listed: false)
        rig.owner.setName("Shima")
        _ = rig.owner.setNumber("0788123456")
        rig.owner.useTwoSIMs()
        _ = rig.owner.setOtherNumber("0728123456")
        #expect(rig.sync.listing?.numbers == ["0788123456", "0728123456"])
    }

    // MARK: Delete All Data

    @Test func eraseDeletesWhatTheServerHolds() async throws {
        let rig = Rig()
        rig.photo.data = jpeg
        rig.sync.photoChanged()
        rig.sync.ownerChanged(at: noon)
        await rig.sync.settle()
        let photoID = try #require(rig.sync.sharedPhotoID)
        // As Delete All Data runs it: the photo removed first.
        rig.photo.data = nil
        rig.sync.photoChanged()
        rig.sync.erase { rig.wipe() }
        await rig.sync.settle()
        #expect(rig.server.photos.contains { $0.data == nil && $0.id == photoID })
        #expect(rig.server.listings.last! == nil)
    }

    @Test func eraseDoesNotNeedThePhotoRemovedFirst() async throws {
        let rig = Rig()
        rig.photo.data = jpeg
        rig.sync.photoChanged()
        await rig.sync.settle()
        let photoID = try #require(rig.sync.sharedPhotoID)
        rig.sync.erase { rig.wipe() }
        rig.photo.data = nil
        await rig.sync.settle()
        #expect(rig.server.photos.last.map { $0.data == nil && $0.id == photoID } == true)
    }

    @Test func aPhotoLeftToDeleteIsDeletedUntilTheServerConfirms() async {
        let rig = Rig()
        rig.photo.data = jpeg
        rig.sync.photoChanged()
        await rig.sync.settle()
        rig.photo.data = nil
        rig.server.photoAnswers = [.failed]
        rig.sync.erase { rig.wipe() }
        await rig.sync.settle()
        let afterErase = rig.server.photos.count
        rig.sync.wake(at: noon)
        await rig.sync.settle()
        #expect(rig.server.photos.count == afterErase + 1)
        rig.sync.wake(at: noon)
        await rig.sync.settle()
        #expect(rig.server.photos.count == afterErase + 1)
    }

    // MARK: The daily count

    @Test func todayIsCountedOncePerKigaliDay() async {
        let rig = Rig()
        // 23:59 and 00:30 in Kigali (UTC+2): two days.
        let lateEvening = Date(timeIntervalSince1970: 1_794_607_140)
        let pastMidnight = lateEvening.addingTimeInterval(31 * 60)
        rig.sync.wake(at: lateEvening)
        await rig.sync.settle()
        rig.sync.wake(at: lateEvening.addingTimeInterval(30))
        await rig.sync.settle()
        #expect(rig.server.pings.count == 1)
        rig.sync.wake(at: pastMidnight)
        await rig.sync.settle()
        #expect(rig.server.pings.count == 2)
        #expect(Set(rig.server.pings).count == 1)
    }

    @Test func aDayNotCountedIsTriedAgain() async {
        let rig = Rig()
        rig.server.countsPings = false
        rig.sync.wake(at: noon)
        await rig.sync.settle()
        rig.server.countsPings = true
        rig.sync.wake(at: noon)
        await rig.sync.settle()
        rig.sync.wake(at: noon)
        await rig.sync.settle()
        #expect(rig.server.pings.count == 2)
    }

    @Test func neverTwoCountsAtOnce() async {
        let rig = Rig()
        rig.sync.wake(at: noon)
        rig.sync.wake(at: noon)
        await rig.sync.settle()
        #expect(rig.server.pings.count == 1)
    }

    @Test func theSimulatorNeverListsOrCounts() async {
        let rig = Rig(isSimulator: true)
        rig.photo.data = jpeg
        rig.sync.photoChanged()
        await rig.sync.settle()
        rig.sync.wake(at: noon)
        await rig.sync.settle()
        #expect(rig.server.listings.isEmpty && rig.server.pings.isEmpty)
        #expect(rig.server.photos.count == 1)
    }

    @Test func kigaliDayFollowsKigalisCalendar() {
        // 23:59 on the 13th and 00:30 on the 14th, in Kigali.
        #expect(ServerSync.kigaliDay(of: Date(timeIntervalSince1970: 1_794_607_140)) == "2026-11-13")
        #expect(ServerSync.kigaliDay(of: Date(timeIntervalSince1970: 1_794_609_000)) == "2026-11-14")
    }
}
