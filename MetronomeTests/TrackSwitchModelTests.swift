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

/// The Backing tracks switch: with it off, every song is a plain metronome.
@MainActor
@Suite
struct TrackSwitchModelTests {
    private let bench: TrackTestBench
    private var engine: FakeClickEngine { bench.engine }
    private var haptics: FakeHaptics { bench.haptics }
    private let cloud = FakeCloudStore()
    private let clock = Clock()

    init() throws {
        bench = try TrackTestBench()
    }

    /// The loaded song with a playable track, and a second song, with a playable track or without one.
    private func makeTwoSongs(secondHasTrack: Bool) throws -> (model: MetronomeModel, first: Song, second: Song) {
        let moment = Date()
        var library = Library()
        let firstTrack = try bench.makeTrack()
        let secondTrack = secondHasTrack ? try bench.makeTrack() : nil
        let added = [
            library.addSong(name: "First", settings: MetronomeSettings(), track: firstTrack, now: moment),
            library.addSong(
                name: "Second", settings: MetronomeSettings(bpm: 90, timeSignature: .fourFour, accents: [1]),
                track: secondTrack, now: moment
            ),
        ]
        let first = try #require(added[0])
        let second = try #require(added[1])
        bench.libraryStore.save(LibraryState(library: library, loadedSongID: first.id))
        return (bench.relaunch(), first, second)
    }

    @Test func theSwitchIsOnAtFirstLaunch() throws {
        let model = try bench.makeModel()
        #expect(model.backingTracksOn)
        #expect(model.isTrackInUse)
        #expect(model.isTrackPlayable)
    }

    @Test func switchedOffTheSongIsPlain() throws {
        let model = try bench.makeModel()
        model.toggleBackingTracks()
        #expect(model.backingTracksOn == false)
        #expect(model.isTrackInUse == false)
        #expect(model.isTrackPlayable == false)
        #expect(model.isTrackMissing == false)
        #expect(model.loadedTrack != nil)
        model.togglePlayback()
        #expect(model.isPlaying)
        #expect(engine.startCount == 1)
        #expect(engine.startedTracks.isEmpty)
        #expect(model.isPlayingTrack == false)
    }

    @Test func switchedOffAMissingFileIsNotReportedMissing() throws {
        let model = try bench.makeModel(missing: true)
        model.toggleBackingTracks()
        #expect(model.isTrackMissing == false)
        model.toggleBackingTracks()
        #expect(model.isTrackMissing)
    }

    @Test func theSwitchDoesNothingWhilePlaying() throws {
        let model = try bench.makeModel()
        model.togglePlayback()
        let ticks = haptics.selectionCount
        model.toggleBackingTracks()
        #expect(model.backingTracksOn)
        #expect(haptics.selectionCount == ticks)
    }

    @Test func theSwitchTicks() throws {
        let model = try bench.makeModel()
        let ticks = haptics.selectionCount
        model.toggleBackingTracks()
        #expect(haptics.selectionCount == ticks + 1)
    }

    @Test func thePositionSurvivesOffAndOn() throws {
        let model = try bench.makeModel()
        model.seekTrack(to: 70)
        model.toggleBackingTracks()
        model.toggleBackingTracks()
        #expect(model.trackPosition == 70)
    }

    @Test func loadingAnotherSongWhileOffResetsThePosition() throws {
        let (model, first, second) = try makeTwoSongs(secondHasTrack: false)
        model.seekTrack(to: 70)
        model.toggleBackingTracks()
        model.loadSong(second.id, from: nil)
        model.loadSong(first.id, from: nil)
        model.toggleBackingTracks()
        #expect(model.trackPosition == 0)
    }

    @Test func theSwitchIsRememberedAcrossLaunches() throws {
        let model = try bench.makeModel()
        model.toggleBackingTracks()
        let relaunched = bench.relaunch()
        #expect(relaunched.backingTracksOn == false)
        #expect(relaunched.isTrackPlayable == false)
    }

    @Test func loadingASongNeverChangesTheSwitch() throws {
        let (model, first, second) = try makeTwoSongs(secondHasTrack: false)
        model.toggleBackingTracks()
        model.loadSong(second.id, from: nil)
        model.loadSong(first.id, from: nil)
        #expect(model.backingTracksOn == false)
        model.toggleBackingTracks()
        model.loadSong(second.id, from: nil)
        #expect(model.backingTracksOn)
    }

    @Test func switchedOffLoadingATrackSongDoesNotStopPlayback() throws {
        let (model, _, second) = try makeTwoSongs(secondHasTrack: true)
        model.toggleBackingTracks()
        model.togglePlayback()
        model.loadSong(second.id, from: nil)
        #expect(model.isPlaying)
        #expect(engine.stopCount == 0)
    }

    @Test func switchedOffReplacingTheFileKeepsPlayingAndGoesToZero() throws {
        let model = try bench.makeModel()
        let song = try #require(model.loadedSong)
        model.seekTrack(to: 70)
        model.toggleBackingTracks()
        model.togglePlayback()
        let picked = PickedTrack(url: try bench.sourceFile(named: "Take.wav"), fileName: "Take.wav", firstBeat: 48)
        model.editSong(song.id, name: song.name, settings: song.settings, track: .attach(picked))
        #expect(model.isPlaying)
        #expect(engine.stopCount == 0)
        #expect(model.loadedTrack?.fileName == "Take.wav")
        #expect(model.trackPosition == 0)
    }

    @Test func switchedOffUnloadDoesNotStopPlayback() throws {
        let model = try bench.makeModel()
        model.toggleBackingTracks()
        model.togglePlayback()
        model.unloadSong()
        #expect(model.loadedSong == nil)
        #expect(model.isPlaying)
        #expect(engine.stopCount == 0)
        #expect(model.backingTracksOn == false)
    }

    @Test func switchedOffSaveAsNewSongDoesNotStopPlayback() throws {
        let model = try bench.makeModel()
        model.toggleBackingTracks()
        model.togglePlayback()
        model.setBPM(130)
        let copy = try #require(model.saveAsNewSong(name: "Copy", settings: model.settings))
        #expect(model.loadedSongID == copy.id)
        #expect(model.isPlaying)
        #expect(engine.stopCount == 0)
    }

    @Test func switchedOffNamingTheSettingsWithATrackDoesNotStopPlayback() throws {
        let model = try bench.makeModel()
        model.unloadSong()
        model.toggleBackingTracks()
        model.togglePlayback()
        let picked = PickedTrack(url: try bench.sourceFile(named: "Take.wav"), fileName: "Take.wav", firstBeat: 48)
        let named = try #require(model.createSong(name: "Named", settings: model.settings, addingTo: nil, track: picked))
        #expect(model.loadedSongID == named.id)
        #expect(model.loadedTrack?.fileName == "Take.wav")
        #expect(model.isPlaying)
        #expect(engine.stopCount == 0)
    }

    @Test func theSongSheetStillSeesTheFileWhileOff() throws {
        let model = try bench.makeModel()
        model.toggleBackingTracks()
        let song = try #require(model.loadedSong)
        #expect(model.hasTrackFile(for: song))
    }

    // MARK: - Changes arriving from another device

    /// One phone with sync on the shared fake iCloud, with its own track files.
    private func makeDevice() -> (model: MetronomeModel, engine: FakeClickEngine, haptics: FakeHaptics) {
        let engine = FakeClickEngine()
        let haptics = FakeHaptics()
        let clock = clock
        let model = MetronomeModel(
            engine: engine,
            store: SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!),
            haptics: haptics,
            libraryStore: LibraryStore(defaults: UserDefaults(suiteName: UUID().uuidString)!),
            sync: LibrarySync(cloud: cloud, defaults: UserDefaults(suiteName: UUID().uuidString)!, syncingDelay: .seconds(3600)),
            now: { clock.now() },
            trackFiles: TrackFileStore(directory: bench.root.appending(path: UUID().uuidString)),
            lengthOfTrack: { _ in 222 }
        )
        model.setSyncEnabled(true)
        return (model, engine, haptics)
    }

    /// Every haptic the device has played.
    private func hapticCount(_ haptics: FakeHaptics) -> Int {
        haptics.beats.count + haptics.selectionCount + haptics.transportCount + haptics.successCount
    }

    @Test func switchedOffATrackArrivingBySyncDoesNotStopPlayback() throws {
        let settings100 = MetronomeSettings(bpm: 100, timeSignature: .fourFour, accents: [1])
        let a = makeDevice(), b = makeDevice()
        clock.advance()
        let first = PickedTrack(url: try bench.sourceFile(named: "Take.wav"), fileName: "Take.wav", firstBeat: 48)
        let song = try #require(a.model.createSong(name: "Song", settings: settings100, addingTo: nil, track: first))
        cloud.send(.changed, toDevice: 1)
        b.model.loadSong(song.id, from: nil)
        let here = PickedTrack(url: try bench.sourceFile(named: "Take.wav"), fileName: "Take.wav", firstBeat: 48)
        b.model.editSong(song.id, name: "Song", settings: settings100, track: .attach(here))
        #expect(b.model.isTrackPlayable)
        b.model.toggleBackingTracks()
        b.model.togglePlayback()
        let haptics = hapticCount(b.haptics)

        clock.advance()
        let replacement = PickedTrack(url: try bench.sourceFile(named: "New.wav"), fileName: "New.wav", firstBeat: 48)
        a.model.editSong(song.id, name: "Song", settings: settings100, track: .attach(replacement))
        cloud.send(.changed, toDevice: 1)
        #expect(b.model.loadedTrack?.fileName == "New.wav")
        #expect(b.model.isPlaying)
        #expect(b.engine.stopCount == 0)
        #expect(b.model.backingTracksOn == false)
        #expect(hapticCount(b.haptics) == haptics)
    }

    @Test func switchedOffATrackAttachedOnAnotherDeviceDoesNotStopPlayback() throws {
        let settings100 = MetronomeSettings(bpm: 100, timeSignature: .fourFour, accents: [1])
        let a = makeDevice(), b = makeDevice()
        clock.advance()
        let song = try #require(a.model.createSong(name: "Song", settings: settings100, addingTo: nil))
        cloud.send(.changed, toDevice: 1)
        b.model.loadSong(song.id, from: nil)
        b.model.toggleBackingTracks()
        b.model.togglePlayback()
        let haptics = hapticCount(b.haptics)

        clock.advance()
        let picked = PickedTrack(url: try bench.sourceFile(named: "Take.wav"), fileName: "Take.wav", firstBeat: 48)
        a.model.editSong(song.id, name: "Song", settings: settings100, track: .attach(picked))
        cloud.send(.changed, toDevice: 1)
        // The header shows the switch for a loaded song with a track.
        #expect(b.model.loadedTrack?.fileName == "Take.wav")
        #expect(b.model.isTrackInUse == false)
        #expect(b.model.isPlaying)
        #expect(b.engine.stopCount == 0)
        #expect(b.model.backingTracksOn == false)
        #expect(hapticCount(b.haptics) == haptics)
    }
}
