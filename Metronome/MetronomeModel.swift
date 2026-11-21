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

/// What the player card shows: the elapsed time, bar count and transport, or the track (6.7, 6.12).
enum PlayerContent: Equatable {
    case metronome, track
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
    var screenStaysAwake: Bool { isPlaying || keepScreenAwake || stageMode != nil }

    private(set) var library: Library
    private(set) var loadedSongID: UUID?
    /// The setlist the loaded song was loaded from; always one that contains it.
    private(set) var loadedFromSetlistID: UUID?
    /// What the library sheet shows; nil means all songs.
    private(set) var selectedSetlistID: UUID?
    /// When each song last became the loaded song on this device. Not synced.
    private(set) var lastPlayed: [UUID: Date]
    /// The Songs tab's order, remembered on this device. Saved directly, not through
    /// `persistLibrary()`, as the library does not change and nothing goes to iCloud.
    var songOrder: SongOrder {
        didSet { if songOrder != oldValue { libraryStore.save(currentLibraryState) } }
    }
    /// The Setlists tab's order, remembered on this device.
    var setlistOrder: SetlistOrder {
        didSet { if setlistOrder != oldValue { libraryStore.save(currentLibraryState) } }
    }
    var orderedSongs: [Song] { library.songs(orderedBy: songOrder, lastPlayed: lastPlayed) }
    var orderedSetlists: [Setlist] { library.setlists(orderedBy: setlistOrder) }

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
    /// The system uptime; what the play count's times are measured in.
    @ObservationIgnored private let uptime: () -> TimeInterval
    /// The player while haptics are on, nil while they are off; every haptic goes through here.
    private var haptics: HapticsPlaying? { hapticsEnabled ? hapticsPlayer : nil }
    @ObservationIgnored private var taps = TapTempo()
    /// Sync mode's Tap tempo keeps a series of its own, apart from the tempo controls' pill.
    @ObservationIgnored private var trackTaps = TapTempo()
    @ObservationIgnored private var beatCount = 0

    init(engine: ClickEngine, store: SettingsStore, haptics: HapticsPlaying, libraryStore: LibraryStore,
         sync: LibrarySync? = nil, now: @escaping () -> Date = Date.init,
         saveOfferDelay: Duration = .milliseconds(500),
         trackFiles: TrackFileStore = TrackFileStore(),
         lengthOfTrack: @escaping (URL) -> TimeInterval? = { try? TrackAudio.length(of: $0) },
         uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.uptime = uptime
        self.saveOfferDelay = saveOfferDelay
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
        let sound = store.loadClickSound()
        clickSound = sound
        engine.setSound(sound)
        let state = libraryStore.load()
        library = state.library
        let stored = store.loadBackingTracksOn()
        let on = stored ?? state.library.songs.contains { $0.track != nil }
        backingTracksOn = on
        if stored == nil { store.saveBackingTracksOn(on) }
        loadedSongID = state.loadedSongID
        loadedFromSetlistID = state.loadedFromSetlistID
        selectedSetlistID = state.selectedSetlistID
        lastPlayed = state.lastPlayed
        songOrder = state.songOrder
        setlistOrder = state.setlistOrder
        // The stored copy only when it belongs to the loaded track's file. Stored at once, so a
        // change arriving from another device stays an unsaved difference after a relaunch.
        keepTrackSettings(loadedTrack.map { store.loadTrackSettings(for: $0.fileID) ?? $0.settings })
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

    /// Writes nothing; Sync mode stays shown.
    func appDidLeaveForeground() {
        stop()
    }

    /// With a playable track, starts track and click together: with the count-in at 0:00,
    /// otherwise from the position at once. A file that cannot be opened plays the click alone
    /// for this run. Either way the click plays at the song's tempo, and the offset, count-in and
    /// mix are the metronome's (`trackSettings`).
    private func start() {
        playCount.restart()
        if isTrackPlayable, let file = loadedTrack, let track = trackSettings, let url = trackFiles.url(for: file.fileID) {
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

    /// Every way playback ends passes through here.
    private func becomeStopped() {
        isPlaying = false
        isPlayingTrack = false
        startedBeforeFile = false
        currentBeat = nil
        playCount.stop(at: uptime())
        closeStageModeIfItsSetlistIsGone()
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
        playCount.count(beat, at: uptime())
        beatCount += 1
        currentBeat = beat.beat
        lastBeat = BeatEvent(id: beatCount, beat: beat.beat, isAccented: beat.isAccented)
        haptics?.beat(accented: beat.isAccented)
    }

    // MARK: - The player

    /// The time and the bars played since the last Start (7.13). Not saved.
    private(set) var playCount = PlayCount()

    /// What the player card's readout shows now. Its time runs with the clock, which is not
    /// observed, so views read it again while playing.
    func readout() -> PlayReadout {
        playCount.readout(at: uptime())
    }

    #if DEBUG
    /// Shows a count already running, for screenshot scenes.
    func showPlayCount(_ count: PlayCount) {
        playCount = count
    }
    #endif

    /// Whether the player card shows the metronome's readout and transport or the track's.
    var playerContent: PlayerContent {
        isTrackInUse ? .track : .metronome
    }

    /// The readout starts again whenever the loaded song becomes another song or none; while
    /// playing it counts afresh from the next beat. Every such change passes through here.
    private func loadedSongChanged() {
        playCount.restart()
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
    /// is remembered on this device and changes only when tapped. With nothing stored it starts
    /// on only when the library already holds a song with a track, and that value is stored at
    /// once, so a track attached or synced later does not change it.
    private(set) var backingTracksOn: Bool

    /// Turns backing tracks on or off, with a tick; only while stopped and never in Sync mode.
    /// It changes no setting. The track's position is kept, so off and on again finds the track
    /// where it was.
    func toggleBackingTracks() {
        guard !isPlaying, !isSyncModeShown else { return }
        backingTracksOn.toggle()
        store.saveBackingTracksOn(backingTracksOn)
        refreshTrackFile()
        haptics?.selection()
    }

    /// The loaded song's track, whether its file is here or not, and whatever the switch says.
    var loadedTrack: BackingTrack? { loadedSong?.track }

    /// Backing tracks is on and the loaded song has a track, whether its file is here or not.
    var isTrackInUse: Bool { backingTracksOn && loadedTrack != nil }

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

    /// Rewind (-15) or Fast-forward (+15). Rewind within the first 15 seconds goes to 0:00, and so
    /// does one that lands within the first second.
    func skipTrack(by seconds: TimeInterval) {
        guard isTrackPlayable, seconds < 0 || canSkipForward else { return }
        moveTrack(to: trackTime + seconds)
    }

    /// From the progress bar, when the finger lifts. A drag to within the first second lands on 0:00.
    func seekTrack(to time: TimeInterval) {
        guard isTrackPlayable else { return }
        moveTrack(to: time)
    }

    /// Every move lands inside the file, and within its first second on 0:00, so that whatever the
    /// elapsed time shows as 0:00 starts with the count-in. Stopped, moves the position; playing
    /// the file, carries on from there with no count-in.
    private func moveTrack(to time: TimeInterval) {
        let place = roundedToStart(clampedToTrack(time))
        if isPlayingTrack {
            engine.seekTrack(to: place)
            startedBeforeFile = false
        } else {
            trackPosition = place
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

    /// Another song is loaded, or the loaded song's track is another file: back to 0:00, and the
    /// metronome takes the track's saved offset, count-in and mix, or none without a track.
    private func loadedTrackReplaced() {
        trackPosition = 0
        keepTrackSettings(loadedTrack?.settings)
        refreshTrackFile()
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
    /// unchanged when they are the same, its offset, count-in and mix kept either way. nil when the
    /// file cannot be stored.
    private func storePicked(_ picked: PickedTrack, forMissing missing: BackingTrack) -> BackingTrack? {
        guard store(picked, as: missing.fileID) else { return nil }
        var track = missing
        track.fileName = picked.fileName
        return track
    }

    /// A picked file stored under a new identifier, with its offset. The count-in and the mix are
    /// kept from the track it replaces. nil when the file cannot be stored.
    private func newTrack(_ picked: PickedTrack, replacing old: BackingTrack?) -> BackingTrack? {
        let fileID = UUID()
        guard store(picked, as: fileID) else { return nil }
        return BackingTrack(
            fileID: fileID, fileName: picked.fileName, offset: picked.offset,
            countIn: old?.countIn ?? .twoBars, mix: old?.mix ?? 0
        )
    }

    // MARK: - Sync mode
    // Everything Sync mode sets, the tempo, the time signature, the accents and the track's offset,
    // count-in and mix, is an ordinary edit of the loaded song: it reaches the engine at once, makes
    // the song edited, and is written only by Save changes. Sync mode itself writes nothing.

    /// Whether the Sync mode sheet (6.13) is shown. Not saved, so off at launch.
    private(set) var isSyncModeShown = false

    /// The loaded song's track's offset, count-in and mix as set on the metronome, kept between
    /// launches on this device; nil without a loaded track. Like `settings`, a working copy:
    /// `isEdited` compares it with the song's track, Save changes writes it and Revert sets it back.
    private(set) var trackSettings: TrackSettings?

    /// The Sync pill of Track content; only with the file here. Playback carries on as it is.
    func enterSyncMode() {
        guard isTrackPlayable else { return }
        isSyncModeShown = true
    }

    /// Done, or the file going away while shown. Playback carries on as it is.
    func leaveSyncMode() {
        guard isSyncModeShown else { return }
        isSyncModeShown = false
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

    /// Sync mode's Tap tempo: the rules of the tempo controls' tap tempo, on the song's tempo, with
    /// a series of its own. A tick for every tap. Its − / + and typed tempo are the dial's
    /// `nudgeBPM(by:)` and `setBPM(_:)`.
    func syncTapTempo(at time: TimeInterval) {
        haptics?.selection()
        guard let bpm = trackTaps.tap(at: time) else { return }
        applyBPM(bpm)
    }

    /// Each step is 0.01 s; the offset stays between 0:00 and the file's end.
    func nudgeOffset(by steps: Int) {
        guard var track = trackSettings else { return }
        let last = trackLength.map { Int(($0 * 100).rounded(.down)) } ?? .max
        let offset = min(max(track.offset + steps, 0), last)
        guard offset != track.offset else { return }
        track.offset = offset
        changeTrackSettings(track)
        userChangedSettings()
        haptics?.selection()
    }

    // MARK: - Tap on beat 1

    /// Only while the file itself is playing, not during the count-in's click alone. Read from
    /// the engine and not observed, so views read it again while playing.
    var canTapDownbeat: Bool {
        isPlayingTrack && !isCountingIn
    }

    /// Takes the place being heard as beat 1 and sets only the offset from it, folded back to the
    /// first bar at the song's tempo. Each tap sets it afresh; the tempo is never changed.
    func tapDownbeat() {
        guard canTapDownbeat, var track = trackSettings, let heard = engine.trackTime, heard >= 0 else { return }
        haptics?.selection()
        let offset = TrackGrid.foldedOffset(
            heard, bpm: settings.bpm, beatsPerBar: settings.timeSignature.beatsPerBar
        )
        guard offset != track.offset else { return }
        track.offset = offset
        changeTrackSettings(track)
        userChangedSettings()
    }

    func setCountIn(_ countIn: CountIn) {
        guard var track = trackSettings, track.countIn != countIn else { return }
        track.countIn = countIn
        changeTrackSettings(track)
        userChangedSettings()
        haptics?.selection()
    }

    /// -1...1; a tick when it arrives at the centre.
    func setMix(_ position: Double) {
        guard var track = trackSettings else { return }
        let mix = min(max(position, -1), 1)
        guard mix != track.mix else { return }
        track.mix = mix
        changeTrackSettings(track)
        userChangedSettings()
        if mix == 0 { haptics?.selection() }
    }

    /// Takes the track settings, remembered on this device with the loaded track's file, without
    /// touching the engine: for a track that is another file, or none.
    private func keepTrackSettings(_ new: TrackSettings?) {
        trackSettings = new
        if let new, let fileID = loadedTrack?.fileID {
            store.saveTrackSettings(new, for: fileID)
        } else {
            store.removeTrackSettings()
        }
    }

    /// Takes the track settings and applies them at once: a new offset moves the grid while the
    /// file plays, a new mix reaches the engine; the count-in waits for the next Start at 0:00.
    private func changeTrackSettings(_ new: TrackSettings) {
        let old = trackSettings
        keepTrackSettings(new)
        if new.offset != old?.offset, isPlayingTrack { engine.setOffset(new.offsetSeconds) }
        if new.mix != old?.mix { sendMix(new.mix) }
    }

    private func sendMix(_ mix: Double) {
        engine.setMix(clickGain: TrackMix.clickGain(at: mix), trackGain: TrackMix.trackGain(at: mix))
    }

    // MARK: - Tempo
    // The dial, - / +, tap tempo and the tempo sheet, here and in Sync mode, set the song's one
    // tempo, with a track in use or not: an ordinary edit, saved only with Save changes.

    func setBPM(_ bpm: Int) {
        guard applyBPM(bpm) else { return }
        haptics?.selection()
    }

    func nudgeBPM(by delta: Int) {
        setBPM(settings.bpm + delta)
    }

    /// The tempo controls' series; Sync mode keeps its own.
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
        userChangedSettings()
    }

    /// A different signature resets the accents and, while playing, starts a new bar.
    /// The same one does nothing.
    func selectTimeSignature(_ signature: TimeSignature) {
        guard settings.setTimeSignature(signature) else { return }
        settingsChanged(startNewBar: true)
        userChangedSettings()
    }

    /// With a track the bar is worked out again from the offset, so no change starts a new bar.
    private func settingsChanged(startNewBar: Bool) {
        store.save(settings)
        if isPlaying { engine.update(settings, startNewBar: startNewBar && !isPlayingTrack) }
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

    /// True when a song is loaded and the current settings, or the track's offset, count-in and
    /// mix, differ from it, with a track in use or not.
    var isEdited: Bool {
        loadedSong.map { $0.settings != settings || $0.track?.settings != trackSettings } ?? false
    }

    /// Whether the badge on the header's menu button is shown. It follows `isEdited`, except
    /// that it stays for a moment when the user's own changes bring the settings back to the
    /// saved ones: turning the dial past the saved tempo must not make the badge blink out
    /// and in again.
    private(set) var isSaveOffered = false
    @ObservationIgnored private var saveOfferHide: Task<Void, Never>?
    @ObservationIgnored private let saveOfferDelay: Duration

    /// After the user changed the tempo, time signature, accents, or the track's offset, count-in
    /// or mix.
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

    /// Whether a list of songs marks this song as the loaded one: a setlist only when the song
    /// was loaded from that setlist, and all the songs (`setlistID` nil) only when it was loaded
    /// on its own. So a row is marked only where tapping it would change nothing.
    func marksLoaded(_ songID: UUID, inSetlist setlistID: UUID?) -> Bool {
        songID == loadedSongID && setlistID == loadedFromSetlistID
    }

    var canGoPrevious: Bool {
        position.map { $0.index > 0 } ?? false
    }

    var canGoNext: Bool {
        position.map { $0.index < $0.count - 1 } ?? false
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
    /// Where the song is tapped decides: loaded from a setlist that holds it, it is loaded
    /// from that setlist; loaded from all songs (`setlistID` nil), it is loaded on its own,
    /// whatever was being stepped through, and Previous and Next go.
    func loadSong(_ id: UUID, from setlistID: UUID?, start shouldStart: Bool = false) {
        guard load(id, from: setlistID) else { return }
        haptics?.selection()
        if shouldStart, !isPlaying { start() }
    }

    /// `loadSong` without its tick and without starting; false when there is no such song.
    private func load(_ id: UUID, from setlistID: UUID?) -> Bool {
        guard let song = library.song(id: id) else { return false }
        let isAnotherSong = id != loadedSongID
        if isAnotherSong, isTrackPlayable || isPlayable(song.track) { stop() }
        loadedSongID = id
        let members = setlistID.flatMap(library.setlist(id:))?.songIDs ?? []
        loadedFromSetlistID = members.contains(id) ? setlistID : nil
        if let loadedFromSetlistID { library.touchSetlist(loadedFromSetlistID, now: now()) }
        if isAnotherSong {
            loadedSongChanged()
            loadedTrackReplaced()
            apply(song.settings)
            markPlayed(id)
        }
        persistLibrary()
        return true
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

    /// Writes the current settings, and the track's offset, count-in and mix, into the loaded
    /// song. The badge on the header's menu button goes away at once, with a success haptic.
    func saveChanges() {
        guard let id = loadedSongID else { return }
        library.updateSong(id, settings: settings, trackSettings: trackSettings, now: now())
        persistLibrary()
        syncSaveOffer()
        haptics?.success()
    }

    /// Sets the metronome back to the loaded song, the track's offset, count-in and mix included.
    /// While playing, the bar carries on unless the time signature goes back too, as with any other
    /// change of tempo or accents; an offset or mix that goes back applies at once.
    func discardChanges() {
        guard let song = loadedSong, isEdited else { return }
        apply(song.settings, startNewBar: song.settings.timeSignature != settings.timeSignature)
        if let track = song.track { changeTrackSettings(track.settings) }
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
        loadedSongID = nil
        loadedFromSetlistID = nil
        loadedSongChanged()
        loadedTrackReplaced()
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
            guard let stored = newTrack(picked, replacing: nil) else { return nil }
            track = stored
        }
        if isTrackPlayable || isPlayable(track) { stop() }
        let moment = now()
        guard let song = library.addSong(name: name, settings: newSettings, track: track, now: moment) else { return nil }
        if let setlistID {
            library.add(song.id, toSetlist: setlistID, now: moment)
            library.touchSetlist(setlistID, now: moment)
        }
        loadedSongID = song.id
        loadedFromSetlistID = setlistID
        loadedSongChanged()
        loadedTrackReplaced()
        apply(song.settings)
        markPlayed(song.id)
        persistLibrary()
        return song
    }

    /// For a song that has just become the loaded one. Not for restoring or combining a state.
    private func markPlayed(_ id: UUID) {
        lastPlayed[id] = now()
    }

    // MARK: - Stage mode

    /// Whether stage mode is shown (9.4), and for which setlist. Not saved, so off at launch.
    private(set) var stageMode: StageMode?

    /// Only for a setlist with songs, and only while stopped.
    func canEnterStageMode(setlistID: UUID) -> Bool {
        guard let setlist = library.setlist(id: setlistID) else { return false }
        return StageMode.canEnter(songCount: setlist.songIDs.count, isPlaying: isPlaying)
    }

    /// Changes nothing on the metronome.
    func enterStageMode(setlistID: UUID) {
        guard canEnterStageMode(setlistID: setlistID) else { return }
        stageMode = StageMode(setlistID: setlistID)
    }

    /// The active tile's song: the loaded song, loaded from stage mode's setlist and still in it.
    private var stageActiveSongID: UUID? {
        guard let stageMode, let setlist = library.setlist(id: stageMode.setlistID) else { return nil }
        return StageMode.activeSongID(
            in: setlist, loadedSongID: loadedSongID, loadedFromSetlistID: loadedFromSetlistID)
    }

    /// The playing tile's song: the active song while it plays. nil when no tile plays.
    var stagePlayingSongID: UUID? {
        isPlaying ? stageActiveSongID : nil
    }

    var stageTiles: [StageTile] {
        guard let stageMode else { return [] }
        return StageMode.tiles(
            for: library.songs(inSetlist: stageMode.setlistID), activeSongID: stageActiveSongID,
            isPlaying: isPlaying, backingTracksOn: backingTracksOn)
    }

    var canLeaveStageMode: Bool {
        StageMode.canLeave(playingSongID: stagePlayingSongID)
    }

    /// Stopped, loads the tile's song from the setlist, as its row there does, and starts it from
    /// the top. The playing tile stops; the other tiles do nothing while one plays.
    func tapStageTile(_ songID: UUID) {
        guard let stageMode else { return }
        switch StageMode.tap(on: songID, playingSongID: stagePlayingSongID, isPlaying: isPlaying) {
        case .start(let id):
            guard load(id, from: stageMode.setlistID) else { return }
            haptics?.transport()
            trackPosition = 0
            start()
        case .stop:
            haptics?.transport()
            stop()
        case .nothing:
            break
        }
    }

    /// `Done`: not while a tile plays.
    func leaveStageMode() {
        guard canLeaveStageMode else { return }
        stageMode = nil
    }

    /// Its setlist deleted or emptied on another device: closes as `Done` does, at once while
    /// stopped, or else when playback stops.
    private func closeStageModeIfItsSetlistIsGone() {
        guard let stageMode, !isPlaying,
              library.setlist(id: stageMode.setlistID)?.songIDs.isEmpty ?? true
        else { return }
        self.stageMode = nil
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
            guard let stored = newTrack(picked, replacing: nil) else { return nil }
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
            loadedSongChanged()
            loadedTrackReplaced()
            markPlayed(song.id)
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

    /// The tempo, time signature and accents Edit song starts from: for the loaded song the
    /// metronome's current ones, unsaved changes included; for any other song its saved ones.
    func editSongSettings(for song: Song) -> MetronomeSettings {
        song.id == loadedSongID ? settings : song.settings
    }

    /// Writes a new name and settings into a song, from Edit song. Only what changed is
    /// written, so an untouched part does not win over another device's change.
    ///
    /// For the loaded song, saving is Save changes with the sheet's values: the track's current
    /// offset, count-in and mix are written with them, the metronome takes the saved song, and
    /// nothing is left unsaved. Values the metronome already has reach the engine as nothing:
    /// no new bar, no move of the track. A different tempo or accents keep the bar while playing;
    /// a different time signature starts a new one.
    ///
    /// The track: a file picked for a missing one is stored under its identifier; the part takes
    /// the picked file's name when it differs and is left alone when it is the same. Any other
    /// file gets a new identifier and a new part, keeping the count-in and mix, the metronome's
    /// current ones for the loaded song. On the loaded song, a file picked or a playable
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
        // The song's track as the metronome has it: for the loaded song, with its current offset,
        // count-in and mix.
        var currentTrack = song.track
        if isLoaded, let trackSettings { currentTrack?.settings = trackSettings }
        var filePicked = false
        // nil leaves the part alone; .some(nil) removes the track.
        var newPart: BackingTrack??
        switch edit {
        case .keep:
            break
        case .remove:
            if song.track != nil { newPart = .some(nil) }
        case .attach(let picked):
            if let missing = currentTrack, !trackFiles.hasFile(missing.fileID) {
                guard let track = storePicked(picked, forMissing: missing) else { return false }
                if track != song.track { newPart = .some(track) }
            } else {
                guard let track = newTrack(picked, replacing: currentTrack) else { return false }
                newPart = .some(track)
            }
            filePicked = true
        }
        let removesPlayable = newPart != nil && !filePicked && isTrackPlayable
        if isLoaded, (filePicked && backingTracksOn) || removesPlayable { stop() }
        if Library.cleanName(name) != song.name {
            library.renameSong(id, to: name, now: moment)
        }
        // A track that stays takes the metronome's offset, count-in and mix; each part is stamped
        // only when it changes.
        let keptTrackSettings = isLoaded && newPart == nil && !filePicked ? trackSettings : nil
        let settingsChanged = newSettings.sanitized() != song.settings
        let trackSettingsChanged = keptTrackSettings != nil && keptTrackSettings != song.track?.settings
        if settingsChanged || trackSettingsChanged {
            library.updateSong(
                id, settings: settingsChanged ? newSettings : song.settings, trackSettings: keptTrackSettings, now: moment
            )
        }
        if let newPart {
            library.setTrack(id, to: newPart, now: moment)
        }
        if isLoaded, let updated = library.song(id: id) {
            apply(updated.settings, startNewBar: updated.settings.timeSignature != settings.timeSignature)
        }
        if isLoaded, filePicked || newPart != nil { loadedTrackReplaced() }
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
        loadedTrackReplaced()
        persistLibrary()
        return true
    }

    /// The metronome keeps its settings if the deleted song was the loaded one; playing with
    /// its track, it stops. The song's file is deleted with it.
    func deleteSong(_ id: UUID) {
        deleteWithoutSaving(id)
        persistLibrary()
    }

    /// Deletes each song as `deleteSong` does, and saves once (8.7).
    func deleteSongs(_ ids: Set<UUID>) {
        ids.forEach(deleteWithoutSaving)
        persistLibrary()
    }

    /// `deleteSong` without the save.
    private func deleteWithoutSaving(_ id: UUID) {
        let isLoaded = loadedSongID == id
        if isLoaded, isPlayingTrack { stop() }
        library.deleteSong(id, now: now())
        lastPlayed[id] = nil
        if isLoaded {
            loadedSongID = nil
            loadedFromSetlistID = nil
            loadedSongChanged()
            loadedTrackReplaced()
        }
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

    /// Adds the songs not yet in the setlist to its end, in the given order, and saves once.
    /// It does not count as using the setlist (8.7, 9.1).
    func addSongs(_ ids: [UUID], toSetlist setlistID: UUID) {
        let moment = now()
        for id in ids { library.add(id, toSetlist: setlistID, now: moment) }
        persistLibrary()
    }

    /// What is needed to put songs back where they were in a setlist (8.5).
    struct SetlistRemoval: Equatable {
        /// The removed songs, in the setlist's order.
        let songIDs: [UUID]
        let firstSongName: String
        let setlistID: UUID
        /// The setlist's order just before the removal.
        let order: [UUID]
        /// The loaded song, when it was among them and loaded from this setlist.
        let loadedSongID: UUID?

        /// The Undo bar's text: `Removed <song name>` for one song, `Removed 3 songs` for several.
        var text: String {
            songIDs.count == 1 ? "Removed \(firstSongName)" : "Removed \(songIDs.count) songs"
        }
    }

    /// Takes the song out of the setlist and returns what `undo` needs to put it back;
    /// nil when it was not in the setlist.
    @discardableResult
    func removeSong(_ songID: UUID, fromSetlist setlistID: UUID) -> SetlistRemoval? {
        removeSongs([songID], fromSetlist: setlistID)
    }

    /// Takes those of the songs that are in the setlist out of it, saves once, and returns
    /// what `undo` needs to put them back; nil when none of them is in it. A removed loaded
    /// song loaded from this setlist stays loaded on its own.
    @discardableResult
    func removeSongs(_ songIDs: [UUID], fromSetlist setlistID: UUID) -> SetlistRemoval? {
        guard let setlist = library.setlist(id: setlistID) else { return nil }
        let asked = Set(songIDs)
        let removed = setlist.songIDs.filter(asked.contains)
        guard let first = removed.first, let firstSong = library.song(id: first) else { return nil }
        let loadedRemoved: UUID? =
            if let loaded = loadedSongID, removed.contains(loaded), loadedFromSetlistID == setlistID {
                loaded
            } else {
                nil
            }
        let removal = SetlistRemoval(
            songIDs: removed, firstSongName: firstSong.name, setlistID: setlistID,
            order: setlist.songIDs, loadedSongID: loadedRemoved
        )
        let moment = now()
        for id in removed { library.remove(id, fromSetlist: setlistID, now: moment) }
        if loadedRemoved != nil { loadedFromSetlistID = nil }
        persistLibrary()
        return removal
    }

    /// Puts removed songs back in their places. If the setlist has changed since, they go
    /// back at the end in the order they had. A song deleted from the library meanwhile does
    /// not come back; nothing happens when none is left or the setlist is gone.
    func undo(_ removal: SetlistRemoval) {
        let songIDs = removal.songIDs.filter { library.song(id: $0) != nil }
        guard !songIDs.isEmpty, library.setlist(id: removal.setlistID) != nil else { return }
        let moment = now()
        for id in songIDs { library.add(id, toSetlist: removal.setlistID, now: moment) }
        library.reorder(setlist: removal.setlistID, to: removal.order, now: moment)
        if let loaded = removal.loadedSongID, loadedSongID == loaded, loadedFromSetlistID == nil {
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
    private func persistLibrary() {
        syncSaveOffer()
        libraryStore.save(currentLibraryState)
        trackFiles.removeAll(except: library.referencedFileIDs)
        if sync?.isOn == true { exchangeWithCloud() }
    }

    private var currentLibraryState: LibraryState {
        LibraryState(
            library: library,
            loadedSongID: loadedSongID,
            loadedFromSetlistID: loadedFromSetlistID,
            selectedSetlistID: selectedSetlistID,
            lastPlayed: lastPlayed,
            songOrder: songOrder,
            setlistOrder: setlistOrder
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
    /// changed shows as edited, because the settings no longer match it. Only a loaded song's
    /// track that is another file, or none, reaches the metronome (`loadedTrackArrived`).
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
        // This device's own: the orders stay, and only times for songs that went are dropped.
        lastPlayed = state.lastPlayed
        if loadedSongID != before.loadedSongID { loadedSongChanged() }
        if loadedTrack != trackBefore { loadedTrackArrived(replacing: trackBefore) }
        libraryStore.save(state)
        trackFiles.removeAll(except: library.referencedFileIDs)
        syncSaveOffer()
        closeStageModeIfItsSetlistIsGone()
    }

    /// The loaded song's track changed on another device, or the song went. The same file with a
    /// new name, offset, count-in or mix changes nothing on the metronome: a new offset, count-in
    /// or mix makes the song edited, as `exchangeWithCloud` shows. A track removed or replaced
    /// stops playback only while playing with its file, and goes to 0:00; an attached one arrives
    /// missing and playback carries on. Either way the metronome takes the arrived track's offset,
    /// count-in and mix, or none.
    private func loadedTrackArrived(replacing old: BackingTrack?) {
        if let old, let track = loadedTrack, track.fileID == old.fileID { return }
        if isPlayingTrack { stop() }
        loadedTrackReplaced()
    }
}
