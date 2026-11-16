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

/// Changing songs, attaching files and the Sync sheet's actions, with backing tracks.
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

    private func picked(_ name: String = "Take.wav", firstBeat: Int = 48) throws -> PickedTrack {
        PickedTrack(url: try bench.sourceFile(named: name), fileName: name, firstBeat: firstBeat)
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
        model.loadSong(setup.other.id, from: setup.setlist)
        #expect(model.trackPosition == 0)
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
        model.togglePlayback()
        engine.trackTime = 30
        model.setBPM(130)
        let copy = try #require(model.saveAsNewSong(name: "Copy", settings: model.settings))
        #expect(copy.track == nil)
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
        let pick = try picked(firstBeat: 48)
        model.editSong(setup.plain.id, name: "Plain", settings: setup.plain.settings, track: .attach(pick))
        let track = try #require(model.library.song(id: setup.plain.id)?.track)
        #expect(track.firstBeat == 48)
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
        model.editSong(setup.other.id, name: "Other", settings: setup.other.settings, track: .attach(try picked(firstBeat: 12)))
        let track = try #require(model.library.song(id: setup.other.id)?.track)
        #expect(track.fileID != old.fileID)
        #expect(track.firstBeat == 12)
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

    @Test func pickingAFileForAMissingTrackChangesNoPart() throws {
        let setup = try makeModel(missing: true)
        let model = setup.model
        let library = model.library
        #expect(model.isTrackMissing)
        model.editSong(setup.song.id, name: "Song", settings: setup.song.settings, track: .attach(try picked(firstBeat: 99)))
        #expect(model.library == library)
        #expect(model.isTrackPlayable)
        #expect(model.isTrackMissing == false)
        #expect(model.trackLength == 222)
        #expect(trackFiles.hasFile(try #require(setup.song.track?.fileID)))
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
    }

    @Test func aNewSongCanBeCreatedWithATrack() throws {
        let setup = try makeModel()
        let model = setup.model
        let settings = MetronomeSettings(bpm: 100, timeSignature: .fourFour, accents: [1])
        let song = try #require(model.createSong(name: "New", settings: settings, addingTo: nil, track: try picked(firstBeat: 20)))
        let track = try #require(song.track)
        #expect(track.firstBeat == 20)
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
        PickedTrack(url: bench.root.appending(path: "Gone/Take.wav"), fileName: "Take.wav", firstBeat: 48)
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

    // MARK: - The Sync sheet

    @Test func nudgingTheFirstBeatSavesAtOnceWithoutEdited() throws {
        let setup = try makeModel()
        let model = setup.model
        model.togglePlayback()
        let ticks = haptics.selectionCount
        model.nudgeFirstBeat(by: 1)
        #expect(model.loadedTrack?.firstBeat == 49)
        #expect(bench.libraryStore.load().library.song(id: setup.song.id)?.track?.firstBeat == 49)
        #expect(model.isEdited == false)
        #expect(model.isSaveOffered == false)
        #expect(engine.firstBeats.last == 0.49)
        #expect(haptics.selectionCount == ticks + 1)
    }

    @Test func theFirstBeatStaysInsideTheFile() throws {
        let model = try makeModel().model
        model.nudgeFirstBeat(by: -100)
        #expect(model.loadedTrack?.firstBeat == 0)

        let short = try makeModel(length: 2.0).model
        short.nudgeFirstBeat(by: 1000)
        #expect(short.loadedTrack?.firstBeat == 200)
    }

    @Test func tapOnBeatOneSetsTheFirstBeatFromTheHeardPosition() throws {
        let model = try makeModel().model
        model.togglePlayback()
        engine.trackTime = 9.30
        let ticks = haptics.selectionCount
        model.tapBeatOne()
        #expect(model.loadedTrack?.firstBeat == 130)
        #expect(engine.firstBeats.last == 1.30)
        #expect(haptics.selectionCount == ticks + 1)
    }

    @Test func tapOnBeatOneDoesNothingWhileStoppedOrCountingIn() throws {
        let model = try makeModel().model
        engine.trackTime = 9.30
        model.tapBeatOne()
        #expect(model.loadedTrack?.firstBeat == 48)

        model.togglePlayback()
        engine.trackTime = -1.5
        let ticks = haptics.selectionCount
        model.tapBeatOne()
        #expect(model.loadedTrack?.firstBeat == 48)
        #expect(engine.firstBeats.isEmpty)
        #expect(haptics.selectionCount == ticks)
    }

    @Test func countInAndMixSaveAtOnce() throws {
        let setup = try makeModel()
        let model = setup.model
        model.setCountIn(.off)
        model.setMix(-0.5)
        let saved = try #require(bench.libraryStore.load().library.song(id: setup.song.id)?.track)
        #expect(saved.countIn == .off)
        #expect(saved.mix == -0.5)
        let mix = try #require(engine.mixes.last)
        #expect(mix.click == 1)
        #expect(abs(mix.track - 0.251) < 0.001)
        #expect(model.isEdited == false)
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

    // MARK: - Changes arriving from another device

    /// One phone with sync on the shared fake iCloud, with its own track files.
    private func makeDevice() -> (model: MetronomeModel, engine: FakeClickEngine, files: TrackFileStore) {
        let engine = FakeClickEngine()
        let files = TrackFileStore(directory: bench.root.appending(path: UUID().uuidString))
        let clock = clock
        let model = MetronomeModel(
            engine: engine,
            store: SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!),
            haptics: FakeHaptics(),
            libraryStore: LibraryStore(defaults: UserDefaults(suiteName: UUID().uuidString)!),
            sync: LibrarySync(cloud: cloud, defaults: UserDefaults(suiteName: UUID().uuidString)!, syncingDelay: .seconds(3600)),
            now: { clock.now() },
            trackFiles: files,
            lengthOfTrack: { _ in 222 }
        )
        model.setSyncEnabled(true)
        return (model, engine, files)
    }

    private let settings100 = MetronomeSettings(bpm: 100, timeSignature: .fourFour, accents: [1])

    /// A makes a song with a track; B gets it and picks the file too, then plays it.
    private func twoDevicesPlayingATrack() throws -> (
        a: MetronomeModel, b: MetronomeModel, bEngine: FakeClickEngine, bFiles: TrackFileStore, song: Song
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
        return (a.model, b.model, b.engine, b.files, song)
    }

    @Test func aFirstBeatArrivingFromAnotherDeviceMovesTheGrid() throws {
        let (a, b, bEngine, _, song) = try twoDevicesPlayingATrack()
        clock.advance()
        a.loadSong(song.id, from: nil)
        a.nudgeFirstBeat(by: 2)
        cloud.send(.changed, toDevice: 1)
        #expect(b.loadedTrack?.firstBeat == 50)
        #expect(bEngine.firstBeats.last == 0.5)
        #expect(b.isPlaying)
        #expect(bEngine.stopCount == 0)
    }

    @Test func aTrackRemovedOnAnotherDeviceStopsItsPlayingTrack() throws {
        let (a, b, bEngine, bFiles, song) = try twoDevicesPlayingATrack()
        let fileID = try #require(song.track?.fileID)
        bEngine.trackTime = 30
        clock.advance()
        a.editSong(song.id, name: "Song", settings: settings100, track: .remove)
        cloud.send(.changed, toDevice: 1)
        #expect(b.loadedTrack == nil)
        #expect(b.isPlaying == false)
        #expect(bEngine.stopCount == 1)
        #expect(b.trackPosition == 0)
        #expect(b.isTrackPlayable == false)
        #expect(bFiles.hasFile(fileID) == false)
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
