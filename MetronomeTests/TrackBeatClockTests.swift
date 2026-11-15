import Foundation
import Testing
@testable import Metronome

struct TrackBeatClockTests {
    private let rate = 48_000.0
    private let start: Int64 = 2_400

    private func clock(startTime: TimeInterval = 0, firstClickIndex: Int = 0) -> TrackBeatClock {
        TrackBeatClock(sampleRate: rate, startSampleTime: start, startTime: startTime, firstClickIndex: firstClickIndex)
    }

    @Test func theCountInEndsOnTheFirstBeat() {
        let grid = TrackGrid(firstBeat: 0.48, bpm: 120, beatsPerBar: 4)
        var clock = clock(startTime: grid.startTime(countIn: .twoBars), firstClickIndex: grid.firstClickIndex(countIn: .twoBars))
        let firstBeat = clock.sampleTime(forFileTime: 0.48)
        let beats = clock.beats(before: firstBeat + 1, notBefore: start, endTime: 100, grid: grid, accents: [1])
        #expect(beats.count == 9)
        #expect(beats.prefix(8).allSatisfy { $0.sampleTime < firstBeat })
        #expect(beats.map(\.beat) == [1, 2, 3, 4, 1, 2, 3, 4, 1])
        #expect(beats.first?.sampleTime == start)
        #expect(beats.last?.sampleTime == firstBeat)
    }

    @Test func noClickBeforeTheFirstBeatWithoutACountIn() {
        let grid = TrackGrid(firstBeat: 2.0, bpm: 120, beatsPerBar: 4)
        var clock = clock()
        let beats = clock.beats(before: clock.sampleTime(forFileTime: 3), notBefore: start, endTime: 100, grid: grid, accents: [1])
        #expect(clock.sampleTime(forFileTime: 0) == start)
        #expect(beats.first?.sampleTime == clock.sampleTime(forFileTime: 2.0))
        #expect(beats.first?.beat == 1)
    }

    @Test func startingMidFileJoinsOnTheNextGridBeat() {
        let grid = TrackGrid(firstBeat: 0.48, bpm: 120, beatsPerBar: 7)
        var clock = clock(startTime: 30.1)
        let beats = clock.beats(before: clock.sampleTime(forFileTime: 31), notBefore: start, endTime: 100, grid: grid, accents: [1])
        #expect(beats.first?.sampleTime == clock.sampleTime(forFileTime: 30.48))
        #expect(beats.first?.beat == grid.barBeat(ofBeat: 60))
    }

    @Test func accentsFollowTheBarBeat() {
        let grid = TrackGrid(firstBeat: 0, bpm: 120, beatsPerBar: 4)
        var clock = clock()
        let beats = clock.beats(before: clock.sampleTime(forFileTime: 2.9), notBefore: start, endTime: 100, grid: grid, accents: [1, 3])
        #expect(beats.map(\.beat) == [1, 2, 3, 4, 1, 2])
        #expect(beats.map(\.isAccented) == [true, false, true, false, true, false])
    }

    @Test func beatsAlreadyReturnedAreNotReturnedAgain() {
        let grid = TrackGrid(firstBeat: 0, bpm: 120, beatsPerBar: 4)
        var clock = clock()
        let horizon = clock.sampleTime(forFileTime: 1.2)
        let first = clock.beats(before: horizon, notBefore: start, endTime: 100, grid: grid, accents: [1])
        let again = clock.beats(before: horizon, notBefore: start, endTime: 100, grid: grid, accents: [1])
        let later = clock.beats(before: clock.sampleTime(forFileTime: 1.7), notBefore: start, endTime: 100, grid: grid, accents: [1])
        #expect(first.map(\.sampleTime) == [0, 0.5, 1.0].map { clock.sampleTime(forFileTime: $0) })
        #expect(again.isEmpty)
        #expect(later.map(\.sampleTime) == [clock.sampleTime(forFileTime: 1.5)])
        #expect(later.map(\.beat) == [4])
    }

    @Test func aSlowerTempoMovesLaterBeatsOntoTheNewGrid() {
        let fast = TrackGrid(firstBeat: 0.48, bpm: 120, beatsPerBar: 4)
        let slow = TrackGrid(firstBeat: 0.48, bpm: 60, beatsPerBar: 4)
        var clock = clock()
        let before = clock.beats(before: clock.sampleTime(forFileTime: 2.2), notBefore: start, endTime: 100, grid: fast, accents: [1])
        let after = clock.beats(before: clock.sampleTime(forFileTime: 6), notBefore: start, endTime: 100, grid: slow, accents: [1])
        #expect(before.count == 4)
        #expect(after.map(\.sampleTime) == [2.48, 3.48, 4.48, 5.48].map { clock.sampleTime(forFileTime: $0) })
        #expect(after.map(\.beat) == [3, 4, 1, 2])
    }

    @Test func aNudgedFirstBeatMovesLaterBeats() {
        let grid = TrackGrid(firstBeat: 0.48, bpm: 120, beatsPerBar: 4)
        let nudged = TrackGrid(firstBeat: 0.49, bpm: 120, beatsPerBar: 4)
        var clock = clock()
        let before = clock.beats(before: clock.sampleTime(forFileTime: 2.2), notBefore: start, endTime: 100, grid: grid, accents: [1])
        let after = clock.beats(before: clock.sampleTime(forFileTime: 3.7), notBefore: start, endTime: 100, grid: nudged, accents: [1])
        #expect(before.count == 4)
        let unmoved = [2.48, 2.98, 3.48].map { clock.sampleTime(forFileTime: $0) }
        #expect(after.map(\.sampleTime) == unmoved.map { $0 + 480 })
    }

    @Test func aNewGridBeatRightAfterTheLastOneIsSkipped() {
        let grid = TrackGrid(firstBeat: 0, bpm: 120, beatsPerBar: 4)
        // 0.1 of a 0.5 s interval later than the old grid.
        let moved = TrackGrid(firstBeat: 0.05, bpm: 120, beatsPerBar: 4)
        var clock = clock()
        let before = clock.beats(before: clock.sampleTime(forFileTime: 1.7), notBefore: start, endTime: 100, grid: grid, accents: [1])
        let after = clock.beats(before: clock.sampleTime(forFileTime: 2.3), notBefore: start, endTime: 100, grid: moved, accents: [1])
        #expect(before.last?.sampleTime == clock.sampleTime(forFileTime: 1.5))
        #expect(after.map(\.sampleTime) == [clock.sampleTime(forFileTime: 2.05)])
    }

    @Test func rapidTempoChangesNeverBunchOrStall() {
        // Mid-file, so every tempo step moves the grid under the next beat by a large amount.
        let startTime = 120.0
        var clock = clock(startTime: startTime)
        var beats: [(sampleTime: Int64, interval: Double)] = []
        let step = Int64(0.025 * rate)
        for call in 0..<200 {
            // 120 up to 180 and back, 5 BPM per call.
            let phase = call % 24
            let bpm = 120 + 5 * (phase <= 12 ? phase : 24 - phase)
            let grid = TrackGrid(firstBeat: 0.48, bpm: bpm, beatsPerBar: 4)
            let now = start + Int64(call) * step
            let returned = clock.beats(
                before: now + Int64(0.150 * rate), notBefore: now + Int64(0.005 * rate),
                endTime: 1_000, grid: grid, accents: [1]
            )
            beats += returned.map { ($0.sampleTime, grid.beatInterval * rate) }
        }
        #expect(beats.count >= 10)
        for (earlier, later) in zip(beats, beats.dropFirst()) {
            let gap = Double(later.sampleTime - earlier.sampleTime)
            let larger = max(earlier.interval, later.interval)
            // The skip rule is half of the interval of the grid the later beat is on.
            #expect(gap >= 0.5 * later.interval)
            #expect(gap <= 2.0 * larger)
        }
    }

    @Test(arguments: [44_100.0, 48_000.0])
    func beatTimesDoNotDriftOverTenMinutes(sampleRate: Double) {
        let grid = TrackGrid(firstBeat: 0.48, bpm: 137, beatsPerBar: 4)
        var clock = TrackBeatClock(sampleRate: sampleRate, startSampleTime: start, startTime: 0, firstClickIndex: 0)
        var beats: [ScheduledBeat] = []
        let step = Int64(0.025 * sampleRate)
        var now = start
        while beats.count <= 1370 {
            beats += clock.beats(
                before: now + Int64(0.150 * sampleRate), notBefore: now + Int64(0.005 * sampleRate),
                endTime: 1_000, grid: grid, accents: [1]
            )
            now += step
        }
        let exact = Double(start) + (0.48 + 1370 * 60 / 137) * sampleRate
        #expect(abs(Double(beats[1370].sampleTime) - exact) <= 1)
    }

    @Test func noBeatAtOrAfterTheEndOfTheFile() {
        let grid = TrackGrid(firstBeat: 0, bpm: 120, beatsPerBar: 4)
        var clock = clock()
        let beats = clock.beats(before: clock.sampleTime(forFileTime: 5), notBefore: start, endTime: 2.0, grid: grid, accents: [1])
        let more = clock.beats(before: clock.sampleTime(forFileTime: 10), notBefore: start, endTime: 2.0, grid: grid, accents: [1])
        #expect(beats.map(\.sampleTime) == [0, 0.5, 1.0, 1.5].map { clock.sampleTime(forFileTime: $0) })
        #expect(more.isEmpty)
    }

    @Test func aTimeSignatureChangeTakesTheBarFromTheFirstBeat() {
        let fourFour = TrackGrid(firstBeat: 0.48, bpm: 120, beatsPerBar: 4)
        let threeFour = TrackGrid(firstBeat: 0.48, bpm: 120, beatsPerBar: 3)
        var clock = clock()
        let before = clock.beats(before: clock.sampleTime(forFileTime: 3.2), notBefore: start, endTime: 100, grid: fourFour, accents: [1])
        let after = clock.beats(before: clock.sampleTime(forFileTime: 3.6), notBefore: start, endTime: 100, grid: threeFour, accents: [1])
        #expect(before.map(\.beat) == [1, 2, 3, 4, 1, 2])
        #expect(after.map(\.sampleTime) == [clock.sampleTime(forFileTime: threeFour.time(ofBeat: 6))])
        #expect(after.first?.beat == threeFour.barBeat(ofBeat: 6))
        #expect(after.first?.beat == 1)
        #expect(after.first?.isAccented == true)
    }
}
