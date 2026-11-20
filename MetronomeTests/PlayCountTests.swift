import Foundation
import Testing
@testable import Metronome

struct PlayCountTests {
    private func b(_ n: Int, countIn: Bool = false) -> ScheduledBeat {
        ScheduledBeat(beat: n, isAccented: n == 1, sampleTime: 0, isCountIn: countIn)
    }

    private func counting(_ beats: [Int], from start: TimeInterval = 0) -> PlayCount {
        var count = PlayCount()
        for (i, beat) in beats.enumerated() {
            count.count(b(beat), at: start + Double(i) * 0.5)
        }
        return count
    }

    @Test func startsAtZeroAndBarOne() {
        let count = PlayCount()
        #expect(count.elapsed(at: 100) == 0)
        #expect(count.bar == 1)
        #expect(count.readout(at: 100).time == "0:00")
        #expect(count.readout(at: 100).bar == "Bar 1")
    }

    @Test func theTimeRunsFromTheFirstCountedBeat() {
        var count = PlayCount()
        count.count(b(1), at: 10)
        #expect(count.elapsed(at: 94.9) == 84.9)
        #expect(count.readout(at: 94.9).time == "1:24")
    }

    @Test func everyBeatOneAfterTheFirstCountsABar() {
        var count = counting([1, 2, 3, 4, 1, 2])
        #expect(count.bar == 2)
        count.count(b(1), at: 10)
        #expect(count.bar == 3)
    }

    @Test func aBarCutShortStillCounts() {
        #expect(counting([1, 2, 1]).bar == 2)
    }

    @Test func aStartMidBarMakesThatBarOne() {
        var count = counting([3, 4])
        #expect(count.bar == 1)
        count.count(b(1), at: 10)
        #expect(count.bar == 2)
    }

    @Test func countInBeatsAreNotCounted() {
        var count = PlayCount()
        for (i, beat) in (1...4).enumerated() {
            count.count(b(beat, countIn: true), at: Double(i) * 0.5)
        }
        #expect(count.elapsed(at: 2) == 0)
        #expect(count.bar == 1)
        count.count(b(1), at: 2)
        #expect(count.elapsed(at: 3) == 1)
        #expect(count.bar == 1)
    }

    @Test func stopKeepsTheTimeAndTheBar() {
        var count = PlayCount()
        count.count(b(1), at: 10)
        count.count(b(2), at: 10.5)
        count.count(b(1), at: 11)
        count.stop(at: 50)
        #expect(count.elapsed(at: 500) == 40)
        #expect(count.bar == 2)
    }

    @Test func restartCountsTheNextBeatAsBarOne() {
        var count = counting([1, 2, 1, 2, 1])
        #expect(count.bar == 3)
        count.restart()
        #expect(count.elapsed(at: 150) == 0)
        #expect(count.bar == 1)
        count.count(b(1), at: 200)
        #expect(count.bar == 1)
        #expect(count.elapsed(at: 201) == 1)
    }

    @Test func theTimeIsShownAsMinutesThenHours() {
        #expect(PlayCount.timeLabel(0) == "0:00")
        #expect(PlayCount.timeLabel(3599.9) == "59:59")
        #expect(PlayCount.timeLabel(3600) == "1:00:00")
        #expect(PlayCount.timeLabel(3727) == "1:02:07")
        #expect(PlayCount.timeLabel(-5) == "0:00")
    }

    @Test func theBarReadsBarAndItsNumber() {
        #expect(PlayCount.barLabel(1) == "Bar 1")
        #expect(PlayCount.barLabel(128) == "Bar 128")
    }

    @Test func theReadoutIsSpokenWithTheBar() {
        #expect(PlayCount.spoken(84, bar: 43) == "1 minute 24 seconds, bar 43")
        #expect(PlayCount.spoken(3727, bar: 1240) == "1 hour 2 minutes 7 seconds, bar 1240")
        #expect(PlayCount.spoken(0, bar: 1) == "0 seconds, bar 1")
        #expect(PlayCount.spoken(3600, bar: 2) == "1 hour, bar 2")
    }
}
