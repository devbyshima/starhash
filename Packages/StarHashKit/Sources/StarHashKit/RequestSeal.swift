import CryptoKit
import Foundation

/// How a request travels through StarHash's server without the server
/// reading it: sealed on the asker's iPhone to the public key the other
/// person's iPhone listed (HPKE, X25519 with ChaCha20-Poly1305), and
/// authenticated by the asker's own key, so the iPhone that opens it knows
/// which key sealed it. The request's id is bound in, so a seal cannot be
/// passed off under another request. An answer goes back the same way.
///
/// Keys travel as base64 of their 32 raw bytes, and a seal as base64 of
/// the encapsulated key followed by the ciphertext.
public enum RequestSeal {
    public typealias PrivateKey = Curve25519.KeyAgreement.PrivateKey

    /// What a seal holds, kept apart so one is never opened as the other.
    public enum Purpose: Sendable {
        /// Someone asks for money: who, how much, what for.
        case ask
        /// The person asked answers.
        case answer

        var info: Data {
            switch self {
            case .ask: Data("StarHash request v1".utf8)
            case .answer: Data("StarHash answer v1".utf8)
            }
        }
    }

    private static let suite = HPKE.Ciphersuite.Curve25519_SHA256_ChachaPoly
    private static let encapsulatedKeySize = 32

    /// A new private key, made once on the iPhone.
    public static func makeKey() -> PrivateKey { PrivateKey() }

    /// The public half of `key`, as the directory lists it.
    public static func publicKey(of key: PrivateKey) -> String {
        key.publicKey.rawRepresentation.base64EncodedString()
    }

    /// A private key kept as its raw bytes, or nil when they are not one.
    public static func privateKey(raw: Data) -> PrivateKey? {
        try? PrivateKey(rawRepresentation: raw)
    }

    /// Whether `text` is a public key as the directory lists one.
    public static func isPublicKey(_ text: String) -> Bool {
        publicKey(text) != nil
    }

    /// `data` sealed for the holder of `recipient`'s private key, by
    /// `sender`; nil when `recipient` is no key.
    public static func seal(_ data: Data, id: UUID, purpose: Purpose, to recipient: String, from sender: PrivateKey) -> String? {
        guard let recipientKey = publicKey(recipient),
              var box = try? HPKE.Sender(recipientKey: recipientKey, ciphersuite: suite, info: purpose.info, authenticatedBy: sender),
              let sealed = try? box.seal(data, authenticating: aad(id)) else { return nil }
        return (box.encapsulatedKey + sealed).base64EncodedString()
    }

    /// What `sender` sealed for `key` under `id`, or nil when it was not
    /// sealed by `sender`, for `key`, for this purpose and id, or was
    /// changed on the way.
    public static func open(_ sealed: String, id: UUID, purpose: Purpose, with key: PrivateKey, from sender: String) -> Data? {
        guard let senderKey = publicKey(sender), let bytes = Data(base64Encoded: sealed),
              bytes.count > encapsulatedKeySize else { return nil }
        let encapsulated = bytes.prefix(encapsulatedKeySize)
        let ciphertext = bytes.dropFirst(encapsulatedKeySize)
        guard var box = try? HPKE.Recipient(
            privateKey: key, ciphersuite: suite, info: purpose.info, encapsulatedKey: Data(encapsulated), authenticatedBy: senderKey
        ) else { return nil }
        return try? box.open(Data(ciphertext), authenticating: aad(id))
    }

    private static func publicKey(_ text: String) -> Curve25519.KeyAgreement.PublicKey? {
        guard let raw = Data(base64Encoded: text), raw.count == 32 else { return nil }
        return try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: raw)
    }

    private static func aad(_ id: UUID) -> Data {
        Data(id.uuidString.lowercased().utf8)
    }
}
