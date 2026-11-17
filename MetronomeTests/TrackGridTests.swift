import Foundation
import Testing
@testable import Metronome

struct TrackGridTests {
    private func near(_ a: TimeInterval, _ b: TimeInterval) -> Bool { abs(a - b) < 1e-9 }

    @Test func beatsFollowTheOffsetAtTheTempo() {
        let grid = TrackGrid(offset: 0.48, bpm: 120, beatsPerBar: 4)
        #expect(near(grid.time(ofBeat: 0), 0.48))
        #expect(near(grid.time(ofBeat: 1), 0.98))
        #expect(near(grid.time(ofBeat: 8), 4.48))
    }

    @Test func barBeatWrapsForwardsAndBackwards() {
        let grid = TrackGrid(offset: 0, bpm: 120, beatsPerBar: 7)
        #expect(grid.barBeat(ofBeat: 0) == 1)
        #expect(grid.barBeat(ofBeat: 6) == 7)
        #expect(grid.barBeat(ofBeat: 7) == 1)
        #expect(grid.barBeat(ofBeat: -1) == 7)
        #expect(grid.barBeat(ofBeat: -7) == 1)
        #expect(grid.barBeat(ofBeat: -14) == 1)
    }

    @Test func firstIndexAtOrAfterATime() {
        let grid = TrackGrid(offset: 0.48, bpm: 120, beatsPerBar: 4)
        #expect(grid.firstIndex(atOrAfter: 0) == 0)
        #expect(grid.firstIndex(atOrAfter: 0.48) == 0)
        #expect(grid.firstIndex(atOrAfter: 0.49) == 1)
        #expect(grid.firstIndex(atOrAfter: 60.48) == 120)
    }

    @Test func aShortIntroStartsTheClickFirst() {
        let grid = TrackGrid(offset: 0.48, bpm: 120, beatsPerBar: 4)
        #expect(near(grid.startTime(countIn: .twoBars), 0.48 - 4.0))
        #expect(grid.firstClickIndex(countIn: .twoBars) == -8)
    }

    @Test func aLongIntroStartsTheFileFirst() {
        let grid = TrackGrid(offset: 10, bpm: 120, beatsPerBar: 4)
        #expect(grid.startTime(countIn: .twoBars) == 0)
        #expect(grid.firstClickIndex(countIn: .twoBars) == -8)
        #expect(near(grid.time(ofBeat: -8), 6))
    }

    @Test func countInOffClicksFromTheOffset() {
        let grid = TrackGrid(offset: 0.48, bpm: 120, beatsPerBar: 4)
        #expect(grid.startTime(countIn: .off) == 0)
        #expect(grid.firstClickIndex(countIn: .off) == 0)
    }

    @Test func tempoIsClampedInTheGrid() {
        let grid = TrackGrid(offset: 0, bpm: 0, beatsPerBar: 4)
        #expect(near(grid.beatInterval, 2))
        #expect(near(grid.time(ofBeat: 1), 2))
    }

    // MARK: - Tap on beat 1's fold

    @Test func theFoldGoesBackWholeBars() {
        #expect(TrackGrid.foldedOffset(9.30, bpm: 120, beatsPerBar: 4) == 130)
        #expect(TrackGrid.foldedOffset(1.30, bpm: 120, beatsPerBar: 4) == 130)
        #expect(TrackGrid.foldedOffset(0.004, bpm: 120, beatsPerBar: 4) == 0)
    }

    @Test func anExactBarFoldsToZero() {
        #expect(TrackGrid.foldedOffset(4.0, bpm: 120, beatsPerBar: 4) == 0)
        #expect(TrackGrid.foldedOffset(6.0, bpm: 120, beatsPerBar: 4) == 0)
    }

    @Test func aFoldThatRoundsToAWholeBarGivesZero() {
        #expect(TrackGrid.foldedOffset(3.998, bpm: 120, beatsPerBar: 4) == 0)
    }

    /// 12 beats at 30 BPM: a bar of 24 s.
    @Test func theFoldWithABarLongerThanTheTap() {
        #expect(TrackGrid.foldedOffset(1.0, bpm: 30, beatsPerBar: 12) == 100)
    }

    /// 4 beats at 30 BPM: a bar of 8 s.
    @Test func theFoldAtTheSlowestTempo() {
        #expect(TrackGrid.foldedOffset(9.0, bpm: 30, beatsPerBar: 4) == 100)
    }
}
