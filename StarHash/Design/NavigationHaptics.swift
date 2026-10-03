import CoreHaptics
import UIKit

/// The weight of moving between pages, felt once, as the page changes: a
/// doubled thump at full strength with a full-strength rumble under it.
/// No sharpness to speak of, so it lands as weight rather than a click.
/// The lens's bounce is seen, not felt. Phones without Core Haptics get a
/// heavy impact.
@MainActor
final class NavigationHaptics {
    static let shared = NavigationHaptics()

    private var engine: CHHapticEngine?
    private var switchPattern: CHHapticPattern?
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)

    private init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        switchPattern = try? Self.makeSwitchPattern()
    }

    /// Starts the engine early, without waiting on it, so the first switch
    /// is neither late nor held up starting it.
    func prepare() {
        heavy.prepare()
        guard engine == nil, switchPattern != nil else { return }
        makeEngine()
    }

    /// A page change from the tab bar or the Pay and Buy switcher.
    func switchPage() {
        if !play(switchPattern) { heavy.impactOccurred(intensity: 1) }
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

    private static func makeSwitchPattern() throws -> CHHapticPattern {
        let events = [
            // The thump: full strength and dull, struck twice 16ms apart so
            // it lands as one heavier blow.
            transient(at: 0, intensity: 1, sharpness: 0.05),
            transient(at: 0.016, intensity: 1, sharpness: 0),
            // Its weight: a full-strength low rumble under it, dying away
            // over 0.22s.
            rumble(at: 0, intensity: 1, fadingOver: 0.22),
        ]
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
