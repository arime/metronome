import AVFoundation
import Foundation
import Testing
@testable import Metronome

/// The rules every click sound must meet (specification 11.1).
struct ClickSynthTests {
    private static let sampleRates = [48_000.0, 44_100.0]

    private func samples(_ sound: ClickSound, accented: Bool, sampleRate: Double = 48_000) -> [Float] {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = ClickSynth.click(sound, accented: accented, format: format)
        let channel = buffer.floatChannelData![0]
        return (0..<Int(buffer.frameLength)).map { channel[$0] }
    }

    private func loudness(_ sound: ClickSound, accented: Bool, sampleRate: Double = 48_000) -> Double {
        let click = samples(sound, accented: accented, sampleRate: sampleRate).map(Double.init)
        let padded = click + Array(repeating: 0, count: Int(ClickSynth.loudnessWindow * sampleRate))
        return ClickSynth.loudness(padded, sampleRate: sampleRate)
    }

    @Test(arguments: ClickSound.allCases, sampleRates)
    func noSoundIsLongerThan150ms(sound: ClickSound, sampleRate: Double) {
        for accented in [true, false] {
            let length = Double(samples(sound, accented: accented, sampleRate: sampleRate).count) / sampleRate
            #expect(length > 0.010)
            #expect(length <= 0.150)
        }
    }

    @Test(arguments: ClickSound.allCases, sampleRates)
    func everySoundReachesHalfItsPeakWithin1ms(sound: ClickSound, sampleRate: Double) {
        for accented in [true, false] {
            let click = samples(sound, accented: accented, sampleRate: sampleRate)
            let half = (click.map(abs).max() ?? 0) / 2
            let first = click.firstIndex { abs($0) >= half } ?? click.count
            #expect(Double(first) / sampleRate <= 0.001, "\(sound) accented: \(accented)")
        }
    }

    @Test(arguments: ClickSound.allCases)
    func peaksStayBelowFullScale(sound: ClickSound) {
        for accented in [true, false] {
            let peak = samples(sound, accented: accented).map(abs).max() ?? 0
            #expect(peak < 0.99, "\(sound) accented: \(accented) peaks at \(peak)")
        }
    }

    @Test(arguments: ClickSound.allCases)
    func everySoundEndsInSilence(sound: ClickSound) {
        for accented in [true, false] {
            #expect(abs(samples(sound, accented: accented).last ?? 1) < 0.001)
        }
    }

    /// The sounds with enough body to reach the full level without being crushed.
    @Test(arguments: [ClickSound.digital, .softBeep, .mallet, .glass], sampleRates)
    func fullBodiedNormalClicksAreAtMinus6LUFS(sound: ClickSound, sampleRate: Double) {
        let level = loudness(sound, accented: false, sampleRate: sampleRate)
        #expect(abs(level + 6) < 0.1, "\(sound) is at \(level) LUFS")
    }

    @Test(arguments: ClickSound.allCases, sampleRates)
    func noClickIsLouderThanItsTarget(sound: ClickSound, sampleRate: Double) {
        #expect(loudness(sound, accented: false, sampleRate: sampleRate) < -5.9)
        #expect(loudness(sound, accented: true, sampleRate: sampleRate) < -1.9)
    }

    @Test(arguments: ClickSound.allCases)
    func accentsAre4dBLouder(sound: ClickSound) {
        let difference = loudness(sound, accented: true) - loudness(sound, accented: false)
        #expect(abs(difference - 4) < 0.1)
    }

    /// The loudness scale is the one music is measured on: a full-scale 997 Hz sine on both
    /// channels is 0 LUFS in ITU-R BS.1770.
    @Test(arguments: sampleRates)
    func loudnessMatchesTheBroadcastReference(sampleRate: Double) {
        let sine = (0..<Int(ClickSynth.loudnessWindow * sampleRate)).map { sin(2 * .pi * 997 * Double($0) / sampleRate) }
        #expect(abs(ClickSynth.loudness(sine, sampleRate: sampleRate)) < 0.5)
    }

    @Test(arguments: ClickSound.allCases)
    func aSoundIsIdenticalEveryTime(sound: ClickSound) {
        #expect(samples(sound, accented: false) == samples(sound, accented: false))
    }

    @Test(arguments: ClickSound.allCases)
    func accentedAndNormalVariantsDiffer(sound: ClickSound) {
        let accented = samples(sound, accented: true)
        let normal = samples(sound, accented: false)
        let scale = (normal.map(abs).max() ?? 1) / (accented.map(abs).max() ?? 1)
        // Not merely the same waveform played louder.
        let difference = zip(accented, normal).map { abs($0 * scale - $1) }.max() ?? 0
        #expect(difference > 0.01)
    }

    @Test func digitalStartsAtItsPeak() {
        let click = samples(.digital, accented: false)
        #expect(abs(click[0]) == click.map(abs).max())
    }
}
