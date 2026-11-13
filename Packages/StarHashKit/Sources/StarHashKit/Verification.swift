import Foundation

/// What a wallet message pasted into Verify did to the payment it was
/// pasted for (`StarHashStore.verify(_:withMessage:)`).
public enum Verification: Hashable, Sendable {
    /// It says the payment went through: confirmed, with the message's
    /// fee, reference and balance.
    case confirmed(Transaction)
    /// It says the payment did not go through: failed, for that reason.
    case failed(Transaction)
    /// MoMoAdvance's, about this payment: its access fee joined the
    /// payment, whose own message still confirms it.
    case overdraft(Transaction)
    /// A wallet's message about another movement: what it moved, and to
    /// whom when it says (MoMoAdvance's does not).
    case anotherPayment(amount: Int, counterparty: Recipient?)
    /// It already confirmed another payment dialled from StarHash.
    case confirmedAnother(Transaction)
    /// Not an MTN MoMo or Airtel Money transaction message.
    case notAMessage
}
