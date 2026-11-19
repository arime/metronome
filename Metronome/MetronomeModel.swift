import Foundation
import Observation

/// One beat as the views see it. `id` goes up by one per beat, so views can animate on change.
struct BeatEvent: Equatable {
    let id: Int
    let beat: Int
    let isAccented: Bool
}

/// A file chosen in the song sheet and already checked: readable, with its first sound found.
struct PickedTrack: Equatable, Sendable {
    /// A temporary copy made by the song sheet; the model copies it into the store and leaves it.
    let url: URL
    let fileName: String
    /// Hundredths of a second.
    let offset: Int
}

/// What saving the song sheet does to the song's backing track.
enum TrackEdit: Equatable, Sendable {
    case keep, remove, attach(PickedTrack)
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
    /// Applies to the whole app and is remembered; songs do not store it.
    private(set) var clickSound: ClickSound
    /// When false the app plays no haptics at all. Applies to the whole app and is remembered.
    private(set) var hapticsEnabled: Bool
    /// When true the screen stays on while the app is open, even when stopped. Remembered on this device.
    private(set) var keepScreenAwake: Bool
    /// Whether the screen should be kept from dimming and locking right now.
    var screenStaysAwake: Bool { isPlaying || keepScreenAwake }

    private(set) var library: Library
    private(set) var loadedSongID: UUID?
    /// The setlist the loaded song was loaded from; always one that contains it.
    private(set) var loadedFromSetlistID: UUID?
    /// What the library sheet shows; nil means all songs.
    private(set) var selectedSetlistID: UUID?

    /// True while sync with iCloud is switched on.
    private(set) var syncEnabled = false
    /// nil while sync is off.
    private(set) var syncStatus: SyncStatus?

    @ObservationIgnored private let engine: ClickEngine
    @ObservationIgnored private let store: SettingsStore
    @ObservationIgnored private let libraryStore: LibraryStore
    @ObservationIgnored private let hapticsPlayer: HapticsPlaying
    @ObservationIgnored private let sync: LibrarySync?
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let trackFiles: TrackFileStore
    @ObservationIgnored private let lengthOfTrack: (URL) -> TimeInterval?
    /// The player while haptics are on, nil while they are off; every haptic goes through here.
    private var haptics: HapticsPlaying? { hapticsEnabled ? hapticsPlayer : nil }
    @ObservationIgnored private var taps = TapTempo()
    /// Sync mode's Tap tempo keeps a series of its own, apart from the plain screen's.
    @ObservationIgnored private var trackTaps = TapTempo()
    @ObservationIgnored private var beatCount = 0

    init(engine: ClickEngine, store: SettingsStore, haptics: HapticsPlaying, libraryStore: LibraryStore,
         sync: LibrarySync? = nil, now: @escaping () -> Date = Date.init,
         saveOfferDelay: Duration = .milliseconds(500),
         syncSettingSaveDelay: Duration = .milliseconds(300),
         trackFiles: TrackFileStore = TrackFileStore(),
         lengthOfTrack: @escaping (URL) -> TimeInterval? = { try? TrackAudio.length(of: $0) }) {
        self.saveOfferDelay = saveOfferDelay
        self.syncSettingSaveDelay = syncSettingSaveDelay
        self.trackFiles = trackFiles
        self.lengthOfTrack = lengthOfTrack
        self.sync = sync
        self.now = now
        self.engine = engine
        self.store = store
        self.libraryStore = libraryStore
        self.hapticsPlayer = haptics
        settings = store.load()
        hapticsEnabled = store.loadHapticsEnabled()
        keepScreenAwake = store.loadKeepScreenAwake()
        backingTracksOn = store.loadBackingTracksOn()
        let sound = store.loadClickSound()
        clickSound = sound
        engine.setSound(sound)
        let state = libraryStore.load()
        library = state.library
        loadedSongID = state.loadedSongID
        loadedFromSetlistID = state.loadedFromSetlistID
        selectedSetlistID = state.selectedSetlistID
        engine.onBeat = { [weak self] beat in self?.beatSounded(beat) }
        engine.onStopped = { [weak self] in self?.engineStopped() }
        engine.onTrackEnded = { [weak self] in self?.trackEnded() }
        refreshTrackFile()
        isSaveOffered = isEdited
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

    /// A backing track stops with the click and keeps its position.
    func stop() {
        guard isPlaying else { return }
        keepTrackPosition()
        engine.stop()
        becomeStopped()
    }

    /// Also saves a Sync mode change still waiting to be saved. Sync mode stays shown.
    func appDidLeaveForeground() {
        stop()
        savePendingChanges()
    }

    /// With a playable track, starts track and click together: with the count-in at 0:00,
    /// otherwise from the position at once. A file that cannot be opened plays the click alone
    /// for this run. Either way the click plays at the tempo in effect.
    private func start() {
        let settings = settingsInEffect
        if isTrackPlayable, let track = loadedTrack, let url = trackFiles.url(for: track.fileID) {
            let grid = TrackGrid(
                offset: track.offsetSeconds, bpm: settings.bpm, beatsPerBar: settings.timeSignature.beatsPerBar
            )
            let fromTheTop = trackPosition == 0
            let playback = TrackPlayback(
                fileURL: url,
                offset: track.offsetSeconds,
                startTime: fromTheTop ? grid.startTime(countIn: track.countIn) : trackPosition,
                firstClickIndex: fromTheTop ? grid.firstClickIndex(countIn: track.countIn) : 0,
                clickGain: TrackMix.clickGain(at: track.mix),
                trackGain: TrackMix.trackGain(at: track.mix)
            )
            do {
                try engine.start(with: settings, track: playback)
                isPlaying = true
                isPlayingTrack = true
                startedBeforeFile = playback.startTime < 0
                return
            } catch {
                // Falls through to the click alone.
            }
        }
        do {
            try engine.start(with: settings)
            isPlaying = true
        } catch {
            becomeStopped()
        }
    }

    private func becomeStopped() {
        isPlaying = false
        isPlayingTrack = false
        startedBeforeFile = false
        currentBeat = nil
    }

    /// An interruption, a route change or an engine failure: the track keeps its position, as with Stop.
    private func engineStopped() {
        keepTrackPosition()
        becomeStopped()
    }

    /// The file played to its end: stopped, and back to 0:00. A late call after Stop changes nothing.
    private func trackEnded() {
        guard isPlayingTrack else { return }
        trackPosition = 0
        becomeStopped()
    }

    /// Stopped during the count-in, before the file started, the position stays at 0:00. A position
    /// within the first second shows as 0:00, so it becomes 0:00 and the next Start counts in.
    private func keepTrackPosition() {
        guard isPlayingTrack else { return }
        trackPosition = roundedToStart(clampedToTrack(engine.trackTime ?? trackPosition))
    }

    /// Below one second, 0:00: whatever the elapsed time shows as 0:00 starts with the count-in.
    private func roundedToStart(_ time: TimeInterval) -> TimeInterval {
        time < 1 ? 0 : time
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

    // MARK: - Backing track

    /// The Backing tracks switch. Off, every song is a plain metronome. Applies to the whole app,
    /// is remembered on this device and changes only when tapped.
    private(set) var backingTracksOn: Bool

    /// Turns backing tracks on or off, with a tick; only while stopped and never in Sync mode.
    /// The track's position is kept, so off and on again finds the track where it was.
    func toggleBackingTracks() {
        guard !isPlaying, !isSyncModeShown else { return }
        backingTracksOn.toggle()
        store.saveBackingTracksOn(backingTracksOn)
        refreshTrackFile()
        // The swap of the tempo in effect can make the song edited or not.
        syncSaveOffer()
        haptics?.selection()
    }

    /// The loaded song's track, whether its file is here or not, and whatever the switch says.
    var loadedTrack: BackingTrack? { loadedSong?.track }

    /// Backing tracks is on and the loaded song has a track, whether its file is here or not.
    var isTrackInUse: Bool { backingTracksOn && loadedTrack != nil }

    /// The tempo the click plays at: the track's while a track is in use, the metronome's otherwise.
    var tempoInEffect: Int {
        tempoInEffect(with: loadedTrack)
    }

    /// The tempo in effect were `track` the loaded song's track.
    private func tempoInEffect(with track: BackingTrack?) -> Int {
        if backingTracksOn, let track { track.bpm } else { settings.bpm }
    }

    /// The settings with the tempo in effect; what the engine and the track's grid get.
    private var settingsInEffect: MetronomeSettings {
        var settings = settings
        settings.setBPM(tempoInEffect)
        return settings
    }

    /// The track is in use and its file is on this device. Kept rather than read from the file
    /// store, as views read it many times a second; `refreshTrackFile()` updates it.
    private(set) var isTrackPlayable = false

    /// The track is in use but its file is not on this device.
    var isTrackMissing: Bool {
        isTrackInUse && !isTrackPlayable
    }

    /// The file's length in seconds; read with `isTrackPlayable`, so nil while the switch is off.
    private(set) var trackLength: TimeInterval?
    /// Where the track is while stopped. Not saved: 0:00 at launch and whenever a song is loaded.
    private(set) var trackPosition: TimeInterval = 0
    /// True while playing and this run was started with the file.
    private(set) var isPlayingTrack = false

    /// The place in the file being heard; the position while not playing the file.
    /// 0:00 during the count-in, before the file starts.
    var trackTime: TimeInterval {
        guard isPlayingTrack, let time = engine.trackTime else { return trackPosition }
        return clampedToTrack(time)
    }

    /// 0...trackLength, where every position is kept.
    private func clampedToTrack(_ time: TimeInterval) -> TimeInterval {
        min(max(time, 0), trackLength ?? .infinity)
    }

    /// This run started with the count-in's click before the file's start. A jump while playing
    /// carries on without a count-in, so it ends this.
    private var startedBeforeFile = false

    /// True while the count-in's click sounds alone, before the file has started. Only a run
    /// started before the file's start counts in: after any start or jump at 0:00 the place heard
    /// is behind the file's start by the output delay, with no count-in.
    var isCountingIn: Bool {
        isPlayingTrack && startedBeforeFile && (engine.trackTime ?? 0) < 0
    }

    /// Fast-forward does nothing within the last 15 seconds.
    var canSkipForward: Bool {
        guard isTrackPlayable, let trackLength else { return false }
        return trackTime < trackLength - Self.skipInterval
    }

    private static let skipInterval: TimeInterval = 15

    /// Rewind (-15) or Fast-forward (+15). Rewind within the first 15 seconds goes to 0:00.
    func skipTrack(by seconds: TimeInterval) {
        guard isTrackPlayable, seconds < 0 || canSkipForward else { return }
        moveTrack(to: trackTime + seconds)
    }

    /// From the progress bar, when the finger lifts. A drag to within the first second lands on 0:00.
    func seekTrack(to time: TimeInterval) {
        guard isTrackPlayable else { return }
        moveTrack(to: roundedToStart(time))
    }

    /// Stopped, moves the position; playing the file, carries on from there with no count-in.
    private func moveTrack(to time: TimeInterval) {
        let clamped = clampedToTrack(time)
        if isPlayingTrack {
            engine.seekTrack(to: clamped)
            startedBeforeFile = false
        } else {
            trackPosition = clamped
        }
    }

    /// Reads whether the loaded song's file is here, and its length. Called whenever either can
    /// change: at launch, when another song becomes the loaded one, when the loaded song's track
    /// changes, when its file is stored and when the switch is turned. With the switch off the file
    /// is not opened. Sync mode ends, as with Done, once there is no playable file to sync.
    private func refreshTrackFile() {
        let url = backingTracksOn ? loadedTrack.flatMap { trackFiles.url(for: $0.fileID) } : nil
        isTrackPlayable = url != nil
        trackLength = url.flatMap(lengthOfTrack)
        if !isTrackPlayable { leaveSyncMode() }
    }

    /// Another song is loaded, or the loaded song's track is another file: back to 0:00. When the
    /// track that came or went changes the tempo in effect, a click that plays on without the file
    /// takes it, for example on Unload from a song whose file is missing.
    private func loadedTrackReplaced(replacing old: BackingTrack?) {
        trackPosition = 0
        refreshTrackFile()
        if isPlaying, tempoInEffect != tempoInEffect(with: old) {
            engine.update(settingsInEffect, startNewBar: false)
        }
    }

    /// Whether the track would play if it were the loaded one: false while the switch is off.
    private func isPlayable(_ track: BackingTrack?) -> Bool {
        backingTracksOn && hasFile(track)
    }

    private func hasFile(_ track: BackingTrack?) -> Bool {
        track.map { trackFiles.hasFile($0.fileID) } ?? false
    }

    /// Whether a song's backing-track file is on this device, whatever the switch says; false for a
    /// song without a track. The song sheet asks it for the song being edited, which need not be
    /// the loaded one.
    func hasTrackFile(for song: Song) -> Bool {
        hasFile(song.track)
    }

    /// Copies a picked file into the store; false when it cannot be copied. The picked file stays.
    private func store(_ picked: PickedTrack, as fileID: UUID) -> Bool {
        do {
            try trackFiles.store(picked.url, as: fileID)
            return true
        } catch {
            return false
        }
    }

    /// A file picked for a missing track, stored under the identifier the track already has (5.1,
    /// 10.3). Returns the track as it then is: with the picked file's name when the names differ,
    /// unchanged when they are the same, its tempo, offset, count-in and mix kept either way. nil
    /// when the file cannot be stored.
    private func storePicked(_ picked: PickedTrack, forMissing missing: BackingTrack) -> BackingTrack? {
        guard store(picked, as: missing.fileID) else { return nil }
        var track = missing
        track.fileName = picked.fileName
        return track
    }

    /// A picked file stored under a new identifier, with its offset. The tempo, the count-in and
    /// the mix are kept from the track it replaces; a track that replaces none gets `bpm`, the
    /// song's tempo as the sheet saves it. nil when the file cannot be stored.
    private func newTrack(_ picked: PickedTrack, bpm: Int, replacing old: BackingTrack?) -> BackingTrack? {
        let fileID = UUID()
        guard store(picked, as: fileID) else { return nil }
        return BackingTrack(
            fileID: fileID, fileName: picked.fileName, offset: picked.offset, bpm: old?.bpm ?? bpm,
            countIn: old?.countIn ?? .twoBars, mix: old?.mix ?? 0
        )
    }

    // MARK: - Sync mode
    // The track's tempo, offset, count-in and mix, and in Sync mode the time signature and the
    // accents, go into the song at once and never make it edited. The engine and the library in
    // memory take them at once; saving the library and sending it to iCloud wait for a pause
    // (`persistSoon`), as a held button or a dragged knob changes them many times a second.

    /// Whether the track screen shows Sync mode (6.13). Not saved, so off at launch.
    private(set) var isSyncModeShown = false

    /// Sync on the track screen; only with the file here. Playback carries on as it is.
    func enterSyncMode() {
        guard isTrackPlayable else { return }
        isSyncModeShown = true
    }

    /// Done, or the file going away while shown. Playback carries on as it is; a change still
    /// waiting to be saved is saved and sent at once.
    func leaveSyncMode() {
        guard isSyncModeShown else { return }
        isSyncModeShown = false
        savePendingChanges()
    }

    /// To the beginning: stopped, the position goes to 0:00, so the next Start counts in; playing
    /// the file, it carries on from 0:00 without a count-in; during the count-in, nothing.
    func goToTrackStart() {
        guard isTrackPlayable, !isCountingIn else { return }
        moveTrack(to: 0)
    }

    /// To the end: what the end of the file does. Playing, it stops; either way the position goes
    /// to 0:00, so the next Start counts in. The loaded song stays.
    func goToTrackEnd() {
        guard isTrackPlayable else { return }
        if isPlaying {
            engine.stop()
            becomeStopped()
        }
        trackPosition = 0
    }

    /// The Sync tempo stepper: the track's tempo by `delta` BPM, within 30...300. The metronome's
    /// tempo is not touched, so this never makes the song edited. Only while a track is in use.
    func nudgeTrackTempo(by delta: Int) {
        guard let bpm = loadedTrack?.bpm else { return }
        setTrackTempo(bpm + delta)
    }

    /// `Set tempo` in the tempo sheet opened from Sync mode: the track's tempo, within 30...300,
    /// with a tick when it changes. Only while a track is in use; never the metronome's tempo.
    func setTrackTempo(_ bpm: Int) {
        guard applyTrackTempo(bpm) else { return }
        haptics?.selection()
    }

    /// Sync mode's Tap tempo: the rules of the plain tap tempo, on the track's tempo, with a series
    /// of its own. A tick for every tap while a track is in use.
    func tapTrackTempo(at time: TimeInterval) {
        guard isTrackInUse else { return }
        haptics?.selection()
        guard let bpm = trackTaps.tap(at: time) else { return }
        applyTrackTempo(bpm)
    }

    /// Sets the track's tempo, saved into the song and sent to a playing engine. Returns true when
    /// it changed.
    @discardableResult
    private func applyTrackTempo(_ bpm: Int) -> Bool {
        guard isTrackInUse, var track = loadedTrack else { return false }
        let bpm = Tempo.clamp(bpm)
        guard bpm != track.bpm else { return false }
        track.bpm = bpm
        saveLoadedTrack(track)
        if isPlaying { engine.update(settingsInEffect, startNewBar: false) }
        return true
    }

    /// Each step is 0.01 s; the offset stays between 0:00 and the file's end.
    func nudgeOffset(by steps: Int) {
        guard let track = loadedTrack else { return }
        let last = trackLength.map { Int(($0 * 100).rounded(.down)) } ?? .max
        let offset = min(max(track.offset + steps, 0), last)
        guard offset != track.offset else { return }
        setOffset(offset)
        haptics?.selection()
    }

    private func setOffset(_ offset: Int) {
        guard var track = loadedTrack else { return }
        track.offset = offset
        saveLoadedTrack(track)
        if isPlayingTrack { engine.setOffset(track.offsetSeconds) }
    }

    // MARK: - Tap on beat 1

    /// Only while the file itself is playing, not during the count-in's click alone. Read from
    /// the engine and not observed, so views read it again while playing.
    var canTapDownbeat: Bool {
        isPlayingTrack && !isCountingIn
    }

    /// Takes the place being heard as beat 1 and sets only the offset from it, folded back to the
    /// first bar at the track's tempo. Each tap sets it afresh; the tempo is never changed.
    func tapDownbeat() {
        guard canTapDownbeat, let track = loadedTrack, let heard = engine.trackTime, heard >= 0 else { return }
        haptics?.selection()
        let offset = TrackGrid.foldedOffset(
            heard, bpm: track.bpm, beatsPerBar: settings.timeSignature.beatsPerBar
        )
        guard offset != track.offset else { return }
        setOffset(offset)
    }

    func setCountIn(_ countIn: CountIn) {
        guard var track = loadedTrack, track.countIn != countIn else { return }
        track.countIn = countIn
        saveLoadedTrack(track)
        haptics?.selection()
    }

    /// -1...1; a tick when it arrives at the centre.
    func setMix(_ position: Double) {
        guard var track = loadedTrack else { return }
        let mix = min(max(position, -1), 1)
        guard mix != track.mix else { return }
        track.mix = mix
        saveLoadedTrack(track)
        sendMix(mix)
        if mix == 0 { haptics?.selection() }
    }

    private func sendMix(_ mix: Double) {
        engine.setMix(clickGain: TrackMix.clickGain(at: mix), trackGain: TrackMix.trackGain(at: mix))
    }

    private func saveLoadedTrack(_ track: BackingTrack) {
        guard let id = loadedSongID else { return }
        library.setTrack(id, to: track, now: now())
        persistSoon()
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

    /// Sets the metronome's tempo. Returns true when it changed.
    @discardableResult
    private func applyBPM(_ bpm: Int) -> Bool {
        let before = settings.bpm
        settings.setBPM(bpm)
        guard settings.bpm != before else { return false }
        settingsChanged(startNewBar: false)
        userChangedSettings()
        return true
    }

    // MARK: - Time signature and accents

    func toggleAccent(beat: Int) {
        let before = settings.accents
        settings.toggleAccent(beat: beat)
        guard settings.accents != before else { return }
        haptics?.selection()
        settingsChanged(startNewBar: false)
        meterChanged()
    }

    /// A different signature resets the accents and, while playing, starts a new bar.
    /// The same one does nothing.
    func selectTimeSignature(_ signature: TimeSignature) {
        guard settings.setTimeSignature(signature) else { return }
        settingsChanged(startNewBar: true)
        meterChanged()
    }

    /// In Sync mode the time signature and the accents go into the song at once, as they are, an
    /// earlier unsaved accent change included; the metronome's tempo is never written. Nothing
    /// then differs from the song, so the badge on the header's menu button goes away at once,
    /// as after Save changes.
    private func meterChanged() {
        guard isSyncModeShown, let id = loadedSongID else {
            userChangedSettings()
            return
        }
        library.updateSongMeter(id, settings: settings, now: now())
        persistSoon()
        syncSaveOffer()
    }

    /// With a track the bar is worked out again from the offset, so no change starts a new bar.
    /// The metronome's own settings are stored; the engine gets them with the tempo in effect.
    private func settingsChanged(startNewBar: Bool) {
        store.save(settings)
        if isPlaying { engine.update(settingsInEffect, startNewBar: startNewBar && !isPlayingTrack) }
    }

    /// Replaces all the settings at once, as loading a song does.
    private func apply(_ newSettings: MetronomeSettings, startNewBar: Bool = true) {
        guard newSettings != settings else { return }
        settings = newSettings
        settingsChanged(startNewBar: startNewBar)
    }

    // MARK: - The loaded song

    var loadedSong: Song? {
        loadedSongID.flatMap(library.song(id:))
    }

    /// The setlist the loaded song was loaded from; nil when there is none or it no longer exists.
    var loadedFromSetlist: Setlist? {
        loadedFromSetlistID.flatMap(library.setlist(id:))
    }

    /// True when a song is loaded and the current settings differ from it. While a track is in use
    /// only the time signature and the accents count, as the tempo on screen is the track's; an
    /// unsaved metronome tempo is kept and counts whenever no track is in use.
    var isEdited: Bool {
        guard let saved = loadedSong?.settings else { return false }
        if isTrackInUse {
            return saved.timeSignature != settings.timeSignature || saved.accents != settings.accents
        }
        return saved != settings
    }

    /// Whether the badge on the header's menu button is shown. It follows `isEdited`, except
    /// that it stays for a moment when the user's own changes bring the settings back to the
    /// saved ones: turning the dial past the saved tempo must not make the badge blink out
    /// and in again.
    private(set) var isSaveOffered = false
    @ObservationIgnored private var saveOfferHide: Task<Void, Never>?
    @ObservationIgnored private let saveOfferDelay: Duration

    /// After the user changed the tempo, time signature or accents.
    private func userChangedSettings() {
        saveOfferHide?.cancel()
        saveOfferHide = nil
        if isEdited {
            isSaveOffered = true
        } else if isSaveOffered {
            // Back on the saved values: take the badge away only if they stay there.
            saveOfferHide = Task { [weak self, saveOfferDelay] in
                try? await Task.sleep(for: saveOfferDelay)
                guard !Task.isCancelled, let self else { return }
                self.isSaveOffered = self.isEdited
            }
        }
    }

    /// After anything else that can change whether the song is edited: saving, reverting,
    /// loading, unloading, or a change arriving from another device. These take effect at once.
    private func syncSaveOffer() {
        saveOfferHide?.cancel()
        saveOfferHide = nil
        isSaveOffered = isEdited
    }

    /// The loaded song's place in the setlist it was loaded from.
    var position: (index: Int, count: Int)? {
        guard let songID = loadedSongID, let setlistID = loadedFromSetlistID,
              let ids = library.setlist(id: setlistID)?.songIDs,
              let index = ids.firstIndex(of: songID)
        else { return nil }
        return (index, ids.count)
    }

    /// Whether a list of songs marks this song as the loaded one. All the songs (`setlistID`
    /// nil) mark it wherever it is; a setlist only when the song was loaded from that setlist.
    func marksLoaded(_ songID: UUID, inSetlist setlistID: UUID?) -> Bool {
        songID == loadedSongID && (setlistID == nil || setlistID == loadedFromSetlistID)
    }

    var canGoPrevious: Bool {
        position.map { $0.index > 0 } ?? false
    }

    var canGoNext: Bool {
        position.map { $0.index < $0.count - 1 } ?? false
    }

    /// The song that Next would load; nil at the end of the setlist or without one.
    var nextSong: Song? {
        guard let position, position.index + 1 < position.count,
              let ids = loadedFromSetlistID.flatMap(library.setlist(id:))?.songIDs
        else { return nil }
        return library.song(id: ids[position.index + 1])
    }

    var headerTitle: String {
        loadedSong?.name ?? "Library"
    }

    /// The header's second line; nil when the song's name says it all. It is the same
    /// with and without unsaved changes, which the badge on the header's menu button shows.
    var headerSubtitle: String? {
        guard loadedSong != nil else { return "No song loaded" }
        guard let position else { return nil }
        let place = "\(position.index + 1) of \(position.count)"
        let source = loadedFromSetlistID.flatMap(library.setlist(id:))?.name ?? ""
        return "\(source) · \(place)"
    }

    /// What VoiceOver reads for the header title. Unsaved changes are shown by the badge on the
    /// header's menu button, which cannot be heard, so they are said here.
    var headerAccessibilityLabel: String {
        [headerTitle, isEdited ? "edited" : nil, headerSubtitle].compactMap { $0 }.joined(separator: ", ")
    }

    /// Applies the song to the metronome. Unsaved edits to the previous song are dropped.
    /// While playing it keeps playing, with a new bar, unless the song being left or the one
    /// being loaded has a playable track; then it stops. The track is at 0:00 either way.
    /// The song that is already loaded is not loaded again: the metronome, its unsaved edits
    /// and the track's position stay as they are, playing or stopped, and only the setlist it
    /// is loaded from follows the rule below.
    /// `start` also starts a stopped metronome.
    /// Loaded from all songs (`setlistID` nil), a song that is in the setlist being
    /// stepped through keeps that setlist, so Previous and Next do not vanish.
    func loadSong(_ id: UUID, from setlistID: UUID?, start shouldStart: Bool = false) {
        guard let song = library.song(id: id) else { return }
        let isAnotherSong = id != loadedSongID
        if isAnotherSong, isTrackPlayable || isPlayable(song.track) { stop() }
        let old = loadedTrack
        loadedSongID = id
        let source = setlistID ?? loadedFromSetlistID
        let members = source.flatMap(library.setlist(id:))?.songIDs ?? []
        loadedFromSetlistID = members.contains(id) ? source : nil
        if let loadedFromSetlistID { library.touchSetlist(loadedFromSetlistID, now: now()) }
        if isAnotherSong {
            loadedTrackReplaced(replacing: old)
            apply(song.settings)
        }
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
              let ids = library.setlist(id: setlistID)?.songIDs,
              ids.indices.contains(position.index + offset)
        else { return }
        loadSong(ids[position.index + offset], from: setlistID)
    }

    /// Writes the current settings into the loaded song. The badge on the header's menu button
    /// goes away at once, with a success haptic.
    func saveChanges() {
        guard let id = loadedSongID else { return }
        library.updateSong(id, settings: settings, now: now())
        persistLibrary()
        syncSaveOffer()
        haptics?.success()
    }

    /// Sets the metronome back to the loaded song. While playing, the bar carries on
    /// unless the time signature goes back too, as with any other change of tempo or accents.
    func discardChanges() {
        guard let song = loadedSong, isEdited else { return }
        apply(song.settings, startNewBar: song.settings.timeSignature != settings.timeSignature)
        syncSaveOffer()
        haptics?.selection()
    }

    /// What Revert goes back to, for example "120 BPM · 4/4"; nil when nothing is loaded.
    var revertDescription: String? {
        loadedSong.map { "\($0.settings.bpm) BPM · \($0.settings.timeSignature.rawValue)" }
    }

    /// Unloads the song. The metronome keeps its settings, playing or stopped, and the
    /// song itself is not changed; unsaved edits simply stay as plain settings.
    /// Playing with its track, it stops.
    func unloadSong() {
        guard loadedSongID != nil else { return }
        if isPlayingTrack { stop() }
        let old = loadedTrack
        loadedSongID = nil
        loadedFromSetlistID = nil
        loadedTrackReplaced(replacing: old)
        persistLibrary()
        haptics?.selection()
    }

    /// Creates a song and makes it the loaded one. It is in no setlist, unless
    /// `addingToLoadedSetlist` adds it at the end of the setlist the song was loaded from; then
    /// it is loaded from that setlist, so Previous and Next stay. When either song has a
    /// playable track, playback stops. nil when the name is empty or a picked file cannot be
    /// stored; then nothing changes (10.3).
    @discardableResult
    func saveAsNewSong(
        name: String, settings newSettings: MetronomeSettings, track picked: PickedTrack? = nil,
        addingToLoadedSetlist: Bool = false
    ) -> Song? {
        guard Library.cleanName(name) != nil else { return nil }
        let setlistID = addingToLoadedSetlist ? loadedFromSetlist?.id : nil
        var track: BackingTrack?
        if let picked {
            guard let stored = newTrack(picked, bpm: newSettings.sanitized().bpm, replacing: nil) else { return nil }
            track = stored
        }
        if isTrackPlayable || isPlayable(track) { stop() }
        let old = loadedTrack
        let moment = now()
        guard let song = library.addSong(name: name, settings: newSettings, track: track, now: moment) else { return nil }
        if let setlistID {
            library.add(song.id, toSetlist: setlistID, now: moment)
            library.touchSetlist(setlistID, now: moment)
        }
        loadedSongID = song.id
        loadedFromSetlistID = setlistID
        loadedTrackReplaced(replacing: old)
        apply(song.settings)
        persistLibrary()
        return song
    }

    // MARK: - The library

    /// Creates a song, optionally at the end of a setlist. It is not loaded, with one
    /// exception: when nothing is loaded and the song holds exactly what the metronome is
    /// set to, the user has just named the current settings, so it becomes the loaded song,
    /// loaded from the setlist it was added to. The metronome itself is not touched, except
    /// that a song loaded this way stops it when its own track is playable, which needs
    /// Backing tracks on. nil when the name is empty or a picked file cannot be stored; then
    /// nothing changes (10.3).
    @discardableResult
    func createSong(
        name: String, settings newSettings: MetronomeSettings, addingTo setlistID: UUID?, track picked: PickedTrack? = nil
    ) -> Song? {
        guard Library.cleanName(name) != nil else { return nil }
        let moment = now()
        let namesCurrentSettings = loadedSongID == nil && newSettings == settings
        var track: BackingTrack?
        if let picked {
            guard let stored = newTrack(picked, bpm: newSettings.sanitized().bpm, replacing: nil) else { return nil }
            track = stored
        }
        guard let song = library.addSong(name: name, settings: newSettings, track: track, now: moment) else { return nil }
        if let setlistID { library.add(song.id, toSetlist: setlistID, now: moment) }
        if namesCurrentSettings {
            if isPlayable(track) { stop() }
            loadedSongID = song.id
            let members = setlistID.flatMap(library.setlist(id:))?.songIDs ?? []
            loadedFromSetlistID = members.contains(song.id) ? setlistID : nil
            if let loadedFromSetlistID { library.touchSetlist(loadedFromSetlistID, now: moment) }
            loadedTrackReplaced(replacing: nil)
        }
        persistLibrary()
        return song
    }

    /// A tick for a key in the tempo sheet.
    func keypadTapped() {
        haptics?.selection()
    }

    func renameSong(_ id: UUID, to name: String) {
        library.renameSong(id, to: name, now: now())
        persistLibrary()
    }

    /// Writes a new name and settings into a song, from Edit in the library. Only what
    /// changed is written, so an untouched part does not win over another device's change.
    /// When it is the loaded song and its settings changed, the metronome takes them, as if
    /// the song were loaded again: unsaved changes are dropped, and while playing the bar
    /// carries on unless the time signature changed. A new name alone leaves the metronome,
    /// and any unsaved changes, as they are.
    ///
    /// The track: a file picked for a missing one is stored under its identifier; the part takes
    /// the picked file's name when it differs and is left alone when it is the same. Any other
    /// file gets a new identifier and a new part. On the loaded song, a file picked or a playable
    /// track removed stops playback and goes to 0:00; with the switch off nothing stops, and a
    /// file picked still goes to 0:00.
    ///
    /// Returns false only when a picked file cannot be stored; then nothing is saved at all, so the
    /// song sheet can stay open with what the user entered (10.3). True otherwise, also when there
    /// was nothing to save.
    @discardableResult
    func editSong(_ id: UUID, name: String, settings newSettings: MetronomeSettings, track edit: TrackEdit = .keep) -> Bool {
        guard let song = library.song(id: id), Library.cleanName(name) != nil else { return true }
        let moment = now()
        let isLoaded = loadedSongID == id
        var filePicked = false
        // nil leaves the part alone; .some(nil) removes the track.
        var newPart: BackingTrack??
        switch edit {
        case .keep:
            break
        case .remove:
            if song.track != nil { newPart = .some(nil) }
        case .attach(let picked):
            if let missing = song.track, !trackFiles.hasFile(missing.fileID) {
                guard let track = storePicked(picked, forMissing: missing) else { return false }
                if track != missing { newPart = .some(track) }
            } else {
                let bpm = newSettings.sanitized().bpm
                guard let track = newTrack(picked, bpm: bpm, replacing: song.track) else { return false }
                newPart = .some(track)
            }
            filePicked = true
        }
        let removesPlayable = newPart != nil && !filePicked && isTrackPlayable
        if isLoaded, (filePicked && backingTracksOn) || removesPlayable { stop() }
        if Library.cleanName(name) != song.name {
            library.renameSong(id, to: name, now: moment)
        }
        let settingsChanged = newSettings.sanitized() != song.settings
        if settingsChanged {
            library.updateSong(id, settings: newSettings, now: moment)
        }
        if let newPart {
            library.setTrack(id, to: newPart, now: moment)
        }
        if isLoaded, settingsChanged, let updated = library.song(id: id) {
            apply(updated.settings, startNewBar: updated.settings.timeSignature != settings.timeSignature)
        }
        if isLoaded, filePicked || newPart != nil { loadedTrackReplaced(replacing: song.track) }
        syncSaveOffer()
        persistLibrary()
        return true
    }

    /// `Choose file` on the player card (6.12): the file is stored at once for the loaded song's
    /// missing track, by the rule for a file picked for a missing track (see `editSong`), and the
    /// song's settings are not touched, so it does not become edited. With Backing tracks on,
    /// playback stops; either way the position goes to 0:00 (7.10).
    ///
    /// `fileID` is the identifier of the track the file was chosen for, so a pick still being read
    /// when another song is loaded is never stored on that song's track.
    ///
    /// Returns false only when the file cannot be stored; then nothing changes. True, doing
    /// nothing, when no song is loaded, it has no track, its track is not the one with `fileID`
    /// or its file is on this device.
    @discardableResult
    func chooseFileForLoadedTrack(_ picked: PickedTrack, for fileID: UUID) -> Bool {
        guard let songID = loadedSongID, let missing = loadedTrack, missing.fileID == fileID,
              !trackFiles.hasFile(missing.fileID)
        else {
            return true
        }
        guard let track = storePicked(picked, forMissing: missing) else { return false }
        if backingTracksOn, isPlaying { stop() }
        if track != missing { library.setTrack(songID, to: track, now: now()) }
        loadedTrackReplaced(replacing: missing)
        persistLibrary()
        return true
    }

    /// The metronome keeps its settings if the deleted song was the loaded one; playing with
    /// its track, it stops. The song's file is deleted with it.
    func deleteSong(_ id: UUID) {
        let isLoaded = loadedSongID == id
        if isLoaded, isPlayingTrack { stop() }
        let old = loadedTrack
        library.deleteSong(id, now: now())
        if isLoaded {
            loadedSongID = nil
            loadedFromSetlistID = nil
            loadedTrackReplaced(replacing: old)
        }
        persistLibrary()
    }

    // MARK: - Setlists

    /// Chooses what the library sheet shows; nil means all songs. Loads nothing.
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

    /// The songs stay in the library, and a song loaded from the setlist stays loaded.
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

    /// Adds the song at the end of the setlist, or takes it out. It always stays in the library.
    func setSong(_ songID: UUID, inSetlist setlistID: UUID, included: Bool) {
        if included {
            library.add(songID, toSetlist: setlistID, now: now())
        } else {
            library.remove(songID, fromSetlist: setlistID, now: now())
            if loadedSongID == songID, loadedFromSetlistID == setlistID {
                loadedFromSetlistID = nil
            }
        }
        persistLibrary()
    }

    /// What is needed to put a song back where it was in a setlist.
    struct SetlistRemoval: Equatable {
        let songID: UUID
        let songName: String
        let setlistID: UUID
        /// The setlist's order just before the removal.
        let order: [UUID]
        /// True when the song was the loaded one, loaded from this setlist.
        let wasLoadedFromIt: Bool
    }

    /// Takes the song out of the setlist and returns what `undo` needs to put it back;
    /// nil when it was not in the setlist.
    @discardableResult
    func removeSong(_ songID: UUID, fromSetlist setlistID: UUID) -> SetlistRemoval? {
        guard let setlist = library.setlist(id: setlistID), setlist.songIDs.contains(songID),
              let song = library.song(id: songID)
        else { return nil }
        let removal = SetlistRemoval(
            songID: songID, songName: song.name, setlistID: setlistID, order: setlist.songIDs,
            wasLoadedFromIt: loadedSongID == songID && loadedFromSetlistID == setlistID
        )
        setSong(songID, inSetlist: setlistID, included: false)
        return removal
    }

    /// Puts a removed song back in its place. If the setlist has changed since, the song
    /// goes back at the end. Does nothing when the song or the setlist is gone.
    func undo(_ removal: SetlistRemoval) {
        guard library.song(id: removal.songID) != nil, library.setlist(id: removal.setlistID) != nil else { return }
        let moment = now()
        library.add(removal.songID, toSetlist: removal.setlistID, now: moment)
        library.reorder(setlist: removal.setlistID, to: removal.order, now: moment)
        if removal.wasLoadedFromIt, loadedSongID == removal.songID, loadedFromSetlistID == nil {
            loadedFromSetlistID = removal.setlistID
        }
        persistLibrary()
    }

    /// Shows the setlist the loaded song came from, so the library opens where the user is.
    /// Without one, the list chosen last stays.
    func showLoadedSetlist() {
        guard let setlistID = loadedFromSetlistID, selectedSetlistID != setlistID else { return }
        selectedSetlistID = setlistID
        persistLibrary()
    }

    /// Deletes a setlist that is still Untitled and empty. Used when the user leaves a setlist
    /// they have just created without doing anything with it.
    func discardSetlistIfUntouched(_ id: UUID) {
        guard let setlist = library.setlist(id: id),
              setlist.name == Library.defaultSetlistName, setlist.songIDs.isEmpty
        else { return }
        deleteSetlist(id)
    }

    func reorderSetlist(_ id: UUID, to order: [UUID]) {
        library.reorder(setlist: id, to: order, now: now())
        persistLibrary()
    }

    /// Saves the library, and sends it to iCloud when sync is on. Track files no song refers to
    /// any more are deleted, so a picked file must be stored before a song refers to it.
    /// It saves the whole library in memory, so a save waiting in `persistSoon` is included and
    /// is no longer needed.
    private func persistLibrary() {
        pendingSave?.cancel()
        pendingSave = nil
        syncSaveOffer()
        libraryStore.save(currentLibraryState)
        trackFiles.removeAll(except: library.referencedFileIDs)
        if sync?.isOn == true { exchangeWithCloud() }
    }

    /// A save waiting for the changes to pause; nil when nothing waits.
    @ObservationIgnored private var pendingSave: Task<Void, Never>?
    @ObservationIgnored private let syncSettingSaveDelay: Duration

    /// `persistLibrary()` once `syncSettingSaveDelay` has passed without another call.
    /// The library in memory already holds the change.
    private func persistSoon() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self, syncSettingSaveDelay] in
            try? await Task.sleep(for: syncSettingSaveDelay)
            guard !Task.isCancelled, let self else { return }
            self.persistLibrary()
        }
    }

    /// Saves at once a change still waiting in `persistSoon`; nothing when none waits.
    /// For leaving Sync mode and the app leaving the foreground.
    func savePendingChanges() {
        guard pendingSave != nil else { return }
        persistLibrary()
    }

    private var currentLibraryState: LibraryState {
        LibraryState(
            library: library,
            loadedSongID: loadedSongID,
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
    /// metronome's settings: none are applied and no haptic plays. A loaded song that arrived
    /// changed shows as edited, because the settings no longer match it. Only the loaded song's
    /// track reaches the engine (`loadedTrackArrived`).
    /// It saves directly, so it cannot start itself again through `persistLibrary()`, and only
    /// when the exchange changed something, since this runs on every library change.
    private func exchangeWithCloud() {
        guard let sync, sync.isOn else { return }
        let before = currentLibraryState
        var state = before
        state.library = sync.exchange(library, now: now())
        state = state.sanitized()
        guard state != before else { return }
        let trackBefore = loadedTrack
        library = state.library
        loadedSongID = state.loadedSongID
        loadedFromSetlistID = state.loadedFromSetlistID
        selectedSetlistID = state.selectedSetlistID
        if loadedTrack != trackBefore { loadedTrackArrived(replacing: trackBefore) }
        libraryStore.save(state)
        trackFiles.removeAll(except: library.referencedFileIDs)
        syncSaveOffer()
    }

    /// The loaded song's track changed on another device, or the song went. The same file with a
    /// new tempo, offset or mix applies at once; a new tempo reaches the click also while the file
    /// is missing. A track removed or replaced stops playback only while playing with its file,
    /// and goes to 0:00; an attached one arrives missing and playback carries on.
    private func loadedTrackArrived(replacing old: BackingTrack?) {
        guard let old, let track = loadedTrack, track.fileID == old.fileID else {
            if isPlayingTrack { stop() }
            loadedTrackReplaced(replacing: old)
            return
        }
        if track.bpm != old.bpm, isPlaying, isTrackInUse { engine.update(settingsInEffect, startNewBar: false) }
        if track.offset != old.offset, isPlayingTrack { engine.setOffset(track.offsetSeconds) }
        if track.mix != old.mix { sendMix(track.mix) }
    }
}
