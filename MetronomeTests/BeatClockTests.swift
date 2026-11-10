import Testing
@testable import Metronome

struct BeatClockTests {
    private func beat(_ beat: Int, _ accented: Bool, _ sampleTime: Int64) -> ScheduledBeat {
        ScheduledBeat(beat: beat, isAccented: accented, sampleTime: sampleTime)
    }

    @Test func spacesBeatsAndWrapsTheBar() {
        var clock = BeatClock(sampleRate: 48_000, startSampleTime: 0)
        let beats = clock.beats(before: 120_001, bpm: 120, beatsPerBar: 4, accents: [1, 3])
        #expect(beats == [
            beat(1, true, 0), beat(2, false, 24_000), beat(3, true, 48_000),
            beat(4, false, 72_000), beat(1, true, 96_000), beat(2, false, 120_000),
        ])
    }

    @Test func laterCallsContinueAndNeverRepeat() {
        var clock = BeatClock(sampleRate: 48_000, startSampleTime: 0)
        _ = clock.beats(before: 30_000, bpm: 120, beatsPerBar: 4, accents: [1])
        #expect(clock.beats(before: 30_000, bpm: 120, beatsPerBar: 4, accents: [1]).isEmpty)
        #expect(clock.beats(before: 50_000, bpm: 120, beatsPerBar: 4, accents: [1]) == [beat(3, false, 48_000)])
    }

    @Test func horizonIsExclusive() {
        var clock = BeatClock(sampleRate: 48_000, startSampleTime: 0)
        #expect(clock.beats(before: 24_000, bpm: 120, beatsPerBar: 4, accents: [1]) == [beat(1, true, 0)])
    }

    @Test func firstBeatIsAtTheStartSampleTime() {
        var clock = BeatClock(sampleRate: 48_000, startSampleTime: 5_000)
        #expect(clock.beats(before: 5_001, bpm: 120, beatsPerBar: 4, accents: [1]) == [beat(1, true, 5_000)])
    }

    @Test func doesNotDriftOverTenMinutesAtTopTempo() {
        var clock = BeatClock(sampleRate: 48_000, startSampleTime: 0)
        let beats = clock.beats(before: 28_800_001, bpm: 250, beatsPerBar: 4, accents: [1])
        #expect(beats.count == 2501)
        #expect(beats.last?.sampleTime == 28_800_000)
    }

    @Test func doesNotDriftAtAnUnevenTempo() {
        var clock = BeatClock(sampleRate: 48_000, startSampleTime: 0)
        let interval = 60.0 / 137.0 * 48_000
        let beats = clock.beats(before: Int64(interval * 5000), bpm: 137, beatsPerBar: 4, accents: [1])
        #expect(beats.count == 5000)
        #expect(beats.enumerated().allSatisfy { index, beat in
            abs(Double(beat.sampleTime) - Double(index) * interval) <= 1
        })
    }

    @Test func tempoChangeAppliesAfterTheLastReturnedBeat() {
        var clock = BeatClock(sampleRate: 48_000, startSampleTime: 0)
        _ = clock.beats(before: 24_001, bpm: 120, beatsPerBar: 4, accents: [1])
        #expect(clock.beats(before: 72_001, bpm: 60, beatsPerBar: 4, accents: [1]) == [beat(3, false, 72_000)])
    }

    @Test func accentChangeAppliesOnlyToBeatsNotYetReturned() {
        var clock = BeatClock(sampleRate: 48_000, startSampleTime: 0)
        let first = clock.beats(before: 1, bpm: 120, beatsPerBar: 2, accents: [1])
        #expect(first == [beat(1, true, 0)])
        let next = clock.beats(before: 48_001, bpm: 120, beatsPerBar: 2, accents: [2])
        #expect(next == [beat(2, true, 24_000), beat(1, false, 48_000)])
    }

    @Test func shrinkingTheBarWrapsToBeatOne() {
        var clock = BeatClock(sampleRate: 48_000, startSampleTime: 0)
        _ = clock.beats(before: 72_001, bpm: 120, beatsPerBar: 4, accents: [1])
        #expect(clock.beats(before: 96_001, bpm: 120, beatsPerBar: 3, accents: [1]) == [beat(1, true, 96_000)])
    }

    @Test func startingANewBarMakesTheNextBeatBeatOne() {
        var clock = BeatClock(sampleRate: 48_000, startSampleTime: 0)
        _ = clock.beats(before: 24_001, bpm: 120, beatsPerBar: 4, accents: [1])
        clock.startNewBar()
        let next = clock.beats(before: 72_001, bpm: 120, beatsPerBar: 3, accents: [1])
        #expect(next == [beat(1, true, 48_000), beat(2, false, 72_000)])
    }

    @Test func bigTempoJumpNeverSchedulesBeatsInThePast() {
        var clock = BeatClock(sampleRate: 48_000, startSampleTime: 0)
        _ = clock.beats(before: 1, bpm: 30, beatsPerBar: 4, accents: [1])
        // 1.9 s after the click at 30 BPM, the tempo jumps to 250 BPM.
        // At 250 BPM the next beats would have been due at 0.24 s, 0.48 s, ... all in the past.
        let now: Int64 = 91_200
        let due = clock.beats(before: now + 7_200, notBefore: now, bpm: 250, beatsPerBar: 4, accents: [1])
        #expect(due == [beat(2, false, now)])
        let next = clock.beats(before: now + 12_000, notBefore: now + 100, bpm: 250, beatsPerBar: 4, accents: [1])
        #expect(next == [beat(3, false, now + 11_520)])
    }

    @Test func fastTempoDraggingNeverBunchesOrSkipsBeats() {
        var clock = BeatClock(sampleRate: 48_000, startSampleTime: 0)
        var all: [ScheduledBeat] = []
        var horizon: Int64 = 0
        var fast = false
        while horizon < 480_000 {
            horizon += 512
            fast.toggle()
            all += clock.beats(before: horizon, bpm: fast ? 250 : 30, beatsPerBar: 4, accents: [1])
        }
        #expect(all.count > 2)
        for (previous, current) in zip(all, all.dropFirst()) {
            #expect(current.sampleTime - previous.sampleTime >= 11_520)
            #expect(current.beat == previous.beat % 4 + 1)
        }
    }
}
