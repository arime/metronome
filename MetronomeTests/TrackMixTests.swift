import Foundation
import Testing
@testable import Metronome

struct TrackMixTests {
    private func decibels(_ gain: Float) -> Double { 20 * log10(Double(gain)) }

    @Test func centreIsFullLevelForBoth() {
        #expect(TrackMix.clickGain(at: 0) == 1)
        #expect(TrackMix.trackGain(at: 0) == 1)
    }

    @Test func towardsClickTurnsOnlyTheTrackDown() {
        #expect(abs(TrackMix.trackGain(at: -1) - 0.0631) < 0.0001)
        #expect(abs(decibels(TrackMix.trackGain(at: -1)) + 24) < 1e-4)
        #expect(TrackMix.clickGain(at: -1) == 1)
        #expect(abs(decibels(TrackMix.trackGain(at: -0.5)) + 12) < 1e-4)
        #expect(TrackMix.clickGain(at: -0.5) == 1)
    }

    @Test func towardsTrackTurnsOnlyTheClickDown() {
        #expect(abs(TrackMix.clickGain(at: 1) - 0.0631) < 0.0001)
        #expect(TrackMix.trackGain(at: 1) == 1)
    }

    @Test func neitherEndIsSilent() {
        #expect(TrackMix.clickGain(at: -1) > 0)
        #expect(TrackMix.trackGain(at: -1) > 0)
        #expect(TrackMix.clickGain(at: 1) > 0)
        #expect(TrackMix.trackGain(at: 1) > 0)
    }

    @Test func theKnobCatchesWithinSixPointsOfTheCentre() {
        #expect(TrackMix.position(forKnobAt: 117, width: 234) == 0)
        #expect(TrackMix.position(forKnobAt: 112, width: 234) == 0)
        #expect(TrackMix.position(forKnobAt: 122, width: 234) == 0)
        #expect(TrackMix.position(forKnobAt: 110, width: 234) < 0)
        #expect(TrackMix.position(forKnobAt: 0, width: 234) == -1)
        #expect(TrackMix.position(forKnobAt: 234, width: 234) == 1)
        #expect(TrackMix.position(forKnobAt: -20, width: 234) == -1)
    }

    @Test func spokenValuesRoundToWholeDecibels() {
        #expect(TrackMix.spoken(0) == "Mix, centre")
        #expect(TrackMix.spoken(-0.5) == "Mix, track turned down 12 decibels")
        #expect(TrackMix.spoken(0.25) == "Mix, click turned down 6 decibels")
    }

    @Test func timesReadAsMinutesAndSeconds() {
        #expect(TrackTime.label(0) == "0:00")
        #expect(TrackTime.label(84) == "1:24")
        #expect(TrackTime.label(222.9) == "3:42")
        #expect(TrackTime.label(3665) == "61:05")
        #expect(TrackTime.label(-2) == "0:00")
    }

    @Test func spokenTimes() {
        #expect(TrackTime.spoken(84) == "1 minute 24 seconds")
        #expect(TrackTime.spoken(180) == "3 minutes")
        #expect(TrackTime.spoken(1) == "1 second")
    }
}
