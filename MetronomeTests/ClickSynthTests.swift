import AVFoundation
import Testing
@testable import Metronome

struct ClickSynthTests {
    private let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!

    private func samples(accented: Bool) -> [Float] {
        let buffer = ClickSynth.click(accented: accented, format: format)
        let channel = buffer.floatChannelData![0]
        return (0..<Int(buffer.frameLength)).map { channel[$0] }
    }

    @Test(arguments: [true, false])
    func clickIsThirtyMilliseconds(accented: Bool) {
        #expect(samples(accented: accented).count == 1440)
    }

    @Test func accentedClickPeaksAtFullLevel() {
        let peak = samples(accented: true).map(abs).max() ?? 0
        #expect(abs(peak - 1.0) < 0.01)
    }

    @Test func normalClickIsQuieter() {
        let peak = samples(accented: false).map(abs).max() ?? 0
        #expect(abs(peak - 0.6) < 0.01)
    }

    @Test(arguments: [true, false])
    func clickDecaysToSilence(accented: Bool) {
        #expect(abs(samples(accented: accented).last ?? 1) < 0.01)
    }
}
