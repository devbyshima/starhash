import StarHashKit
import SwiftUI

/// The owner's wallets (`OwnerWallets`) as a view's own value, worked out
/// afresh whenever a number, the count of SIMs or the wallet changes.
@propertyWrapper
struct OwnWallets: DynamicProperty {
    @AppStorage(PreferenceKey.profileNumber) private var profileNumber = ""
    @AppStorage(PreferenceKey.secondNumber) private var secondNumber = ""
    @AppStorage(PreferenceKey.simCount) private var simCount = 1
    @AppStorage(PreferenceKey.wallet) private var wallet: Recipient.Network = .mtn

    var wrappedValue: OwnerWallets {
        OwnerWallets(numbers: [profileNumber] + (simCount == 2 ? [secondNumber] : []), chosen: wallet)
    }
}
