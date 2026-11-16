import Foundation
import Testing
@testable import Metronome

/// The tap pad: downbeats tapped while the track plays set its tempo and offset together.
@MainActor
@Suite
struct TapRunModelTests {
    private let bench: TrackTestBench
    private var engine: FakeClickEngine { bench.engine }
    private var haptics: FakeHaptics { bench.haptics }

    init() throws {
        bench = try TrackTestBench()
    }

    /// Playing a song at 120 BPM in 4/4 whose track is at 120 BPM with its offset at 0.48 s.
    private func playingModel() throws -> MetronomeModel {
        let model = try bench.makeModel()
        model.togglePlayback()
        return model
    }

    private func tap(_ model: MetronomeModel, at time: TimeInterval) {
        engine.trackTime = time
        model.tapDownbeat()
    }

    @Test func oneTapOnThePadSetsTheOffsetFromTheHeardPlace() throws {
        let model = try playingModel()
        let ticks = haptics.selectionCount
        tap(model, at: 9.30)
        #expect(model.loadedTrack?.offset == 130)
        #expect(model.loadedTrack?.bpm == 120)
        #expect(engine.offsets.last == 1.30)
        #expect(haptics.selectionCount == ticks + 1)
        #expect(model.tapRun.taps.count == 1)
    }

    @Test func theWorkedExampleOnThePad() throws {
        let model = try playingModel()
        tap(model, at: 10.11)
        tap(model, at: 12.01)
        #expect(model.loadedTrack?.bpm == 126)
        #expect(model.loadedTrack?.offset == 58)
        #expect(engine.lastUpdate?.bpm == 126)
        tap(model, at: 13.95)
        tap(model, at: 19.69)
        #expect(model.loadedTrack?.bpm == 125)
        #expect(model.loadedTrack?.offset == 50)
        #expect(model.tapRun.countLine == "4 taps · 6 bars")
        #expect(model.settings.bpm == 120)
    }

    @Test func thePadDoesNothingWhileStoppedOrCountingIn() throws {
        let model = try bench.makeModel()
        let ticks = haptics.selectionCount
        #expect(model.canTapDownbeat == false)
        tap(model, at: 9.30)
        #expect(model.loadedTrack?.offset == 48)

        model.togglePlayback()
        tap(model, at: -1)
        #expect(model.canTapDownbeat == false)
        #expect(model.loadedTrack?.offset == 48)
        #expect(engine.offsets.isEmpty)
        #expect(haptics.selectionCount == ticks)
        #expect(model.tapRun.isEmpty)
    }

    @Test func aBouncedFingerIsOneTap() throws {
        let model = try playingModel()
        tap(model, at: 9.30)
        let ticks = haptics.selectionCount
        tap(model, at: 9.40)
        #expect(haptics.selectionCount == ticks)
        #expect(model.loadedTrack?.bpm == 120)
        #expect(model.loadedTrack?.offset == 130)
        #expect(model.tapRun.countLine == "1 tap · 1 bar")
    }

    @Test func startOverForgetsTheRunAndKeepsTheValues() throws {
        let model = try playingModel()
        tap(model, at: 10.11)
        tap(model, at: 12.01)
        let ticks = haptics.selectionCount
        model.startTapRunOver()
        #expect(model.tapRun.isEmpty)
        #expect(model.loadedTrack?.bpm == 126)
        #expect(model.loadedTrack?.offset == 58)
        #expect(haptics.selectionCount == ticks)
    }

    @Test func aTimeSignatureChangeEndsTheRun() throws {
        let model = try playingModel()
        tap(model, at: 9.30)
        model.selectTimeSignature(.fourFour)
        #expect(model.tapRun.taps.count == 1)
        model.selectTimeSignature(.threeFour)
        #expect(model.tapRun.isEmpty)
    }

    @Test func steppingTheTempoOrTheOffsetEndsTheRun() throws {
        let model = try playingModel()
        tap(model, at: 9.30)
        model.nudgeTrackTempo(by: 1)
        #expect(model.tapRun.isEmpty)
        tap(model, at: 11.30)
        model.nudgeOffset(by: 1)
        #expect(model.tapRun.isEmpty)
    }

    @Test func theMixAccentsAndCountInKeepTheRun() throws {
        let model = try playingModel()
        tap(model, at: 9.30)
        model.setMix(0.4)
        model.toggleAccent(beat: 2)
        model.setCountIn(.off)
        #expect(model.tapRun.taps.count == 1)
    }

    @Test func stopKeepsTheRun() throws {
        let model = try playingModel()
        tap(model, at: 9.30)
        model.togglePlayback()
        #expect(model.tapRun.taps.count == 1)
    }

    @Test func severalTapsSaveOnce() async throws {
        let song = try #require(try bench.makeModel().loadedSong)
        let model = bench.relaunch(saveDelay: .milliseconds(20))
        model.togglePlayback()
        let writes = bench.libraryDefaults.writes
        tap(model, at: 10.11)
        tap(model, at: 12.01)
        tap(model, at: 13.95)
        #expect(bench.libraryDefaults.writes == writes)
        // Waits for the save however busy the main actor is. Only one save can be waiting at a
        // time, so once it has run no other can follow, and the count is final.
        let deadline = ContinuousClock.now + .seconds(10)
        while bench.libraryDefaults.writes == writes, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(bench.libraryDefaults.writes == writes + 1)
        let saved = bench.libraryStore.load().library.song(id: song.id)?.track
        #expect(saved?.bpm == 125)
        #expect(saved?.offset == 50)
    }
}
