import Foundation
import Testing
@testable import StarHashKit

@MainActor
@Suite("The owner")
struct OwnerTests {
    private let mtn = Recipient.ownNumber("0788123456")!
    private let airtel = Recipient.ownNumber("0722123456")!

    private func freshDefaults() -> UserDefaults {
        let name = "OwnerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    /// An owner with two SIMs, both numbers in, paying from `wallet`.
    private func twoSIMs(_ number: String, _ other: String, wallet: Recipient.Network, defaults: UserDefaults? = nil) -> Owner {
        let owner = Owner(defaults: defaults ?? freshDefaults())
        owner.choose(wallet)
        owner.setNumber(number)
        owner.useTwoSIMs()
        owner.setOtherNumber(other)
        return owner
    }

    /// Profile and Settings say the same thing about a number, because
    /// `Owner` says it.
    @Test func aNumberRefusedSaysWhy() {
        let owner = twoSIMs("0788123456", "0791234567", wallet: .mtn)
        #expect(owner.problem(withNumber: "0788 12") == nil)
        #expect(owner.problem(withNumber: "0252 123 456") == .notRwandanMobile)
        #expect(owner.problem(withNumber: "0791 234 567") == .otherSIMsNumber)
        #expect(owner.problem(withOtherNumber: "0252123456") == .notRwandanMobile)
        #expect(owner.problem(withOtherNumber: "+250 788 123 456") == .defaultSIMsNumber)
        #expect(owner.problem(withOtherNumber: "0722123456") == nil)
    }

    /// With one SIM, a number on the other carrier is kept, and warned about.
    @Test func oneSIMOnTheOtherCarrierIsWarnedAbout() {
        let owner = Owner(defaults: freshDefaults())
        owner.choose(.mtn)
        #expect(owner.setNumber("0722123456"))
        #expect(owner.problem(withNumber: "0722123456") == .otherCarrier(.airtel, wallet: .mtn))
    }

    @Test func onlyAWholeNumberIsKept() {
        let defaults = freshDefaults()
        let owner = Owner(defaults: defaults)
        #expect(!owner.setNumber("0788 12"))
        #expect(owner.defaultSIM == nil)
        #expect(owner.setNumber("0788 123 456"))
        #expect(owner.defaultSIM?.destination == "0788123456")
        #expect(defaults.string(forKey: "profileNumber") == "0788123456")
        // Half typed again: the whole one stays until the field is empty.
        owner.setNumber("0788 1")
        #expect(owner.defaultSIM?.destination == "0788123456")
        owner.setNumber("")
        #expect(owner.defaultSIM == nil)
    }

    @Test func theOtherNumberWaitsForTwoSIMs() {
        let owner = Owner(defaults: freshDefaults())
        #expect(!owner.setOtherNumber("0722 123 456"))
        owner.useTwoSIMs()
        #expect(owner.usesTwoSIMs)
        #expect(owner.otherSIM == nil)
        #expect(owner.setOtherNumber("0722 123 456"))
        #expect(owner.otherSIM?.destination == "0722123456")
    }

    @Test func theOtherNumberIsNeverTheDefaultOne() {
        let owner = Owner(defaults: freshDefaults())
        owner.setNumber("0788123456")
        owner.useTwoSIMs()
        // However it is written, the default's number is refused.
        #expect(owner.isDefaultNumber("+250 788 123 456"))
        #expect(!owner.setOtherNumber("+250 788 123 456"))
        #expect(!owner.setOtherNumber("0788 123 456"))
        #expect(owner.otherSIM == nil)
        #expect(owner.setOtherNumber("0722 123 456"))
        // Nor can the default become the other's.
        #expect(owner.isOtherNumber("0722123456"))
        #expect(!owner.setNumber("0722123456"))
        #expect(owner.defaultSIM?.destination == "0788123456")
        #expect(owner.otherSIM?.destination == "0722123456")
    }

    @Test func oneNumberKeptTwiceIsReadAsOne() {
        let defaults = freshDefaults()
        defaults.set("0788123456", forKey: "profileNumber")
        defaults.set("0788 123 456", forKey: "secondNumber")
        defaults.set(2, forKey: "simCount")
        let owner = Owner(defaults: defaults)
        #expect(owner.defaultSIM?.destination == "0788123456")
        #expect(owner.otherSIM == nil)

        let restored = Owner(defaults: freshDefaults())
        restored.restore(OwnerProfile(name: "Shima", number: "0788123456", otherNumber: "0788123456"))
        #expect(restored.otherSIM == nil)
        #expect(!restored.usesTwoSIMs)
    }

    @Test func numbersSavedSpacedStillRead() {
        // Settings kept the other SIM's number as it showed it.
        let defaults = freshDefaults()
        defaults.set("0788123456", forKey: "profileNumber")
        defaults.set("0791 234 567", forKey: "secondNumber")
        defaults.set(2, forKey: "simCount")
        defaults.set("mtn", forKey: "wallet")
        let owner = Owner(defaults: defaults)
        #expect(owner.otherSIM?.destination == "0791234567")
        #expect(owner.wallets.hasTwoSIMs)
    }

    @Test func choosingTheOtherSIMTradesTheNumbers() {
        let defaults = freshDefaults()
        let owner = twoSIMs("0788123456", "0722123456", wallet: .mtn, defaults: defaults)
        let airtelWallet = owner.wallets.wallets.first { $0.network == .airtel }!
        owner.choose(airtelWallet)
        #expect(owner.defaultSIM == airtel)
        #expect(owner.otherSIM == mtn)
        #expect(owner.wallet == .airtel)
        #expect(defaults.string(forKey: "profileNumber") == "0722123456")
        #expect(defaults.string(forKey: "secondNumber") == "0788123456")
        // The default again changes nothing.
        owner.choose(airtelWallet)
        #expect(owner.defaultSIM == airtel)
    }

    @Test func twoSIMsOnOneCarrierKeepTheWallet() {
        let owner = twoSIMs("0788123456", "0791234567", wallet: .mtn)
        owner.choose(owner.wallets.wallets.first { $0.sim?.destination == "0791234567" }!)
        #expect(owner.defaultSIM?.destination == "0791234567")
        #expect(owner.otherSIM == mtn)
        #expect(owner.wallet == .mtn)
    }

    @Test func aWalletChosenBeforeTheDefaultMakesItsSIMTheDefault() {
        // Airtel Money chosen on Pay while the MTN SIM came first, saved
        // before StarHash kept the two in step.
        let defaults = freshDefaults()
        defaults.set("0788123456", forKey: "profileNumber")
        defaults.set("0722 123 456", forKey: "secondNumber")
        defaults.set(2, forKey: "simCount")
        defaults.set("airtel", forKey: "wallet")
        let owner = Owner(defaults: defaults)
        #expect(owner.defaultSIM == airtel)
        #expect(owner.otherSIM == mtn)
        #expect(owner.wallet == .airtel)
        #expect(defaults.string(forKey: "profileNumber") == "0722123456")
    }

    @Test func theWalletFollowsTheDefaultSIM() {
        // The default SIM's number changed to an Airtel one.
        let owner = twoSIMs("0788123456", "0791234567", wallet: .mtn)
        owner.setNumber("0733 123 456")
        #expect(owner.wallet == .airtel)
        #expect(owner.defaultSIM?.destination == "0733123456")
    }

    @Test func aWalletNeitherSIMIsOnGoesToTheDefaults() {
        // Airtel Money left chosen, and both SIMs on MTN.
        let owner = twoSIMs("0788123456", "0791234567", wallet: .mtn)
        owner.choose(.airtel)
        #expect(owner.defaultSIM == mtn)
        #expect(owner.wallet == .mtn)
    }

    @Test func oneSIMIsLeftAlone() {
        // One SIM on another carrier than the wallet is Profile's warning to
        // give, not a change to make: the owner may have a second SIM
        // StarHash does not know.
        let owner = Owner(defaults: freshDefaults())
        owner.choose(.airtel)
        #expect(owner.setNumber("0788123456"))
        #expect(owner.wallet == .airtel)
        #expect(owner.defaultSIMOnOtherCarrier == .mtn)
        // Nor before the other number is whole.
        owner.useTwoSIMs()
        owner.setOtherNumber("0722 12")
        #expect(owner.defaultSIM == mtn)
        #expect(owner.wallet == .airtel)
        // Once it is, the wallet follows the default SIM, as it does for
        // any new number with both in.
        owner.setOtherNumber("0722 123 456")
        #expect(owner.wallet == .mtn)
        #expect(owner.defaultSIMOnOtherCarrier == nil)
    }

    @Test func goingToOneSIMKeepsTheOneChosen() {
        let defaults = freshDefaults()
        let owner = twoSIMs("0788123456", "0722123456", wallet: .mtn, defaults: defaults)
        owner.useOneSIM(keeping: airtel)
        #expect(owner.defaultSIM == airtel)
        #expect(owner.otherSIM == nil)
        #expect(!owner.usesTwoSIMs)
        #expect(owner.wallet == .airtel)
        #expect(defaults.integer(forKey: "simCount") == 1)
        #expect(defaults.string(forKey: "secondNumber") == nil)
    }

    @Test func goingToOneSIMWithOneNumberKeepsIt() {
        // Only the other number in: it becomes the one SIM.
        let owner = Owner(defaults: freshDefaults())
        owner.choose(.mtn)
        owner.useTwoSIMs()
        owner.setOtherNumber("0722123456")
        owner.useOneSIM()
        #expect(owner.defaultSIM == airtel)
        #expect(owner.otherSIM == nil)
        // One SIM's carrier is not forced on the wallet.
        #expect(owner.wallet == .mtn)
    }

    @Test func theStoreHearsOnceForEachChangeToOwnAccounts() {
        let owner = Owner(defaults: freshDefaults())
        var heard = 0
        owner.onOwnAccountsChange = { heard += 1 }
        owner.choose(.mtn)
        owner.setNumber("0788123456")
        owner.setName("Shima")
        // With one SIM there are no own accounts to change.
        #expect(heard == 0)
        owner.useTwoSIMs()
        #expect(heard == 1)
        owner.setOtherNumber("0722123456")
        #expect(heard == 2)
        owner.setOtherNumber("0722 123 456")
        #expect(heard == 2)
        owner.setName("Shima Serein")
        #expect(heard == 3)
        // Trading the default SIM keeps the same two numbers.
        owner.choose(owner.wallets.wallets.first { $0.network == .airtel }!)
        #expect(heard == 3)
        owner.useOneSIM(keeping: mtn)
        #expect(heard == 4)
        #expect(owner.ownAccounts == nil)
    }

    @Test func aBackupFillsAnEmptyProfileAndBringsBackTwoSIMs() {
        let owner = Owner(defaults: freshDefaults())
        owner.choose(.mtn)
        var heard = 0
        owner.onOwnAccountsChange = { heard += 1 }
        let backup = OwnerProfile(name: "Shima", number: "0788123456", otherNumber: "0722 123 456")
        #expect(owner.restore(backup))
        #expect(owner.name == "Shima")
        #expect(owner.defaultSIM == mtn)
        #expect(owner.otherSIM == airtel)
        #expect(owner.usesTwoSIMs)
        #expect(heard == 1)
        // A profile already given stays.
        #expect(!owner.restore(OwnerProfile(name: "Someone", number: "0791234567")))
        #expect(owner.name == "Shima")
        #expect(owner.profile == OwnerProfile(name: "Shima", number: "0788123456", otherNumber: "0722123456"))
    }

    @Test func deleteAllDataIsReadAgain() {
        let name = "OwnerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        let owner = twoSIMs("0788123456", "0722123456", wallet: .mtn, defaults: defaults)
        owner.setName("Shima")
        var heard = 0
        owner.onOwnAccountsChange = { heard += 1 }
        defaults.removePersistentDomain(forName: name)
        owner.reload()
        #expect(owner.name.isEmpty)
        #expect(owner.defaultSIM == nil)
        #expect(owner.otherSIM == nil)
        #expect(!owner.usesTwoSIMs)
        #expect(owner.chosenWallet == nil)
        #expect(heard == 1)
        // Reading is all it does: nothing is written back.
        #expect(defaults.object(forKey: "simCount") == nil)
    }

    @Test func theCodeCarriesTheDefaultSIMUnderTheOwnersName() {
        let owner = Owner(defaults: freshDefaults())
        #expect(owner.codeRecipient == nil)
        owner.setName("  Shima  ")
        owner.setNumber("0788123456")
        #expect(owner.codeRecipient?.destination == "0788123456")
        #expect(owner.codeRecipient?.name == "Shima")
    }
}
