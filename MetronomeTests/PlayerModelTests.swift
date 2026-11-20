import Foundation
import Testing
@testable import Metronome

/// A system uptime the tests move by hand.
@MainActor
private final class Uptime {
    var now: TimeInterval = 0
}

private struct StartFailure: Error {}

/// The elapsed time and bar count the player card's Metronome content shows (7.13).
@MainActor
struct PlayerModelTests {
    private let engine = FakeClickEngine()
    private let haptics = FakeHaptics()
    private let store = SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    private let libraryStore = LibraryStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    private let uptime = Uptime()

    private func makeModel() -> MetronomeModel {
        let uptime = uptime
        return MetronomeModel(
            engine: engine, store: store, haptics: haptics, libraryStore: libraryStore,
            trackFiles: .temporary(), uptime: { uptime.now }
        )
    }

    /// A model with three songs in a setlist, in the order slow, mid, fast; nothing loaded.
    private func modelWithSetlist() -> (model: MetronomeModel, songs: [Song], setlist: UUID) {
        let model = makeModel()
        let songs = [("Slow", 60), ("Mid", 100), ("Fast", 180)].map {
            model.createSong(
                name: $0.0, settings: MetronomeSettings(bpm: $0.1, timeSignature: .fourFour, accents: [1]),
                addingTo: nil
            )!
        }
        let setlist = model.createSetlist()
        songs.forEach { model.setSong($0.id, inSetlist: setlist, included: true) }
        return (model, songs, setlist)
    }

    /// A model whose loaded song, at 120 BPM in 4/4, has a playable backing track, with
    /// Backing tracks on, so the player card shows Track content.
    private func modelWithATrack() throws -> MetronomeModel {
        let files = TrackFileStore.temporary()
        let source = FileManager.default.temporaryDirectory.appending(path: "PlayerTrack-\(UUID().uuidString).m4a")
        try Data("audio".utf8).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }
        let track = BackingTrack(fileID: UUID(), fileName: "Song.m4a", offset: 48, bpm: 120)
        try files.store(source, as: track.fileID)
        var library = Library()
        let added = library.addSong(name: "Song", settings: MetronomeSettings(), track: track, now: Date())
        let song = try #require(added)
        libraryStore.save(LibraryState(library: library, loadedSongID: song.id))
        let uptime = uptime
        return MetronomeModel(
            engine: engine, store: store, haptics: haptics, libraryStore: libraryStore,
            trackFiles: files, lengthOfTrack: { _ in 222 }, uptime: { uptime.now }
        )
    }

    /// The beats sound, in order, at the current uptime.
    private func sound(_ beats: Int..., countIn: Bool = false) {
        for beat in beats {
            engine.onBeat?(ScheduledBeat(beat: beat, isAccented: beat == 1, sampleTime: 0, isCountIn: countIn))
        }
    }

    private func shown(_ model: MetronomeModel) -> [String] {
        let readout = model.readout()
        return [readout.time, readout.bar]
    }

    /// Started and played in 4/4 into its third bar, 84 s after the first beat, at "1:24" and "Bar 3".
    private func playIntoBarThree(_ model: MetronomeModel) {
        model.togglePlayback()
        uptime.now = 10
        sound(1, 2, 3, 4, 1, 2, 3, 4, 1)
        uptime.now = 94
    }

    @Test func startSetsTheReadoutToZero() {
        let model = makeModel()
        playIntoBarThree(model)
        #expect(shown(model) == ["1:24", "Bar 3"])
        model.togglePlayback()
        model.togglePlayback()
        #expect(shown(model) == ["0:00", "Bar 1"])
    }

    @Test func theReadoutRunsWithTheBeats() {
        let model = makeModel()
        model.togglePlayback()
        uptime.now = 10
        sound(1)
        uptime.now = 94
        #expect(shown(model) == ["1:24", "Bar 1"])
        sound(2, 3, 4, 1)
        #expect(shown(model) == ["1:24", "Bar 2"])
    }

    @Test func stopKeepsTheReadout() {
        let model = makeModel()
        model.togglePlayback()
        uptime.now = 10
        sound(1, 2, 3, 4, 1)
        uptime.now = 94
        model.togglePlayback()
        uptime.now = 500
        #expect(shown(model) == ["1:24", "Bar 2"])
    }

    @Test func theEngineStoppingKeepsTheReadout() {
        let model = makeModel()
        model.togglePlayback()
        uptime.now = 10
        sound(1, 2, 3, 4, 1)
        uptime.now = 94
        engine.onStopped?()
        #expect(model.isPlaying == false)
        uptime.now = 500
        #expect(shown(model) == ["1:24", "Bar 2"])
    }

    @Test func loadingAnotherSongWhilePlayingCountsAfresh() {
        let (model, songs, setlist) = modelWithSetlist()
        model.loadSong(songs[0].id, from: setlist)
        playIntoBarThree(model)
        #expect(shown(model) == ["1:24", "Bar 3"])
        model.loadSong(songs[1].id, from: setlist)
        #expect(model.isPlaying)
        #expect(shown(model) == ["0:00", "Bar 1"])
        uptime.now = 50
        sound(1)
        uptime.now = 52
        #expect(shown(model) == ["0:02", "Bar 1"])
    }

    @Test func unloadWhilePlayingCountsAfreshFromTheNextBeat() {
        let (model, songs, setlist) = modelWithSetlist()
        model.loadSong(songs[0].id, from: setlist)
        playIntoBarThree(model)
        sound(2)
        model.unloadSong()
        #expect(model.isPlaying)
        sound(3)
        #expect(shown(model).last == "Bar 1")
        sound(4, 1)
        #expect(shown(model).last == "Bar 2")
    }

    @Test func tappingTheLoadedSongsRowChangesNothing() {
        let (model, songs, setlist) = modelWithSetlist()
        model.loadSong(songs[0].id, from: setlist)
        playIntoBarThree(model)
        model.loadSong(songs[0].id, from: setlist)
        #expect(shown(model) == ["1:24", "Bar 3"])
    }

    @Test func switchesAndMuteLeaveTheReadout() throws {
        let model = try modelWithATrack()
        #expect(model.playerContent == .track)
        model.togglePlayback()
        uptime.now = 10
        sound(1, 2, 3, 4, 1)
        uptime.now = 94
        model.togglePlayback()
        model.toggleBackingTracks()
        #expect(model.playerContent == .metronome)
        model.toggleMute()
        #expect(shown(model) == ["1:24", "Bar 2"])
        model.toggleBackingTracks()
        #expect(model.playerContent == .track)
        #expect(shown(model) == ["1:24", "Bar 2"])
    }

    @Test func theEndOfTheTrackFreezesTheReadout() throws {
        let model = try modelWithATrack()
        playIntoBarThree(model)
        engine.onTrackEnded?()
        #expect(model.isPlaying == false)
        uptime.now = 500
        #expect(shown(model) == ["1:24", "Bar 3"])
    }

    @Test func aFailedStartLeavesZeroWithNoRunningTime() {
        let model = makeModel()
        playIntoBarThree(model)
        model.togglePlayback()
        engine.startError = StartFailure()
        model.togglePlayback()
        #expect(model.isPlaying == false)
        uptime.now = 500
        #expect(shown(model) == ["0:00", "Bar 1"])
    }

    @Test func savingAsANewSongCountsAfresh() throws {
        let (model, songs, setlist) = modelWithSetlist()
        model.loadSong(songs[0].id, from: setlist)
        playIntoBarThree(model)
        let saved = try #require(model.saveAsNewSong(name: "Copy", settings: model.settings))
        #expect(model.loadedSong?.id == saved.id)
        #expect(shown(model) == ["0:00", "Bar 1"])
    }

    @Test func namingTheCurrentSettingsCountsAfresh() throws {
        let model = makeModel()
        playIntoBarThree(model)
        let named = try #require(model.createSong(name: "Named", settings: model.settings, addingTo: nil))
        #expect(model.loadedSong?.id == named.id)
        #expect(shown(model) == ["0:00", "Bar 1"])
    }

    @Test func deletingTheLoadedSongCountsAfresh() {
        let (model, songs, setlist) = modelWithSetlist()
        model.loadSong(songs[0].id, from: setlist)
        playIntoBarThree(model)
        model.deleteSong(songs[0].id)
        #expect(model.loadedSong == nil)
        #expect(shown(model) == ["0:00", "Bar 1"])
    }

    @Test func aCountInIsNotCounted() {
        let model = makeModel()
        model.togglePlayback()
        uptime.now = 10
        sound(1, 2, 3, 4, countIn: true)
        uptime.now = 14
        #expect(shown(model) == ["0:00", "Bar 1"])
    }

    @Test func theReadoutIsNotKept() {
        let model = makeModel()
        playIntoBarThree(model)
        model.togglePlayback()
        let relaunched = makeModel()
        #expect(shown(relaunched) == ["0:00", "Bar 1"])
    }

    @Test func theReadoutIsSpoken() {
        let model = makeModel()
        model.togglePlayback()
        sound(1)
        for _ in 1..<43 { sound(2, 3, 4, 1) }
        uptime.now = 84
        #expect(model.readout().spoken == "1 minute 24 seconds, bar 43")
    }
}
