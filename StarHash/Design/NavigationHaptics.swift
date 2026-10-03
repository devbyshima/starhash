import CoreHaptics
import UIKit

/// The weight of moving between pages, felt in layers that follow the tab
/// bar's lens: a doubled thump at full strength with a full-strength
/// rumble under it as the page changes, a second heavy hit with its own
/// rumble as the lens lands at the top of its overshoot, and a lighter one
/// as it settles back. No sharpness to speak of, so it lands as weight
/// rather than a click. A knock with a little body marks each symbol a
/// dragged lens passes. Phones without Core Haptics get a heavy impact.
@MainActor
final class NavigationHaptics {
    static let shared = NavigationHaptics()

    private var engine: CHHapticEngine?
    private var switchPattern: CHHapticPattern?
    private var settledSwitchPattern: CHHapticPattern?
    private var passPattern: CHHapticPattern?
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)

    /// When the lens's spring (response 0.4, damping 0.61) reaches the top
    /// of its overshoot, and when it swings back past its mark.
    private static let landing: TimeInterval = 0.25
    private static let settling: TimeInterval = 0.5

    private init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        switchPattern = try? Self.switchPattern(withLanding: true)
        settledSwitchPattern = try? Self.switchPattern(withLanding: false)
        passPattern = try? CHHapticPattern(events: [
            Self.transient(at: 0, intensity: 0.85, sharpness: 0.1),
            Self.rumble(at: 0, intensity: 0.5, fadingOver: 0.06),
        ], parameters: [])
    }

    /// Starts the engine early, without waiting on it, so the first switch
    /// is neither late nor held up starting it.
    func prepare() {
        heavy.prepare()
        guard engine == nil, switchPattern != nil else { return }
        makeEngine()
    }

    /// A page change from the tab bar or the Pay and Buy switcher.
    /// `landsWithLens` false (Reduce Motion, where the lens does not
    /// overshoot, and the switcher, which has no lens) keeps only the
    /// first layer.
    func switchPage(landsWithLens: Bool = true) {
        let pattern = landsWithLens ? switchPattern : settledSwitchPattern
        if !play(pattern) { heavy.impactOccurred(intensity: 1) }
    }

    /// The lens, dragged, passing over another symbol.
    func passSymbol() {
        if !play(passPattern) { heavy.impactOccurred(intensity: 0.8) }
    }

    // MARK: Engine

    /// Never waits on the engine: a player starts it again by itself after
    /// an idle shutdown, and if that fails (a reset, the app sent to the
    /// background) this tap gets the plain impact while a new engine
    /// starts for the next.
    private func play(_ pattern: CHHapticPattern?) -> Bool {
        guard let pattern, let engine else {
            if switchPattern != nil, engine == nil { makeEngine() }
            return false
        }
        do {
            try engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            makeEngine()
            return false
        }
    }

    private func makeEngine() {
        guard let engine = try? CHHapticEngine() else { return }
        engine.playsHapticsOnly = true
        engine.isAutoShutdownEnabled = true
        engine.resetHandler = { [weak self] in
            Task { @MainActor in self?.makeEngine() }
        }
        engine.start { _ in }
        self.engine = engine
    }

    // MARK: Patterns

    private static func switchPattern(withLanding: Bool) throws -> CHHapticPattern {
        var events = [
            // The thump: full strength and dull, struck twice 16ms apart so
            // it lands as one heavier blow.
            transient(at: 0, intensity: 1, sharpness: 0.05),
            transient(at: 0.016, intensity: 1, sharpness: 0),
            // Its weight: a full-strength low rumble under it, dying away
            // over 0.22s.
            rumble(at: 0, intensity: 1, fadingOver: 0.22),
        ]
        if withLanding {
            events.append(transient(at: landing, intensity: 0.95, sharpness: 0.05))
            events.append(rumble(at: landing, intensity: 0.7, fadingOver: 0.1))
            events.append(transient(at: settling, intensity: 0.5, sharpness: 0))
        }
        return try CHHapticPattern(events: events, parameters: [])
    }

    /// A low continuous buzz that starts at `intensity` and dies away.
    private static func rumble(at time: TimeInterval, intensity: Float, fadingOver decay: TimeInterval) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0),
                CHHapticEventParameter(parameterID: .sustained, value: 0),
                CHHapticEventParameter(parameterID: .decayTime, value: Float(decay)),
            ],
            relativeTime: time,
            duration: decay + 0.02
        )
    }

    private static func transient(at time: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: time
        )
    }
}
