import Foundation
import Observation

/// One beat as the views see it. `id` goes up by one per beat, so views can animate on change.
struct BeatEvent: Equatable {
    let id: Int
    let beat: Int
    let isAccented: Bool
}

/// The state of the app, and the rules for changing it.
@MainActor
@Observable
final class MetronomeModel {
    private(set) var settings: MetronomeSettings
    private(set) var isPlaying = false
    /// The beat that is sounding; nil when stopped.
    private(set) var currentBeat: Int?
    private(set) var lastBeat: BeatEvent?
    /// True while the click is silenced. Not saved: the app always launches with sound on.
    private(set) var isMuted = false
    /// Applies to the whole app and is remembered; presets do not store it.
    private(set) var clickSound: ClickSound
    /// When false the app plays no haptics at all. Applies to the whole app and is remembered.
    private(set) var hapticsEnabled: Bool
    /// When true the screen stays on while the app is open, even when stopped. Remembered on this device.
    private(set) var keepScreenAwake: Bool
    /// Whether the screen should be kept from dimming and locking right now.
    var screenStaysAwake: Bool { isPlaying || keepScreenAwake }

    private(set) var library: Library
    private(set) var loadedPresetID: UUID?
    /// The setlist the loaded preset was loaded from; always one that contains it.
    private(set) var loadedFromSetlistID: UUID?
    /// What the library sheet shows; nil means all presets.
    private(set) var selectedSetlistID: UUID?

    /// True while sync with iCloud is switched on.
    private(set) var syncEnabled = false
    /// nil while sync is off.
    private(set) var syncStatus: SyncStatus?

    var tempoName: String { Tempo.name(for: settings.bpm) }

    @ObservationIgnored private let engine: ClickEngine
    @ObservationIgnored private let store: SettingsStore
    @ObservationIgnored private let libraryStore: LibraryStore
    @ObservationIgnored private let hapticsPlayer: HapticsPlaying
    @ObservationIgnored private let sync: LibrarySync?
    @ObservationIgnored private let now: () -> Date
    /// The player while haptics are on, nil while they are off; every haptic goes through here.
    private var haptics: HapticsPlaying? { hapticsEnabled ? hapticsPlayer : nil }
    @ObservationIgnored private var taps = TapTempo()
    @ObservationIgnored private var beatCount = 0

    init(engine: ClickEngine, store: SettingsStore, haptics: HapticsPlaying, libraryStore: LibraryStore,
         sync: LibrarySync? = nil, now: @escaping () -> Date = Date.init) {
        self.sync = sync
        self.now = now
        self.engine = engine
        self.store = store
        self.libraryStore = libraryStore
        self.hapticsPlayer = haptics
        settings = store.load()
        hapticsEnabled = store.loadHapticsEnabled()
        keepScreenAwake = store.loadKeepScreenAwake()
        let sound = store.loadClickSound()
        clickSound = sound
        engine.setSound(sound)
        let state = libraryStore.load()
        library = state.library
        loadedPresetID = state.loadedPresetID
        loadedFromSetlistID = state.loadedFromSetlistID
        selectedSetlistID = state.selectedSetlistID
        engine.onBeat = { [weak self] beat in self?.beatSounded(beat) }
        engine.onStopped = { [weak self] in self?.becomeStopped() }
        if let sync {
            syncEnabled = sync.isOn
            syncStatus = sync.status
            sync.onStatusChange = { [weak self] in self?.syncChanged() }
            sync.onCloudChange = { [weak self] in self?.exchangeWithCloud() }
        }
    }

    // MARK: - Playback

    func togglePlayback() {
        haptics?.transport()
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
        haptics?.beat(accented: beat.isAccented)
    }

    /// Silences the click or brings it back. The metronome keeps running either way,
    /// so the beat visuals and haptics carry on.
    func toggleMute() {
        isMuted.toggle()
        engine.setMuted(isMuted)
        haptics?.selection()
    }

    /// Selects the sound at once. When stopped it also plays a preview, even of the
    /// sound already selected; when playing, the metronome itself is the preview.
    func selectClickSound(_ sound: ClickSound) {
        haptics?.selection()
        if sound != clickSound {
            clickSound = sound
            store.saveClickSound(sound)
            engine.setSound(sound)
        }
        if !isPlaying { engine.preview(sound) }
    }

    /// Turning haptics on plays one tick, so the user feels they are back.
    func setHapticsEnabled(_ enabled: Bool) {
        guard enabled != hapticsEnabled else { return }
        hapticsEnabled = enabled
        store.saveHapticsEnabled(enabled)
        haptics?.selection()
    }

    /// Like the sync switch, it plays no haptic.
    func setKeepScreenAwake(_ enabled: Bool) {
        guard enabled != keepScreenAwake else { return }
        keepScreenAwake = enabled
        store.saveKeepScreenAwake(enabled)
    }

    // MARK: - Tempo

    func setBPM(_ bpm: Int) {
        guard applyBPM(bpm) else { return }
        haptics?.selection()
    }

    func nudgeBPM(by delta: Int) {
        setBPM(settings.bpm + delta)
    }

    func tapTempo(at time: TimeInterval) {
        haptics?.selection()
        guard let bpm = taps.tap(at: time) else { return }
        applyBPM(bpm)
    }

    /// Returns true when the tempo changed.
    @discardableResult
    private func applyBPM(_ bpm: Int) -> Bool {
        let before = settings.bpm
        settings.setBPM(bpm)
        guard settings.bpm != before else { return false }
        settingsChanged(startNewBar: false)
        return true
    }

    // MARK: - Time signature and accents

    func toggleAccent(beat: Int) {
        let before = settings.accents
        settings.toggleAccent(beat: beat)
        guard settings.accents != before else { return }
        haptics?.selection()
        settingsChanged(startNewBar: false)
    }

    /// A different signature resets the accents and, while playing, starts a new bar.
    /// The same one does nothing.
    func selectTimeSignature(_ signature: TimeSignature) {
        guard settings.setTimeSignature(signature) else { return }
        settingsChanged(startNewBar: true)
    }

    private func settingsChanged(startNewBar: Bool) {
        store.save(settings)
        if isPlaying { engine.update(settings, startNewBar: startNewBar) }
    }

    /// Replaces all the settings at once, as loading a preset does.
    private func apply(_ newSettings: MetronomeSettings, startNewBar: Bool = true) {
        guard newSettings != settings else { return }
        settings = newSettings
        settingsChanged(startNewBar: startNewBar)
    }

    // MARK: - The loaded preset

    var loadedPreset: Preset? {
        loadedPresetID.flatMap(library.preset(id:))
    }

    /// True when a preset is loaded and the current settings differ from it.
    var isEdited: Bool {
        loadedPreset.map { $0.settings != settings } ?? false
    }

    /// The loaded preset's place in the setlist it was loaded from.
    var position: (index: Int, count: Int)? {
        guard let presetID = loadedPresetID, let setlistID = loadedFromSetlistID,
              let ids = library.setlist(id: setlistID)?.presetIDs,
              let index = ids.firstIndex(of: presetID)
        else { return nil }
        return (index, ids.count)
    }

    var canGoPrevious: Bool {
        position.map { $0.index > 0 } ?? false
    }

    var canGoNext: Bool {
        position.map { $0.index < $0.count - 1 } ?? false
    }

    /// The preset that Next would load; nil at the end of the setlist or without one.
    var nextPreset: Preset? {
        guard let position, position.index + 1 < position.count,
              let ids = loadedFromSetlistID.flatMap(library.setlist(id:))?.presetIDs
        else { return nil }
        return library.preset(id: ids[position.index + 1])
    }

    var headerTitle: String {
        loadedPreset?.name ?? "Library"
    }

    /// The header's second line; nil when the preset's name says it all. It is the same
    /// with and without unsaved changes, which the Save button shows.
    var headerSubtitle: String? {
        guard loadedPreset != nil else { return "No preset loaded" }
        guard let position else { return nil }
        let place = "\(position.index + 1) of \(position.count)"
        let source = loadedFromSetlistID.flatMap(library.setlist(id:))?.name ?? ""
        return "\(source) · \(place)"
    }

    /// What VoiceOver reads for the header title. Unsaved changes are shown only by the Save
    /// button appearing, which cannot be heard, so they are said here.
    var headerAccessibilityLabel: String {
        [headerTitle, isEdited ? "edited" : nil, headerSubtitle].compactMap { $0 }.joined(separator: ", ")
    }

    /// Applies the preset to the metronome. Unsaved edits to the previous preset are dropped.
    /// While playing it keeps playing, with a new bar; `start` also starts a stopped metronome.
    func loadPreset(_ id: UUID, from setlistID: UUID?, start shouldStart: Bool = false) {
        guard let preset = library.preset(id: id) else { return }
        loadedPresetID = id
        let members = setlistID.flatMap(library.setlist(id:))?.presetIDs ?? []
        loadedFromSetlistID = members.contains(id) ? setlistID : nil
        if let loadedFromSetlistID { library.touchSetlist(loadedFromSetlistID, now: now()) }
        apply(preset.settings)
        persistLibrary()
        haptics?.selection()
        if shouldStart, !isPlaying { start() }
    }

    func goToPrevious() {
        step(by: -1)
    }

    func goToNext() {
        step(by: 1)
    }

    /// Does nothing at either end of the setlist: it does not wrap around.
    private func step(by offset: Int) {
        guard let position, let setlistID = loadedFromSetlistID,
              let ids = library.setlist(id: setlistID)?.presetIDs,
              ids.indices.contains(position.index + offset)
        else { return }
        loadPreset(ids[position.index + offset], from: setlistID)
    }

    /// Writes the current settings into the loaded preset.
    func saveChanges() {
        guard let id = loadedPresetID else { return }
        library.updatePreset(id, settings: settings, now: now())
        persistLibrary()
        haptics?.selection()
    }

    /// Sets the metronome back to the loaded preset. While playing, the bar carries on
    /// unless the time signature goes back too, as with any other change of tempo or accents.
    func discardChanges() {
        guard let preset = loadedPreset, isEdited else { return }
        apply(preset.settings, startNewBar: preset.settings.timeSignature != settings.timeSignature)
        haptics?.selection()
    }

    /// What Revert goes back to, for example "120 BPM · 4/4"; nil when nothing is loaded.
    var revertDescription: String? {
        loadedPreset.map { "\($0.settings.bpm) BPM · \($0.settings.timeSignature.rawValue)" }
    }

    /// Unloads the preset. The metronome keeps its settings, playing or stopped, and the
    /// preset itself is not changed; unsaved edits simply stay as plain settings.
    func clearPreset() {
        guard loadedPresetID != nil else { return }
        loadedPresetID = nil
        loadedFromSetlistID = nil
        persistLibrary()
        haptics?.selection()
    }

    /// Creates a preset and makes it the loaded one. It is in no setlist.
    @discardableResult
    func saveAsNewPreset(name: String, settings newSettings: MetronomeSettings) -> Preset? {
        guard let preset = library.addPreset(name: name, settings: newSettings, now: now()) else { return nil }
        loadedPresetID = preset.id
        loadedFromSetlistID = nil
        apply(preset.settings)
        persistLibrary()
        return preset
    }

    // MARK: - The library

    /// Creates a preset, optionally at the end of a setlist. It is not loaded, with one
    /// exception: when nothing is loaded and the preset holds exactly what the metronome is
    /// set to, the user has just named the current settings, so it becomes the loaded preset,
    /// loaded from the setlist it was added to. The metronome itself is not touched.
    @discardableResult
    func createPreset(name: String, settings newSettings: MetronomeSettings, addingTo setlistID: UUID?) -> Preset? {
        let moment = now()
        let namesCurrentSettings = loadedPresetID == nil && newSettings == settings
        guard let preset = library.addPreset(name: name, settings: newSettings, now: moment) else { return nil }
        if let setlistID { library.add(preset.id, toSetlist: setlistID, now: moment) }
        if namesCurrentSettings {
            loadedPresetID = preset.id
            let members = setlistID.flatMap(library.setlist(id:))?.presetIDs ?? []
            loadedFromSetlistID = members.contains(preset.id) ? setlistID : nil
            if let loadedFromSetlistID { library.touchSetlist(loadedFromSetlistID, now: moment) }
        }
        persistLibrary()
        return preset
    }

    /// A tick for a key in the tempo sheet.
    func keypadTapped() {
        haptics?.selection()
    }

    func renamePreset(_ id: UUID, to name: String) {
        library.renamePreset(id, to: name, now: now())
        persistLibrary()
    }

    /// The metronome keeps its settings if the deleted preset was the loaded one.
    func deletePreset(_ id: UUID) {
        library.deletePreset(id, now: now())
        if loadedPresetID == id {
            loadedPresetID = nil
            loadedFromSetlistID = nil
        }
        persistLibrary()
    }

    // MARK: - Setlists

    /// Chooses what the library sheet shows; nil means all presets. Loads nothing.
    func selectFilter(_ setlistID: UUID?) {
        selectedSetlistID = setlistID.flatMap(library.setlist(id:))?.id
        if let selectedSetlistID { library.touchSetlist(selectedSetlistID, now: now()) }
        persistLibrary()
    }

    /// Creates an empty setlist and selects it.
    @discardableResult
    func createSetlist() -> UUID {
        let setlist = library.addSetlist(name: Library.defaultSetlistName, now: now())
        selectedSetlistID = setlist.id
        persistLibrary()
        return setlist.id
    }

    func renameSetlist(_ id: UUID, to name: String) {
        library.renameSetlist(id, to: name, now: now())
        persistLibrary()
    }

    /// The presets stay in the library, and a preset loaded from the setlist stays loaded.
    func deleteSetlist(_ id: UUID) {
        library.deleteSetlist(id, now: now())
        if selectedSetlistID == id { selectedSetlistID = nil }
        if loadedFromSetlistID == id { loadedFromSetlistID = nil }
        persistLibrary()
    }

    /// Copies the setlist and selects the copy.
    @discardableResult
    func duplicateSetlist(_ id: UUID) -> UUID? {
        guard let copy = library.duplicateSetlist(id, now: now()) else { return nil }
        selectedSetlistID = copy.id
        persistLibrary()
        return copy.id
    }

    /// Adds the preset at the end of the setlist, or takes it out. It always stays in the library.
    func setPreset(_ presetID: UUID, inSetlist setlistID: UUID, included: Bool) {
        if included {
            library.add(presetID, toSetlist: setlistID, now: now())
        } else {
            library.remove(presetID, fromSetlist: setlistID, now: now())
            if loadedPresetID == presetID, loadedFromSetlistID == setlistID {
                loadedFromSetlistID = nil
            }
        }
        persistLibrary()
    }

    func reorderSetlist(_ id: UUID, to order: [UUID]) {
        library.reorder(setlist: id, to: order, now: now())
        persistLibrary()
    }

    /// Saves the library, and sends it to iCloud when sync is on.
    private func persistLibrary() {
        libraryStore.save(currentLibraryState)
        if sync?.isOn == true { exchangeWithCloud() }
    }

    private var currentLibraryState: LibraryState {
        LibraryState(
            library: library,
            loadedPresetID: loadedPresetID,
            loadedFromSetlistID: loadedFromSetlistID,
            selectedSetlistID: selectedSetlistID
        )
    }

    // MARK: - Sync

    /// Switching on exchanges the library at once; switching off leaves it as it is.
    func setSyncEnabled(_ enabled: Bool) {
        guard let sync else { return }
        if enabled {
            sync.turnOn(now: now())
            exchangeWithCloud()
        } else {
            sync.turnOff(now: now())
        }
    }

    /// Call when the app becomes active.
    func appDidBecomeActive() {
        guard let sync else { return }
        sync.appOpened(now: now())
        exchangeWithCloud()
    }

    private func syncChanged() {
        syncEnabled = sync?.isOn ?? false
        syncStatus = sync?.status
    }

    /// Combines the library with iCloud and keeps what the user has open. It never touches the
    /// metronome: no settings are applied, the engine hears nothing and no haptic plays. A loaded
    /// preset that arrived changed shows as edited, because the settings no longer match it.
    /// It saves directly, so it cannot start itself again through `persistLibrary()`, and only
    /// when the exchange changed something, since this runs on every library change.
    private func exchangeWithCloud() {
        guard let sync, sync.isOn else { return }
        let before = currentLibraryState
        var state = before
        state.library = sync.exchange(library, now: now())
        state = state.sanitized()
        guard state != before else { return }
        library = state.library
        loadedPresetID = state.loadedPresetID
        loadedFromSetlistID = state.loadedFromSetlistID
        selectedSetlistID = state.selectedSetlistID
        libraryStore.save(state)
    }
}
