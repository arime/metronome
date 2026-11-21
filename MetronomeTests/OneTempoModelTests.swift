import Foundation
import Testing
@testable import Metronome

/// A song has one tempo, with its track in use or not: every tempo control sets it as an ordinary
/// edit, the click plays at it, and the Backing tracks switch changes no setting.
@MainActor
@Suite
struct OneTempoModelTests {
    private let bench: TrackTestBench
    private var engine: FakeClickEngine { bench.engine }
    private var haptics: FakeHaptics { bench.haptics }

    init() throws {
        bench = try TrackTestBench()
    }

    /// The loaded song is at 120 BPM in 4/4 with a track, playable unless `missing`.
    private func makeModel(missing: Bool = false) throws -> MetronomeModel {
        try bench.makeModel(missing: missing)
    }

    private func savedSong(_ model: MetronomeModel) -> Song? {
        model.loadedSongID.flatMap { bench.libraryStore.load().library.song(id: $0) }
    }

    // MARK: - The tempo controls

    @Test func theDialSetsTheSongsTempoWithATrackInUse() throws {
        let model = try makeModel()
        let ticks = haptics.selectionCount
        model.setBPM(100)
        #expect(model.settings.bpm == 100)
        #expect(model.isEdited)
        #expect(model.isSaveOffered)
        #expect(haptics.selectionCount == ticks + 1)
    }

    @Test func minusPlusAndTapTempoSetTheSameTempo() throws {
        let model = try makeModel()
        model.nudgeBPM(by: 5)
        #expect(model.settings.bpm == 125)
        model.tapTempo(at: 0)
        model.tapTempo(at: 0.5)
        #expect(model.settings.bpm == 120)
    }

    @Test func theTempoStaysInRange() throws {
        let model = try makeModel()
        model.setBPM(400)
        #expect(model.settings.bpm == 300)
        model.setBPM(10)
        #expect(model.settings.bpm == 30)
    }

    @Test func theClickPlaysAtTheSongsTempoWithTheTrack() throws {
        let model = try makeModel()
        model.setBPM(100)
        model.togglePlayback()
        #expect(engine.startedSettings.last?.bpm == 100)
        #expect(model.isPlayingTrack)
    }

    @Test func aDialTurnWhilePlayingFollowsTheGridAndWritesNothing() throws {
        let model = try makeModel()
        model.togglePlayback()
        let writes = bench.libraryDefaults.writes
        for bpm in 91...110 {
            model.setBPM(bpm)
            #expect(engine.lastUpdate?.bpm == bpm)
            #expect(engine.lastUpdateStartedNewBar == false)
        }
        #expect(bench.libraryDefaults.writes == writes)
        #expect(model.isPlayingTrack)
    }

    @Test func withTheFileMissingTheDialSetsTheTempo() throws {
        let model = try makeModel(missing: true)
        model.setBPM(100)
        model.togglePlayback()
        #expect(engine.startedSettings.last?.bpm == 100)
        #expect(model.isEdited)
    }

    @Test func withTheFileMissingATempoChangeReachesThePlayingClick() throws {
        let model = try makeModel(missing: true)
        model.togglePlayback()
        #expect(model.isPlaying)
        #expect(model.isPlayingTrack == false)
        model.setBPM(100)
        #expect(engine.lastUpdate?.bpm == 100)
        #expect(model.isPlaying)
    }

    @Test func syncModesTempoStepperIsTheDials() throws {
        let model = try makeModel()
        model.enterSyncMode()
        model.nudgeBPM(by: 1)
        #expect(model.settings.bpm == 121)
        #expect(model.isSaveOffered)
        model.leaveSyncMode()
        #expect(model.settings.bpm == 121)
        #expect(model.isSaveOffered)
    }

    // MARK: - Save, Revert, Unload and Edit song

    @Test func saveChangesSavesATempoSetWithATrackInUse() throws {
        let model = try makeModel()
        model.setBPM(100)
        model.saveChanges()
        #expect(savedSong(model)?.settings.bpm == 100)
        #expect(model.isSaveOffered == false)
    }

    @Test func revertSetsTheTempoBackWhilePlaying() throws {
        let model = try makeModel()
        model.togglePlayback()
        model.setBPM(100)
        model.discardChanges()
        #expect(model.settings.bpm == 120)
        #expect(engine.lastUpdate?.bpm == 120)
        #expect(engine.lastUpdateStartedNewBar == false)
        #expect(model.isSaveOffered == false)
    }

    @Test func unloadKeepsTheTempo() throws {
        let model = try makeModel()
        model.setBPM(100)
        model.unloadSong()
        #expect(model.settings.bpm == 100)
    }

    @Test func editingTheLoadedSongsTempoMovesTheClick() throws {
        let model = try makeModel()
        let id = try #require(model.loadedSongID)
        model.togglePlayback()
        model.editSong(id, name: "Song", settings: MetronomeSettings(bpm: 100, timeSignature: .fourFour, accents: [1]))
        #expect(model.settings.bpm == 100)
        #expect(engine.lastUpdate?.bpm == 100)
        #expect(engine.lastUpdateStartedNewBar == false)
        #expect(model.isPlayingTrack)
        #expect(engine.stopCount == 0)
    }

    // MARK: - The Backing tracks switch

    @Test func theSwitchChangesNoSetting() throws {
        let model = try makeModel()
        model.setBPM(100)
        model.toggleAccent(beat: 2)
        model.toggleBackingTracks()
        #expect(model.settings.bpm == 100)
        #expect(model.settings.accents == [1, 2])
        #expect(model.isEdited)
        #expect(model.isSaveOffered)
        model.togglePlayback()
        #expect(engine.startedSettings.last?.bpm == 100)
        model.togglePlayback()
        model.toggleBackingTracks()
        #expect(model.settings.bpm == 100)
        #expect(model.settings.accents == [1, 2])
        #expect(model.isEdited)
        #expect(model.isSaveOffered)
    }

    @Test func theSwitchLeavesAnUneditedSongUnedited() throws {
        let model = try makeModel()
        model.toggleBackingTracks()
        #expect(model.isEdited == false)
        #expect(model.isSaveOffered == false)
        model.toggleBackingTracks()
        #expect(model.isEdited == false)
        #expect(model.isSaveOffered == false)
    }

    @Test func thePlayerFollowsTheSwitch() throws {
        let model = try makeModel()
        #expect(model.playerContent == .track)
        model.toggleBackingTracks()
        #expect(model.playerContent == .metronome)
        model.toggleBackingTracks()
        model.unloadSong()
        #expect(model.playerContent == .track)
        #expect(model.trackCard == .nothingLoaded)
        model.toggleBackingTracks()
        #expect(model.playerContent == .metronome)
    }

    // MARK: - The meter with a track in use

    @Test func anAccentWhileATrackIsInUseShowsSave() throws {
        let model = try makeModel()
        model.toggleAccent(beat: 2)
        #expect(model.isEdited)
        #expect(model.isSaveOffered)
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

    // MARK: - A song with two tempos

    /// Saves a library whose one song, not loaded, has 120 in its tempo part and 168 in its track
    /// part, as a build with a tempo for the track apart from the song's can leave it.
    private func saveASongWithTwoTempos() throws -> UUID {
        let moment = Date()
        var library = Library()
        let settings = MetronomeSettings(bpm: 120, timeSignature: .fourFour, accents: [1])
        let added = library.addSong(name: "Two", settings: settings, track: try bench.makeTrack(), now: moment)
        let song = try #require(added)
        var record = try #require(library.songRecords[song.id])
        guard case .object(var fields)? = record.parts[SongRecord.trackKey]?.value else {
            throw CocoaError(.coderValueNotFound)
        }
        fields[SongRecord.trackTempoKey] = .number(168)
        record.parts[SongRecord.trackKey] = Part(time: moment + 1, value: .object(fields))
        library.merge(songs: [record], setlists: [])
        bench.libraryStore.save(LibraryState(library: library))
        return song.id
    }

    @Test func aSongWithTwoTemposLoadsAtItsTracksTempoWithoutAWrite() throws {
        let id = try saveASongWithTwoTempos()
        let stored = bench.libraryStore.load().library.songRecords[id]
        let model = bench.relaunch()
        model.loadSong(id, from: nil)
        #expect(model.settings.bpm == 168)
        #expect(model.isEdited == false)
        #expect(model.library.songRecords[id]?.parts[SongRecord.tempoKey]?.value == .number(120))
        #expect(bench.libraryStore.load().library.songRecords[id] == stored)
        model.togglePlayback()
        #expect(engine.startedSettings.last?.bpm == 168)
    }

    @Test func savingSuchASongMakesItsTwoTemposOne() throws {
        let id = try saveASongWithTwoTempos()
        let model = bench.relaunch()
        model.loadSong(id, from: nil)
        model.toggleAccent(beat: 2)
        model.saveChanges()
        let record = model.library.songRecords[id]
        #expect(record?.parts[SongRecord.tempoKey]?.value == .number(168))
        guard case .object(let fields)? = record?.parts[SongRecord.trackKey]?.value else {
            Issue.record("no track part"); return
        }
        #expect(fields[SongRecord.trackTempoKey] == .number(168))
    }

    @Test func removingTheTrackOfSuchASongKeepsItsTempo() throws {
        let id = try saveASongWithTwoTempos()
        let model = bench.relaunch()
        model.loadSong(id, from: nil)
        let song = try #require(model.loadedSong)
        model.editSong(id, name: song.name, settings: song.settings, track: .remove)
        #expect(model.loadedTrack == nil)
        #expect(model.loadedSong?.settings.bpm == 168)
        #expect(model.settings.bpm == 168)
        #expect(model.isEdited == false)
        #expect(model.isSaveOffered == false)
        #expect(bench.libraryStore.load().library.song(id: id)?.settings.bpm == 168)
    }

    @Test func theLibraryShowsTheTracksTempo() throws {
        let id = try saveASongWithTwoTempos()
        let model = bench.relaunch()
        #expect(model.library.song(id: id)?.settings.bpm == 168)
    }
}
