import Foundation
import Testing
@testable import Metronome

private struct StartFailed: Error {}

@MainActor
struct StageModeModelTests {
    private let engine = FakeClickEngine()
    private let haptics = FakeHaptics()
    private let store = SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    private let libraryStore = LibraryStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)

    private func makeModel() -> MetronomeModel {
        MetronomeModel(
            engine: engine, store: store, haptics: haptics, libraryStore: libraryStore, trackFiles: .temporary()
        )
    }

    /// A model with songs A 96, B 120 and C 168 in a setlist, in that order. B is in 3/4 so that
    /// creating it does not name the metronome's own settings and load it.
    private func modelWithSetlist() -> (model: MetronomeModel, a: UUID, b: UUID, c: UUID, setlist: UUID) {
        let model = makeModel()
        let songs = [(96, TimeSignature.fourFour), (120, .threeFour), (168, .sevenEight)].enumerated().map {
            model.createSong(
                name: ["A", "B", "C"][$0.offset],
                settings: MetronomeSettings(bpm: $0.element.0, timeSignature: $0.element.1, accents: [1]),
                addingTo: nil)!
        }
        let setlist = model.createSetlist()
        songs.forEach { model.setSong($0.id, inSetlist: setlist, included: true) }
        return (model, songs[0].id, songs[1].id, songs[2].id, setlist)
    }

    // MARK: - Entering

    @Test func enteringFromTheLoadedSetlistMarksTheLoadedSong() {
        let (model, _, b, _, setlist) = modelWithSetlist()
        model.loadSong(b, from: setlist)
        model.enterStageMode(setlistID: setlist)
        #expect(model.stageMode == StageMode(setlistID: setlist))
        #expect(model.stageTiles.map(\.mark) == [.none, .active, .none])
    }

    @Test func enteringWithASongFromElsewhereMarksNothing() {
        let (model, _, b, _, setlist) = modelWithSetlist()
        model.loadSong(b, from: nil)
        model.enterStageMode(setlistID: setlist)
        #expect(model.stageTiles.map(\.mark) == [.none, .none, .none])
    }

    @Test func enteringWithASongFromAnotherSetlistMarksNothing() {
        let (model, _, b, _, setlist) = modelWithSetlist()
        let other = model.createSetlist()
        model.setSong(b, inSetlist: other, included: true)
        model.loadSong(b, from: other)
        model.enterStageMode(setlistID: setlist)
        #expect(model.stageTiles.map(\.mark) == [.none, .none, .none])
    }

    @Test func enteringWithNothingLoadedMarksNothing() {
        let (model, _, _, _, setlist) = modelWithSetlist()
        model.unloadSong()
        model.enterStageMode(setlistID: setlist)
        #expect(model.loadedSongID == nil)
        #expect(model.stageTiles.map(\.mark) == [.none, .none, .none])
    }

    @Test func enteringChangesNothingOnTheMetronome() {
        let (model, _, b, _, setlist) = modelWithSetlist()
        model.loadSong(b, from: setlist)
        model.setBPM(130)
        model.enterStageMode(setlistID: setlist)
        #expect(model.stageMode != nil)
        #expect(model.settings.bpm == 130)
        #expect(model.isEdited)
        #expect(model.loadedSongID == b)
        #expect(engine.startCount == 0)
    }

    @Test func stageModeCannotBeEnteredWhilePlayingOrEmpty() {
        let (model, _, _, _, setlist) = modelWithSetlist()
        model.togglePlayback()
        #expect(model.canEnterStageMode(setlistID: setlist) == false)
        model.enterStageMode(setlistID: setlist)
        #expect(model.stageMode == nil)
        model.togglePlayback()

        let empty = model.createSetlist()
        #expect(model.canEnterStageMode(setlistID: empty) == false)
        model.enterStageMode(setlistID: empty)
        #expect(model.stageMode == nil)
        #expect(model.canEnterStageMode(setlistID: UUID()) == false)
    }

    // MARK: - Tiles

    @Test func aTapLoadsFromTheSetlistAndStarts() {
        let (model, _, _, c, setlist) = modelWithSetlist()
        model.enterStageMode(setlistID: setlist)
        let selections = haptics.selectionCount
        model.tapStageTile(c)
        #expect(model.loadedSongID == c)
        #expect(model.loadedFromSetlistID == setlist)
        #expect(model.isPlaying)
        #expect(engine.startCount == 1)
        #expect(model.stagePlayingSongID == c)
        #expect(haptics.transportCount == 1)
        #expect(haptics.selectionCount == selections)
        #expect(model.stageTiles.map(\.mark) == [.none, .none, .playing])
    }

    @Test func aTapDropsAnotherSongsUnsavedEdits() {
        let (model, a, b, _, setlist) = modelWithSetlist()
        model.loadSong(a, from: setlist)
        model.setBPM(99)
        model.enterStageMode(setlistID: setlist)
        model.tapStageTile(b)
        #expect(model.loadedSongID == b)
        #expect(model.settings.bpm == 120)
    }

    @Test func theLoadedSongsOwnTileKeepsItsEdits() {
        let (model, a, _, _, setlist) = modelWithSetlist()
        model.loadSong(a, from: setlist)
        model.setBPM(99)
        model.enterStageMode(setlistID: setlist)
        model.tapStageTile(a)
        #expect(model.settings.bpm == 99)
        #expect(model.isPlaying)
        #expect(engine.startedSettings.last?.bpm == 99)
    }

    @Test func tappingThePlayingTileStopsAndKeepsItMarked() {
        let (model, _, b, _, setlist) = modelWithSetlist()
        model.enterStageMode(setlistID: setlist)
        model.tapStageTile(b)
        model.tapStageTile(b)
        #expect(model.isPlaying == false)
        #expect(engine.stopCount == 1)
        #expect(haptics.transportCount == 2)
        #expect(model.stageTiles.map(\.mark) == [.none, .active, .none])
    }

    @Test func stoppingTheLastSongKeepsItMarked() {
        let (model, _, _, c, setlist) = modelWithSetlist()
        model.enterStageMode(setlistID: setlist)
        model.tapStageTile(c)
        model.tapStageTile(c)
        #expect(model.isPlaying == false)
        #expect(model.stageMode != nil)
        #expect(model.stageTiles.map(\.mark) == [.none, .none, .active])
    }

    @Test func otherTilesDoNothingWhileOnePlays() {
        let (model, a, _, c, setlist) = modelWithSetlist()
        model.enterStageMode(setlistID: setlist)
        model.tapStageTile(a)
        model.tapStageTile(c)
        #expect(model.loadedSongID == a)
        #expect(model.isPlaying)
        #expect(engine.startCount == 1)
        #expect(haptics.transportCount == 1)
    }

    @Test func doneDoesNothingWhileATilePlays() {
        let (model, a, _, _, setlist) = modelWithSetlist()
        model.enterStageMode(setlistID: setlist)
        model.tapStageTile(a)
        #expect(model.canLeaveStageMode == false)
        model.leaveStageMode()
        #expect(model.stageMode != nil)
        model.tapStageTile(a)
        #expect(model.canLeaveStageMode)
        model.leaveStageMode()
        #expect(model.stageMode == nil)
        #expect(model.loadedSongID == a)
        #expect(model.stageTiles.isEmpty)
    }

    // MARK: - Stopping by itself

    @Test func anInterruptionKeepsThePlayedSongMarked() {
        let (model, a, _, _, setlist) = modelWithSetlist()
        model.enterStageMode(setlistID: setlist)
        model.tapStageTile(a)
        engine.onStopped?()
        #expect(model.isPlaying == false)
        #expect(model.stageMode != nil)
        #expect(model.stageTiles.map(\.mark) == [.active, .none, .none])
    }

    @Test func leavingTheForegroundKeepsThePlayedSongMarked() {
        let (model, a, _, _, setlist) = modelWithSetlist()
        model.enterStageMode(setlistID: setlist)
        model.tapStageTile(a)
        model.appDidLeaveForeground()
        #expect(model.isPlaying == false)
        #expect(model.stageTiles.map(\.mark) == [.active, .none, .none])
    }

    @Test func aFailedStartMarksTheTappedTile() {
        let (model, _, b, _, setlist) = modelWithSetlist()
        model.enterStageMode(setlistID: setlist)
        engine.startError = StartFailed()
        model.tapStageTile(b)
        #expect(model.isPlaying == false)
        #expect(model.stageTiles.map(\.mark) == [.none, .active, .none])
    }

    @Test func theScreenStaysAwakeWhileStageModeIsShown() {
        let (model, _, _, _, setlist) = modelWithSetlist()
        #expect(model.keepScreenAwake == false)
        #expect(model.screenStaysAwake == false)
        model.enterStageMode(setlistID: setlist)
        #expect(model.screenStaysAwake)
        model.leaveStageMode()
        #expect(model.screenStaysAwake == false)
    }

    // MARK: - Backing tracks

    /// The bench's song with a track, first in a setlist, and a song without one after it.
    private func trackModelInStageMode(
        _ bench: TrackTestBench, missing: Bool = false
    ) throws -> (model: MetronomeModel, song: UUID) {
        let model = try bench.makeModel(missing: missing)
        let song = try #require(model.loadedSongID)
        let setlist = model.createSetlist()
        model.setSong(song, inSetlist: setlist, included: true)
        _ = try #require(
            model.createSong(name: "Following", settings: MetronomeSettings(bpm: 90, timeSignature: .fourFour, accents: [1]), addingTo: setlist))
        model.enterStageMode(setlistID: setlist)
        return (model, song)
    }

    @Test func aTileWithATrackCountsIn() throws {
        let bench = try TrackTestBench()
        let (model, song) = try trackModelInStageMode(bench)
        model.tapStageTile(song)
        let started = try #require(bench.engine.startedTracks.last)
        #expect(started.startTime < 0)
        #expect(model.isPlayingTrack)
        #expect(model.stagePlayingSongID == song)
    }

    @Test func theSameTileAgainStartsFromTheTop() throws {
        let bench = try TrackTestBench()
        let (model, song) = try trackModelInStageMode(bench)
        model.tapStageTile(song)
        bench.engine.trackTime = 80
        model.tapStageTile(song)
        #expect(model.isPlaying == false)
        #expect(model.trackPosition == 80)
        model.tapStageTile(song)
        #expect(bench.engine.startedTracks.count == 2)
        let started = try #require(bench.engine.startedTracks.last)
        #expect(started.startTime < 0)
    }

    @Test func theLoadedSongsTilePlaysItsUnsavedOffsetAndCountInFromTheTop() throws {
        let bench = try TrackTestBench()
        let (model, song) = try trackModelInStageMode(bench)
        #expect(model.loadedSongID == song)
        model.nudgeOffset(by: 2)
        model.setCountIn(.oneBar)
        model.seekTrack(to: 30)
        model.tapStageTile(song)
        let started = try #require(bench.engine.startedTracks.last)
        #expect(started.offset == 0.5)
        #expect(started.startTime == 0.5 - 2.0)
        #expect(started.firstClickIndex == -4)
        #expect(model.trackSettings?.offset == 50)
        #expect(model.isEdited)
    }

    @Test func theEndOfTheTrackKeepsItsSongMarked() throws {
        let bench = try TrackTestBench()
        let (model, song) = try trackModelInStageMode(bench)
        model.tapStageTile(song)
        bench.engine.onTrackEnded?()
        #expect(model.isPlaying == false)
        #expect(model.stageTiles.map(\.mark) == [.active, .none])
    }

    @Test func theTrackMarksFollowTheBackingTracksSwitch() throws {
        let bench = try TrackTestBench()
        let (model, _) = try trackModelInStageMode(bench)
        #expect(model.backingTracksOn)
        #expect(model.stageTiles.map(\.showsTrackMark) == [true, false])
        model.toggleBackingTracks()
        #expect(model.stageTiles.map(\.showsTrackMark) == [false, false])
    }

    @Test func aTrackWhoseFileIsMissingStillShowsTheMark() throws {
        let bench = try TrackTestBench()
        let (model, _) = try trackModelInStageMode(bench, missing: true)
        #expect(model.stageTiles.map(\.showsTrackMark) == [true, false])
    }

    @Test func aMissingFilePlaysTheClickAlone() throws {
        let bench = try TrackTestBench()
        let (model, song) = try trackModelInStageMode(bench, missing: true)
        model.tapStageTile(song)
        #expect(model.isPlaying)
        #expect(bench.engine.startedTracks.isEmpty)
        #expect(model.stagePlayingSongID == song)
    }
}
