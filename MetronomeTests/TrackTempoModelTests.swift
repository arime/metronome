import Foundation
import Testing
@testable import Metronome

/// The track's own tempo: the tempo in effect, the Save button around it and its stepper.
@MainActor
@Suite
struct TrackTempoModelTests {
    private let bench: TrackTestBench
    private var engine: FakeClickEngine { bench.engine }
    private var haptics: FakeHaptics { bench.haptics }

    init() throws {
        bench = try TrackTestBench()
    }

    /// The loaded song is at 120 BPM in 4/4; its track is at 90 BPM.
    private func makeModel(trackBPM: Int = 90, missing: Bool = false) throws -> MetronomeModel {
        try bench.makeModel(trackBPM: trackBPM, missing: missing)
    }

    // MARK: - The tempo in effect

    @Test func theClickPlaysAtTheTracksTempo() throws {
        let model = try makeModel()
        #expect(model.tempoInEffect == 90)
        #expect(model.settings.bpm == 120)
        model.togglePlayback()
        #expect(engine.startedSettings.last?.bpm == 90)
        #expect(engine.startedTracks.count == 1)
    }

    @Test func aMissingFilePlaysTheClickAtTheTracksTempo() throws {
        let model = try makeModel(missing: true)
        model.togglePlayback()
        #expect(engine.startedSettings.last?.bpm == 90)
        #expect(engine.startedTracks.isEmpty)
    }

    @Test func switchedOffTheClickPlaysAtTheMetronomesTempo() throws {
        let model = try makeModel()
        model.toggleBackingTracks()
        #expect(model.tempoInEffect == 120)
        model.togglePlayback()
        #expect(engine.startedSettings.last?.bpm == 120)
    }

    @Test func theSwitchSwapsTheTempoWithoutChangingEither() throws {
        let model = try makeModel()
        model.toggleBackingTracks()
        #expect(model.tempoInEffect == 120)
        #expect(model.loadedTrack?.bpm == 90)
        #expect(model.settings.bpm == 120)
        model.toggleBackingTracks()
        #expect(model.tempoInEffect == 90)
        #expect(model.loadedTrack?.bpm == 90)
        #expect(model.settings.bpm == 120)
    }

    @Test func unloadPlaysAtTheMetronomesTempo() throws {
        let model = try makeModel()
        model.unloadSong()
        #expect(model.tempoInEffect == 120)
    }

    @Test func aClickThatPlaysOnTakesTheTempoInEffectWhenTheTrackGoes() throws {
        let model = try makeModel(missing: true)
        model.togglePlayback()
        model.unloadSong()
        #expect(model.isPlaying)
        #expect(engine.lastUpdate?.bpm == 120)
    }

    // MARK: - Save and Revert

    /// The metronome's tempo, set with Backing tracks off, as the dial sets the track's while it is on.
    private func setMetronomeTempo(of model: MetronomeModel, by delta: Int) {
        model.toggleBackingTracks()
        model.nudgeBPM(by: delta)
        model.toggleBackingTracks()
    }

    @Test func anUnsavedMetronomeTempoIsNotEditedWhileTheTrackIsInUse() throws {
        let model = try makeModel()
        setMetronomeTempo(of: model, by: 5)
        #expect(model.settings.bpm == 125)
        #expect(model.isEdited == false)
        #expect(model.isSaveOffered == false)
        #expect(model.tempoInEffect == 90)
        model.toggleBackingTracks()
        #expect(model.isEdited)
        #expect(model.isSaveOffered)
        model.toggleBackingTracks()
        #expect(model.isEdited == false)
        #expect(model.isSaveOffered == false)
    }

    @Test func anAccentOnTheTrackScreenShowsSave() throws {
        let model = try makeModel()
        model.toggleAccent(beat: 2)
        #expect(model.isEdited)
        #expect(model.isSaveOffered)
    }

    @Test func saveWritesTheMetronomesTempoToo() throws {
        let model = try makeModel()
        setMetronomeTempo(of: model, by: 5)
        model.toggleAccent(beat: 2)
        model.saveChanges()
        #expect(model.loadedSong?.settings.bpm == 125)
        #expect(model.loadedSong?.settings.accents == [1, 2])
        #expect(model.loadedTrack?.bpm == 90)
    }

    @Test func revertSetsBackTheMetronomesTempoAndLeavesTheTracks() throws {
        let model = try makeModel()
        setMetronomeTempo(of: model, by: 5)
        model.togglePlayback()
        model.toggleAccent(beat: 2)
        model.discardChanges()
        #expect(model.settings.bpm == 120)
        #expect(engine.lastUpdate?.bpm == 90)
        #expect(model.loadedTrack?.bpm == 90)
    }

    @Test func editingTheSongsTempoLeavesTheTempoInEffect() throws {
        let model = try makeModel()
        let id = try #require(model.loadedSongID)
        model.togglePlayback()
        model.editSong(id, name: "Song", settings: MetronomeSettings(bpm: 100, timeSignature: .fourFour, accents: [1]))
        #expect(model.settings.bpm == 100)
        #expect(model.tempoInEffect == 90)
        #expect(engine.lastUpdate?.bpm == 90)
    }

    // MARK: - The tempo controls while a track is in use

    private func savedSong(_ model: MetronomeModel) -> Song? {
        model.loadedSongID.flatMap { bench.libraryStore.load().library.song(id: $0) }
    }

    @Test func theDialSetsTheTracksTempoWhileATrackIsInUse() throws {
        let model = try makeModel()
        model.setBPM(100)
        #expect(model.loadedTrack?.bpm == 100)
        #expect(model.settings.bpm == 120)
        #expect(model.tempoInEffect == 100)
        #expect(model.isSaveOffered == false)
        #expect(haptics.selectionCount == 1)
    }

    @Test func minusAndPlusStepTheTracksTempo() throws {
        let model = try makeModel()
        model.nudgeBPM(by: 5)
        #expect(model.loadedTrack?.bpm == 95)
        #expect(model.settings.bpm == 120)
    }

    @Test func tapTempoSetsTheTracksTempo() throws {
        let model = try makeModel()
        model.tapTempo(at: 0)
        model.tapTempo(at: 0.5)
        #expect(model.loadedTrack?.bpm == 120)
        #expect(model.settings.bpm == 120)
    }

    @Test func theTracksTempoStaysInRange() throws {
        let model = try makeModel()
        model.setBPM(400)
        #expect(model.loadedTrack?.bpm == 300)
    }

    @Test func aDialTurnWhilePlayingFollowsTheGridAndSavesOnce() async throws {
        let song = try #require(try makeModel().loadedSong)
        let model = bench.relaunch(saveDelay: .milliseconds(20))
        model.togglePlayback()
        let writes = bench.libraryDefaults.writes
        for bpm in 91...110 {
            model.setBPM(bpm)
            #expect(engine.lastUpdate?.bpm == bpm)
            #expect(engine.lastUpdateStartedNewBar == false)
        }
        #expect(engine.lastUpdate?.bpm == 110)
        #expect(engine.lastUpdateStartedNewBar == false)
        #expect(bench.libraryDefaults.writes == writes)
        try await bench.waitForASave(after: writes)
        #expect(bench.libraryDefaults.writes == writes + 1)
        #expect(bench.libraryStore.load().library.song(id: song.id)?.track?.bpm == 110)
    }

    @Test func saveAndRevertLeaveATempoSetFromTheDial() throws {
        let model = try makeModel()
        model.setBPM(100)
        model.toggleAccent(beat: 2)
        model.discardChanges()
        #expect(model.loadedTrack?.bpm == 100)
        model.toggleAccent(beat: 2)
        model.saveChanges()
        #expect(model.loadedTrack?.bpm == 100)
        #expect(savedSong(model)?.settings.bpm == 120)
        #expect(savedSong(model)?.track?.bpm == 100)
    }

    @Test func withTheFileMissingTheDialSetsTheTracksTempo() throws {
        let model = try makeModel(missing: true)
        model.setBPM(100)
        #expect(model.loadedTrack?.bpm == 100)
    }

    @Test func withBackingTracksOffTheDialSetsTheMetronomesTempo() throws {
        let model = try makeModel()
        model.toggleBackingTracks()
        model.setBPM(100)
        #expect(model.settings.bpm == 100)
        #expect(model.loadedTrack?.bpm == 90)
        #expect(model.isEdited)
    }

    @Test func aTimeSignatureWhileATrackIsInUseMakesTheSongEdited() throws {
        let model = try makeModel()
        model.selectTimeSignature(.threeFour)
        #expect(model.isEdited)
        #expect(model.isSaveOffered)
        #expect(savedSong(model)?.settings.timeSignature == .fourFour)
        model.saveChanges()
        #expect(savedSong(model)?.settings.timeSignature == .threeFour)
    }

    @Test func thePlayerShowsTheTrackOnlyWhileATrackIsInUse() throws {
        let model = try makeModel()
        #expect(model.playerContent == .track)
        model.toggleBackingTracks()
        #expect(model.playerContent == .metronome)
        model.toggleBackingTracks()
        model.unloadSong()
        #expect(model.playerContent == .metronome)
    }

    // MARK: - The Sync tempo stepper

    @Test func theTrackTempoStepsByOne() throws {
        let model = try makeModel()
        let ticks = haptics.selectionCount
        model.nudgeTrackTempo(by: 1)
        #expect(model.loadedTrack?.bpm == 91)
        #expect(model.settings.bpm == 120)
        #expect(model.isEdited == false)
        #expect(model.isSaveOffered == false)
        #expect(haptics.selectionCount == ticks + 1)
    }

    @Test func theTrackTempoStaysInRange() throws {
        let model = try makeModel(trackBPM: 300)
        let ticks = haptics.selectionCount
        model.nudgeTrackTempo(by: 1)
        #expect(model.loadedTrack?.bpm == 300)
        #expect(haptics.selectionCount == ticks)
    }

    @Test func aTrackTempoStepReachesThePlayingEngine() throws {
        let model = try makeModel()
        model.togglePlayback()
        model.nudgeTrackTempo(by: 1)
        #expect(engine.lastUpdate?.bpm == 91)
        #expect(engine.lastUpdateStartedNewBar == false)
    }

    @Test func aTrackTempoStepReachesTheClickOfAMissingFile() throws {
        let model = try makeModel(missing: true)
        model.togglePlayback()
        model.nudgeTrackTempo(by: 1)
        #expect(engine.lastUpdate?.bpm == 91)
    }

    @Test func severalTrackTempoStepsSaveOnce() async throws {
        let song = try #require(try makeModel().loadedSong)
        let model = bench.relaunch(saveDelay: .milliseconds(20))
        let writes = bench.libraryDefaults.writes
        for _ in 0..<5 { model.nudgeTrackTempo(by: 1) }
        #expect(bench.libraryDefaults.writes == writes)
        try await bench.waitForASave(after: writes)
        #expect(bench.libraryDefaults.writes == writes + 1)
        let saved = bench.libraryStore.load().library.song(id: song.id)
        #expect(saved?.track?.bpm == 95)
        #expect(saved?.settings.bpm == 120)
    }

    @Test func aTrackTempoSurvivesARelaunch() throws {
        let model = try makeModel()
        model.nudgeTrackTempo(by: 1)
        model.savePendingChanges()
        let relaunched = bench.relaunch()
        #expect(relaunched.loadedTrack?.bpm == 91)
        #expect(relaunched.loadedSong?.settings.bpm == 120)
    }

    // MARK: - Data from an earlier build

    /// A model whose loaded song is at 96 BPM with a playable track whose part has no tempo, as an
    /// earlier build wrote it.
    private func modelWithTrackFromAnEarlierBuild() throws -> MetronomeModel {
        let settings = MetronomeSettings(bpm: 96, timeSignature: .fourFour, accents: [1])
        let fileID = UUID()
        try bench.trackFiles.store(try bench.sourceFile(), as: fileID)
        let moment = Date()
        var record = SongRecord(id: UUID(), name: "Song", settings: settings, created: moment, now: moment)
        record.parts[SongRecord.trackKey] = Part(time: moment, value: .object([
            "fileID": .string(fileID.uuidString), "fileName": .string("Song.m4a"),
            "firstBeat": .number(48), "countIn": .number(2), "mix": .number(0),
        ]))
        var library = Library()
        library.merge(songs: [record], setlists: [])
        bench.settingsStore.save(settings)
        bench.libraryStore.save(LibraryState(library: library, loadedSongID: record.id))
        return bench.relaunch()
    }

    /// Loaded at launch, it plays at the song's tempo, offers no Save and writes nothing.
    @Test func aTrackFromAnEarlierBuildIsReadWithoutBeingWritten() throws {
        let model = try modelWithTrackFromAnEarlierBuild()
        let writes = bench.libraryDefaults.writes
        #expect(model.isTrackPlayable)
        #expect(model.tempoInEffect == 96)
        #expect(model.isSaveOffered == false)
        model.togglePlayback()
        #expect(engine.startedSettings.last?.bpm == 96)
        model.togglePlayback()
        #expect(bench.libraryDefaults.writes == writes)
    }

    @Test func editingTheSongsTempoLeavesAnEarlierBuildsTrackTempo() throws {
        let model = try modelWithTrackFromAnEarlierBuild()
        let id = try #require(model.loadedSongID)
        model.editSong(id, name: "Song", settings: MetronomeSettings(bpm: 100, timeSignature: .fourFour, accents: [1]))
        #expect(model.loadedSong?.settings.bpm == 100)
        #expect(model.tempoInEffect == 96)
        #expect(model.loadedTrack?.bpm == 96)
    }

    @Test func aTrackTempoStepNeedsATrackInUse() throws {
        let model = try makeModel()
        model.toggleBackingTracks()
        let ticks = haptics.selectionCount
        model.nudgeTrackTempo(by: 1)
        #expect(model.loadedTrack?.bpm == 90)
        #expect(haptics.selectionCount == ticks)
    }
}
