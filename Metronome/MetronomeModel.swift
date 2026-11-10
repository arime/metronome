import Foundation
import Observation

/// One beat as the views see it. `id` goes up by one per beat, so views can animate on change.
struct BeatEvent: Equatable {
    let id: Int
    let beat: Int
    let isAccented: Bool
}

/// The state of the one screen, and the rules for changing it.
@MainActor
@Observable
final class MetronomeModel {
    private(set) var settings: MetronomeSettings
    private(set) var isPlaying = false
    /// The beat that is sounding; nil when stopped.
    private(set) var currentBeat: Int?
    private(set) var lastBeat: BeatEvent?

    var tempoName: String { Tempo.name(for: settings.bpm) }

    @ObservationIgnored private let engine: ClickEngine
    @ObservationIgnored private let store: SettingsStore
    @ObservationIgnored private let haptics: HapticsPlaying
    @ObservationIgnored private var taps = TapTempo()
    @ObservationIgnored private var beatCount = 0

    init(engine: ClickEngine, store: SettingsStore, haptics: HapticsPlaying) {
        self.engine = engine
        self.store = store
        self.haptics = haptics
        settings = store.load()
        engine.onBeat = { [weak self] beat in self?.beatSounded(beat) }
        engine.onStopped = { [weak self] in self?.becomeStopped() }
    }

    // MARK: - Playback

    func togglePlayback() {
        haptics.transport()
        if isPlaying {
            stop()
        } else {
            start()
        }
    }

    func stop() {
        guard isPlaying else { return }
        engine.stop()
        becomeStopped()
    }

    func appDidLeaveForeground() {
        stop()
    }

    private func start() {
        do {
            try engine.start(with: settings)
            isPlaying = true
        } catch {
            becomeStopped()
        }
    }

    private func becomeStopped() {
        isPlaying = false
        currentBeat = nil
    }

    private func beatSounded(_ beat: ScheduledBeat) {
        // A callback that was already on its way when playback stopped.
        guard isPlaying else { return }
        beatCount += 1
        currentBeat = beat.beat
        lastBeat = BeatEvent(id: beatCount, beat: beat.beat, isAccented: beat.isAccented)
        haptics.beat(accented: beat.isAccented)
    }

    // MARK: - Tempo

    func setBPM(_ bpm: Int) {
        guard applyBPM(bpm) else { return }
        haptics.selection()
    }

    func nudgeBPM(by delta: Int) {
        setBPM(settings.bpm + delta)
    }

    func tapTempo(at time: TimeInterval) {
        haptics.selection()
        guard let bpm = taps.tap(at: time) else { return }
        applyBPM(bpm)
    }

    /// Returns true when the tempo changed.
    @discardableResult
    private func applyBPM(_ bpm: Int) -> Bool {
        let before = settings.bpm
        settings.setBPM(bpm)
        guard settings.bpm != before else { return false }
        settingsChanged()
        return true
    }

    // MARK: - Time signature and accents

    func toggleAccent(beat: Int) {
        let before = settings.accents
        settings.toggleAccent(beat: beat)
        guard settings.accents != before else { return }
        haptics.selection()
        settingsChanged()
    }

    /// A different signature stops playback and resets accents; the same one does nothing.
    func selectTimeSignature(_ signature: TimeSignature) {
        guard settings.setTimeSignature(signature) else { return }
        stop()
        store.save(settings)
    }

    private func settingsChanged() {
        store.save(settings)
        if isPlaying { engine.update(settings) }
    }
}
