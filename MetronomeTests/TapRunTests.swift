import Foundation
import Testing
@testable import Metronome

/// Bar numbers, the fit and the count line of a run of tapped downbeats (7.11).
struct TapRunTests {
    private func run(_ times: [TimeInterval], bpm: Int = 120, beatsPerBar: Int = 4) -> TapRun {
        var run = TapRun()
        for time in times { run.add(at: time, bpm: bpm, beatsPerBar: beatsPerBar) }
        return run
    }

    @Test func theWorkedExample() {
        var run = TapRun()
        run.add(at: 10.11, bpm: 120, beatsPerBar: 4)
        #expect(run.fitted(bpm: 120, beatsPerBar: 4) == TapFit(bpm: 120, offset: 11))
        run.add(at: 12.01, bpm: 120, beatsPerBar: 4)
        #expect(run.taps.map(\.bar) == [0, 1])
        #expect(run.fitted(bpm: 120, beatsPerBar: 4) == TapFit(bpm: 126, offset: 58))
        run.add(at: 13.95, bpm: 126, beatsPerBar: 4)
        #expect(run.taps.map(\.bar) == [0, 1, 2])
        #expect(run.fitted(bpm: 126, beatsPerBar: 4) == TapFit(bpm: 125, offset: 50))
        run.add(at: 19.69, bpm: 125, beatsPerBar: 4)
        #expect(run.taps.map(\.bar) == [0, 1, 2, 5])
        #expect(run.fitted(bpm: 125, beatsPerBar: 4) == TapFit(bpm: 125, offset: 50))
        #expect(run.countLine == "4 taps · 6 bars")
        #expect(run.spokenCountLine == "4 taps, 6 bars")
    }

    @Test func oneTapSetsOnlyTheOffset() {
        #expect(run([9.30]).fitted(bpm: 120, beatsPerBar: 4) == TapFit(bpm: 120, offset: 130))
    }

    @Test func aShortGapStillCountsOneBar() {
        #expect(run([10.0, 10.5]).taps.map(\.bar) == [0, 1])
    }

    @Test func halfABarRoundsUp() {
        #expect(run([0.0, 3.0]).taps.map(\.bar) == [0, 2])
    }

    @Test func aTapNotLaterThanTheLastStartsANewRun() {
        var taps = run([10, 12, 11])
        #expect(taps.taps == [TapRun.Tap(bar: 0, time: 11)])
        taps.add(at: 11, bpm: 120, beatsPerBar: 4)
        #expect(taps.taps == [TapRun.Tap(bar: 0, time: 11)])
    }

    @Test func aBouncedFingerIsNotASecondTap() {
        var taps = TapRun()
        let first = taps.add(at: 10.0, bpm: 120, beatsPerBar: 4)
        let bounce = taps.add(at: 10.15, bpm: 120, beatsPerBar: 4)
        #expect(first)
        #expect(bounce == false)
        #expect(taps.taps == [TapRun.Tap(bar: 0, time: 10.0)])
    }

    @Test func aTapAtTheBounceLimitIsTaken() {
        var taps = TapRun()
        taps.add(at: 10.0, bpm: 120, beatsPerBar: 4)
        let taken = taps.add(at: 10.2, bpm: 120, beatsPerBar: 4)
        #expect(taken)
        #expect(taps.taps.map(\.bar) == [0, 1])
    }

    @Test func anExactBarFoldsToZero() {
        #expect(TapRun.foldedOffset(4.0, barLength: 2.0) == 0)
        #expect(TapRun.foldedOffset(6.0, barLength: 2.0) == 0)
    }

    @Test func aFoldThatRoundsToAWholeBarGivesZero() {
        #expect(TapRun.foldedOffset(3.998, barLength: 2.0) == 0)
    }

    @Test func aMeanDownbeatJustBeforeTheStartGoesForwardABar() {
        #expect(run([0.0, 1.7]).fitted(bpm: 120, beatsPerBar: 4) == TapFit(bpm: 141, offset: 170))
    }

    @Test func theFittedTempoStaysInRange() {
        #expect(run([0.0, 0.25], bpm: 300).fitted(bpm: 300, beatsPerBar: 4)?.bpm == 300)
        #expect(run([0, 30], bpm: 30, beatsPerBar: 12).fitted(bpm: 30, beatsPerBar: 12)?.bpm == 30)
    }

    @Test func theCountLineIsSingularAndPlural() {
        #expect(TapRun().countLine == nil)
        #expect(TapRun().spokenCountLine == nil)
        #expect(run([10.0]).countLine == "1 tap · 1 bar")
        #expect(run([10.0]).spokenCountLine == "1 tap, 1 bar")
        #expect(run([10.0, 12.0]).countLine == "2 taps · 2 bars")
    }

    @Test func theFoldGoesBackWholeBars() {
        #expect(TapRun.foldedOffset(9.30, barLength: 2.0) == 130)
        #expect(TapRun.foldedOffset(1.30, barLength: 2.0) == 130)
        #expect(TapRun.foldedOffset(0.004, barLength: 2.0) == 0)
    }

    @Test func theFoldWithABarLongerThanTheTap() {
        #expect(TapRun.foldedOffset(1.0, barLength: 24.0) == 100)
    }

    @Test func theFoldAtTheSlowestTempo() {
        #expect(TapRun.foldedOffset(9.0, barLength: 8.0) == 100)
    }
}
