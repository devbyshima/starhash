import SwiftUI

/// A person with no photo: one of DiceBear's "Shadows" silhouettes (a
/// bust in one ink, CC0 1.0, fetched by `scripts/make_avatars.py`), picked
/// by `seed` so the same person always wears the same one. The drawings are
/// template images, so they take the foreground style: StarHash's own
/// greys, never DiceBear's colours.
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

    /// FNV-1a over the seed's bytes rather than `hashValue`, which Swift
    /// seeds afresh on every launch: a person must keep their silhouette.
    static func assetName(for seed: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        let index = Int(hash % UInt64(count)) + 1
        return index < 10 ? "Shadow0\(index)" : "Shadow\(index)"
    }
}
