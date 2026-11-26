import Foundation
import Testing
@testable import StarHashKit

/// ServerSync, through its interface only: a server in memory, a fixed key,
/// settings of its own and the time handed in. `settle()` waits for every
/// task to end, so a task that never does would hang the run: the limit
/// fails it instead.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct ServerSyncTests {
    /// StarHash's server in memory: what it was sent, and how it answers.
    @MainActor
    final class FakeServer: ServerSync.Server {
        /// The next answers to photo sends, in order; then each is taken.
        var photoAnswers: [ServerSync.PhotoAnswer] = []
        var takesListings = true
        var countsPings = true
        var takesPush = true
        private(set) var photos: [(data: Data?, id: UUID)] = []
        private(set) var listings: [ServerSync.Listing?] = []
        private(set) var pings: [String] = []
        /// Push tokens tied ("+token", "+token-replacing") and untied
        /// ("-token"), in order.
        private(set) var push: [String] = []

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

        func registerPush(_ token: PushToken, replacing: String?, key: String) async -> Bool {
            push.append("+" + token.hex + (replacing.map { "-" + $0 } ?? ""))
            return takesPush
        }

        func removePush(_ hex: String, key: String) async -> Bool {
            push.append("-" + hex)
            return takesPush
        }
    }

    /// The owner's photo, as the app keeps it.
    @MainActor
    final class PhotoBox {
        var data: Data?
    }

    /// The owner's public key for requests, while they take them.
    @MainActor
    final class KeyBox {
        var key: String?
    }

    @MainActor
    final class Rig {
        let defaults = TestDefaults("ServerSyncTests")
        let server = FakeServer()
        let owner: Owner
        let photo = PhotoBox()
        let sync: ServerSync

        /// The public key requests are sealed to, while the owner takes them.
        let publicKey = KeyBox()

        init(listed: Bool = true, isSimulator: Bool = false, push: Bool = false) {
            owner = Owner(defaults: defaults)
            if listed {
                owner.setName("Shima Serein")
                _ = owner.setNumber("0788123456")
            }
            let photo = photo, publicKey = publicKey
            sync = ServerSync(
                server: server, key: { "key" }, owner: owner, photo: { photo.data }, hasPhoto: { photo.data != nil },
                publicKey: { publicKey.key }, defaults: defaults, version: "1.1.0", isSimulator: isSimulator,
                pushEnabled: push
            )
        }

        /// Delete All Data's wipe of the settings and the owner.
        func wipe() {
            defaults.removePersistentDomain(forName: defaults.suiteName)
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
        try #require(rig.server.photos.count == 2)
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
        let first = try #require(rig.server.photos.first)
        let last = try #require(rig.server.photos.last)
        #expect(last.data == nil && last.id == first.id)
        #expect(rig.sync.sharedPhotoID == nil)
    }

    // MARK: Show My Name

    @Test func theListingIsSentOnceWhenItChanges() async throws {
        let rig = Rig()
        rig.sync.ownerChanged(at: noon)
        await rig.sync.settle()
        rig.sync.ownerChanged(at: noon)
        await rig.sync.settle()
        try #require(rig.server.listings.count == 1)
        let listing = try #require(rig.server.listings[0])
        #expect(listing.numbers == ["0788123456"] && listing.name == "Shima Serein" && listing.photo == nil)
        rig.owner.setName("Shima")
        rig.sync.ownerChanged(at: noon)
        await rig.sync.settle()
        #expect(rig.server.listings.last??.name == "Shima")
    }

    @Test func theListingCarriesTheKeyRequestsAreSealedTo() async throws {
        let rig = Rig()
        rig.sync.ownerChanged(at: noon)
        await rig.sync.settle()
        // Without one it reads as it always did, so an update sends nothing.
        #expect(rig.sync.listing?.state == "0788123456|Shima Serein|")
        rig.publicKey.key = RequestSeal.publicKey(of: RequestSeal.makeKey())
        rig.sync.ownerChanged(at: noon)
        await rig.sync.settle()
        try #require(rig.server.listings.count == 2)
        #expect(rig.server.listings[1]?.key == rig.publicKey.key)
        // Requests off again: the key goes from the listing.
        rig.publicKey.key = nil
        rig.sync.ownerChanged(at: noon)
        await rig.sync.settle()
        #expect(rig.server.listings.count == 3 && rig.server.listings[2]?.key == nil)
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

    @Test func showMyNameOffClearsTheListing() async throws {
        let rig = Rig()
        rig.sync.ownerChanged(at: noon)
        await rig.sync.settle()
        rig.defaults.set(false, forKey: Preferences.showMyName.key)
        rig.sync.ownerChanged(at: noon)
        await rig.sync.settle()
        #expect(rig.server.listings.count == 2)
        let last = try #require(rig.server.listings.last)
        #expect(last == nil)
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
        let last = try #require(rig.server.listings.last)
        #expect(last == nil)
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

    // MARK: Push

    private let token = PushToken(hex: "ab01", sandbox: false)
    private let newToken = PushToken(hex: "cd02", sandbox: false)

    @Test func theTokenIsOnTheServerOnlyWhileTheOwnerTakesRequestsAndWantsWordOfThem() {
        let week = 7 * 86_400.0
        func step(
            _ token: PushToken?, _ listing: ServerSync.ListingForPush, notifies: Bool = true,
            sent: PushToken? = nil, sentAt: Date? = nil, now: Date? = nil
        ) -> ServerSync.PushStep {
            ServerSync.pushStep(
                token: token, listing: listing, notifies: notifies, sent: sent, sentAt: sentAt ?? noon, now: now ?? noon
            )
        }
        #expect(step(token, .takesRequests) == .register(token, replacing: nil))
        #expect(step(token, .takesRequests, sent: token) == .keep)
        // A week on, it goes again so the server never lets it lapse.
        #expect(step(token, .takesRequests, sent: token, now: noon.addingTimeInterval(week - 60)) == .keep)
        #expect(step(token, .takesRequests, sent: token, now: noon.addingTimeInterval(week + 60)) == .register(token, replacing: nil))
        // A new token replaces the old one there.
        #expect(step(newToken, .takesRequests, sent: token) == .register(newToken, replacing: "ab01"))
        // The same token, from the other service.
        let sandboxed = PushToken(hex: "ab01", sandbox: true)
        #expect(step(sandboxed, .takesRequests, sent: token) == .register(sandboxed, replacing: nil))
        // A listing on its way: the token waits for it, whatever was sent.
        #expect(step(token, .onItsWay) == .keep)
        #expect(step(nil, .onItsWay, sent: token) == .keep)
        // No push in this build, no listing, or no word of requests wanted:
        // what was sent goes, and nothing is sent when nothing was.
        #expect(step(nil, .takesRequests, sent: token) == .remove("ab01"))
        #expect(step(token, .notTaking, sent: token) == .remove("ab01"))
        #expect(step(token, .takesRequests, notifies: false, sent: token) == .remove("ab01"))
        #expect(step(nil, .notTaking) == .keep)
        #expect(step(token, .takesRequests, notifies: false) == .keep)
    }

    /// A rig listed with the key requests are sealed to, in a build with push.
    private func pushRig() -> Rig {
        let rig = Rig(push: true)
        rig.publicKey.key = RequestSeal.publicKey(of: RequestSeal.makeKey())
        return rig
    }

    @Test func theTokenGoesOnceTheServerHasTheListing() async {
        let rig = pushRig()
        rig.server.takesListings = false
        rig.sync.pushTokenReceived(token, at: noon)
        rig.sync.ownerChanged(at: noon)
        await rig.sync.settle()
        // The server takes a token only from a key it lists.
        #expect(rig.server.push.isEmpty)
        rig.server.takesListings = true
        rig.sync.wake(at: noon)
        await rig.sync.settle()
        #expect(rig.server.listings.count == 2 && rig.server.push == ["+ab01"])
        // Sent once.
        rig.sync.wake(at: noon)
        rig.sync.pushTokenReceived(token, at: noon)
        await rig.sync.settle()
        #expect(rig.server.push == ["+ab01"])
    }

    @Test func aTokenThatComesAfterTheListingGoesStraightAway() async {
        let rig = pushRig()
        rig.sync.ownerChanged(at: noon)
        await rig.sync.settle()
        #expect(rig.server.push.isEmpty)
        rig.sync.pushTokenReceived(token, at: noon)
        await rig.sync.settle()
        #expect(rig.server.push == ["+ab01"])
        rig.sync.pushTokenReceived(newToken, at: noon)
        await rig.sync.settle()
        #expect(rig.server.push == ["+ab01", "+cd02-ab01"])
    }

    @Test func noTokenGoesWithoutRequestsFromAnywhere() async {
        let rig = Rig(push: true)
        rig.sync.pushTokenReceived(token, at: noon)
        rig.sync.ownerChanged(at: noon)
        await rig.sync.settle()
        #expect(rig.server.listings.count == 1 && rig.server.push.isEmpty)
    }

    @Test func noTokenGoesFromABuildWithoutPush() async {
        let rig = Rig()
        rig.publicKey.key = RequestSeal.publicKey(of: RequestSeal.makeKey())
        rig.sync.pushTokenReceived(token, at: noon)
        rig.sync.ownerChanged(at: noon)
        await rig.sync.settle()
        #expect(rig.server.push.isEmpty)
    }

    @Test func aBuildWithoutPushRemovesTheTokenAnEarlierOneSent() async {
        let pushed = pushRig()
        pushed.sync.pushTokenReceived(token, at: noon)
        pushed.sync.ownerChanged(at: noon)
        await pushed.sync.settle()
        #expect(pushed.server.push == ["+ab01"])
        // The next build, with the switch off, on the same settings.
        let server = FakeServer()
        let owner = Owner(defaults: pushed.defaults)
        let key = pushed.publicKey.key
        let next = ServerSync(
            server: server, key: { "key" }, owner: owner, photo: { nil }, hasPhoto: { false }, publicKey: { key },
            defaults: pushed.defaults, version: "1.1.1", isSimulator: false
        )
        next.wake(at: noon)
        await next.settle()
        #expect(server.push == ["-ab01"])
        next.wake(at: noon)
        await next.settle()
        #expect(server.push == ["-ab01"])
    }

    @Test func showMyNameOffRemovesTheToken() async {
        let rig = pushRig()
        rig.sync.pushTokenReceived(token, at: noon)
        rig.sync.ownerChanged(at: noon)
        await rig.sync.settle()
        rig.defaults.set(false, forKey: Preferences.showMyName.key)
        rig.sync.ownerChanged(at: noon)
        await rig.sync.settle()
        #expect(rig.server.push == ["+ab01", "-ab01"])
        // Back on: it goes again with the listing.
        rig.defaults.set(true, forKey: Preferences.showMyName.key)
        rig.sync.ownerChanged(at: noon)
        await rig.sync.settle()
        #expect(rig.server.push == ["+ab01", "-ab01", "+ab01"])
    }

    @Test func requestNotificationsOffRemovesTheToken() async {
        let rig = pushRig()
        rig.sync.pushTokenReceived(token, at: noon)
        rig.sync.ownerChanged(at: noon)
        await rig.sync.settle()
        rig.defaults.set(false, forKey: Preferences.requestNotifications.key)
        rig.sync.requestNotificationsChanged(at: noon)
        await rig.sync.settle()
        #expect(rig.server.push == ["+ab01", "-ab01"])
        rig.defaults.set(true, forKey: Preferences.requestNotifications.key)
        rig.sync.requestNotificationsChanged(at: noon)
        await rig.sync.settle()
        #expect(rig.server.push == ["+ab01", "-ab01", "+ab01"])
    }

    @Test func aTokenRemovalTheServerDidNotTakeGoesAgain() async {
        let rig = pushRig()
        rig.sync.pushTokenReceived(token, at: noon)
        rig.sync.ownerChanged(at: noon)
        await rig.sync.settle()
        rig.server.takesPush = false
        rig.defaults.set(false, forKey: Preferences.showMyName.key)
        rig.sync.ownerChanged(at: noon)
        await rig.sync.settle()
        rig.server.takesPush = true
        rig.sync.wake(at: noon)
        await rig.sync.settle()
        rig.sync.wake(at: noon)
        await rig.sync.settle()
        #expect(rig.server.push == ["+ab01", "-ab01", "-ab01"])
    }

    @Test func theTokenGoesAgainAfterAWeek() async {
        let rig = pushRig()
        rig.sync.pushTokenReceived(token, at: noon)
        rig.sync.ownerChanged(at: noon)
        await rig.sync.settle()
        rig.sync.wake(at: noon.addingTimeInterval(6 * 86_400))
        await rig.sync.settle()
        #expect(rig.server.push == ["+ab01"])
        rig.sync.wake(at: noon.addingTimeInterval(8 * 86_400))
        await rig.sync.settle()
        #expect(rig.server.listings.count == 2 && rig.server.push == ["+ab01", "+ab01"])
    }

    @Test func eraseRemovesTheTokenAndKeepsItForTheNextListing() async {
        let rig = pushRig()
        rig.sync.pushTokenReceived(token, at: noon)
        rig.sync.ownerChanged(at: noon)
        await rig.sync.settle()
        rig.sync.erase { rig.wipe() }
        await rig.sync.settle()
        #expect(rig.server.push == ["+ab01", "-ab01"])
        let last = rig.server.listings.last
        #expect(last == .some(nil))
        // Set up again: the token iOS gave this run goes with the new listing.
        rig.owner.setName("Shima")
        _ = rig.owner.setNumber("0788123456")
        rig.sync.ownerChanged(at: noon)
        await rig.sync.settle()
        #expect(rig.server.push == ["+ab01", "-ab01", "+ab01"])
    }

    @Test func theSimulatorNeverSendsAToken() async {
        let rig = Rig(isSimulator: true, push: true)
        rig.publicKey.key = RequestSeal.publicKey(of: RequestSeal.makeKey())
        rig.sync.pushTokenReceived(token, at: noon)
        rig.sync.wake(at: noon)
        await rig.sync.settle()
        #expect(rig.server.push.isEmpty)
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
