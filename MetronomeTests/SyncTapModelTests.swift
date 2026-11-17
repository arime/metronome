import Foundation
import Testing
@testable import Metronome

/// Sync mode's Tap tempo and Tap on beat 1 pads, and the tempo typed in the tempo sheet: each sets
/// one value of the track and never the metronome's tempo.
@MainActor
@Suite
struct SyncTapModelTests {
    private let bench: TrackTestBench
    private var engine: FakeClickEngine { bench.engine }
    private var haptics: FakeHaptics { bench.haptics }

    init() throws {
        bench = try TrackTestBench()
    }

    /// The loaded song is at 120 BPM in 4/4; its track is at `trackBPM` with its offset at 0.48 s.
    private func makeModel(trackBPM: Int = 90) throws -> MetronomeModel {
        try bench.makeModel(trackBPM: trackBPM)
    }

    private func tapOnBeat1(_ model: MetronomeModel, at time: TimeInterval) {
        engine.trackTime = time
        model.tapDownbeat()
    }

    // MARK: - Tap on beat 1

    @Test func tapOnBeat1SetsTheOffsetFromTheHeardPlace() throws {
        let model = try makeModel(trackBPM: 120)
        model.togglePlayback()
        let ticks = haptics.selectionCount
        tapOnBeat1(model, at: 9.30)
        #expect(model.loadedTrack?.offset == 130)
        #expect(model.loadedTrack?.bpm == 120)
        #expect(engine.offsets.last == 1.30)
        #expect(haptics.selectionCount == ticks + 1)
        #expect(model.isSaveOffered == false)
    }

    @Test func tapOnBeat1NeverChangesTheTempo() throws {
        let model = try makeModel(trackBPM: 125)
        model.togglePlayback()
        engine.lastUpdate = nil
        tapOnBeat1(model, at: 10.11)
        tapOnBeat1(model, at: 12.01)
        tapOnBeat1(model, at: 13.95)
        #expect(model.loadedTrack?.bpm == 125)
        #expect(model.settings.bpm == 120)
        #expect(engine.lastUpdate == nil)
        // A bar at 125 BPM in 4/4 is 1.92 s: 13.95 − 7 × 1.92 = 0.51.
        #expect(model.loadedTrack?.offset == 51)
    }

    @Test func theLatestTapOnBeat1Wins() throws {
        let model = try makeModel(trackBPM: 120)
        model.togglePlayback()
        tapOnBeat1(model, at: 9.30)
        tapOnBeat1(model, at: 10.70)
        #expect(model.loadedTrack?.offset == 70)
        tapOnBeat1(model, at: 9.50)
        #expect(model.loadedTrack?.offset == 150)
        #expect(engine.offsets.last == 1.50)
    }

    @Test func aTapOnBeat1AtTheSameOffsetMovesNothing() throws {
        let model = try makeModel(trackBPM: 120)
        model.togglePlayback()
        tapOnBeat1(model, at: 9.30)
        let offsets = engine.offsets.count
        let ticks = haptics.selectionCount
        tapOnBeat1(model, at: 11.30)
        #expect(model.loadedTrack?.offset == 130)
        #expect(engine.offsets.count == offsets)
        #expect(haptics.selectionCount == ticks + 1)
    }

    @Test func tapOnBeat1DoesNothingWhileStoppedOrCountingIn() throws {
        let model = try makeModel()
        let ticks = haptics.selectionCount
        #expect(model.canTapDownbeat == false)
        tapOnBeat1(model, at: 9.30)
        #expect(model.loadedTrack?.offset == 48)

        model.togglePlayback()
        tapOnBeat1(model, at: -1)
        #expect(model.canTapDownbeat == false)
        #expect(model.loadedTrack?.offset == 48)
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
        #expect(model.loadedTrack?.offset == 48)
        #expect(haptics.selectionCount == ticks)
    }

    @Test func severalTapsOnBeat1SaveOnce() async throws {
        let song = try #require(try makeModel(trackBPM: 120).loadedSong)
        let model = bench.relaunch(saveDelay: .milliseconds(20))
        model.togglePlayback()
        let writes = bench.libraryDefaults.writes
        tapOnBeat1(model, at: 9.30)
        tapOnBeat1(model, at: 10.70)
        tapOnBeat1(model, at: 12.90)
        #expect(bench.libraryDefaults.writes == writes)
        try await bench.waitForASave(after: writes)
        #expect(bench.libraryDefaults.writes == writes + 1)
        #expect(bench.libraryStore.load().library.song(id: song.id)?.track?.offset == 90)
    }

    // MARK: - Tap tempo

    @Test func tapTempoSetsTheTracksTempo() throws {
        let model = try makeModel()
        let ticks = haptics.selectionCount
        model.tapTrackTempo(at: 0)
        #expect(model.loadedTrack?.bpm == 90)
        model.tapTrackTempo(at: 0.5)
        #expect(model.loadedTrack?.bpm == 120)
        model.tapTrackTempo(at: 1.5)
        #expect(model.loadedTrack?.bpm == 80)
        #expect(haptics.selectionCount == ticks + 3)
        #expect(model.settings.bpm == 120)
        #expect(model.isEdited == false)
        #expect(model.isSaveOffered == false)
    }

    @Test func tapTempoAveragesTheLastFourIntervals() throws {
        let model = try makeModel()
        for time in [0, 1.0, 1.5, 2.0, 2.5, 3.0] { model.tapTrackTempo(at: time) }
        #expect(model.loadedTrack?.bpm == 120)
    }

    @Test func aPauseStartsANewTapTempoSeries() throws {
        let model = try makeModel()
        model.tapTrackTempo(at: 0)
        model.tapTrackTempo(at: 0.5)
        model.tapTrackTempo(at: 3.0)
        #expect(model.loadedTrack?.bpm == 120)
        model.tapTrackTempo(at: 3.4)
        #expect(model.loadedTrack?.bpm == 150)
    }

    @Test func tapTempoStaysInRange() throws {
        let model = try makeModel()
        model.tapTrackTempo(at: 0)
        model.tapTrackTempo(at: 0.1)
        #expect(model.loadedTrack?.bpm == 300)
        model.tapTrackTempo(at: 10)
        model.tapTrackTempo(at: 11.99)
        #expect(model.loadedTrack?.bpm == 30)
    }

    @Test func tapTempoReachesThePlayingEngine() throws {
        let model = try makeModel()
        model.togglePlayback()
        model.tapTrackTempo(at: 0)
        model.tapTrackTempo(at: 0.5)
        #expect(engine.lastUpdate?.bpm == 120)
        #expect(engine.lastUpdateStartedNewBar == false)
        #expect(model.isPlaying)
    }

    @Test func tapTempoTicksForEveryTapWhilePlaying() throws {
        let model = try makeModel()
        model.togglePlayback()
        let ticks = haptics.selectionCount
        model.tapTrackTempo(at: 0)
        model.tapTrackTempo(at: 0.5)
        model.tapTrackTempo(at: 1.0)
        #expect(haptics.selectionCount == ticks + 3)
        #expect(model.isPlaying)
    }

    @Test func tapTempoHasASeriesOfItsOwn() throws {
        let model = try makeModel()
        model.toggleBackingTracks()
        model.tapTempo(at: 0)
        model.toggleBackingTracks()
        model.tapTrackTempo(at: 0.5)
        #expect(model.loadedTrack?.bpm == 90)
        #expect(model.settings.bpm == 120)
    }

    @Test func tapTempoNeedsATrackInUse() throws {
        let model = try makeModel()
        model.toggleBackingTracks()
        let ticks = haptics.selectionCount
        model.tapTrackTempo(at: 0)
        model.tapTrackTempo(at: 0.5)
        #expect(model.loadedTrack?.bpm == 90)
        #expect(model.settings.bpm == 120)
        #expect(haptics.selectionCount == ticks)

        model.toggleBackingTracks()
        model.unloadSong()
        let unloadedTicks = haptics.selectionCount
        model.tapTrackTempo(at: 1)
        model.tapTrackTempo(at: 1.5)
        #expect(model.settings.bpm == 120)
        #expect(haptics.selectionCount == unloadedTicks)
    }

    @Test func severalTapTempoTapsSaveOnce() async throws {
        let song = try #require(try makeModel().loadedSong)
        let model = bench.relaunch(saveDelay: .milliseconds(20))
        let writes = bench.libraryDefaults.writes
        for time in [0, 0.5, 1.0, 1.5] { model.tapTrackTempo(at: time) }
        #expect(bench.libraryDefaults.writes == writes)
        try await bench.waitForASave(after: writes)
        #expect(bench.libraryDefaults.writes == writes + 1)
        let saved = bench.libraryStore.load().library.song(id: song.id)
        #expect(saved?.track?.bpm == 120)
        #expect(saved?.settings.bpm == 120)
    }

    // MARK: - The typed tempo

    @Test func theTypedTempoSetsTheTracksTempo() throws {
        let model = try makeModel()
        let ticks = haptics.selectionCount
        model.setTrackTempo(140)
        #expect(model.loadedTrack?.bpm == 140)
        #expect(model.settings.bpm == 120)
        #expect(haptics.selectionCount == ticks + 1)
        #expect(model.isEdited == false)
        #expect(model.isSaveOffered == false)
        model.savePendingChanges()
        #expect(bench.relaunch().loadedTrack?.bpm == 140)
    }

    @Test func theTypedTempoTicksOnlyWhenItChanges() throws {
        let model = try makeModel()
        let ticks = haptics.selectionCount
        model.setTrackTempo(90)
        #expect(haptics.selectionCount == ticks)
    }

    @Test func theTypedTempoIsClamped() throws {
        let model = try makeModel()
        model.setTrackTempo(400)
        #expect(model.loadedTrack?.bpm == 300)
        model.setTrackTempo(10)
        #expect(model.loadedTrack?.bpm == 30)
    }

    @Test func theTypedTempoReachesThePlayingEngine() throws {
        let model = try makeModel()
        model.togglePlayback()
        model.setTrackTempo(140)
        #expect(engine.lastUpdate?.bpm == 140)
        #expect(engine.lastUpdateStartedNewBar == false)
    }

    @Test func theTypedTempoNeedsATrackInUse() throws {
        let model = try makeModel()
        model.toggleBackingTracks()
        let ticks = haptics.selectionCount
        model.setTrackTempo(140)
        #expect(model.loadedTrack?.bpm == 90)
        #expect(model.settings.bpm == 120)
        #expect(haptics.selectionCount == ticks)
    }
}
