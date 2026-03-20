import AVFoundation

/// Plays a synthesized chime sound that bypasses the ringer/silent switch.
enum Chime {
    private static var player: AVAudioPlayer?

    private static let chimeData = Self.makeChimeData(
        format: AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44100,
            channels: 1,
            interleaved: false,
        )!
    )

    static func play() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: .mixWithOthers)
        try? session.setActive(true)

        player = try? AVAudioPlayer(data: chimeData, fileTypeHint: AVFileType.caf.rawValue)
        player?.play()
    }

    private static func makeChimeData(format: AVAudioFormat) -> Data {
        let sampleRate = format.sampleRate
        let duration = 1.2
        let frameCount = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: frameCount)

        // Partials: (frequency Hz, relative amplitude, decay rate)
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

        // Wrap as a CAF file so AVAudioPlayer can decode it
        return cafData(samples: samples, sampleRate: sampleRate)
    }

    // Builds a minimal CAF container around big-endian Float32 PCM.
    private static func cafData(samples: [Float], sampleRate: Double) -> Data {
        var data = Data()

        func appendUInt16BE(_ v: UInt16) { var x = v.bigEndian; data.append(contentsOf: withUnsafeBytes(of: &x) { Array($0) }) }
        func appendUInt32BE(_ v: UInt32) { var x = v.bigEndian; data.append(contentsOf: withUnsafeBytes(of: &x) { Array($0) }) }
        func appendInt64BE(_ v: Int64)   { var x = v.bigEndian; data.append(contentsOf: withUnsafeBytes(of: &x) { Array($0) }) }
        func appendFloat64BE(_ v: Double){ var x = v.bitPattern.bigEndian; data.append(contentsOf: withUnsafeBytes(of: &x) { Array($0) }) }
        func appendFourCC(_ s: String)   { data.append(contentsOf: s.utf8.prefix(4)) }

        // CAF file header: 'caff', version=1, flags=0
        appendFourCC("caff")
        appendUInt16BE(1)
        appendUInt16BE(0)

        // "desc" chunk (32 bytes)
        appendFourCC("desc")
        appendInt64BE(32)
        appendFloat64BE(sampleRate)
        appendFourCC("lpcm")
        appendUInt32BE(1)  // kCAFLinearPCMFormatFlagIsFloat, big-endian (no flag needed)
        appendUInt32BE(4)  // bytes per packet
        appendUInt32BE(1)  // frames per packet
        appendUInt32BE(1)  // channels per frame
        appendUInt32BE(32) // bits per channel

        // Convert samples to big-endian floats
        var beData = Data(count: samples.count * 4)
        beData.withUnsafeMutableBytes { ptr in
            let floats = ptr.bindMemory(to: UInt32.self)
            for (i, s) in samples.enumerated() {
                floats[i] = s.bitPattern.bigEndian
            }
        }

        // "data" chunk
        appendFourCC("data")
        appendInt64BE(Int64(beData.count) + 4)
        appendUInt32BE(0) // edit count
        data.append(beData)

        return data
    }
}
