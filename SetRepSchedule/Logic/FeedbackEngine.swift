import AVFoundation
import CoreHaptics

/// Plays haptic and audio feedback for workout events.
enum FeedbackEngine {
    enum Event {
        case rep(Bool)
        case startTimer, abortTimer, completeTimer(Bool)
    }

    private static var hapticEngine: CHHapticEngine?
    private static var chimePlayer: AVAudioPlayer?

    private static let chimeData = makeChimeData(
        format: AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44100,
            channels: 1,
            interleaved: false
        )!
    )

    static func prepare() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let e = try CHHapticEngine()
            e.isAutoShutdownEnabled = true
            try e.start()
            hapticEngine = e
        } catch {
            hapticEngine = nil
        }
    }

    static func playFeedback(for event: Event, isMuted: Bool) {
        let hapticEvents: [CHHapticEvent] = switch event {
        case .rep(false): [
            transient(intensity: 1.0, sharpness: 0.5, at: 0),
            transient(intensity: 1.0, sharpness: 0.5, at: 0.2),
        ]
        case .rep(true): [
            continuous(intensity: 0.6, sharpness: 0.2, attack: 0.25, release: 0.05, at: 0, duration: 0.4),
            transient(intensity: 1.0, sharpness: 0.7, at: 0.5),
            transient(intensity: 1.0, sharpness: 0.7, at: 0.75),
            transient(intensity: 1.0, sharpness: 0.7, at: 1.0),
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
        }

        if !hapticEvents.isEmpty {
            play(hapticEvents)
        }

        switch event {
        case .completeTimer:
            if !isMuted { playChime() }
        default:
            break
        }
    }

    // MARK: - Chime

    private static func playChime() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: .mixWithOthers)
        try? session.setActive(true)

        chimePlayer = try? AVAudioPlayer(data: chimeData, fileTypeHint: AVFileType.caf.rawValue)
        chimePlayer?.play()
    }

    private static func makeChimeData(format: AVAudioFormat) -> Data {
        let sampleRate = format.sampleRate
        let duration = 1.2
        let frameCount = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: frameCount)

        let partials: [(freq: Double, amp: Double, decay: Double)] = [
            (880.0,  1.0,  4.0),
            (2637.0, 0.5,  6.0),
            (1320.0, 0.35, 8.0),
        ]

        for (freq, amp, decay) in partials {
            for i in 0..<frameCount {
                let t = Double(i) / sampleRate
                samples[i] += Float(amp * exp(-decay * t) * sin(2 * .pi * freq * t))
            }
        }

        let peak = samples.map({ abs($0) }).max() ?? 1
        let scale = Float(0.9) / peak
        samples = samples.map { $0 * scale }

        return cafData(samples: samples, sampleRate: sampleRate)
    }

    private static func cafData(samples: [Float], sampleRate: Double) -> Data {
        var data = Data()

        func appendUInt16BE(_ v: UInt16) { var x = v.bigEndian; data.append(contentsOf: withUnsafeBytes(of: &x) { Array($0) }) }
        func appendUInt32BE(_ v: UInt32) { var x = v.bigEndian; data.append(contentsOf: withUnsafeBytes(of: &x) { Array($0) }) }
        func appendInt64BE(_ v: Int64)   { var x = v.bigEndian; data.append(contentsOf: withUnsafeBytes(of: &x) { Array($0) }) }
        func appendFloat64BE(_ v: Double){ var x = v.bitPattern.bigEndian; data.append(contentsOf: withUnsafeBytes(of: &x) { Array($0) }) }
        func appendFourCC(_ s: String)   { data.append(contentsOf: s.utf8.prefix(4)) }

        appendFourCC("caff")
        appendUInt16BE(1)
        appendUInt16BE(0)

        appendFourCC("desc")
        appendInt64BE(32)
        appendFloat64BE(sampleRate)
        appendFourCC("lpcm")
        appendUInt32BE(1)
        appendUInt32BE(4)
        appendUInt32BE(1)
        appendUInt32BE(1)
        appendUInt32BE(32)

        var beData = Data(count: samples.count * 4)
        beData.withUnsafeMutableBytes { ptr in
            let floats = ptr.bindMemory(to: UInt32.self)
            for (i, s) in samples.enumerated() {
                floats[i] = s.bitPattern.bigEndian
            }
        }

        appendFourCC("data")
        appendInt64BE(Int64(beData.count) + 4)
        appendUInt32BE(0)
        data.append(beData)

        return data
    }

    // MARK: - Haptics

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
        if hapticEngine == nil { prepare() }
        guard let hapticEngine else { return }
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try hapticEngine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Haptics are best-effort; ignore failures.
        }
    }
}
