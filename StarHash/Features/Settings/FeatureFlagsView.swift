import StarHashKit
import SwiftUI

/// Feature Flags, under About StarHash in dev and beta builds only: this
/// build's channel, then a switch for each flag, which starts where its
/// rollout puts it in this channel. The App Store build never shows the
/// page and ignores the switches (`ReleaseChannel.allowsOverrides`).
struct FeatureFlagsView: View {
    /// The switches as this page last saw them; each change writes through
    /// to UserDefaults, which `@FeatureFlagged` follows.
    @State private var overrides: [String: Bool] = Self.savedOverrides()

    var body: some View {
        SettingsScroll {
            SettingsCard {
                SettingsRow(
                    symbol: "shippingbox.fill",
                    title: "Channel",
                    caption: "Sets where each flag starts",
                    value: ReleaseChannel.current.title
                )
            }

            SettingsCard("Flags") {
                ForEach(FeatureFlag.all) { flag in
                    SettingsToggleRow(
                        symbol: "flag.fill",
                        title: flag.title,
                        caption: caption(for: flag),
                        isOn: binding(for: flag)
                    )
                }
            }

            if !overrides.isEmpty {
                SettingsCard {
                    Button {
                        FeatureFlags.resetOverrides()
                        withAnimation(.smooth) { overrides = [:] }
                    } label: {
                        SettingsRow(symbol: "arrow.counterclockwise", title: "Reset All", caption: "Every flag back to where its rollout puts it")
                    }
                    .buttonStyle(HighlightRowButtonStyle())
                }
                .transition(.opacity)
            }
        }
        .settingsPage("Feature Flags")
        .animation(.smooth, value: overrides.isEmpty)
    }

    /// What it does, and a word when this iPhone has switched it away from
    /// its rollout.
    private func caption(for flag: FeatureFlag) -> String {
        overrides[flag.key] == nil ? flag.detail : "\(flag.detail). Changed on this iPhone"
    }

    private func binding(for flag: FeatureFlag) -> Binding<Bool> {
        Binding {
            flag.isOn(in: .current, override: overrides[flag.key])
        } set: { isOn in
            // A switch put back to the rollout's state forgets itself, so
            // a later rollout change reaches this device too.
            let override: Bool? = isOn == flag.isOnByDefault(in: .current) ? nil : isOn
            if let override {
                UserDefaults.standard.set(override, forKey: flag.defaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: flag.defaultsKey)
            }
            overrides[flag.key] = override
        }
    }

    private static func savedOverrides() -> [String: Bool] {
        FeatureFlag.all.reduce(into: [:]) { saved, flag in
            saved[flag.key] = FeatureFlags.override(for: flag)
        }
    }
}
