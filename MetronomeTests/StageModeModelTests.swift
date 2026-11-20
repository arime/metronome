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
        #expect(model.stageMode == StageMode(setlistID: setlist, nextSongID: b))
    }

    @Test func enteringWithASongFromElsewhereMarksTheFirst() {
        let (model, a, b, _, setlist) = modelWithSetlist()
        model.loadSong(b, from: nil)
        model.enterStageMode(setlistID: setlist)
        #expect(model.stageMode?.nextSongID == a)
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

    @Test func tappingThePlayingTileStopsAndMarksTheFollowing() {
        let (model, _, b, c, setlist) = modelWithSetlist()
        model.enterStageMode(setlistID: setlist)
        model.tapStageTile(b)
        model.tapStageTile(b)
        #expect(model.isPlaying == false)
        #expect(engine.stopCount == 1)
        #expect(haptics.transportCount == 2)
        #expect(model.stageMode?.nextSongID == c)
        #expect(model.stageTiles.map(\.mark) == [.none, .none, .next])
    }

    @Test func stoppingTheLastSongMarksNothing() {
        let (model, _, _, c, setlist) = modelWithSetlist()
        model.enterStageMode(setlistID: setlist)
        model.tapStageTile(c)
        model.tapStageTile(c)
        #expect(model.isPlaying == false)
        #expect(model.stageMode != nil)
        #expect(model.stageMode?.nextSongID == nil)
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

    @Test func anInterruptionMarksTheFollowingSong() {
        let (model, a, b, _, setlist) = modelWithSetlist()
        model.enterStageMode(setlistID: setlist)
        model.tapStageTile(a)
        engine.onStopped?()
        #expect(model.isPlaying == false)
        #expect(model.stageMode?.nextSongID == b)
        #expect(model.stageMode != nil)
    }

    @Test func leavingTheForegroundMarksTheFollowingSong() {
        let (model, a, b, _, setlist) = modelWithSetlist()
        model.enterStageMode(setlistID: setlist)
        model.tapStageTile(a)
        model.appDidLeaveForeground()
        #expect(model.isPlaying == false)
        #expect(model.stageMode?.nextSongID == b)
    }

    @Test func aFailedStartKeepsTheTappedTileNext() {
        let (model, _, b, _, setlist) = modelWithSetlist()
        model.enterStageMode(setlistID: setlist)
        engine.startError = StartFailed()
        model.tapStageTile(b)
        #expect(model.isPlaying == false)
        #expect(model.stageMode?.nextSongID == b)
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
    ) throws -> (model: MetronomeModel, song: UUID, following: UUID) {
        let model = try bench.makeModel(missing: missing)
        let song = try #require(model.loadedSongID)
        let setlist = model.createSetlist()
        model.setSong(song, inSetlist: setlist, included: true)
        let following = try #require(
            model.createSong(name: "Following", settings: MetronomeSettings(bpm: 90, timeSignature: .fourFour, accents: [1]), addingTo: setlist))
        model.enterStageMode(setlistID: setlist)
        return (model, song, following.id)
    }

    @Test func aTileWithATrackCountsIn() throws {
        let bench = try TrackTestBench()
        let (model, song, _) = try trackModelInStageMode(bench)
        model.tapStageTile(song)
        let started = try #require(bench.engine.startedTracks.last)
        #expect(started.startTime < 0)
        #expect(model.isPlayingTrack)
        #expect(model.stagePlayingSongID == song)
    }

    @Test func theSameTileAgainStartsFromTheTop() throws {
        let bench = try TrackTestBench()
        let (model, song, _) = try trackModelInStageMode(bench)
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

    @Test func theEndOfTheTrackMarksTheFollowingSong() throws {
        let bench = try TrackTestBench()
        let (model, song, following) = try trackModelInStageMode(bench)
        model.tapStageTile(song)
        bench.engine.onTrackEnded?()
        #expect(model.isPlaying == false)
        #expect(model.stageMode?.nextSongID == following)
    }

    @Test func aMissingFilePlaysTheClickAlone() throws {
        let bench = try TrackTestBench()
        let (model, song, _) = try trackModelInStageMode(bench, missing: true)
        model.tapStageTile(song)
        #expect(model.isPlaying)
        #expect(bench.engine.startedTracks.isEmpty)
        #expect(model.stagePlayingSongID == song)
    }
}
