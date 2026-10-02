import StarHashKit
import SwiftUI

@main
struct StarHashApp: App {
    @Environment(\.scenePhase) private var scenePhase

    private let store = AppEnvironment.store
    private let router = AppEnvironment.router

    init() {
        #if DEBUG
        if DebugLaunch.arguments.contains("-skipOnboarding") {
            UserDefaults.standard.set(true, forKey: PreferenceKey.hasOnboarded)
            // Onboarding asks for the number; skipping it needs one.
            if (UserDefaults.standard.string(forKey: PreferenceKey.ownerNumber) ?? "").isEmpty {
                UserDefaults.standard.set("0781234567", forKey: PreferenceKey.ownerNumber)
            }
        }
        if DebugLaunch.arguments.contains("-resetOnboarding") {
            UserDefaults.standard.set(false, forKey: PreferenceKey.hasOnboarded)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(router)
                .tint(Color.starhashInk)
                .onOpenURL { router.handle($0) }
        }
        .onChange(of: scenePhase) { _, phase in
            // The Process Carrier SMS shortcut may have written while we
            // were in the background.
            if phase == .active { store.reloadFromDisk() }
        }
    }
}
