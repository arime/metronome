import Foundation
import Testing
@testable import Metronome

private struct TrackOpenFailed: Error {}

/// Each test gets its own stores and a temporary directory for the track files, removed when the test ends.
@MainActor
@Suite
final class TrackModelTests {
    private let root: URL
    private let trackFiles: TrackFileStore
    private let engine = FakeClickEngine()
    private let haptics = FakeHaptics()
    private let settingsStore = SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    private let libraryStore = LibraryStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "TrackModelTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        trackFiles = TrackFileStore(directory: root.appending(path: "Tracks"))
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    /// A model whose loaded song is at 120 BPM in 4/4 with a track whose first beat is 0.48 s.
    /// With `missing` the track's file is not stored.
    private func makeModel(
        length: TimeInterval = 222, countIn: CountIn = .twoBars, mix: Double = 0, missing: Bool = false
    ) throws -> MetronomeModel {
        let track = BackingTrack(fileID: UUID(), fileName: "Song.m4a", firstBeat: 48, countIn: countIn, mix: mix)
        var library = Library()
        let added = library.addSong(name: "Song", settings: MetronomeSettings(), track: track, now: Date())
        let song = try #require(added)
        libraryStore.save(LibraryState(library: library, loadedSongID: song.id))
        if !missing {
            let source = root.appending(path: "Song.m4a")
            try Data("audio".utf8).write(to: source)
            try trackFiles.store(source, as: track.fileID)
        }
        return relaunch(length: length)
    }

    /// A new model on the same stores, as after the app is opened again.
    private func relaunch(length: TimeInterval = 222) -> MetronomeModel {
        MetronomeModel(
            engine: engine, store: settingsStore, haptics: haptics, libraryStore: libraryStore,
            trackFiles: trackFiles, lengthOfTrack: { _ in length }
        )
    }

    // MARK: - Start

    @Test func startAtZeroPlaysTheCountIn() throws {
        let model = try makeModel()
        model.togglePlayback()
        let started = try #require(engine.startedTracks.last)
        #expect(started.startTime == 0.48 - 4.0)
        #expect(started.firstClickIndex == -8)
        #expect(started.firstBeat == 0.48)
        #expect(started.clickGain == 1)
        #expect(started.trackGain == 1)
        #expect(model.isPlaying)
        #expect(model.isPlayingTrack)
    }

    @Test func countInOffStartsTheFileAtOnce() throws {
        let model = try makeModel(countIn: .off)
        model.togglePlayback()
        let started = try #require(engine.startedTracks.last)
        #expect(started.startTime == 0)
        #expect(started.firstClickIndex == 0)
    }

    @Test func startAwayFromZeroSkipsTheCountIn() throws {
        let model = try makeModel()
        model.seekTrack(to: 30)
        model.togglePlayback()
        let started = try #require(engine.startedTracks.last)
        #expect(started.startTime == 30)
        #expect(started.firstClickIndex == 0)
    }

    // MARK: - Stop and the end of the track

    @Test func stopKeepsThePosition() throws {
        let model = try makeModel()
        model.togglePlayback()
        engine.trackTime = 84.2
        model.togglePlayback()
        #expect(model.isPlaying == false)
        #expect(model.trackPosition == 84.2)
        #expect(engine.stopCount == 1)
    }

    @Test func stoppingDuringTheCountInStaysAtZero() throws {
        let model = try makeModel()
        model.togglePlayback()
        engine.trackTime = -1.5
        #expect(model.isCountingIn)
        #expect(model.trackTime == 0)
        model.togglePlayback()
        #expect(model.trackPosition == 0)
    }

    @Test func theEndOfTheTrackStopsAndGoesBackToZero() throws {
        let model = try makeModel()
        model.seekTrack(to: 30)
        model.togglePlayback()
        engine.onBeat?(ScheduledBeat(beat: 2, isAccented: false, sampleTime: 0))
        engine.trackTime = 222
        engine.onTrackEnded?()
        #expect(model.isPlaying == false)
        #expect(model.isPlayingTrack == false)
        #expect(model.currentBeat == nil)
        #expect(model.trackPosition == 0)
    }

    // Review Focus 1
    @Test func lateTrackEndAfterStopKeepsThePosition() throws {
        let model = try makeModel()
        model.togglePlayback()
        engine.trackTime = 84.2
        model.togglePlayback()
        engine.onTrackEnded?()
        #expect(model.trackPosition == 84.2)
        #expect(model.isPlaying == false)
    }

    @Test func anInterruptionKeepsThePosition() throws {
        let model = try makeModel()
        model.togglePlayback()
        engine.trackTime = 50
        engine.onStopped?()
        #expect(model.isPlaying == false)
        #expect(model.isPlayingTrack == false)
        #expect(model.trackPosition == 50)
    }

    // MARK: - Rewind, Fast-forward and seeking

    @Test func rewindNearTheStartGoesToZero() throws {
        let model = try makeModel()
        model.seekTrack(to: 9)
        model.skipTrack(by: -15)
        #expect(model.trackPosition == 0)
    }

    @Test func fastForwardIsRefusedInTheLastFifteenSeconds() throws {
        let model = try makeModel(length: 222)
        model.seekTrack(to: 210)
        #expect(model.canSkipForward == false)
        model.skipTrack(by: 15)
        #expect(model.trackPosition == 210)
    }

    // Review Focus 2
    @Test func skipsStayInsideAShortFile() throws {
        let model = try makeModel(length: 8)
        #expect(model.trackLength == 8)
        model.seekTrack(to: 5)
        model.skipTrack(by: 15)
        #expect(model.trackPosition == 5)
        model.skipTrack(by: -15)
        #expect(model.trackPosition == 0)
        model.seekTrack(to: 100)
        #expect(model.trackPosition == 8)
    }

    @Test func skippingWhilePlayingSeeksTheEngine() throws {
        let model = try makeModel()
        model.togglePlayback()
        engine.trackTime = 40
        model.skipTrack(by: 15)
        #expect(engine.seeks == [55])
        #expect(model.isPlaying)
        #expect(engine.startCount == 1)
    }

    @Test func skippingBackToZeroWhilePlayingPlaysNoCountIn() throws {
        let model = try makeModel()
        model.togglePlayback()
        engine.trackTime = 5
        model.skipTrack(by: -15)
        #expect(engine.seeks == [0])
        #expect(engine.startCount == 1)
    }

    // MARK: - Changes while playing

    @Test func aTempoChangeWhilePlayingKeepsTheBarOnTheTrack() throws {
        let model = try makeModel()
        model.togglePlayback()
        model.selectTimeSignature(.threeFour)
        #expect(engine.lastUpdate?.timeSignature == .threeFour)
        #expect(engine.lastUpdateStartedNewBar == false)
    }

    @Test func muteLeavesTheTrackAlone() throws {
        let model = try makeModel()
        model.togglePlayback()
        model.toggleMute()
        #expect(engine.muted)
        #expect(engine.mixes.isEmpty)
        #expect(model.isPlayingTrack)
    }

    // MARK: - Missing and unreadable files

    // Review Focus 3
    @Test func unreadableFileAtStartPlaysTheClickAlone() throws {
        let model = try makeModel()
        engine.trackStartError = TrackOpenFailed()
        model.togglePlayback()
        #expect(model.isPlaying)
        #expect(model.isPlayingTrack == false)
        #expect(engine.startCount == 1)
        #expect(engine.startedTracks.isEmpty)
    }

    @Test func aMissingFilePlaysLikeASongWithoutATrack() throws {
        let model = try makeModel(missing: true)
        #expect(model.loadedTrack != nil)
        #expect(model.isTrackMissing)
        #expect(model.isTrackPlayable == false)
        model.togglePlayback()
        #expect(model.isPlaying)
        #expect(model.isPlayingTrack == false)
        #expect(engine.startCount == 1)
        #expect(engine.startedTracks.isEmpty)
    }

    // MARK: - The Sync sheet and the mix

    @Test func theSheetsPlayNeverCountsIn() throws {
        let model = try makeModel()
        model.toggleTrackPlaybackWithoutCountIn()
        let started = try #require(engine.startedTracks.last)
        #expect(started.startTime == 0)
        #expect(started.firstClickIndex == 0)
        #expect(model.isPlayingTrack)
    }

    @Test func theMixSetsTheGainsAtStart() throws {
        let model = try makeModel(mix: -0.5)
        model.togglePlayback()
        let started = try #require(engine.startedTracks.last)
        #expect(abs(started.trackGain - 0.251) < 0.001)
        #expect(started.clickGain == 1)
    }

    // MARK: - Launch and songs without a track

    @Test func thePositionIsZeroAtLaunch() throws {
        let model = try makeModel()
        model.togglePlayback()
        engine.trackTime = 84.2
        model.togglePlayback()
        #expect(model.trackPosition == 84.2)
        let relaunched = relaunch()
        #expect(relaunched.trackPosition == 0)
        #expect(relaunched.trackLength == 222)
    }

    @Test func songsWithoutATrackStartAsBefore() {
        let model = relaunch()
        #expect(model.loadedTrack == nil)
        #expect(model.isTrackPlayable == false)
        #expect(model.isTrackMissing == false)
        #expect(model.canSkipForward == false)
        model.togglePlayback()
        #expect(model.isPlaying)
        #expect(model.isPlayingTrack == false)
        #expect(engine.startCount == 1)
        #expect(engine.startedTracks.isEmpty)
        model.selectTimeSignature(.threeFour)
        #expect(engine.lastUpdateStartedNewBar == true)
    }
}
