import Foundation
import Testing
@testable import Metronome

@MainActor
private final class FakeClickEngine: ClickEngine {
    var onBeat: ((ScheduledBeat) -> Void)?
    var onStopped: (() -> Void)?
    var startCount = 0
    var stopCount = 0
    var lastUpdate: MetronomeSettings?
    var startError: Error?

    func start(with settings: MetronomeSettings) throws {
        if let startError { throw startError }
        startCount += 1
    }

    var muted = false

    func update(_ settings: MetronomeSettings) { lastUpdate = settings }
    func setMuted(_ muted: Bool) { self.muted = muted }
    func stop() { stopCount += 1 }
}

@MainActor
private final class FakeHaptics: HapticsPlaying {
    var beats: [Bool] = []
    var selectionCount = 0
    var transportCount = 0

    func beat(accented: Bool) { beats.append(accented) }
    func selection() { selectionCount += 1 }
    func transport() { transportCount += 1 }
}

private struct StartFailed: Error {}

@MainActor
struct MetronomeModelTests {
    private let engine = FakeClickEngine()
    private let haptics = FakeHaptics()
    private let store = SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)

    private func makeModel() -> MetronomeModel {
        MetronomeModel(engine: engine, store: store, haptics: haptics)
    }

    private func beat(_ number: Int, accented: Bool = false) -> ScheduledBeat {
        ScheduledBeat(beat: number, isAccented: accented, sampleTime: 0)
    }

    @Test func startsStoppedWithStoredSettings() {
        var stored = MetronomeSettings()
        stored.setBPM(90)
        store.save(stored)
        let model = makeModel()
        #expect(model.isPlaying == false)
        #expect(model.currentBeat == nil)
        #expect(model.settings.bpm == 90)
        #expect(model.tempoName == "Andante")
    }

    @Test func togglePlaybackStarts() {
        let model = makeModel()
        model.togglePlayback()
        #expect(model.isPlaying)
        #expect(engine.startCount == 1)
        #expect(haptics.transportCount == 1)
    }

    @Test func secondToggleStops() {
        let model = makeModel()
        model.togglePlayback()
        engine.onBeat?(beat(1, accented: true))
        model.togglePlayback()
        #expect(model.isPlaying == false)
        #expect(model.currentBeat == nil)
        #expect(engine.startCount == 1)
        #expect(engine.stopCount == 1)
    }

    @Test func failedStartLeavesItStopped() {
        engine.startError = StartFailed()
        let model = makeModel()
        model.togglePlayback()
        #expect(model.isPlaying == false)
    }

    @Test func beatsUpdateTheScreenAndPlayHaptics() {
        let model = makeModel()
        model.togglePlayback()
        engine.onBeat?(beat(2))
        #expect(model.currentBeat == 2)
        #expect(model.lastBeat?.beat == 2)
        #expect(model.lastBeat?.isAccented == false)
        #expect(haptics.beats == [false])
        let firstID = model.lastBeat?.id ?? -1
        engine.onBeat?(beat(3, accented: true))
        #expect(model.lastBeat?.id == firstID + 1)
        #expect(haptics.beats == [false, true])
    }

    @Test func lateBeatAfterStopChangesNothing() {
        let model = makeModel()
        model.togglePlayback()
        model.stop()
        engine.onBeat?(beat(2))
        #expect(model.currentBeat == nil)
        #expect(haptics.beats.isEmpty)
    }

    @Test func engineStoppingByItselfReturnsToReady() {
        let model = makeModel()
        model.togglePlayback()
        engine.onBeat?(beat(1))
        engine.onStopped?()
        #expect(model.isPlaying == false)
        #expect(model.currentBeat == nil)
        #expect(engine.stopCount == 0)
    }

    @Test func tempoChangesWhilePlayingKeepPlaying() {
        let model = makeModel()
        model.togglePlayback()
        model.setBPM(140)
        #expect(model.settings.bpm == 140)
        #expect(engine.lastUpdate?.bpm == 140)
        #expect(model.isPlaying)
        #expect(store.load().bpm == 140)
    }

    @Test func selectionHapticOnlyWhenTheTempoChanges() {
        let model = makeModel()
        model.setBPM(140)
        model.setBPM(140)
        #expect(haptics.selectionCount == 1)
    }

    @Test func nudgeStaysInsideTheRange() {
        let model = makeModel()
        model.setBPM(30)
        model.nudgeBPM(by: -1)
        #expect(model.settings.bpm == 30)
        model.nudgeBPM(by: 1)
        #expect(model.settings.bpm == 31)
    }

    @Test func accentsCanBeToggledWhilePlaying() {
        let model = makeModel()
        model.togglePlayback()
        let before = haptics.selectionCount
        model.toggleAccent(beat: 3)
        #expect(model.settings.accents == [1, 3])
        #expect(model.isPlaying)
        #expect(engine.lastUpdate?.accents == [1, 3])
        #expect(haptics.selectionCount == before + 1)
        #expect(store.load().accents == [1, 3])
    }

    @Test func changingTheSignatureWhilePlayingStopsAndResetsAccents() {
        let model = makeModel()
        model.toggleAccent(beat: 3)
        model.togglePlayback()
        model.selectTimeSignature(.threeFour)
        #expect(model.isPlaying == false)
        #expect(model.settings.timeSignature == .threeFour)
        #expect(model.settings.accents == [1])
        #expect(engine.stopCount == 1)
        #expect(store.load().timeSignature == .threeFour)
    }

    @Test func reselectingTheSignatureWhilePlayingChangesNothing() {
        let model = makeModel()
        model.toggleAccent(beat: 3)
        model.togglePlayback()
        model.selectTimeSignature(.fourFour)
        #expect(model.isPlaying)
        #expect(model.settings.accents == [1, 3])
    }

    @Test func tapTempoSetsTheTempo() {
        let model = makeModel()
        model.tapTempo(at: 0)
        model.tapTempo(at: 0.5)
        #expect(model.settings.bpm == 120)
        model.tapTempo(at: 1.5)
        #expect(model.settings.bpm == 80)
        #expect(haptics.selectionCount == 3)
    }

    @Test func startsWithSoundOn() {
        let model = makeModel()
        #expect(model.isMuted == false)
        #expect(engine.muted == false)
    }

    @Test func muteSilencesTheEngineAndTogglesBack() {
        let model = makeModel()
        model.toggleMute()
        #expect(model.isMuted)
        #expect(engine.muted)
        #expect(haptics.selectionCount == 1)
        model.toggleMute()
        #expect(model.isMuted == false)
        #expect(engine.muted == false)
    }

    @Test func mutingWhilePlayingKeepsTheBeatGoing() {
        let model = makeModel()
        model.togglePlayback()
        model.toggleMute()
        #expect(model.isPlaying)
        #expect(engine.stopCount == 0)
        engine.onBeat?(beat(2, accented: true))
        #expect(model.currentBeat == 2)
        #expect(haptics.beats == [true])
    }

    @Test func muteSetBeforeStartStaysOnAcrossStartAndStop() {
        let model = makeModel()
        model.toggleMute()
        model.togglePlayback()
        #expect(model.isPlaying)
        #expect(engine.muted)
        model.togglePlayback()
        #expect(model.isMuted)
        #expect(engine.muted)
    }

    @Test func leavingTheForegroundStopsPlayback() {
        let model = makeModel()
        model.togglePlayback()
        model.appDidLeaveForeground()
        #expect(model.isPlaying == false)
        #expect(engine.stopCount == 1)
    }
}
