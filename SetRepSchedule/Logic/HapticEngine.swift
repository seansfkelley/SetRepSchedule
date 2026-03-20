import CoreHaptics

enum HapticEngine {
    enum Event {
        case completeRep, startTimer, abortTimer, completeTimer, completeSet
    }

    private static var engine: CHHapticEngine?

    static func prepare() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let e = try CHHapticEngine()
            e.isAutoShutdownEnabled = true
            try e.start()
            engine = e
        } catch {
            engine = nil
        }
    }

    static func playFeedback(for event: Event) {
        let haptic = switch event {
        case .completeRep: [
            transient(intensity: 1.0, sharpness: 0.5, at: 0),
            transient(intensity: 1.0, sharpness: 0.5, at: 0.2),
        ]
        case .startTimer: [
            transient(intensity: 1.0, sharpness: 1.0, at: 0),
            transient(intensity: 1.0, sharpness: 1.0, at: 0.25),
            transient(intensity: 1.0, sharpness: 1.0, at: 0.5),
        ]
        case .abortTimer: [
            continuous(intensity: 1.0, sharpness: 0.8, decay: 0.5, sustained: 0, at: 0, duration: 0.6),
        ]
        case .completeTimer: [
            continuous(intensity: 0.6, sharpness: 0.2, attack: 0.25, release: 0.05, at: 0, duration: 0.4),
        ]
        case .completeSet: [
            continuous(intensity: 0.6, sharpness: 0.2, attack: 0.25, release: 0.05, at: 0, duration: 0.4),
            transient(intensity: 1.0, sharpness: 0.7, at: 0.5),
            transient(intensity: 1.0, sharpness: 0.7, at: 0.75),
            transient(intensity: 1.0, sharpness: 0.7, at: 1.0),
        ]
        }

        play(haptic)
    }

    private static func continuous(
        intensity: Float,
        sharpness: Float,
        attack: Float = 0,
        decay: Float = 0,
        release: Float = 0,
        sustained: Float = 1,
        at time: TimeInterval,
        duration: TimeInterval
    ) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
                CHHapticEventParameter(parameterID: .attackTime, value: attack),
                CHHapticEventParameter(parameterID: .decayTime, value: decay),
                CHHapticEventParameter(parameterID: .releaseTime, value: release),
                CHHapticEventParameter(parameterID: .sustained, value: sustained)
            ],
            relativeTime: time,
            duration: duration
        )
    }

    private static func transient(intensity: Float, sharpness: Float, at time: TimeInterval) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: time
        )
    }

    private static func play(_ events: [CHHapticEvent]) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        if engine == nil { prepare() }
        guard let engine else { return }
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Haptics are best-effort; ignore failures.
        }
    }
}
