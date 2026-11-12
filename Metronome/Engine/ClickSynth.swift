import AVFoundation

/// Generates the click sounds (specification 11.1) at the output's own sample rate.
///
/// Each sound is built from decaying sines, an FM bell or filtered noise, then raised to a
/// fixed loudness through a soft limiter, so that the clicks hold their own against music
/// played at the same system volume. Every accented click is 4 dB louder than its normal one.
enum ClickSynth {
    /// Loudness of a normal click, in LUFS (see `loudness`), for every sound that can reach
    /// it within `maximumDrive`.
    static let normalLoudness = -6.0
    static let accentGainDecibels = 4.0
    /// The limiter leaves samples below the knee alone and bends everything above it
    /// smoothly towards the ceiling, which no sample reaches.
    static let limiterKnee = 0.5
    static let limiterCeiling = 0.95
    /// How far a sound's peak may be pushed past the ceiling into the limiter, in dB. A
    /// sound that would need more stays quieter instead of being crushed. Digital, a pure
    /// tone, was judged by ear to take a little more.
    static func maximumDrive(_ sound: ClickSound) -> Double {
        sound == .digital ? 8 : 6
    }
    static let loudnessWindow = 0.100
    private static let tailFade = 0.003

    static func click(_ sound: ClickSound, accented: Bool, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let accent = shaped(sound, accented: true, to: normalLoudness + accentGainDecibels, sampleRate: sampleRate)
        let samples: [Double]
        if accented {
            samples = accent
        } else {
            // If the accent could not reach its target, the normal click stays 4 dB under it.
            let accentLoudness = loudness(padded(accent, sampleRate: sampleRate), sampleRate: sampleRate)
            let target = min(normalLoudness, accentLoudness - accentGainDecibels)
            samples = shaped(sound, accented: false, to: target, sampleRate: sampleRate)
        }

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

    private static func shaped(_ sound: ClickSound, accented: Bool, to target: Double, sampleRate: Double) -> [Double] {
        let synth = Synth(sampleRate: sampleRate)
        var raw = synth.make(sound, accented: accented)
        fadeTail(&raw, frames: synth.frames(tailFade))
        return louden(raw, to: target, maximumDrive: maximumDrive(sound), sampleRate: sampleRate)
    }

    /// The click with silence after it, filling the loudness window.
    private static func padded(_ samples: [Double], sampleRate: Double) -> [Double] {
        let window = Int((loudnessWindow * sampleRate).rounded())
        return samples + Array(repeating: 0, count: max(0, window - samples.count))
    }

    /// Finds the gain that, after limiting, brings the loudness to the target, but never
    /// drives the peak more than `maximumDrive` into the limiter. Limiting only ever lowers
    /// a sample, so the loudness rises with the gain and a bisection on the gain in decibels
    /// finds it.
    private static func louden(_ samples: [Double], to target: Double, maximumDrive: Double, sampleRate: Double) -> [Double] {
        let measured = padded(samples, sampleRate: sampleRate)
        let level = loudness(measured, sampleRate: sampleRate)
        guard level.isFinite else { return samples }
        var low = target - level
        var high = low + 40
        for _ in 0..<40 {
            let middle = (low + high) / 2
            let gain = pow(10, middle / 20)
            if loudness(measured.map { limit($0 * gain) }, sampleRate: sampleRate) < target {
                low = middle
            } else {
                high = middle
            }
        }
        let peak = samples.map(abs).max() ?? 1
        let gain = min(pow(10, (low + high) / 40), limiterCeiling * pow(10, maximumDrive / 20) / peak)
        return samples.map { limit($0 * gain) }
    }

    /// Loudness on the scale music is mastered to (ITU-R BS.1770, LUFS), over the first
    /// 100 ms of a click: the ear judges a short sound over about that long. The click is
    /// K-weighted, which counts the 2–8 kHz range the ear is most sensitive to about 4 dB
    /// higher, and played on both channels. The low-frequency part of K-weighting is left
    /// out, as no click has any energy down there.
    static func loudness(_ samples: [Double], sampleRate: Double) -> Double {
        let window = Int((loudnessWindow * sampleRate).rounded())
        let weighted = Biquad.highShelf(1681.974, gainDecibels: 3.999843, q: 0.7071752, sampleRate: sampleRate)
            .apply(Array(samples.prefix(window)))
        let meanSquare = weighted.reduce(0) { $0 + $1 * $1 } / Double(window)
        return -0.691 + 10 * log10(2 * meanSquare)
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
            return (0..<frames(0.150)).map { index in
                let time = Double(index) / sampleRate
                return exp(-time / 0.030) * cos(2 * .pi * (accented ? 1760 : 1175) * time)
            }
        case .softBeep:
            // A real beep: held flat, with soft edges.
            let f = accented ? 1568.0 : 1047.0
            return (0..<frames(0.070)).map { index in
                let time = Double(index) / sampleRate
                return held(time, attack: 0.001, hold: 0.035, release: 0.008) * sin(2 * .pi * f * time)
            }
        case .woodblock:
            // A hollow tone half an octave down gives the block its body; gentle saturation
            // gives it grit.
            let f = accented ? 1180.0 : 880.0
            let body = modes(
                [(f, 1, 0.020), (f * 0.5, 0.6, 0.025), (f * 2.65, 0.4, 0.006), (f * 4.1, 0.15, 0.003)],
                length: 0.080, attack: 0.0005
            )
            let noise = noiseBurst(length: 0.010, decay: .infinity, seed: accented ? 3 : 4)
            let strike = fade(Biquad.bandPass(f * 3, q: 2, sampleRate: sampleRate).apply(noise), decay: 0.0012)
            return saturate(mix(body, scale(strike, 0.5)), drive: 2.5)
        case .mallet:
            // Marimba-like tuning: partials at 4 f and 10 f.
            let f = accented ? 1047.0 : 784.0
            return saturate(
                modes([(f, 1, 0.045), (f * 4, 0.4, 0.015), (f * 10, 0.1, 0.004)], length: 0.120, attack: 0.0008),
                drive: 2
            )
        case .glass:
            return fmBell(carrier: accented ? 1760 : 1319)
        case .tick:
            // A watch: a crisp, high, metallic tick with a short strike.
            let f = accented ? 4000.0 : 3000.0
            let body = modes([(f, 1, 0.006), (f * 1.48, 0.7, 0.004), (f * 2.3, 0.4, 0.003)], length: 0.040, attack: 0.0003)
            return saturate(mix(body, scale(strike(f * 1.8, decay: 0.0005, seed: accented ? 17 : 18), 0.5)), drive: 2)
        case .classic:
            // Pendulum: a clock's escapement, a short metallic ping on a brief wooden body.
            let pitch = accented ? 1.33 : 1.0
            let ping = modes(
                [(3200 * pitch, 1, 0.004), (4750 * pitch, 0.6, 0.003), (7300 * pitch, 0.3, 0.002)],
                length: 0.030, attack: 0.0003
            )
            let wood = modes([(700 * pitch, 1, 0.014), (1350 * pitch, 0.6, 0.009)], length: 0.070, attack: 0.0003)
            return saturate(mix(scale(ping, 0.7), wood), drive: 2)
        }
    }

    /// A 6 ms burst of band-passed noise that dies away fast: the moment of impact.
    private func strike(_ frequency: Double, decay: Double, seed: UInt64) -> [Double] {
        let noise = noiseBurst(length: 0.006, decay: .infinity, seed: seed)
        return fade(Biquad.bandPass(frequency, q: 1.5, sampleRate: sampleRate).apply(noise), decay: decay)
    }

    /// An exponential fade from the first sample.
    private func fade(_ samples: [Double], decay: Double) -> [Double] {
        samples.enumerated().map { index, sample in sample * exp(-(Double(index) / sampleRate) / decay) }
    }

    /// Raised-cosine attack, a flat hold, then an exponential release.
    private func held(_ time: Double, attack: Double, hold: Double, release: Double) -> Double {
        if time < attack { return 0.5 - 0.5 * cos(.pi * time / attack) }
        if time < attack + hold { return 1 }
        return exp(-(time - attack - hold) / release)
    }

    /// tanh saturation that adds harmonics and fills out the body. Scaled so the peak stays
    /// where it was.
    private func saturate(_ samples: [Double], drive: Double) -> [Double] {
        let peak = samples.map(abs).max() ?? 1
        guard peak > 0 else { return samples }
        return samples.map { tanh(drive * $0 / peak) / tanh(drive) * peak }
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
            let modulationIndex = 2.2 * exp(-time / 0.025)
            var level = exp(-time / 0.045)
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

    static func highShelf(_ frequency: Double, gainDecibels: Double, q: Double, sampleRate: Double) -> Biquad {
        let (alpha, cosine) = terms(frequency, q, sampleRate)
        let a = pow(10, gainDecibels / 40)
        let root = 2 * a.squareRoot() * alpha
        return Biquad(
            b0: a * ((a + 1) + (a - 1) * cosine + root),
            b1: -2 * a * ((a - 1) + (a + 1) * cosine),
            b2: a * ((a + 1) + (a - 1) * cosine - root),
            a0: (a + 1) - (a - 1) * cosine + root,
            a1: 2 * ((a - 1) - (a + 1) * cosine),
            a2: (a + 1) - (a - 1) * cosine - root
        )
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
