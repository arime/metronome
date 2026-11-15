import AVFoundation

enum TrackAudioError: Error {
    case unreadable
}

/// What is read from a backing-track file when it is attached (spec 10.3).
enum TrackAudio {
    /// The level a file must rise above to count as sound: -40 dB of full scale.
    private static let threshold = Float(pow(10, -40.0 / 20))
    private static let chunkFrames: AVAudioFrameCount = 16_384

    /// The file's length in seconds. Throws `unreadable` when it cannot be opened as audio or has no frames.
    static func length(of url: URL) throws -> TimeInterval {
        let file = try open(url)
        return Double(file.length) / file.processingFormat.sampleRate
    }

    /// Hundredths of a second where the level first rises above -40 dB of full scale on any channel;
    /// 0 when it never does or when the file starts with sound.
    /// Reads in chunks and stops at the first such frame, so a long file is not read whole.
    static func firstSound(in url: URL) throws -> Int {
        let file = try open(url)
        let format = file.processingFormat
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkFrames),
              format.commonFormat == .pcmFormatFloat32
        else { throw TrackAudioError.unreadable }
        let channels = Int(format.channelCount)
        var start: AVAudioFramePosition = 0
        while start < file.length {
            do {
                try file.read(into: buffer, frameCount: chunkFrames)
            } catch {
                throw TrackAudioError.unreadable
            }
            let frames = Int(buffer.frameLength)
            guard frames > 0, let data = buffer.floatChannelData else { break }
            for frame in 0..<frames {
                for channel in 0..<channels where abs(data[channel][frame]) > threshold {
                    let seconds = Double(start + AVAudioFramePosition(frame)) / format.sampleRate
                    return Int((seconds * 100).rounded())
                }
            }
            start += AVAudioFramePosition(frames)
        }
        return 0
    }

    private static func open(_ url: URL) throws -> AVAudioFile {
        guard let file = try? AVAudioFile(forReading: url), file.length > 0 else {
            throw TrackAudioError.unreadable
        }
        return file
    }
}
