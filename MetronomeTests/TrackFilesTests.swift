import AVFoundation
import Foundation
import Testing
@testable import Metronome

/// Each test gets its own temporary directory, removed when the test ends.
final class TrackFilesTests {
    private let root: URL
    private let store: TrackFileStore

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "TrackFilesTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        store = TrackFileStore(directory: root.appending(path: "Store"))
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    /// Writes a mono 16-bit WAV: `silenceFor` seconds at `leadAmplitude` (silence by default),
    /// then a 440 Hz sine at amplitude 0.5 up to `seconds`.
    private func makeWAV(
        seconds: Double, sampleRate: Double = 44100, silenceFor: Double = 0, leadAmplitude: Float = 0
    ) throws -> URL {
        let url = root.appending(path: "\(UUID().uuidString).wav")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        let file = try AVAudioFile(
            forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false
        )
        let frames = AVAudioFrameCount((seconds * sampleRate).rounded())
        let lead = Int((silenceFor * sampleRate).rounded())
        let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frames)!
        buffer.frameLength = frames
        let samples = buffer.floatChannelData![0]
        for n in 0..<Int(frames) {
            if n < lead {
                samples[n] = leadAmplitude * Float(sin(2 * Double.pi * 60 * Double(n) / sampleRate))
            } else {
                samples[n] = 0.5 * Float(sin(2 * Double.pi * 440 * Double(n - lead) / sampleRate))
            }
        }
        try file.write(from: buffer)
        return url
    }

    private func makeFile(named name: String, contents: String) throws -> URL {
        let url = root.appending(path: name)
        try Data(contents.utf8).write(to: url)
        return url
    }

    // MARK: - Store

    @Test func aStoredFileIsFoundUnderItsIdentifier() throws {
        let source = try makeFile(named: "Song.m4a", contents: "audio")
        let id = UUID()
        try store.store(source, as: id)
        #expect(store.hasFile(id))
        let url = try #require(store.url(for: id))
        #expect(url.lastPathComponent == "\(id.uuidString).m4a")
        #expect(try String(contentsOf: url, encoding: .utf8) == "audio")
    }

    @Test func storingAgainReplacesTheCopy() throws {
        let id = UUID()
        try store.store(try makeFile(named: "First.m4a", contents: "first"), as: id)
        try store.store(try makeFile(named: "Second.mp3", contents: "second"), as: id)
        let url = try #require(store.url(for: id))
        #expect(url.pathExtension == "mp3")
        #expect(try String(contentsOf: url, encoding: .utf8) == "second")
        let names = try FileManager.default.contentsOfDirectory(atPath: root.appending(path: "Store").path)
        #expect(names.count == 1)
    }

    @Test func removeAllExceptKeepsOnlyTheNamedFiles() throws {
        let kept = UUID(), gone = UUID(), alsoGone = UUID()
        try store.store(try makeFile(named: "A.wav", contents: "a"), as: kept)
        try store.store(try makeFile(named: "B.wav", contents: "b"), as: gone)
        try store.store(try makeFile(named: "C.aiff", contents: "c"), as: alsoGone)
        store.removeAll(except: [kept])
        #expect(store.hasFile(kept))
        #expect(!store.hasFile(gone))
        #expect(!store.hasFile(alsoGone))
    }

    @Test func anUnknownIdentifierHasNoFile() {
        #expect(!store.hasFile(UUID()))
        #expect(store.url(for: UUID()) == nil)
    }

    // MARK: - Audio

    @Test func lengthOfAGeneratedFile() throws {
        let url = try makeWAV(seconds: 2.0, sampleRate: 44100)
        #expect(abs(try TrackAudio.length(of: url) - 2.0) < 0.001)
    }

    @Test func firstSoundAfterLeadingSilence() throws {
        let url = try makeWAV(seconds: 2.0, silenceFor: 0.48)
        #expect(try TrackAudio.firstSound(in: url) == 48)
    }

    @Test func aFileThatStartsWithSoundHasFirstSoundAtZero() throws {
        let url = try makeWAV(seconds: 1.0)
        #expect(try TrackAudio.firstSound(in: url) == 0)
    }

    // Review Focus 2
    @Test func silentFileHasFirstSoundAtZero() throws {
        let url = try makeWAV(seconds: 1.0, silenceFor: 1.0)
        #expect(try TrackAudio.firstSound(in: url) == 0)
    }

    @Test func aQuietRumbleBelowTheThresholdIsNotTheFirstSound() throws {
        let url = try makeWAV(seconds: 2.0, silenceFor: 1.0, leadAmplitude: 0.005)
        #expect(try TrackAudio.firstSound(in: url) == 100)
    }

    @Test func aTextFileIsUnreadable() throws {
        let url = try makeFile(named: "Notes.txt", contents: "These are not audio.")
        #expect(throws: TrackAudioError.unreadable) { try TrackAudio.length(of: url) }
        #expect(throws: TrackAudioError.unreadable) { try TrackAudio.firstSound(in: url) }
    }

    @Test func firstSoundIsTheSameAt48kAnd44k() throws {
        let at44 = try makeWAV(seconds: 2.0, sampleRate: 44100, silenceFor: 0.73)
        let at48 = try makeWAV(seconds: 2.0, sampleRate: 48000, silenceFor: 0.73)
        #expect(try TrackAudio.firstSound(in: at44) == 73)
        #expect(try TrackAudio.firstSound(in: at48) == 73)
    }
}
