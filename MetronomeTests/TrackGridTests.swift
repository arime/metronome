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
}
