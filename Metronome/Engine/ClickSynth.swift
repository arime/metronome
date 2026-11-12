import AVFoundation

/// Generates the click sounds (specification 11.1) at the output's own sample rate.
///
/// Each sound is built from decaying sines, an FM bell or filtered noise, then raised to a
/// fixed loudness through a soft limiter, so that every normal click is equally loud, every
/// accented click is 4 dB louder, and the clicks hold their own against music played at the
/// same system volume.
enum ClickSynth {
    /// RMS of every normal click over its first 20 ms, in dBFS.
    static let normalLevelDecibels = -11.0
    static let accentGainDecibels = 4.0
    /// The limiter leaves samples below the knee alone and bends everything above it
    /// smoothly towards the ceiling, which no sample reaches.
    static let limiterKnee = 0.5
    static let limiterCeiling = 0.95
    private static let loudnessWindow = 0.020
    private static let tailFade = 0.003

    static func click(_ sound: ClickSound, accented: Bool, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let synth = Synth(sampleRate: format.sampleRate)
        var raw = synth.make(sound, accented: accented)
        fadeTail(&raw, frames: synth.frames(tailFade))

        let decibels = normalLevelDecibels + (accented ? accentGainDecibels : 0)
        let samples = louden(raw, to: pow(10, decibels / 20), window: synth.frames(loudnessWindow))

        let frames = AVAudioFrameCount(samples.count)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channels = buffer.floatChannelData
        else { preconditionFailure("ClickSynth needs a float PCM format") }
        buffer.frameLength = frames
        for channel in 0..<Int(format.channelCount) {
            for (index, sample) in samples.enumerated() {
                channels[channel][index] = Float(sample)
            }
        }
        return buffer
    }

    /// Finds the gain that, after limiting, brings the RMS over the window to the target.
    /// Limiting only ever lowers a sample, so the level rises with the gain and a bisection
    /// on the gain in decibels finds it.
    private static func louden(_ samples: [Double], to target: Double, window: Int) -> [Double] {
        let measured = samples.prefix(window)
        let level = rms(measured)
        guard level > 0 else { return samples }
        var low = 20 * log10(target / level)
        var high = low + 40
        for _ in 0..<40 {
            let middle = (low + high) / 2
            let gain = pow(10, middle / 20)
            if rms(measured.map { limit($0 * gain) }[...]) < target {
                low = middle
            } else {
                high = middle
            }
        }
        let gain = pow(10, (low + high) / 40)
        return samples.map { limit($0 * gain) }
    }

    /// Unity below the knee; above it a tanh curve with the same slope at the knee that
    /// approaches the ceiling.
    static func limit(_ sample: Double) -> Double {
        let magnitude = abs(sample)
        guard magnitude > limiterKnee else { return sample }
        let range = limiterCeiling - limiterKnee
        let bent = limiterKnee + range * tanh((magnitude - limiterKnee) / range)
        return sample < 0 ? -bent : bent
    }

    private static func fadeTail(_ samples: inout [Double], frames: Int) {
        let count = min(frames, samples.count)
        guard count > 0 else { return }
        for step in 0..<count {
            samples[samples.count - 1 - step] *= Double(step) / Double(count)
        }
    }

    private static func rms(_ samples: ArraySlice<Double>) -> Double {
        guard !samples.isEmpty else { return 0 }
        return (samples.reduce(0) { $0 + $1 * $1 } / Double(samples.count)).squareRoot()
    }
}

/// The building blocks, at one sample rate. Times are in seconds, frequencies in hertz.
private struct Synth {
    let sampleRate: Double

    func frames(_ seconds: Double) -> Int {
        Int((seconds * sampleRate).rounded())
    }

    func make(_ sound: ClickSound, accented: Bool) -> [Double] {
        switch sound {
        case .digital:
            // Cosine phase, so the very first sample is the peak.
            return (0..<frames(0.030)).map { index in
                let time = Double(index) / sampleRate
                return exp(-time / 0.005) * cos(2 * .pi * (accented ? 1760 : 1175) * time)
            }
        case .softBeep:
            return accented
                ? modes([(1568, 1, 0.022)], length: 0.090, attack: 0.001)
                : modes([(1047, 1, 0.018)], length: 0.080, attack: 0.001)
        case .woodblock:
            let f = accented ? 1180.0 : 880.0
            let body = modes([(f, 1, 0.014), (f * 2.65, 0.45, 0.006), (f * 4.1, 0.15, 0.003)], length: 0.070)
            let strike = Biquad.bandPass(f * 3, q: 2, sampleRate: sampleRate)
                .apply(noiseBurst(length: 0.010, decay: 0.0008, seed: accented ? 3 : 4))
            return mix(body, scale(strike, 0.6))
        case .mallet:
            let f = accented ? 1047.0 : 784.0
            return modes([(f, 1, 0.045), (f * 4, 0.30, 0.012), (f * 9.9, 0.06, 0.004)], length: 0.140, attack: 0.0007)
        case .glass:
            return fmBell(carrier: accented ? 1760 : 1319)
        case .tick:
            let noise = noiseBurst(length: 0.060, decay: accented ? 0.008 : 0.005, seed: accented ? 5 : 6)
            let air = Biquad.highPass(6000, q: 0.707, sampleRate: sampleRate).apply(noise)
            let ring = Biquad.bandPass(accented ? 5200 : 7500, q: 4, sampleRate: sampleRate).apply(noise)
            return mix(air, scale(ring, 0.8))
        case .classic:
            let pitch = accented ? 1.2 : 1.0
            let noise = noiseBurst(length: 0.050, decay: 0.0025, seed: accented ? 1 : 2)
            let upper = Biquad.bandPass(2400 * pitch, q: 6, sampleRate: sampleRate).apply(noise)
            let lower = Biquad.bandPass(950 * pitch, q: 8, sampleRate: sampleRate).apply(noise)
            let hiss = Biquad.highPass(4000, q: 0.707, sampleRate: sampleRate).apply(noise)
            return mix(upper, scale(lower, 0.7), scale(hiss, 0.25))
        }
    }

    /// Decaying sines that start at zero, each (frequency, level, decay), with an optional
    /// raised-cosine fade-in.
    private func modes(_ partials: [(Double, Double, Double)], length: Double, attack: Double = 0) -> [Double] {
        (0..<frames(length)).map { index in
            let time = Double(index) / sampleRate
            let fadeIn = attack > 0 && time < attack ? 0.5 - 0.5 * cos(.pi * time / attack) : 1
            return partials.reduce(0) { sum, partial in
                sum + partial.1 * fadeIn * exp(-time / partial.2) * sin(2 * .pi * partial.0 * time)
            }
        }
    }

    /// Modulator at 3.5 × the carrier; the modulation index decays faster than the level.
    private func fmBell(carrier: Double) -> [Double] {
        (0..<frames(0.140)).map { index in
            let time = Double(index) / sampleRate
            let modulationIndex = 2.2 * exp(-time / 0.012)
            var level = exp(-time / 0.038)
            if time < 0.0006 { level *= 0.5 - 0.5 * cos(.pi * time / 0.0006) }
            let modulator = modulationIndex * sin(2 * .pi * 3.5 * carrier * time)
            return level * sin(2 * .pi * carrier * time + modulator)
        }
    }

    /// White noise with an exponential decay. A fixed seed keeps each sound identical every time.
    private func noiseBurst(length: Double, decay: Double, seed: UInt64) -> [Double] {
        var random = SplitMix64(seed: seed)
        return (0..<frames(length)).map { index in
            random.nextUniform() * exp(-(Double(index) / sampleRate) / decay)
        }
    }

    private func mix(_ layers: [Double]...) -> [Double] {
        let count = layers.map(\.count).max() ?? 0
        return (0..<count).map { index in
            layers.reduce(0) { $0 + (index < $1.count ? $1[index] : 0) }
        }
    }

    private func scale(_ samples: [Double], _ gain: Double) -> [Double] {
        samples.map { $0 * gain }
    }
}

/// A second-order filter from the Audio EQ Cookbook.
private struct Biquad {
    let b0, b1, b2, a1, a2: Double

    /// Band-pass with a peak gain of 1.
    static func bandPass(_ frequency: Double, q: Double, sampleRate: Double) -> Biquad {
        let (alpha, cosine) = terms(frequency, q, sampleRate)
        return Biquad(b0: alpha, b1: 0, b2: -alpha, a0: 1 + alpha, a1: -2 * cosine, a2: 1 - alpha)
    }

    static func highPass(_ frequency: Double, q: Double, sampleRate: Double) -> Biquad {
        let (alpha, cosine) = terms(frequency, q, sampleRate)
        return Biquad(
            b0: (1 + cosine) / 2, b1: -(1 + cosine), b2: (1 + cosine) / 2,
            a0: 1 + alpha, a1: -2 * cosine, a2: 1 - alpha
        )
    }

    private static func terms(_ frequency: Double, _ q: Double, _ sampleRate: Double) -> (Double, Double) {
        let omega = 2 * .pi * frequency / sampleRate
        return (sin(omega) / (2 * q), cos(omega))
    }

    private init(b0: Double, b1: Double, b2: Double, a0: Double, a1: Double, a2: Double) {
        self.b0 = b0 / a0
        self.b1 = b1 / a0
        self.b2 = b2 / a0
        self.a1 = a1 / a0
        self.a2 = a2 / a0
    }

    func apply(_ input: [Double]) -> [Double] {
        var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0
        return input.map { x in
            let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            x2 = x1
            x1 = x
            y2 = y1
            y1 = y
            return y
        }
    }
}

/// A small, fast pseudo-random generator; the same seed always gives the same noise.
private struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    /// Uniform in −1…1.
    mutating func nextUniform() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Double(z >> 11) / Double(1 << 53) * 2 - 1
    }
}
