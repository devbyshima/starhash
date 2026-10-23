import Foundation

/// The language StarHash speaks, which the app sets from its own choice in
/// Settings rather than the iPhone's. Foundation's `String(localized:)`
/// reads the iPhone's language on every lookup and asks the bundle
/// nothing, so a choice made while StarHash runs would never reach it:
/// every string StarHash writes out goes through `String(starhash:)`,
/// which looks it up in this language instead.
public enum StarHashLanguage {
    /// Set on the main actor at launch and whenever the choice changes,
    /// read wherever a string is written out.
    nonisolated(unsafe) public static var locale: Locale = .autoupdatingCurrent
}

extension String {
    /// `String(localized:)` in the language chosen in StarHash. A literal
    /// passed here is a `LocalizedStringResource`, so Xcode still finds it
    /// for the string catalog.
    public init(starhash resource: LocalizedStringResource) {
        var resource = resource
        resource.locale = StarHashLanguage.locale
        self.init(localized: resource)
    }

    /// The kit's own strings, from its catalog rather than the app's.
    init(kit resource: LocalizedStringResource) {
        // A resource's bundle is fixed once made, so make it again in the
        // kit's: a literal's value is its key, with its values filled in.
        self.init(localized: LocalizedStringResource(
            resource.defaultValue,
            table: resource.table,
            locale: StarHashLanguage.locale,
            bundle: .atURL(Bundle.module.bundleURL)
        ))
    }
}
