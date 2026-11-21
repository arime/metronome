import Foundation
import Testing
@testable import Metronome

/// A clock the tests move by hand, so that a later change really is later.
@MainActor
private final class Clock {
    private var current = Date(timeIntervalSince1970: 2_000_000_000)

    func now() -> Date {
        current
    }

    func advance() {
        current += 10
    }
}

/// Changing songs, attaching files and Sync mode's actions, with backing tracks.
@MainActor
@Suite
struct TrackSongModelTests {
    private let bench: TrackTestBench
    private var engine: FakeClickEngine { bench.engine }
    private var haptics: FakeHaptics { bench.haptics }
    private var trackFiles: TrackFileStore { bench.trackFiles }
    private let cloud = FakeCloudStore()
    private let clock = Clock()

    init() throws {
        bench = try TrackTestBench()
    }

    /// The model and the three songs of its setlist "Gig", in this order.
    private struct Setup {
        let model: MetronomeModel
        /// Loaded from the setlist: 120 BPM, 4/4, a track at 0.48 s, with its file unless `missing`.
        let song: Song
        /// 90 BPM, no track.
        let plain: Song
        /// 140 BPM, a playable track with a one-bar count-in and the mix at -0.5.
        let other: Song
        let setlist: UUID
    }

    private func makeModel(length: TimeInterval = 222, missing: Bool = false) throws -> Setup {
        let moment = Date()
        var library = Library()
        let songTrack = try bench.makeTrack(missing: missing)
        let otherTrack = try bench.makeTrack(countIn: .oneBar, mix: -0.5)
        let added = [
            library.addSong(name: "Song", settings: MetronomeSettings(), track: songTrack, now: moment),
            library.addSong(
                name: "Plain", settings: MetronomeSettings(bpm: 90, timeSignature: .fourFour, accents: [1]), now: moment
            ),
            library.addSong(
                name: "Other", settings: MetronomeSettings(bpm: 140, timeSignature: .fourFour, accents: [1]),
                track: otherTrack, now: moment
            ),
        ]
        let song = try #require(added[0])
        let plain = try #require(added[1])
        let other = try #require(added[2])
        let setlist = library.addSetlist(name: "Gig", now: moment)
        for id in [song.id, plain.id, other.id] {
            library.add(id, toSetlist: setlist.id, now: moment)
        }
        bench.libraryStore.save(LibraryState(library: library, loadedSongID: song.id, loadedFromSetlistID: setlist.id))
        return Setup(model: bench.relaunch(length: length), song: song, plain: plain, other: other, setlist: setlist.id)
    }

    private func picked(_ name: String = "Take.wav", offset: Int = 48) throws -> PickedTrack {
        PickedTrack(url: try bench.sourceFile(named: name), fileName: name, offset: offset)
    }

    // MARK: - Changing songs

    @Test func loadingASongWithATrackWhilePlayingStops() throws {
        let setup = try makeModel()
        let model = setup.model
        model.loadSong(setup.plain.id, from: setup.setlist)
        model.togglePlayback()
        model.loadSong(setup.other.id, from: setup.setlist)
        #expect(model.isPlaying == false)
        #expect(engine.stopCount == 1)
        #expect(model.loadedSongID == setup.other.id)
        #expect(model.isTrackPlayable)
    }

    @Test func leavingASongWithATrackWhilePlayingStops() throws {
        let setup = try makeModel()
        let model = setup.model
        model.togglePlayback()
        model.goToNext()
        #expect(model.loadedSongID == setup.plain.id)
        #expect(model.isPlaying == false)
        #expect(model.isPlayingTrack == false)
        #expect(engine.stopCount == 1)
    }

    @Test func twoSongsWithoutTracksKeepPlaying() throws {
        let setup = try makeModel()
        let model = setup.model
        let ballad = try #require(model.createSong(
            name: "Ballad", settings: MetronomeSettings(bpm: 70, timeSignature: .threeFour, accents: [1]), addingTo: nil
        ))
        model.loadSong(setup.plain.id, from: setup.setlist)
        model.togglePlayback()
        model.loadSong(ballad.id, from: nil)
        #expect(model.isPlaying)
        #expect(engine.stopCount == 0)
        #expect(engine.lastUpdate?.bpm == 70)
        #expect(engine.lastUpdateStartedNewBar == true)
    }

    @Test func aMissingFileCountsAsNoTrackWhenLoading() throws {
        let setup = try makeModel(missing: true)
        let model = setup.model
        model.togglePlayback()
        model.goToNext()
        #expect(model.loadedSongID == setup.plain.id)
        #expect(model.isPlaying)
        #expect(engine.stopCount == 0)
    }

    @Test func loadingAlwaysGoesToZero() throws {
        let setup = try makeModel(length: 200)
        let model = setup.model
        model.seekTrack(to: 30)
        model.loadSong(setup.plain.id, from: setup.setlist)
        #expect(model.trackPosition == 0)
        #expect(model.trackLength == nil)
        #expect(model.isTrackPlayable == false)
        model.loadSong(setup.other.id, from: setup.setlist)
        #expect(model.trackLength == 200)
        model.seekTrack(to: 50)
        model.loadSong(setup.song.id, from: setup.setlist)
        #expect(model.trackPosition == 0)
    }

    @Test func selectingTheLoadedSongKeepsTheTrackPlaying() throws {
        let setup = try makeModel()
        let model = setup.model
        #expect(model.backingTracksOn)
        #expect(model.isTrackPlayable)
        model.seekTrack(to: 30)
        model.togglePlayback()
        engine.trackTime = 40
        model.loadSong(setup.song.id, from: setup.setlist)
        #expect(model.isPlaying)
        #expect(model.isPlayingTrack)
        #expect(engine.stopCount == 0)
        #expect(engine.startCount == 1)
        #expect(model.trackPosition == 30)
        #expect(model.trackTime == 40)
    }

    @Test func selectingTheLoadedSongWhileStoppedKeepsThePosition() throws {
        let setup = try makeModel()
        let model = setup.model
        model.seekTrack(to: 30)
        model.loadSong(setup.song.id, from: setup.setlist)
        #expect(model.isPlaying == false)
        #expect(model.trackPosition == 30)
    }

    @Test func detachingTheLoadedSongOnTheSongsTabKeepsTheTrackPlaying() throws {
        let setup = try makeModel()
        let model = setup.model
        #expect(model.backingTracksOn)
        #expect(model.isTrackPlayable)
        #expect(model.loadedFromSetlistID == setup.setlist)
        model.seekTrack(to: 30)
        model.togglePlayback()
        model.loadSong(setup.song.id, from: nil)
        #expect(model.isPlaying)
        #expect(engine.stopCount == 0)
        #expect(model.trackPosition == 30)
        #expect(model.loadedFromSetlistID == nil)
    }

    @Test func unloadStopsOnlyAPlayingTrack() throws {
        let setup = try makeModel()
        let model = setup.model
        model.togglePlayback()
        engine.trackTime = 30
        model.unloadSong()
        #expect(model.isPlaying == false)
        #expect(engine.stopCount == 1)
        #expect(model.trackPosition == 0)
        #expect(model.isTrackPlayable == false)
        #expect(model.trackLength == nil)

        model.loadSong(setup.plain.id, from: setup.setlist)
        model.togglePlayback()
        model.unloadSong()
        #expect(model.isPlaying)
        #expect(engine.stopCount == 1)
    }

    @Test func deletingTheLoadedSongStopsItsPlayingTrackAndDeletesTheFile() throws {
        let setup = try makeModel()
        let model = setup.model
        let fileID = try #require(setup.song.track?.fileID)
        model.togglePlayback()
        engine.trackTime = 30
        model.deleteSong(setup.song.id)
        #expect(model.isPlaying == false)
        #expect(model.loadedSong == nil)
        #expect(model.trackPosition == 0)
        #expect(model.isTrackPlayable == false)
        #expect(trackFiles.hasFile(fileID) == false)
        #expect(trackFiles.hasFile(try #require(setup.other.track?.fileID)))
    }

    @Test func saveAsNewSongHasNoTrackAndStopsAPlayingTrack() throws {
        let setup = try makeModel()
        let model = setup.model
        model.setBPM(130)
        model.togglePlayback()
        engine.trackTime = 30
        let copy = try #require(model.saveAsNewSong(name: "Copy", settings: model.settings))
        #expect(copy.track == nil)
        #expect(copy.settings.bpm == 130)
        #expect(model.loadedSongID == copy.id)
        #expect(model.isPlaying == false)
        #expect(model.trackPosition == 0)
        #expect(model.isTrackPlayable == false)
        #expect(model.isTrackMissing == false)
        #expect(model.library.song(id: setup.song.id)?.track == setup.song.track)
        #expect(trackFiles.hasFile(try #require(setup.song.track?.fileID)))
    }

    // MARK: - Attaching, replacing and removing

    @Test func whetherASongsFileIsHereIsReadForAnySong() throws {
        let setup = try makeModel(missing: true)
        let model = setup.model
        #expect(model.hasTrackFile(for: setup.song) == false)
        #expect(model.hasTrackFile(for: setup.plain) == false)
        #expect(model.hasTrackFile(for: setup.other))
    }

    @Test func attachingAFileInEditStoresItAndGuessesNothingItself() throws {
        let setup = try makeModel()
        let model = setup.model
        let pick = try picked(offset: 48)
        model.editSong(setup.plain.id, name: "Plain", settings: setup.plain.settings, track: .attach(pick))
        let track = try #require(model.library.song(id: setup.plain.id)?.track)
        #expect(track.offset == 48)
        #expect(track.countIn == .twoBars)
        #expect(track.mix == 0)
        #expect(track.fileName == "Take.wav")
        #expect(trackFiles.hasFile(track.fileID))
        #expect(FileManager.default.fileExists(atPath: pick.url.path()))
    }

    @Test func replacingTheFileKeepsCountInAndMixAndDropsTheOldFile() throws {
        let setup = try makeModel()
        let model = setup.model
        let old = try #require(setup.other.track)
        model.editSong(setup.other.id, name: "Other", settings: setup.other.settings, track: .attach(try picked(offset: 12)))
        let track = try #require(model.library.song(id: setup.other.id)?.track)
        #expect(track.fileID != old.fileID)
        #expect(track.offset == 12)
        #expect(track.fileName == "Take.wav")
        #expect(track.countIn == .oneBar)
        #expect(track.mix == -0.5)
        #expect(trackFiles.hasFile(track.fileID))
        #expect(trackFiles.hasFile(old.fileID) == false)
    }

    @Test func removingTheTrackForgetsItAndDeletesTheFile() throws {
        let setup = try makeModel()
        let model = setup.model
        let old = try #require(setup.other.track)
        model.editSong(setup.other.id, name: "Other", settings: setup.other.settings, track: .remove)
        #expect(model.library.song(id: setup.other.id)?.track == nil)
        #expect(trackFiles.hasFile(old.fileID) == false)
    }

    @Test func pickingAFileWithTheSameNameForAMissingTrackChangesNoPart() throws {
        let setup = try makeModel(missing: true)
        let model = setup.model
        let library = model.library
        #expect(model.isTrackMissing)
        model.editSong(
            setup.song.id, name: "Song", settings: setup.song.settings, track: .attach(try picked("Song.m4a", offset: 99))
        )
        #expect(model.library == library)
        #expect(model.isTrackPlayable)
        #expect(model.isTrackMissing == false)
        #expect(model.trackLength == 222)
        #expect(trackFiles.hasFile(try #require(setup.song.track?.fileID)))
    }

    @Test func pickingAFileWithAnotherNameRenamesTheTrackAndKeepsTheRest() throws {
        let setup = try makeModel(missing: true)
        let model = setup.model
        let old = try #require(setup.song.track)
        let parts = try #require(model.library.songRecords[setup.song.id]?.parts)
        let before = Date()
        model.editSong(setup.song.id, name: "Song", settings: setup.song.settings, track: .attach(try picked(offset: 99)))
        let after = Date()
        let track = try #require(model.library.song(id: setup.song.id)?.track)
        #expect(track.fileName == "Take.wav")
        #expect(track.fileID == old.fileID)
        #expect(track.offset == old.offset)
        #expect(track.countIn == old.countIn)
        #expect(track.mix == old.mix)
        let edited = try #require(model.library.songRecords[setup.song.id]?.parts)
        let time = try #require(edited[SongRecord.trackKey]?.time)
        #expect(time >= before && time <= after)
        #expect(edited[SongRecord.nameKey] == parts[SongRecord.nameKey])
        #expect(edited[SongRecord.tempoKey] == parts[SongRecord.tempoKey])
        #expect(edited[SongRecord.meterKey] == parts[SongRecord.meterKey])
    }

    @Test func attachingATrackWritesTheSongsTempoIntoItsPart() throws {
        let setup = try makeModel()
        let model = setup.model
        let settings = MetronomeSettings(bpm: 95, timeSignature: .fourFour, accents: [1])
        model.editSong(setup.plain.id, name: "Plain", settings: settings, track: .attach(try picked()))
        guard case .object(let fields)? = model.library.songRecords[setup.plain.id]?.parts[SongRecord.trackKey]?.value
        else { Issue.record("no track part"); return }
        #expect(fields["bpm"] == .number(95))
    }

    @Test func editingTheLoadedSongsTrackStopsAndGoesToZero() throws {
        let setup = try makeModel()
        let model = setup.model
        model.togglePlayback()
        engine.trackTime = 30
        model.editSong(setup.song.id, name: "Song", settings: setup.song.settings, track: .attach(try picked()))
        #expect(model.isPlaying == false)
        #expect(model.trackPosition == 0)
        #expect(model.isTrackPlayable)

        model.seekTrack(to: 40)
        model.togglePlayback()
        model.editSong(setup.song.id, name: "Song", settings: setup.song.settings, track: .remove)
        #expect(model.isPlaying == false)
        #expect(model.trackPosition == 0)
        #expect(model.isTrackPlayable == false)
        #expect(model.trackLength == nil)
    }

    @Test func removingAMissingFileTrackKeepsPlaying() throws {
        let setup = try makeModel(missing: true)
        let model = setup.model
        model.togglePlayback()
        model.editSong(setup.song.id, name: "Song", settings: setup.song.settings, track: .remove)
        #expect(model.isPlaying)
        #expect(engine.stopCount == 0)
        #expect(model.loadedTrack == nil)
        #expect(model.isTrackMissing == false)
    }

    @Test func editingOnlyTheTempoOfALoadedTrackSongKeepsPlaying() throws {
        let setup = try makeModel()
        let model = setup.model
        model.togglePlayback()
        var settings = setup.song.settings
        settings.setBPM(130)
        model.editSong(setup.song.id, name: "Song", settings: settings)
        #expect(model.isPlaying)
        #expect(model.isPlayingTrack)
        #expect(engine.stopCount == 0)
        #expect(engine.lastUpdate?.bpm == 130)
        #expect(engine.lastUpdateStartedNewBar == false)
    }

    @Test func aNewSongCanBeCreatedWithATrack() throws {
        let setup = try makeModel()
        let model = setup.model
        let settings = MetronomeSettings(bpm: 100, timeSignature: .fourFour, accents: [1])
        let song = try #require(model.createSong(name: "New", settings: settings, addingTo: nil, track: try picked(offset: 20)))
        let track = try #require(song.track)
        #expect(track.offset == 20)
        #expect(track.countIn == .twoBars)
        #expect(track.mix == 0)
        #expect(trackFiles.hasFile(track.fileID))
        #expect(model.loadedSongID == setup.song.id)

        // Naming the current settings with a track loads it and stops the click.
        model.unloadSong()
        model.togglePlayback()
        let named = try #require(model.createSong(name: "Named", settings: model.settings, addingTo: nil, track: try picked()))
        #expect(model.loadedSongID == named.id)
        #expect(model.isPlaying == false)
        #expect(model.isTrackPlayable)
        #expect(model.trackPosition == 0)
    }

    // MARK: - A file that cannot be stored

    /// A pick whose file is gone, so copying it into the store fails, as on a full phone.
    private func unstorable() -> PickedTrack {
        PickedTrack(url: bench.root.appending(path: "Gone/Take.wav"), fileName: "Take.wav", offset: 48)
    }

    @Test func editSongSavesNothingWhenTheFileCannotBeStored() throws {
        let setup = try makeModel()
        let model = setup.model
        let library = model.library
        let stored = bench.libraryStore.load()
        var settings = setup.other.settings
        settings.setBPM(150)
        model.togglePlayback()
        #expect(model.editSong(setup.plain.id, name: "Renamed", settings: settings, track: .attach(unstorable())) == false)
        #expect(model.editSong(setup.other.id, name: "Renamed", settings: settings, track: .attach(unstorable())) == false)
        #expect(model.editSong(setup.song.id, name: "Renamed", settings: settings, track: .attach(unstorable())) == false)
        #expect(model.library == library)
        #expect(bench.libraryStore.load() == stored)
        #expect(model.isPlaying)
        #expect(engine.stopCount == 0)
    }

    @Test func editSongSavesNothingWhenTheFileForAMissingTrackCannotBeStored() throws {
        let setup = try makeModel(missing: true)
        let model = setup.model
        let library = model.library
        #expect(model.editSong(setup.song.id, name: "Renamed", settings: setup.song.settings, track: .attach(unstorable())) == false)
        #expect(model.library == library)
        #expect(model.isTrackMissing)
    }

    @Test func aSavedEditReportsSuccess() throws {
        let setup = try makeModel()
        #expect(setup.model.editSong(setup.plain.id, name: "Renamed", settings: setup.plain.settings))
        #expect(setup.model.editSong(setup.plain.id, name: "Plain", settings: setup.plain.settings, track: .attach(try picked())))
    }

    @Test func createSongSavesNothingWhenTheFileCannotBeStored() throws {
        let setup = try makeModel()
        let model = setup.model
        let library = model.library
        #expect(model.createSong(name: "New", settings: model.settings, addingTo: setup.setlist, track: unstorable()) == nil)
        // Naming the current settings with nothing loaded does not load anything either.
        model.unloadSong()
        #expect(model.createSong(name: "New", settings: model.settings, addingTo: nil, track: unstorable()) == nil)
        #expect(model.library == library)
        #expect(model.loadedSongID == nil)
    }

    @Test func saveAsNewSongSavesNothingWhenTheFileCannotBeStored() throws {
        let setup = try makeModel()
        let model = setup.model
        let library = model.library
        model.togglePlayback()
        #expect(model.saveAsNewSong(name: "Copy", settings: model.settings, track: unstorable()) == nil)
        #expect(model.library == library)
        #expect(model.loadedSongID == setup.song.id)
        #expect(model.isPlaying)
        #expect(engine.stopCount == 0)
    }

    // MARK: - Choose file on the player card

    @Test func choosingAFileFromTheCardStoresItAtOnce() throws {
        let setup = try makeModel(missing: true)
        let model = setup.model
        let library = model.library
        #expect(model.backingTracksOn)
        #expect(model.isTrackMissing)
        #expect(model.chooseFileForLoadedTrack(try picked("Song.m4a", offset: 99), for: try #require(setup.song.track?.fileID)))
        #expect(model.isTrackMissing == false)
        #expect(model.isTrackPlayable)
        #expect(model.trackPosition == 0)
        #expect(model.isEdited == false)
        #expect(model.isSaveOffered == false)
        #expect(model.library == library)
        #expect(trackFiles.hasFile(try #require(setup.song.track?.fileID)))
    }

    @Test func choosingAFileWithAnotherNameFromTheCardRenamesTheTrack() throws {
        let setup = try makeModel(missing: true)
        let model = setup.model
        let old = try #require(setup.song.track)
        #expect(model.chooseFileForLoadedTrack(try picked(offset: 99), for: old.fileID))
        let track = try #require(model.loadedTrack)
        #expect(track.fileName == "Take.wav")
        #expect(track.fileID == old.fileID)
        #expect(track.offset == old.offset)
        #expect(track.countIn == old.countIn)
        #expect(track.mix == old.mix)
        #expect(model.isEdited == false)
        #expect(model.isTrackPlayable)
    }

    @Test func choosingAFileWhilePlayingStopsPlayback() throws {
        let setup = try makeModel(missing: true)
        let model = setup.model
        model.togglePlayback()
        #expect(model.isPlaying)
        #expect(model.chooseFileForLoadedTrack(try picked(), for: try #require(setup.song.track?.fileID)))
        #expect(model.isPlaying == false)
        #expect(engine.stopCount == 1)
        #expect(model.trackPosition == 0)
    }

    @Test func choosingAFileThatCannotBeStoredChangesNothing() throws {
        let setup = try makeModel(missing: true)
        let model = setup.model
        let library = model.library
        #expect(model.chooseFileForLoadedTrack(unstorable(), for: try #require(setup.song.track?.fileID)) == false)
        #expect(model.isTrackMissing)
        #expect(model.loadedTrack?.fileName == "Song.m4a")
        #expect(model.library == library)
    }

    @Test func choosingAFileWhenTheTrackIsNotMissingDoesNothing() throws {
        let setup = try makeModel()
        let model = setup.model
        let library = model.library
        let fileID = try #require(setup.song.track?.fileID)
        let pick = try picked()
        try Data("another".utf8).write(to: pick.url)
        model.togglePlayback()
        #expect(model.chooseFileForLoadedTrack(pick, for: fileID))
        #expect(try Data(contentsOf: try #require(trackFiles.url(for: fileID))) == Data("audio".utf8))
        #expect(model.library == library)
        #expect(model.isPlaying)
        #expect(model.isPlayingTrack)
        #expect(engine.stopCount == 0)

        // No song loaded.
        model.togglePlayback()
        model.unloadSong()
        model.togglePlayback()
        let stops = engine.stopCount
        #expect(model.chooseFileForLoadedTrack(pick, for: fileID))
        #expect(model.library == library)
        #expect(model.isPlaying)
        #expect(engine.stopCount == stops)
    }

    @Test func choosingAFileForAnotherTrackDoesNothing() throws {
        let moment = Date()
        var library = Library()
        let firstTrack = try bench.makeTrack(missing: true)
        let secondTrack = try bench.makeTrack(missing: true)
        let added = [
            library.addSong(name: "First", settings: MetronomeSettings(), track: firstTrack, now: moment),
            library.addSong(name: "Second", settings: MetronomeSettings(), track: secondTrack, now: moment),
        ]
        let first = try #require(added[0])
        let second = try #require(added[1])
        bench.libraryStore.save(LibraryState(library: library, loadedSongID: first.id))
        let model = bench.relaunch()
        // The pill was tapped for the first song's track; the second song is loaded while the file is read.
        let fileID = try #require(model.loadedTrack?.fileID)
        #expect(fileID == firstTrack.fileID)
        model.loadSong(second.id, from: nil)
        let loaded = model.library
        #expect(model.chooseFileForLoadedTrack(try picked(), for: fileID))
        #expect(model.isTrackMissing)
        #expect(model.loadedTrack?.fileName == "Song.m4a")
        #expect(model.library == loaded)
        #expect(trackFiles.hasFile(firstTrack.fileID) == false)
        #expect(trackFiles.hasFile(secondTrack.fileID) == false)
    }

    // MARK: - Sync mode

    @Test func nudgingTheOffsetIsAnEdit() throws {
        let setup = try makeModel()
        let model = setup.model
        model.togglePlayback()
        let ticks = haptics.selectionCount
        model.nudgeOffset(by: 1)
        #expect(model.trackSettings?.offset == 49)
        #expect(model.loadedTrack?.offset == 48)
        #expect(model.isEdited)
        #expect(model.isSaveOffered)
        #expect(engine.offsets.last == 0.49)
        #expect(haptics.selectionCount == ticks + 1)
    }

    @Test func theOffsetStaysInsideTheFile() throws {
        let model = try makeModel().model
        model.nudgeOffset(by: -100)
        #expect(model.trackSettings?.offset == 0)

        let short = try makeModel(length: 2.0).model
        short.nudgeOffset(by: 1000)
        #expect(short.trackSettings?.offset == 200)
    }

    @Test func countInAndMixAreEdits() throws {
        let setup = try makeModel()
        let model = setup.model
        model.setCountIn(.off)
        model.setMix(-0.5)
        let mix = try #require(engine.mixes.last)
        #expect(mix.click == 1)
        #expect(abs(mix.track - 0.251) < 0.001)
        #expect(model.isSaveOffered)
        #expect(savedTrack(of: setup.song) == setup.song.track)
        model.saveChanges()
        let saved = try #require(savedTrack(of: setup.song))
        #expect(saved.countIn == .off)
        #expect(saved.mix == -0.5)
        #expect(model.isSaveOffered == false)
    }

    @Test func theMixTicksOnlyOnArrivingAtTheCentre() throws {
        let model = try makeModel().model
        model.setMix(0.3)
        var ticks = haptics.selectionCount
        model.setMix(0)
        #expect(haptics.selectionCount == ticks + 1)
        ticks = haptics.selectionCount
        model.setMix(0)
        #expect(haptics.selectionCount == ticks)
        model.setMix(0.3)
        model.setMix(0.2)
        #expect(haptics.selectionCount == ticks)
    }

    @Test func settingTheSameMixAgainDoesNothing() throws {
        let model = try makeModel().model
        model.setMix(0.25)
        let mixes = engine.mixes.count
        model.setMix(0.25)
        #expect(engine.mixes.count == mixes)
    }

    // MARK: - Saving Sync mode's changes

    private func savedTrack(of song: Song) -> BackingTrack? {
        bench.libraryStore.load().library.song(id: song.id)?.track
    }

    @Test func saveChangesWritesTheTrackSettingsWithTheRest() throws {
        let setup = try makeModel()
        let model = setup.model
        model.setBPM(130)
        model.nudgeOffset(by: 2)
        model.setMix(0.4)
        let writes = bench.libraryDefaults.writes
        model.saveChanges()
        #expect(bench.libraryDefaults.writes == writes + 1)
        let saved = bench.libraryStore.load().library
        #expect(saved.song(id: setup.song.id)?.settings.bpm == 130)
        #expect(saved.song(id: setup.song.id)?.track?.offset == 50)
        #expect(saved.song(id: setup.song.id)?.track?.mix == 0.4)
        guard case .object(let fields)? = saved.songRecords[setup.song.id]?.parts[SongRecord.trackKey]?.value
        else { Issue.record("no track part"); return }
        #expect(fields["bpm"] == .number(130))
    }

    @Test func revertSetsTheTrackSettingsBack() throws {
        let setup = try makeModel()
        let model = setup.model
        model.togglePlayback()
        model.nudgeOffset(by: 2)
        model.setMix(0.4)
        model.setCountIn(.off)
        model.discardChanges()
        #expect(model.trackSettings == model.loadedTrack?.settings)
        #expect(engine.offsets.last == 0.48)
        let mix = try #require(engine.mixes.last)
        #expect(mix.click == TrackMix.clickGain(at: 0))
        #expect(mix.track == TrackMix.trackGain(at: 0))
        #expect(engine.stopCount == 0)
        #expect(model.isPlaying)
        #expect(model.isSaveOffered == false)
    }

    @Test func unsavedTrackSettingsSurviveARelaunch() throws {
        let setup = try makeModel()
        let model = setup.model
        model.nudgeOffset(by: 5)
        model.setMix(-0.3)
        let relaunched = bench.relaunch()
        #expect(relaunched.trackSettings?.offset == 53)
        #expect(relaunched.trackSettings?.mix == -0.3)
        #expect(relaunched.loadedTrack?.offset == 48)
        #expect(relaunched.isEdited)
    }

    @Test func withNothingStoredTheTrackSettingsAreTheSongs() throws {
        let model = try makeModel().model
        #expect(model.trackSettings != nil)
        #expect(model.trackSettings == model.loadedTrack?.settings)
        #expect(model.isEdited == false)
    }

    @Test func loadingAnotherSongDropsUnsavedTrackSettings() throws {
        let setup = try makeModel()
        let model = setup.model
        model.nudgeOffset(by: 2)
        model.loadSong(setup.plain.id, from: setup.setlist)
        #expect(model.trackSettings == nil)
        model.loadSong(setup.song.id, from: setup.setlist)
        #expect(model.trackSettings?.offset == 48)
    }

    @Test func unloadDropsTheTrackSettings() throws {
        let model = try makeModel().model
        model.nudgeOffset(by: 2)
        model.unloadSong()
        #expect(model.trackSettings == nil)
        #expect(model.isEdited == false)
    }

    @Test func editingTheLoadedSongsSettingsDropsUnsavedTrackSettings() throws {
        let setup = try makeModel()
        let model = setup.model
        model.togglePlayback()
        model.nudgeOffset(by: 2)
        var settings = setup.song.settings
        settings.setBPM(130)
        model.editSong(setup.song.id, name: "Song", settings: settings)
        #expect(model.trackSettings?.offset == 48)
        #expect(engine.offsets.last == 0.48)
        #expect(model.settings.bpm == 130)
        #expect(model.isPlaying)
    }

    @Test func renamingTheLoadedSongKeepsUnsavedTrackSettings() throws {
        let setup = try makeModel()
        let model = setup.model
        model.nudgeOffset(by: 1)
        model.editSong(setup.song.id, name: "Renamed", settings: setup.song.settings)
        #expect(model.trackSettings?.offset == 49)
    }

    @Test func theSwitchKeepsUnsavedTrackSettings() throws {
        let model = try makeModel().model
        model.nudgeOffset(by: 1)
        model.toggleBackingTracks()
        #expect(model.trackSettings?.offset == 49)
        #expect(model.isSaveOffered)
    }

    @Test func replacingTheLoadedSongsFileTakesTheNewTracksSettings() throws {
        let setup = try makeModel()
        let model = setup.model
        model.nudgeOffset(by: 2)
        model.editSong(setup.song.id, name: "Song", settings: setup.song.settings, track: .attach(try picked(offset: 12)))
        #expect(model.trackSettings?.offset == 12)
    }

    // MARK: - Changes arriving from another device

    /// One phone with sync on the shared fake iCloud, with its own track files.
    private func makeDevice() -> (model: MetronomeModel, engine: FakeClickEngine, files: TrackFileStore, haptics: FakeHaptics) {
        let engine = FakeClickEngine()
        let haptics = FakeHaptics()
        let files = TrackFileStore(directory: bench.root.appending(path: UUID().uuidString))
        let clock = clock
        let model = MetronomeModel(
            engine: engine,
            store: SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!),
            haptics: haptics,
            libraryStore: LibraryStore(defaults: UserDefaults(suiteName: UUID().uuidString)!),
            sync: LibrarySync(cloud: cloud, defaults: UserDefaults(suiteName: UUID().uuidString)!, syncingDelay: .seconds(3600)),
            now: { clock.now() },
            trackFiles: files,
            lengthOfTrack: { _ in 222 }
        )
        model.setSyncEnabled(true)
        return (model, engine, files, haptics)
    }

    /// Every haptic the device has played.
    private func hapticCount(_ haptics: FakeHaptics) -> Int {
        haptics.beats.count + haptics.selectionCount + haptics.transportCount + haptics.successCount
    }

    private let settings100 = MetronomeSettings(bpm: 100, timeSignature: .fourFour, accents: [1])

    /// A makes a song with a track; B gets it and picks the file too, then plays it.
    private func twoDevicesPlayingATrack() throws -> (
        a: MetronomeModel, b: MetronomeModel, bEngine: FakeClickEngine, bFiles: TrackFileStore, song: Song,
        bHaptics: FakeHaptics
    ) {
        let a = makeDevice(), b = makeDevice()
        clock.advance()
        let song = try #require(a.model.createSong(name: "Song", settings: settings100, addingTo: nil, track: try picked()))
        cloud.send(.changed, toDevice: 1)
        b.model.loadSong(song.id, from: nil)
        #expect(b.model.isTrackMissing)
        b.model.editSong(song.id, name: "Song", settings: settings100, track: .attach(try picked()))
        b.model.togglePlayback()
        #expect(b.model.isPlayingTrack)
        return (a.model, b.model, b.engine, b.files, song, b.haptics)
    }

    @Test func anOffsetArrivingFromAnotherDeviceMakesTheSongEdited() throws {
        let (a, b, bEngine, _, song, bHaptics) = try twoDevicesPlayingATrack()
        let offsets = bEngine.offsets
        let haptics = hapticCount(bHaptics)
        clock.advance()
        a.loadSong(song.id, from: nil)
        a.nudgeOffset(by: 2)
        a.saveChanges()
        cloud.send(.changed, toDevice: 1)
        #expect(b.loadedTrack?.offset == 50)
        #expect(b.trackSettings?.offset == 48)
        #expect(bEngine.offsets == offsets)
        #expect(b.isSaveOffered)
        #expect(b.isPlaying)
        #expect(bEngine.stopCount == 0)
        #expect(hapticCount(bHaptics) == haptics)
    }

    @Test func revertTakesTheArrivedOffset() throws {
        let (a, b, bEngine, _, song, _) = try twoDevicesPlayingATrack()
        clock.advance()
        a.loadSong(song.id, from: nil)
        a.nudgeOffset(by: 2)
        a.saveChanges()
        cloud.send(.changed, toDevice: 1)
        b.discardChanges()
        #expect(b.trackSettings?.offset == 50)
        #expect(bEngine.offsets.last == 0.5)
    }

    @Test func aTempoArrivingFromAnotherDeviceMakesTheSongEdited() throws {
        let (a, b, bEngine, _, song, bHaptics) = try twoDevicesPlayingATrack()
        let update = bEngine.lastUpdate
        let haptics = hapticCount(bHaptics)
        clock.advance()
        a.loadSong(song.id, from: nil)
        a.setBPM(102)
        a.saveChanges()
        cloud.send(.changed, toDevice: 1)
        #expect(b.loadedSong?.settings.bpm == 102)
        #expect(b.settings.bpm == 100)
        #expect(b.isSaveOffered)
        #expect(bEngine.lastUpdate == update)
        #expect(b.isPlaying)
        #expect(hapticCount(bHaptics) == haptics)
    }

    @Test func aTrackRemovedOnAnotherDeviceStopsItsPlayingTrack() throws {
        let (a, b, bEngine, bFiles, song, _) = try twoDevicesPlayingATrack()
        let fileID = try #require(song.track?.fileID)
        bEngine.trackTime = 30
        clock.advance()
        a.editSong(song.id, name: "Song", settings: settings100, track: .remove)
        cloud.send(.changed, toDevice: 1)
        #expect(b.loadedTrack == nil)
        #expect(b.trackSettings == nil)
        #expect(b.isPlaying == false)
        #expect(bEngine.stopCount == 1)
        #expect(b.trackPosition == 0)
        #expect(b.isTrackPlayable == false)
        #expect(bFiles.hasFile(fileID) == false)
    }

    @Test func aTrackReplacedOnAnotherDeviceStopsPlaybackAndIsMissingHere() throws {
        let (a, b, bEngine, bFiles, song, bHaptics) = try twoDevicesPlayingATrack()
        let oldID = try #require(song.track?.fileID)
        bEngine.trackTime = 30
        let haptics = hapticCount(bHaptics)
        clock.advance()
        a.editSong(song.id, name: "Song", settings: settings100, track: .attach(try picked("New.wav")))
        cloud.send(.changed, toDevice: 1)
        #expect(b.loadedTrack?.fileName == "New.wav")
        #expect(b.trackSettings == b.loadedTrack?.settings)
        #expect(b.isTrackMissing)
        #expect(b.isPlaying == false)
        #expect(bEngine.stopCount == 1)
        #expect(b.trackPosition == 0)
        #expect(bFiles.hasFile(oldID) == false)
        #expect(hapticCount(bHaptics) == haptics)
    }

    @Test func theLoadedSongDeletedOnAnotherDeviceStopsItsPlayingTrack() throws {
        let (a, b, bEngine, _, song, bHaptics) = try twoDevicesPlayingATrack()
        bEngine.trackTime = 30
        let haptics = hapticCount(bHaptics)
        clock.advance()
        a.deleteSong(song.id)
        cloud.send(.changed, toDevice: 1)
        #expect(b.loadedSong == nil)
        #expect(b.isPlaying == false)
        #expect(bEngine.stopCount == 1)
        #expect(b.trackPosition == 0)
        #expect(hapticCount(bHaptics) == haptics)
    }

    @Test func aMixArrivingFromAnotherDeviceMakesTheSongEdited() throws {
        let (a, b, bEngine, _, song, bHaptics) = try twoDevicesPlayingATrack()
        let mixes = bEngine.mixes.count
        let haptics = hapticCount(bHaptics)
        clock.advance()
        a.loadSong(song.id, from: nil)
        a.setMix(0.5)
        a.saveChanges()
        cloud.send(.changed, toDevice: 1)
        #expect(b.loadedTrack?.mix == 0.5)
        #expect(b.trackSettings?.mix == 0)
        #expect(bEngine.mixes.count == mixes)
        #expect(b.isSaveOffered)
        #expect(b.isPlaying)
        #expect(hapticCount(bHaptics) == haptics)
    }

    @Test func syncModeEndsWhenTheTrackIsRemovedElsewhere() throws {
        let (a, b, _, _, song, _) = try twoDevicesPlayingATrack()
        b.enterSyncMode()
        clock.advance()
        a.editSong(song.id, name: "Song", settings: settings100, track: .remove)
        cloud.send(.changed, toDevice: 1)
        #expect(b.loadedTrack == nil)
        #expect(b.isSyncModeShown == false)
    }

    @Test func syncModeEndsWhenTheTrackIsReplacedElsewhere() throws {
        let (a, b, _, _, song, _) = try twoDevicesPlayingATrack()
        b.enterSyncMode()
        clock.advance()
        a.editSong(song.id, name: "Song", settings: settings100, track: .attach(try picked("New.wav")))
        cloud.send(.changed, toDevice: 1)
        #expect(b.isTrackMissing)
        #expect(b.isSyncModeShown == false)
    }

    @Test func syncModeEndsWhenTheSongIsDeletedElsewhere() throws {
        let (a, b, _, _, song, _) = try twoDevicesPlayingATrack()
        b.enterSyncMode()
        clock.advance()
        a.deleteSong(song.id)
        cloud.send(.changed, toDevice: 1)
        #expect(b.loadedSong == nil)
        #expect(b.isSyncModeShown == false)
    }

    @Test func aTempoArrivingKeepsSyncModeShown() throws {
        let (a, b, _, _, song, _) = try twoDevicesPlayingATrack()
        b.enterSyncMode()
        clock.advance()
        a.loadSong(song.id, from: nil)
        a.setBPM(102)
        a.saveChanges()
        cloud.send(.changed, toDevice: 1)
        #expect(b.loadedSong?.settings.bpm == 102)
        #expect(b.isSyncModeShown)
    }

    @Test func aTrackAttachedOnAnotherDeviceArrivesMissingAndKeepsPlaying() throws {
        let a = makeDevice(), b = makeDevice()
        clock.advance()
        let song = try #require(a.model.createSong(name: "Song", settings: settings100, addingTo: nil))
        cloud.send(.changed, toDevice: 1)
        b.model.loadSong(song.id, from: nil)
        b.model.togglePlayback()

        clock.advance()
        a.model.editSong(song.id, name: "Song", settings: settings100, track: .attach(try picked()))
        cloud.send(.changed, toDevice: 1)
        #expect(b.model.loadedTrack?.fileName == "Take.wav")
        #expect(b.model.trackSettings == b.model.loadedTrack?.settings)
        #expect(b.model.isTrackMissing)
        #expect(b.model.isPlaying)
        #expect(b.engine.stopCount == 0)
    }

    @Test func filesNoSongRefersToAreRemoved() throws {
        let setup = try makeModel()
        let stray = UUID()
        try trackFiles.store(try bench.sourceFile(), as: stray)
        setup.model.renameSong(setup.plain.id, to: "Plainer")
        #expect(trackFiles.hasFile(stray) == false)
        #expect(trackFiles.hasFile(try #require(setup.song.track?.fileID)))
        #expect(trackFiles.hasFile(try #require(setup.other.track?.fileID)))
    }
}
