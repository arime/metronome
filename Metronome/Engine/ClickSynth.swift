import AVFoundation

/// Placeholder click sounds, generated in code until the final sounds are chosen.
enum ClickSynth {
    private static let duration = 0.030
    private static let decayTime = 0.005

    /// A 30 ms sine burst with exponential decay.
    /// Accented: 1760 Hz at full level. Normal: 1175 Hz at 0.6.
    static func click(accented: Bool, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let frequency = accented ? 1760.0 : 1175.0
        let peak = accented ? 1.0 : 0.6
        let sampleRate = format.sampleRate
        let frames = AVAudioFrameCount((duration * sampleRate).rounded())
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channels = buffer.floatChannelData
        else { preconditionFailure("ClickSynth needs a float PCM format") }
        buffer.frameLength = frames
        for frame in 0..<Int(frames) {
            let time = Double(frame) / sampleRate
            // Cosine phase, so the very first sample is the peak.
            let sample = Float(peak * exp(-time / decayTime) * cos(2 * .pi * frequency * time))
            for channel in 0..<Int(format.channelCount) {
                channels[channel][frame] = sample
            }
        }
        return buffer
    }
}
