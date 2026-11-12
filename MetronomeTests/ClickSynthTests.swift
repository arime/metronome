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

    private func rmsOfFirst20ms(_ samples: [Float], sampleRate: Double = 48_000) -> Double {
        let count = Int(0.020 * sampleRate)
        let sum = samples.prefix(count).reduce(0.0) { $0 + Double($1) * Double($1) }
        return (sum / Double(count)).squareRoot()
    }

    private func decibels(_ ratio: Double) -> Double { 20 * log10(ratio) }

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

    @Test(arguments: ClickSound.allCases, sampleRates)
    func normalClicksAreAllEquallyLoud(sound: ClickSound, sampleRate: Double) {
        let reference = rmsOfFirst20ms(samples(.digital, accented: false, sampleRate: sampleRate), sampleRate: sampleRate)
        let level = rmsOfFirst20ms(samples(sound, accented: false, sampleRate: sampleRate), sampleRate: sampleRate)
        #expect(abs(decibels(level / reference)) < 0.1)
    }

    @Test(arguments: ClickSound.allCases, sampleRates)
    func normalClicksAreAtMinus11dBFS(sound: ClickSound, sampleRate: Double) {
        let level = rmsOfFirst20ms(samples(sound, accented: false, sampleRate: sampleRate), sampleRate: sampleRate)
        #expect(abs(decibels(level) + 11) < 0.1, "\(sound) is at \(decibels(level)) dBFS")
    }

    @Test(arguments: ClickSound.allCases)
    func accentsAre4dBLouder(sound: ClickSound) {
        let accented = rmsOfFirst20ms(samples(sound, accented: true))
        let normal = rmsOfFirst20ms(samples(sound, accented: false))
        #expect(abs(decibels(accented / normal) - 4) < 0.1)
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
