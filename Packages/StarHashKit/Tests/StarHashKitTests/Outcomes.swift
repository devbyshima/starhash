import Foundation
@testable import StarHashKit

// What an outcome carries, nil for any other outcome, so a test can
// `try #require` the one it expects and stop there when it is another.

extension Verification {
    var confirmed: Transaction? {
        if case .confirmed(let transaction) = self { transaction } else { nil }
    }

    var failed: Transaction? {
        if case .failed(let transaction) = self { transaction } else { nil }
    }

    var overdraft: Transaction? {
        if case .overdraft(let transaction) = self { transaction } else { nil }
    }

    var confirmedAnother: Transaction? {
        if case .confirmedAnother(let transaction) = self { transaction } else { nil }
    }

    var isAnotherPayment: Bool {
        if case .anotherPayment = self { true } else { false }
    }
}

extension AutoVerify.Outcome {
    var confirmed: (transaction: Transaction, wasFailed: Bool)? {
        if case .confirmed(let transaction, let wasFailed) = self { (transaction, wasFailed) } else { nil }
    }

    var added: Transaction? {
        if case .added(let transaction) = self { transaction } else { nil }
    }

    var scam: ScamWarning? {
        if case .scam(let warning) = self { warning } else { nil }
    }

    var failed: Transaction? {
        if case .failed(let transaction) = self { transaction } else { nil }
    }
}

extension StarHashStore.Applied {
    var added: Transaction? {
        if case .added(let transaction) = self { transaction } else { nil }
    }
}

extension StarHashLink {
    var payment: PaymentRequest? {
        if case .payment(let request) = self { request } else { nil }
    }
}
