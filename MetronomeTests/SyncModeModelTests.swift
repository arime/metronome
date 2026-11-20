import Foundation
import Testing
@testable import Metronome

/// Sync mode while a track is in use: entering and leaving it, its transport buttons, and the time
/// signature and accents it saves into the song at once.
@MainActor
@Suite
struct SyncModeModelTests {
    private let bench: TrackTestBench
    private var engine: FakeClickEngine { bench.engine }
    private var haptics: FakeHaptics { bench.haptics }

    init() throws {
        bench = try TrackTestBench()
    }

    private func savedSong(_ model: MetronomeModel) -> Song? {
        model.loadedSongID.flatMap { bench.libraryStore.load().library.song(id: $0) }
    }

    // MARK: - Entering and leaving

    @Test func syncModeIsOffAtLaunch() throws {
        let model = try bench.makeModel()
        #expect(model.isSyncModeShown == false)
        model.enterSyncMode()
        #expect(model.isSyncModeShown)
        #expect(bench.relaunch().isSyncModeShown == false)
    }

    @Test func enteringAndLeavingLeavesPlaybackAsItIs() throws {
        let model = try bench.makeModel()
        model.togglePlayback()
        let ticks = haptics.selectionCount
        let transports = haptics.transportCount
        let successes = haptics.successCount
        model.enterSyncMode()
        #expect(model.isSyncModeShown)
        #expect(model.isPlaying)
        #expect(engine.stopCount == 0)
        model.leaveSyncMode()
        #expect(model.isSyncModeShown == false)
        #expect(model.isPlaying)
        #expect(engine.stopCount == 0)
        #expect(haptics.selectionCount == ticks)
        #expect(haptics.transportCount == transports)
        #expect(haptics.successCount == successes)
    }

    @Test func syncModeNeedsThePlayableFile() throws {
        let missing = try bench.makeModel(missing: true)
        missing.enterSyncMode()
        #expect(missing.isSyncModeShown == false)

        let model = try bench.makeModel()
        model.toggleBackingTracks()
        model.enterSyncMode()
        #expect(model.isSyncModeShown == false)
    }

    @Test func doneSavesAWaitingChangeAtOnce() throws {
        let model = try bench.makeModel()
        model.enterSyncMode()
        model.nudgeOffset(by: 1)
        model.leaveSyncMode()
        #expect(savedSong(model)?.track?.offset == 49)
    }

    @Test func leavingTheForegroundKeepsSyncModeAndSaves() throws {
        let model = try bench.makeModel()
        model.enterSyncMode()
        model.togglePlayback()
        model.nudgeOffset(by: 1)
        model.appDidLeaveForeground()
        #expect(model.isPlaying == false)
        #expect(model.isSyncModeShown)
        #expect(savedSong(model)?.track?.offset == 49)
    }

    @Test func theSwitchCannotBeTurnedInSyncMode() throws {
        let model = try bench.makeModel()
        model.enterSyncMode()
        let ticks = haptics.selectionCount
        model.toggleBackingTracks()
        #expect(model.backingTracksOn)
        #expect(model.isSyncModeShown)
        #expect(haptics.selectionCount == ticks)
    }

    // MARK: - Transport

    @Test func playInSyncModeCountsInAtZero() throws {
        let model = try bench.makeModel()
        model.enterSyncMode()
        model.togglePlayback()
        let started = try #require(engine.startedTracks.last)
        #expect(started.startTime == 0.48 - 4.0)
        #expect(started.firstClickIndex == -8)
    }

    @Test func toTheBeginningWhileStoppedGoesToZero() throws {
        let model = try bench.makeModel()
        model.enterSyncMode()
        model.seekTrack(to: 70)
        #expect(model.trackPosition == 70)
        let ticks = haptics.selectionCount
        model.goToTrackStart()
        #expect(model.trackPosition == 0)
        #expect(haptics.selectionCount == ticks)
    }

    @Test func toTheBeginningWhilePlayingCarriesOnWithoutCountIn() throws {
        let model = try bench.makeModel()
        model.enterSyncMode()
        model.togglePlayback()
        engine.trackTime = 30
        model.goToTrackStart()
        #expect(engine.seeks.last == 0)
        #expect(model.isPlaying)
        #expect(engine.startCount == 1)
    }

    @Test func toTheBeginningDuringTheCountInChangesNothing() throws {
        let model = try bench.makeModel()
        model.enterSyncMode()
        model.togglePlayback()
        engine.trackTime = -2
        model.goToTrackStart()
        #expect(engine.seeks.isEmpty)
        #expect(model.isPlaying)
    }

    @Test func toTheEndStopsAndGoesToZero() throws {
        let model = try bench.makeModel()
        model.enterSyncMode()
        model.togglePlayback()
        engine.trackTime = 30
        let transports = haptics.transportCount
        model.goToTrackEnd()
        #expect(model.isPlaying == false)
        #expect(engine.stopCount == 1)
        #expect(model.trackPosition == 0)
        #expect(model.loadedTrack != nil)
        #expect(haptics.transportCount == transports)
        model.togglePlayback()
        #expect(engine.startedTracks.last?.startTime == 0.48 - 4.0)

        model.togglePlayback()
        model.seekTrack(to: 70)
        model.goToTrackEnd()
        #expect(model.trackPosition == 0)
    }

    // MARK: - Time signature and accents

    @Test func aTimeSignatureInSyncModeIsSavedAtOnce() throws {
        let model = try bench.makeModel()
        model.enterSyncMode()
        model.selectTimeSignature(.threeFour)
        #expect(model.loadedSong?.settings.timeSignature == .threeFour)
        #expect(model.loadedSong?.settings.accents == [1])
        #expect(model.isEdited == false)
        #expect(model.isSaveOffered == false)
        model.savePendingChanges()
        #expect(savedSong(model)?.settings.timeSignature == .threeFour)
    }

    @Test func anAccentInSyncModeIsSavedAtOnce() throws {
        let model = try bench.makeModel()
        model.enterSyncMode()
        model.toggleAccent(beat: 3)
        #expect(model.loadedSong?.settings.accents == [1, 3])
        #expect(model.isEdited == false)
        #expect(model.isSaveOffered == false)
        model.savePendingChanges()
        #expect(savedSong(model)?.settings.accents == [1, 3])
    }

    @Test func syncModeSavesAnEarlierAccentAndLeavesTheMetronomeTempo() throws {
        let model = try bench.makeModel()
        model.toggleAccent(beat: 2)
        #expect(model.isSaveOffered)
        // The metronome's tempo is set with the switch off, as the dial sets the track's while it is on.
        model.toggleBackingTracks()
        model.nudgeBPM(by: 5)
        model.toggleBackingTracks()
        model.enterSyncMode()
        model.toggleAccent(beat: 3)
        #expect(model.isSaveOffered == false)
        model.leaveSyncMode()
        #expect(savedSong(model)?.settings.accents == [1, 2, 3])
        #expect(savedSong(model)?.settings.bpm == 120)
        model.toggleBackingTracks()
        #expect(model.isEdited)
        #expect(model.isSaveOffered)
    }

    @Test func outsideSyncModeTheMeterIsNotSaved() throws {
        let model = try bench.makeModel()
        model.selectTimeSignature(.threeFour)
        #expect(model.loadedSong?.settings.timeSignature == .fourFour)
        #expect(model.isEdited)
    }

    @Test func severalSyncModeChangesSaveOnce() async throws {
        let song = try #require(try bench.makeModel().loadedSong)
        let model = bench.relaunch(saveDelay: .milliseconds(20))
        model.enterSyncMode()
        let writes = bench.libraryDefaults.writes
        model.toggleAccent(beat: 2)
        model.toggleAccent(beat: 3)
        model.nudgeOffset(by: 1)
        model.toggleAccent(beat: 4)
        model.nudgeOffset(by: 1)
        #expect(bench.libraryDefaults.writes == writes)
        try await bench.waitForASave(after: writes)
        #expect(bench.libraryDefaults.writes == writes + 1)
        let saved = bench.libraryStore.load().library.song(id: song.id)
        #expect(saved?.settings.accents == [1, 2, 3, 4])
        #expect(saved?.track?.offset == 50)
    }
}
