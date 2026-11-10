import Testing
@testable import Metronome

struct TapTempoTests {
    @Test func firstTapGivesNothingThenTapsGiveTempo() {
        var taps = TapTempo()
        #expect(taps.tap(at: 0) == nil)
        #expect(taps.tap(at: 0.5) == 120)
        #expect(taps.tap(at: 1.0) == 120)
    }

    @Test func averagesOnlyTheLastFourIntervals() {
        var taps = TapTempo()
        for time in [0, 1.0, 1.5, 2.0, 2.5] { _ = taps.tap(at: time) }
        #expect(taps.tap(at: 3.0) == 120)
    }

    @Test func pauseLongerThanTwoSecondsStartsANewSeries() {
        var taps = TapTempo()
        _ = taps.tap(at: 0)
        _ = taps.tap(at: 0.5)
        #expect(taps.tap(at: 2.6) == nil)
        #expect(taps.tap(at: 3.6) == 60)
    }

    @Test func exactlyTwoSecondsIsTheSameSeriesAndClampsLow() {
        var taps = TapTempo()
        _ = taps.tap(at: 0)
        #expect(taps.tap(at: 2.0) == 30)
    }

    @Test func veryFastTapsClampHigh() {
        var taps = TapTempo()
        _ = taps.tap(at: 0)
        #expect(taps.tap(at: 0.02) == 250)
    }

    @Test func identicalTimestampsDoNotDivideByZero() {
        var taps = TapTempo()
        _ = taps.tap(at: 1)
        #expect(taps.tap(at: 1) == 250)
    }
}
