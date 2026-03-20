import AVFoundation
import CoreHaptics

enum FeedbackEngine {
    enum Event {
        case rep(Bool)
        case startTimer, abortTimer, completeTimer(Bool)
    }

    static func playFeedback(for event: Event, isMuted: Bool) {
        HapticFeedback.play(for: event)
        AudioFeedback.play(for: event, isMuted: isMuted)
    }
}

// MARK: - AudioFeedback

private enum AudioFeedback {
    private static var player: AVAudioPlayer?

    private static let sampleRate: Double = 44100
    private static let chime = makeChime(sampleRate: sampleRate)
    private static let risingChime = makeRisingChime(sampleRate: sampleRate)
    private static let click = makeClick(sampleRate: sampleRate)

    fileprivate static func play(for event: FeedbackEngine.Event, isMuted: Bool) {
        guard !isMuted else { return }
        
        switch event {
        case .completeTimer(false):
            play(chime)
        case .rep(true), .completeTimer(true):
            play(risingChime)
        case .rep(false), .startTimer:
            play(click)
        case .abortTimer:
            break
        }
    }

    private static func play(_ data: Data) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: .mixWithOthers)
        try? session.setActive(true)
        player = try? AVAudioPlayer(data: data, fileTypeHint: AVFileType.caf.rawValue)
        player?.play()
    }

    private static func makeRisingChime(sampleRate: Double) -> Data {
        let secondHitOffset = 0.15
        let totalDuration = secondHitOffset + 1.2  // enough room for the second hit to fully decay
        let frameCount = Int(sampleRate * totalDuration)
        var samples = [Float](repeating: 0, count: frameCount)

        // Each hit: (offset, scale, partials)
        // First hit: a fifth below (880Hz fundamental), quieter
        // Second hit: 1320Hz fundamental (3:2 ratio = perfect fifth above), full volume
        let hits: [(offset: Double, scale: Double, partials: [(freq: Double, amp: Double, decay: Double)])] = [
            (0.0, 0.4, [
                (880.0,  1.0,  4.0),
                (2640.0, 0.5,  6.0),
                (1760.0, 0.35, 8.0),
            ]),
            (secondHitOffset, 1.0, [
                (1320.0, 1.0,  4.0),
                (3960.0, 0.5,  6.0),
                (2640.0, 0.35, 8.0),
            ]),
        ]

        for (offset, scale, partials) in hits {
            for (freq, amp, decay) in partials {
                let start = Int(offset * sampleRate)
                for i in start..<frameCount {
                    let t = Double(i - start) / sampleRate
                    samples[i] += Float(scale * amp * exp(-decay * t) * sin(2 * .pi * freq * t))
                }
            }
        }

        let peak = samples.map({ abs($0) }).max() ?? 1
        let scale = Float(0.9) / peak
        samples = samples.map { $0 * scale }

        return cafData(samples: samples, sampleRate: sampleRate)
    }

    private static func makeClick(sampleRate: Double) -> Data {
        let duration = 0.08
        let frameCount = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: frameCount)

        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            samples[i] = Float(exp(-300.0 * t) * sin(2 * .pi * 1000.0 * t))
        }

        let peak = samples.map({ abs($0) }).max() ?? 1
        let scale = Float(0.9) / peak
        samples = samples.map { $0 * scale }

        return cafData(samples: samples, sampleRate: sampleRate)
    }

    private static func makeChime(sampleRate: Double) -> Data {
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
}

// MARK: - HapticFeedback

private enum HapticFeedback {
    private static var engine: CHHapticEngine?

    fileprivate static func play(for event: FeedbackEngine.Event) {
        prepare()
        guard let engine else { return }

        let events: [CHHapticEvent] = switch event {
        case .rep(false): [
            transient(intensity: 1.0, sharpness: 0.5, at: 0),
            transient(intensity: 1.0, sharpness: 0.5, at: 0.2),
        ]
        case .rep(true), .completeTimer(true): [
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
        case .completeTimer(false): [
            continuous(intensity: 0.6, sharpness: 0.2, attack: 0.25, release: 0.05, at: 0, duration: 0.4),
        ]
        }

        guard !events.isEmpty else { return }

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Haptics are best-effort; ignore failures.
        }
    }

    private static func prepare() {
        guard engine == nil, CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let e = try CHHapticEngine()
            e.isAutoShutdownEnabled = true
            try e.start()
            engine = e
        } catch {
            engine = nil
        }
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
}
