import Foundation
import Testing
@testable import Metronome

@MainActor
final class FakeClickEngine: ClickEngine {
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

    var lastUpdateStartedNewBar: Bool?

    func update(_ settings: MetronomeSettings, startNewBar: Bool) {
        lastUpdate = settings
        lastUpdateStartedNewBar = startNewBar
    }
    func setMuted(_ muted: Bool) { self.muted = muted }
    var sound: ClickSound?
    var previews: [ClickSound] = []
    func setSound(_ sound: ClickSound) { self.sound = sound }
    func preview(_ sound: ClickSound) { previews.append(sound) }
    func stop() { stopCount += 1 }
}

@MainActor
final class FakeHaptics: HapticsPlaying {
    var beats: [Bool] = []
    var selectionCount = 0
    var transportCount = 0
    var successCount = 0

    func beat(accented: Bool) { beats.append(accented) }
    func selection() { selectionCount += 1 }
    func transport() { transportCount += 1 }
    func success() { successCount += 1 }
}

private struct StartFailed: Error {}

@MainActor
struct MetronomeModelTests {
    private let engine = FakeClickEngine()
    private let haptics = FakeHaptics()
    private let store = SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)

    private func makeModel() -> MetronomeModel {
        MetronomeModel(
            engine: engine, store: store, haptics: haptics,
            libraryStore: LibraryStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        )
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

    @Test func changingTheSignatureWhilePlayingStartsANewBarAndResetsAccents() {
        let model = makeModel()
        model.toggleAccent(beat: 3)
        model.togglePlayback()
        model.selectTimeSignature(.threeFour)
        #expect(model.isPlaying)
        #expect(model.settings.timeSignature == .threeFour)
        #expect(model.settings.accents == [1])
        #expect(engine.stopCount == 0)
        #expect(engine.lastUpdate?.timeSignature == .threeFour)
        #expect(engine.lastUpdateStartedNewBar == true)
        #expect(store.load().timeSignature == .threeFour)
    }

    @Test func tempoAndAccentChangesKeepTheBarPosition() {
        let model = makeModel()
        model.togglePlayback()
        model.setBPM(140)
        #expect(engine.lastUpdateStartedNewBar == false)
        model.toggleAccent(beat: 2)
        #expect(engine.lastUpdateStartedNewBar == false)
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

    // MARK: - Click sound

    @Test func freshInstallStartsWithDigital() {
        let model = makeModel()
        #expect(model.clickSound == .digital)
        #expect(engine.sound == .digital)
    }

    @Test func choosingASoundWhenStoppedSelectsAndPreviewsIt() {
        let model = makeModel()
        model.selectClickSound(.woodblock)
        #expect(model.clickSound == .woodblock)
        #expect(engine.sound == .woodblock)
        #expect(engine.previews == [.woodblock])
        #expect(haptics.selectionCount == 1)
    }

    @Test func tappingTheSelectedSoundPreviewsItAgain() {
        let model = makeModel()
        model.selectClickSound(.glass)
        model.selectClickSound(.glass)
        #expect(engine.previews == [.glass, .glass])
    }

    @Test func choosingASoundWhilePlayingChangesItWithoutAPreview() {
        let model = makeModel()
        model.togglePlayback()
        model.selectClickSound(.tick)
        #expect(engine.sound == .tick)
        #expect(engine.previews.isEmpty)
        #expect(model.isPlaying)
        #expect(engine.stopCount == 0)
    }

    @Test func theChosenSoundSurvivesARelaunch() {
        makeModel().selectClickSound(.classic)
        let relaunched = makeModel()
        #expect(relaunched.clickSound == .classic)
        #expect(engine.sound == .classic)
    }

    @Test func presetsDoNotCarryTheSound() {
        let model = makeModel()
        model.selectClickSound(.mallet)
        let preset = model.createPreset(name: "Song", settings: model.settings, addingTo: nil)!
        model.selectClickSound(.digital)
        model.loadPreset(preset.id, from: nil)
        #expect(model.clickSound == .digital)
    }

    // MARK: - Haptics switch

    @Test func freshInstallHasHapticsOn() {
        #expect(makeModel().hapticsEnabled)
    }

    @Test func turningHapticsOffSilencesEveryHaptic() {
        let model = makeModel()
        model.setHapticsEnabled(false)
        #expect(haptics.selectionCount == 0)
        model.togglePlayback()
        engine.onBeat?(beat(1, accented: true))
        model.setBPM(140)
        model.toggleAccent(beat: 2)
        model.tapTempo(at: 0)
        model.toggleMute()
        model.selectClickSound(.glass)
        model.togglePlayback()
        #expect(haptics.beats.isEmpty)
        #expect(haptics.selectionCount == 0)
        #expect(haptics.transportCount == 0)
    }

    @Test func turningHapticsBackOnTicksOnceAndRestoresThem() {
        let model = makeModel()
        model.setHapticsEnabled(false)
        model.setHapticsEnabled(true)
        #expect(haptics.selectionCount == 1)
        model.togglePlayback()
        engine.onBeat?(beat(1))
        #expect(haptics.beats == [false])
        #expect(haptics.transportCount == 1)
    }

    @Test func hapticsSwitchKeepsPlaybackRunning() {
        let model = makeModel()
        model.togglePlayback()
        model.setHapticsEnabled(false)
        #expect(model.isPlaying)
        #expect(engine.stopCount == 0)
    }

    @Test func theHapticsSwitchSurvivesARelaunch() {
        makeModel().setHapticsEnabled(false)
        #expect(makeModel().hapticsEnabled == false)
    }

    // MARK: - Keep screen awake switch

    @Test func freshInstallHasKeepScreenAwakeOff() {
        let model = makeModel()
        #expect(model.keepScreenAwake == false)
        #expect(model.screenStaysAwake == false)
    }

    @Test func screenStaysAwakeOnlyWhilePlayingWhenTheSwitchIsOff() {
        let model = makeModel()
        model.togglePlayback()
        #expect(model.screenStaysAwake)
        model.togglePlayback()
        #expect(model.screenStaysAwake == false)
    }

    @Test func screenStaysAwakeWhenStoppedWithTheSwitchOn() {
        let model = makeModel()
        model.setKeepScreenAwake(true)
        #expect(model.screenStaysAwake)
        model.togglePlayback()
        model.togglePlayback()
        #expect(model.screenStaysAwake)
        model.setKeepScreenAwake(false)
        #expect(model.screenStaysAwake == false)
    }

    @Test func keepScreenAwakeSwitchPlaysNoHapticAndKeepsPlaybackRunning() {
        let model = makeModel()
        model.togglePlayback()
        let before = haptics.selectionCount
        model.setKeepScreenAwake(true)
        model.setKeepScreenAwake(false)
        #expect(haptics.selectionCount == before)
        #expect(model.isPlaying)
        #expect(engine.stopCount == 0)
        #expect(model.screenStaysAwake)
    }

    @Test func theKeepScreenAwakeSwitchSurvivesARelaunch() {
        makeModel().setKeepScreenAwake(true)
        #expect(makeModel().keepScreenAwake)
    }
}
