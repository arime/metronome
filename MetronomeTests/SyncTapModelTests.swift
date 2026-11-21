import Foundation
import Testing
@testable import Metronome

/// Sync mode's Tap tempo and Tap on beat 1 pads: Tap tempo sets the song's tempo, Tap on beat 1
/// only the track's offset.
@MainActor
@Suite
struct SyncTapModelTests {
    private let bench: TrackTestBench
    private var engine: FakeClickEngine { bench.engine }
    private var haptics: FakeHaptics { bench.haptics }

    init() throws {
        bench = try TrackTestBench()
    }

    /// The loaded song is at `bpm` in 4/4, with a track whose offset is 0.48 s.
    private func makeModel(bpm: Int = 90) throws -> MetronomeModel {
        try bench.makeModel(bpm: bpm)
    }

    private func tapOnBeat1(_ model: MetronomeModel, at time: TimeInterval) {
        engine.trackTime = time
        model.tapDownbeat()
    }

    // MARK: - Tap on beat 1

    @Test func tapOnBeat1SetsTheOffsetFromTheHeardPlace() throws {
        let model = try makeModel(bpm: 120)
        model.togglePlayback()
        let ticks = haptics.selectionCount
        tapOnBeat1(model, at: 9.30)
        #expect(model.trackSettings?.offset == 130)
        #expect(model.settings.bpm == 120)
        #expect(engine.offsets.last == 1.30)
        #expect(haptics.selectionCount == ticks + 1)
        #expect(model.isSaveOffered)
    }

    @Test func tapOnBeat1NeverChangesTheTempo() throws {
        let model = try makeModel(bpm: 125)
        model.togglePlayback()
        engine.lastUpdate = nil
        tapOnBeat1(model, at: 10.11)
        tapOnBeat1(model, at: 12.01)
        tapOnBeat1(model, at: 13.95)
        #expect(model.settings.bpm == 125)
        #expect(engine.lastUpdate == nil)
        // A bar at 125 BPM in 4/4 is 1.92 s: 13.95 − 7 × 1.92 = 0.51.
        #expect(model.trackSettings?.offset == 51)
    }

    @Test func theLatestTapOnBeat1Wins() throws {
        let model = try makeModel(bpm: 120)
        model.togglePlayback()
        tapOnBeat1(model, at: 9.30)
        tapOnBeat1(model, at: 10.70)
        #expect(model.trackSettings?.offset == 70)
        tapOnBeat1(model, at: 9.50)
        #expect(model.trackSettings?.offset == 150)
        #expect(engine.offsets.last == 1.50)
    }

    @Test func aTapOnBeat1AtTheSameOffsetMovesNothing() throws {
        let model = try makeModel(bpm: 120)
        model.togglePlayback()
        tapOnBeat1(model, at: 9.30)
        let offsets = engine.offsets.count
        let ticks = haptics.selectionCount
        tapOnBeat1(model, at: 11.30)
        #expect(model.trackSettings?.offset == 130)
        #expect(engine.offsets.count == offsets)
        #expect(haptics.selectionCount == ticks + 1)
    }

    @Test func tapOnBeat1DoesNothingWhileStoppedOrCountingIn() throws {
        let model = try makeModel()
        let ticks = haptics.selectionCount
        #expect(model.canTapDownbeat == false)
        tapOnBeat1(model, at: 9.30)
        #expect(model.trackSettings?.offset == 48)

        model.togglePlayback()
        tapOnBeat1(model, at: -1)
        #expect(model.canTapDownbeat == false)
        #expect(model.trackSettings?.offset == 48)
        #expect(engine.offsets.isEmpty)
        #expect(haptics.selectionCount == ticks)
    }

    @Test func tapOnBeat1NeedsATrackInUse() throws {
        let model = try makeModel()
        model.toggleBackingTracks()
        model.togglePlayback()
        let ticks = haptics.selectionCount
        tapOnBeat1(model, at: 9.30)
        #expect(model.canTapDownbeat == false)
        #expect(model.trackSettings?.offset == 48)
        #expect(haptics.selectionCount == ticks)
    }

    // MARK: - Tap tempo

    @Test func tapTempoSetsTheSongsTempo() throws {
        let model = try makeModel()
        let ticks = haptics.selectionCount
        model.syncTapTempo(at: 0)
        #expect(model.settings.bpm == 90)
        model.syncTapTempo(at: 0.5)
        #expect(model.settings.bpm == 120)
        model.syncTapTempo(at: 1.5)
        #expect(model.settings.bpm == 80)
        #expect(haptics.selectionCount == ticks + 3)
        #expect(model.isEdited)
        #expect(model.isSaveOffered)
    }

    @Test func tapTempoAveragesTheLastFourIntervals() throws {
        let model = try makeModel()
        for time in [0, 1.0, 1.5, 2.0, 2.5, 3.0] { model.syncTapTempo(at: time) }
        #expect(model.settings.bpm == 120)
    }

    @Test func aPauseStartsANewTapTempoSeries() throws {
        let model = try makeModel()
        model.syncTapTempo(at: 0)
        model.syncTapTempo(at: 0.5)
        model.syncTapTempo(at: 3.0)
        #expect(model.settings.bpm == 120)
        model.syncTapTempo(at: 3.4)
        #expect(model.settings.bpm == 150)
    }

    @Test func tapTempoStaysInRange() throws {
        let model = try makeModel()
        model.syncTapTempo(at: 0)
        model.syncTapTempo(at: 0.1)
        #expect(model.settings.bpm == 300)
        model.syncTapTempo(at: 10)
        model.syncTapTempo(at: 11.99)
        #expect(model.settings.bpm == 30)
    }

    @Test func tapTempoReachesThePlayingEngine() throws {
        let model = try makeModel()
        model.togglePlayback()
        model.syncTapTempo(at: 0)
        model.syncTapTempo(at: 0.5)
        #expect(engine.lastUpdate?.bpm == 120)
        #expect(engine.lastUpdateStartedNewBar == false)
        #expect(model.isPlaying)
    }

    @Test func tapTempoTicksForEveryTapWhilePlaying() throws {
        let model = try makeModel()
        model.togglePlayback()
        let ticks = haptics.selectionCount
        model.syncTapTempo(at: 0)
        model.syncTapTempo(at: 0.5)
        model.syncTapTempo(at: 1.0)
        #expect(haptics.selectionCount == ticks + 3)
        #expect(model.isPlaying)
    }

    @Test func tapTempoHasASeriesOfItsOwn() throws {
        let model = try makeModel()
        model.tapTempo(at: 0)
        model.syncTapTempo(at: 0.5)
        #expect(model.settings.bpm == 90)
    }

    @Test func syncTapTempoWritesNothing() throws {
        let model = try makeModel()
        let writes = bench.libraryDefaults.writes
        for time in [0, 0.5, 1.0, 1.5] { model.syncTapTempo(at: time) }
        #expect(bench.libraryDefaults.writes == writes)
        #expect(model.settings.bpm == 120)
        #expect(model.loadedSong?.settings.bpm == 90)
    }
}
