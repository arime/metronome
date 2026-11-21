import Foundation
import Testing
@testable import Metronome

private struct TrackOpenFailed: Error {}

/// Each test gets its own bench: stores and a temporary directory for the track files.
@MainActor
@Suite
struct TrackModelTests {
    private let bench: TrackTestBench
    private var engine: FakeClickEngine { bench.engine }

    init() throws {
        bench = try TrackTestBench()
    }

    private func makeModel(
        length: TimeInterval = 222, countIn: CountIn = .twoBars, mix: Double = 0, missing: Bool = false
    ) throws -> MetronomeModel {
        try bench.makeModel(length: length, countIn: countIn, mix: mix, missing: missing)
    }

    private func relaunch(length: TimeInterval = 222) -> MetronomeModel {
        bench.relaunch(length: length)
    }

    // MARK: - Start

    @Test func startAtZeroPlaysTheCountIn() throws {
        let model = try makeModel()
        model.togglePlayback()
        let started = try #require(engine.startedTracks.last)
        #expect(started.startTime == 0.48 - 4.0)
        #expect(started.firstClickIndex == -8)
        #expect(started.offset == 0.48)
        #expect(started.clickGain == 1)
        #expect(started.trackGain == 1)
        #expect(model.isPlaying)
        #expect(model.isPlayingTrack)
    }

    @Test func startAtZeroWithOneBarPlaysOneBarOfCountIn() throws {
        let model = try makeModel(countIn: .oneBar)
        model.togglePlayback()
        let started = try #require(engine.startedTracks.last)
        #expect(started.startTime == 0.48 - 2.0)
        #expect(started.firstClickIndex == -4)
    }

    @Test func countInOffStartsTheFileAtOnce() throws {
        let model = try makeModel(countIn: .off)
        model.togglePlayback()
        let started = try #require(engine.startedTracks.last)
        #expect(started.startTime == 0)
        #expect(started.firstClickIndex == 0)
    }

    @Test func startPlaysAnUnsavedCountInAndMix() throws {
        let model = try makeModel()
        model.setCountIn(.oneBar)
        model.setMix(-0.5)
        model.togglePlayback()
        let started = try #require(engine.startedTracks.last)
        #expect(started.startTime == 0.48 - 2.0)
        #expect(started.firstClickIndex == -4)
        #expect(started.clickGain == TrackMix.clickGain(at: -0.5))
        #expect(started.trackGain == TrackMix.trackGain(at: -0.5))
        #expect(model.loadedTrack?.countIn == .twoBars)
        #expect(model.loadedTrack?.mix == 0)
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

    @Test func theKeptPositionStaysInsideTheFile() throws {
        let model = try makeModel(length: 100)
        model.togglePlayback()
        engine.trackTime = 100.4
        model.togglePlayback()
        #expect(model.trackPosition == 100)
        model.togglePlayback()
        engine.trackTime = 100.4
        engine.onStopped?()
        #expect(model.trackPosition == 100)
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

    // The heard place is behind the file's start by the output delay just after a start or a jump
    // to 0:00; only a run started before the file's start counts in.

    @Test func countInOffNeverShowsTheCountIn() throws {
        let model = try makeModel(countIn: .off)
        model.togglePlayback()
        engine.trackTime = -0.05
        #expect(model.isCountingIn == false)
        #expect(model.trackTime == 0)
        #expect(model.canTapDownbeat)
    }

    @Test func anOffsetLongerThanTheCountInShowsNoCountIn() throws {
        let model = try makeModel(countIn: .twoBars)
        // 4.48 s, further into the file than two bars at 120 BPM (4 s).
        model.nudgeOffset(by: 400)
        model.togglePlayback()
        let started = try #require(engine.startedTracks.last)
        #expect(started.startTime == 0)
        engine.trackTime = -0.05
        #expect(model.isCountingIn == false)
    }

    @Test func startingFromAKeptPositionShowsNoCountIn() throws {
        let model = try makeModel()
        model.seekTrack(to: 30)
        model.togglePlayback()
        engine.trackTime = -0.05
        #expect(model.isCountingIn == false)
    }

    @Test func theCountInShowsUntilTheFileIsHeard() throws {
        let model = try makeModel(countIn: .twoBars)
        model.togglePlayback()
        engine.trackTime = -2
        #expect(model.isCountingIn)
        #expect(model.canTapDownbeat == false)
        engine.trackTime = 0.5
        #expect(model.isCountingIn == false)
        #expect(model.canTapDownbeat)
    }

    @Test func toTheBeginningWhilePlayingShowsNoCountIn() throws {
        let model = try makeModel()
        model.togglePlayback()
        engine.trackTime = -2
        model.goToTrackStart()
        #expect(engine.seeks.isEmpty)
        #expect(model.isCountingIn)
        engine.trackTime = 30
        model.goToTrackStart()
        #expect(engine.seeks == [0])
        engine.trackTime = -0.05
        #expect(model.isCountingIn == false)
    }

    @Test func rewindingToZeroWhilePlayingShowsNoCountIn() throws {
        let model = try makeModel()
        model.togglePlayback()
        engine.trackTime = 5
        model.skipTrack(by: -15)
        #expect(engine.seeks == [0])
        engine.trackTime = -0.05
        #expect(model.isCountingIn == false)
    }

    @Test func startingAgainAtZeroShowsTheCountInAgain() throws {
        let model = try makeModel(countIn: .twoBars)
        model.togglePlayback()
        engine.trackTime = -1
        model.togglePlayback()
        #expect(model.isCountingIn == false)
        model.togglePlayback()
        engine.trackTime = -1
        #expect(model.isCountingIn)
    }

    @Test func stopWithinTheFirstSecondGoesToZeroAndCountsInAgain() throws {
        let model = try makeModel()
        model.togglePlayback()
        engine.trackTime = 0.4
        model.togglePlayback()
        #expect(model.trackPosition == 0)
        model.togglePlayback()
        let started = try #require(engine.startedTracks.last)
        #expect(started.firstClickIndex == -8)
    }

    @Test func stopAfterTheFirstSecondKeepsThePositionWithoutCountIn() throws {
        let model = try makeModel()
        model.togglePlayback()
        engine.trackTime = 1.2
        model.togglePlayback()
        #expect(model.trackPosition == 1.2)
        model.togglePlayback()
        let started = try #require(engine.startedTracks.last)
        #expect(started.startTime == 1.2)
        #expect(started.firstClickIndex == 0)
    }

    @Test func anInterruptionWithinTheFirstSecondGoesToZero() throws {
        let model = try makeModel()
        model.togglePlayback()
        engine.trackTime = 0.7
        engine.onStopped?()
        #expect(model.trackPosition == 0)
    }

    @Test func aSeekWithinTheFirstSecondLandsOnZero() throws {
        let model = try makeModel()
        model.seekTrack(to: 0.6)
        #expect(model.trackPosition == 0)
        model.togglePlayback()
        engine.trackTime = 20
        model.seekTrack(to: 0.6)
        #expect(engine.seeks == [0])
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

    // MARK: - The mix

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
