import SwiftUI

/// A person with no photo: one of DiceBear's "Shadows" silhouettes (a
/// bust in one ink, CC0 1.0, fetched by `scripts/make_avatars.py`), handed
/// out at random. The draw is salted once per install, so who wears which
/// has nothing to do with their number, yet the same `seed` keeps its
/// silhouette on every screen and every launch. The drawings are template
/// images, so they take the foreground style: StarHash's own greys, never
/// DiceBear's colours.
struct ShadowAvatar: View {
    let seed: String

    var body: some View {
        Image(Self.assetName(for: seed))
            .resizable()
            .scaledToFit()
            .accessibilityHidden(true)
    }

    /// How many silhouettes the asset catalog holds (Shadow01...Shadow12).
    static let count = 12

    /// This install's draw, made the first time a silhouette is needed and
    /// kept (Delete All Data draws again).
    static let salt: UInt64 = {
        let key = "shadowAvatarSalt"
        if let saved = UserDefaults.standard.string(forKey: key), let salt = UInt64(saved) { return salt }
        let salt = UInt64.random(in: .min ... .max)
        UserDefaults.standard.set(String(salt), forKey: key)
        return salt
    }()

    /// FNV-1a over the salt and the seed's bytes rather than `hashValue`,
    /// which Swift seeds afresh on every launch: a person must keep their
    /// silhouette. The last stir carries the salt into the low bits that
    /// pick the drawing.
    static func assetName(for seed: String, salt: UInt64 = salt) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in withUnsafeBytes(of: salt.littleEndian, Array.init) + Array(seed.utf8) {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        hash ^= hash >> 33
        hash = hash &* 0xff51_afd7_ed55_8ccd
        hash ^= hash >> 33
        let index = Int(hash % UInt64(count)) + 1
        return index < 10 ? "Shadow0\(index)" : "Shadow\(index)"
    }
}
