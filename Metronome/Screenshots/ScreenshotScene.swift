#if DEBUG
import AVFoundation
import Foundation

/// A screen set up with sample songs for the App Store screenshots. Debug builds only.
///
/// `scripts/screenshots.sh` launches the app with `-screenshotScene <name>`. The scene's
/// library and settings live in their own defaults domain, so the simulator's real data is
/// never touched, and there is no iCloud. The App Store scenes have no sound or haptics; the
/// track scenes play and vibrate for real, so the click and the track can be heard together.
enum ScreenshotScene: String, CaseIterable {
    /// The metronome playing a song loaded from a setlist, with an accented beat sounding.
    case playing
    /// The library sheet showing all songs.
    case library
    /// The library sheet showing a setlist in its order.
    case setlist
    /// The library sheet of `setlist` with `li` typed in the setlist's search. Not an App
    /// Store screenshot; for checking the search in the simulator.
    case setlistSearch
    /// The library sheet of `setlist` in select mode, with Copper Sky, Waltz for June and Slow
    /// Burn ticked. Not an App Store screenshot; for checking a setlist's select mode in the
    /// simulator.
    case setlistSelect
    /// The library sheet with no songs and no setlists. Not an App Store screenshot; for
    /// checking the empty tabs in the simulator.
    case emptyLibrary
    /// The library sheet of `library` in select mode, with the first three songs ticked. Not
    /// an App Store screenshot; for checking select mode in the simulator.
    case librarySelect
    /// The time signature picker over the metronome.
    case timeSignature
    /// The settings sheet.
    case settings
    /// The metronome with a song loaded from the setlist, stopped, and its tempo 4 BPM up, so
    /// the badge and the full header menu show. Not an App Store screenshot; for checking the
    /// header in the simulator.
    case edited
    /// The song of `edited` loaded on its own, stopped, so the pill shows without Previous and
    /// Next. Not an App Store screenshot.
    case metronomeSolo
    /// Track content: a song with a playable backing track, loaded from the setlist and
    /// stopped. Not an App Store screenshot; for checking the screen in the simulator. The
    /// click and the track play for real, so their sync can be heard.
    case trackScreen
    /// Track content of `trackScreen`, playing from launch, so the dial's number marking the
    /// beat can be caught in a screenshot. It plays nothing: its beats come from a timer, so the
    /// screen pulses even where the simulator's audio does not run.
    case trackPlaying
    /// Track content in Sync mode.
    case trackSync
    /// Sync mode of `trackSync` with the widest values the steppers show: 288 BPM and an offset
    /// of 25.40 s.
    case trackSyncWide
    /// Sync mode of `trackSync` with 9/8 chosen, as from the row, for the two-row tiles.
    case trackSyncNine
    /// Sync mode of `trackSync`, stopped, with an engine that plays nothing: its beats come from a
    /// timer and its file time from the clock, count-in included, so Start, the tap pads and the
    /// transport can be tried where the simulator's audio does not run.
    case trackSyncTimer
    /// Track content for the same song loaded on its own, outside the setlist.
    case trackSolo
    /// Track content for a song whose backing track's file is not on this device.
    case trackMissing
    /// Track content with the track on the setlist's first song, loaded from the setlist.
    case trackFirst
    /// Track content with the track on the setlist's last song, loaded from the setlist.
    case trackLast
    /// Track content of `trackScreen` with the track at 168 BPM while the song stays at 120, so
    /// the two tempos differ. Not an App Store screenshot; for checking that the dial shows the
    /// track's tempo while the track is in use. The demo file still ticks at 120, so it plays out of sync.
    case trackOtherTempo
    /// Stage mode for the sample setlist, stopped, with the loaded song's tile marked. Not an App
    /// Store screenshot; for checking stage mode in the simulator.
    case stage
    /// Stage mode with the track song's tile playing from launch, on an engine that plays nothing,
    /// as `trackSyncTimer`'s, so the beat dots and the track's time run where the simulator's audio
    /// does not. Not an App Store screenshot.
    case stagePlaying

    /// The scenes with a backing track. They write their own audio file at launch, except
    /// the scene whose file is missing.
    var hasTrack: Bool {
        switch self {
        case .trackScreen, .trackPlaying, .trackSync, .trackSyncWide, .trackSyncNine, .trackSyncTimer, .trackSolo,
             .trackMissing, .trackFirst, .trackLast, .trackOtherTempo, .stagePlaying: true
        default: false
        }
    }

    /// Where in the setlist the song with the track is.
    private var trackIndex: Int {
        switch self {
        case .trackFirst: 0
        case .trackLast: 7
        default: 1
        }
    }

    /// The scene the app was launched with, if any.
    static let current: ScreenshotScene? = UserDefaults.standard
        .string(forKey: "screenshotScene")
        .flatMap(ScreenshotScene.init(rawValue:))

    /// The beat shown sounding in the playing scene; accented in the loaded song.
    private static let soundingBeat = 5
    /// How long the playing scene's song has been playing: its readout starts at 2:14.
    private static let playingSeconds: TimeInterval = 134
    /// Every change time in the sample library; the date itself never shows.
    private static let date = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private static let suiteName = "metronome.screenshots"

    @MainActor
    func makeModel() -> MetronomeModel {
        guard let defaults = UserDefaults(suiteName: Self.suiteName) else {
            fatalError("The screenshot defaults domain could not be opened")
        }
        defaults.removePersistentDomain(forName: Self.suiteName)
        let settingsStore = SettingsStore(defaults: defaults)
        let libraryStore = LibraryStore(defaults: defaults)

        var sample = SampleLibrary(now: Self.date, trackIndex: trackIndex)
        let trackFiles = TrackFileStore(
            directory: FileManager.default.temporaryDirectory.appending(path: "ScreenshotTracks", directoryHint: .isDirectory)
        )
        if self == .trackMissing {
            trackFiles.removeAll(except: [])
            sample.attachTrack(
                BackingTrack(fileID: UUID(), fileName: DemoTrack.fileName, offset: 50, bpm: 120), now: Self.date
            )
        } else if hasTrack {
            var track = DemoTrack.make(in: trackFiles)
            if self == .trackSyncWide {
                track.offset = 2540
                track.bpm = 288
            }
            if self == .trackOtherTempo { track.bpm = 168 }
            sample.attachTrack(track, now: Self.date)
        }
        if self == .emptyLibrary {
            libraryStore.save(LibraryState())
        } else {
            libraryStore.save(LibraryState(
                library: sample.library,
                loadedSongID: sample.loadedSongID,
                // The library opens on the setlist its loaded song came from, so the scene
                // that shows all songs has the song loaded on its own.
                loadedFromSetlistID: self == .library || self == .librarySelect || self == .trackSolo
                    || self == .metronomeSolo ? nil : sample.setlistID,
                selectedSetlistID: self == .setlist || self == .setlistSearch || self == .setlistSelect
                    ? sample.setlistID : nil
            ))
        }
        settingsStore.save(sample.loadedSettings)
        settingsStore.saveClickSound(.woodblock)

        if self == .trackPlaying {
            let model = MetronomeModel(
                engine: ScreenshotEngine(soundingBeat: 1, repeats: true),
                store: settingsStore,
                haptics: NoHaptics(),
                libraryStore: libraryStore,
                now: { Self.date },
                trackFiles: trackFiles
            )
            model.togglePlayback()
            return model
        }
        if self == .trackSyncTimer || self == .stagePlaying {
            let model = MetronomeModel(
                engine: ScreenshotEngine(soundingBeat: 1, repeats: true, clocksTrack: true),
                store: settingsStore,
                haptics: NoHaptics(),
                libraryStore: libraryStore,
                now: { Self.date },
                trackFiles: trackFiles
            )
            if self == .trackSyncTimer {
                model.enterSyncMode()
            } else if let trackSongID = sample.loadedSongID {
                // The track song is the loaded one.
                model.enterStageMode(setlistID: sample.setlistID)
                model.tapStageTile(trackSongID)
            }
            return model
        }
        if hasTrack {
            let model = MetronomeModel(
                engine: AudioClickEngine(),
                store: settingsStore,
                haptics: Haptics(),
                libraryStore: libraryStore,
                now: { Self.date },
                trackFiles: trackFiles
            )
            if self == .trackSync || self == .trackSyncWide || self == .trackSyncNine { model.enterSyncMode() }
            if self == .trackSyncNine { model.selectTimeSignature(.nineEight) }
            return model
        }
        let model = MetronomeModel(
            engine: ScreenshotEngine(soundingBeat: Self.soundingBeat),
            store: settingsStore,
            haptics: NoHaptics(),
            libraryStore: libraryStore,
            now: { Self.date }
        )
        if self == .playing {
            model.togglePlayback()
            // The engine sounds a single beat, so the readout is seeded with a run already going;
            // its time runs on from 2:14.
            let settings = sample.loadedSettings
            let bar = 1 + Int(Self.playingSeconds * Double(settings.bpm) / 60) / settings.timeSignature.beatsPerBar
            model.showPlayCount(PlayCount(
                runningSince: ProcessInfo.processInfo.systemUptime - Self.playingSeconds, bar: bar
            ))
        }
        if self == .edited { model.nudgeBPM(by: 4) }
        if self == .stage { model.enterStageMode(setlistID: sample.setlistID) }
        return model
    }
}

/// A 30-second file to test sync by ear: half a second of silence, then from 0.50 s a tick every
/// half second (120 BPM), higher on each bar's first beat in 4/4, over a quiet low tone.
private enum DemoTrack {
    static let fileName = "Click test 120.wav"
    private static let sampleRate = 44_100.0
    private static let seconds = 30.0
    private static let offset = 0.5
    private static let beatInterval = 0.5

    /// Stores the file under a new identifier and returns its track, at 120 BPM with the offset at 0.50 s.
    static func make(in store: TrackFileStore) -> BackingTrack {
        let fileID = UUID()
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let source = folder.appending(path: fileName)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try write(to: source)
            store.removeAll(except: [])
            try store.store(source, as: fileID)
            try? FileManager.default.removeItem(at: folder)
        } catch {
            fatalError("The demo track could not be written: \(error)")
        }
        return BackingTrack(fileID: fileID, fileName: fileName, offset: Int(offset * 100), bpm: 120)
    }

    private static func write(to url: URL) throws {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            throw TrackAudioError.unreadable
        }
        let frames = AVAudioFrameCount(seconds * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let samples = buffer.floatChannelData?[0]
        else { throw TrackAudioError.unreadable }
        buffer.frameLength = frames
        let start = Int(offset * sampleRate)
        for frame in 0..<Int(frames) {
            guard frame >= start else {
                samples[frame] = 0
                continue
            }
            let time = Double(frame - start) / sampleRate
            let beat = Int(time / beatInterval)
            let sinceBeat = time - Double(beat) * beatInterval
            let pitch = beat % 4 == 0 ? 2_000.0 : 1_400.0
            let tick = 0.6 * sin(2 * .pi * pitch * sinceBeat) * exp(-sinceBeat / 0.012)
            let tone = 0.04 * sin(2 * .pi * 110 * time)
            samples[frame] = Float(tick + tone)
        }
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        try file.write(from: buffer)
    }
}

/// A gig setlist and a few practice songs, with the third song of the setlist loaded.
private struct SampleLibrary {
    private(set) var library = Library()
    private(set) var setlistID = UUID()
    private(set) var loadedSongID: UUID?
    private(set) var loadedSettings = MetronomeSettings()
    /// The song that gets the track: Copper Sky, at 120 BPM in 4/4 like the demo track, unless
    /// a scene needs the track at an end of the setlist.
    private var trackSongID: UUID?

    /// Gives the track song a backing track and loads it in place of the third song.
    mutating func attachTrack(_ track: BackingTrack, now: Date) {
        guard let trackSongID, let song = library.song(id: trackSongID) else { return }
        library.setTrack(trackSongID, to: track, now: now)
        loadedSongID = trackSongID
        loadedSettings = song.settings
    }

    /// `trackIndex` is the place in the setlist of the song that a track can be attached to.
    init(now: Date, trackIndex: Int = 1) {
        let setlist: [(String, Int, TimeSignature, Set<Int>)] = [
            ("Harbour Lights", 96, .fourFour, [1]),
            ("Copper Sky", 120, .fourFour, [1, 3]),
            ("Seven Bridges", 168, .sevenEight, [1, 3, 5]),
            ("Midnight Ferry", 72, .sixEight, [1, 4]),
            ("Waltz for June", 138, .threeFour, [1]),
            ("Slow Burn", 64, .twelveEight, [1, 4, 7, 10]),
            ("Northern Line", 152, .fiveFour, [1, 4]),
            ("Last Orders", 184, .twoFour, [1]),
        ]
        let practice: [(String, Int, TimeSignature, Set<Int>)] = [
            ("Paradiddle warm-up", 80, .fourFour, [1]),
            ("Scales in thirds", 100, .fourFour, [1]),
            ("Odd-time drill", 140, .nineEight, [1, 3, 5, 7]),
        ]
        setlistID = library.addSetlist(name: "Friday gig", now: now).id
        for (index, entry) in setlist.enumerated() {
            guard let song = add(entry, now: now) else { continue }
            library.add(song.id, toSetlist: setlistID, now: now)
            if index == trackIndex { trackSongID = song.id }
            if index == 2 {
                loadedSongID = song.id
                loadedSettings = song.settings
            }
        }
        for entry in practice { add(entry, now: now) }
    }

    @discardableResult
    private mutating func add(_ entry: (String, Int, TimeSignature, Set<Int>), now: Date) -> Song? {
        let settings = MetronomeSettings(bpm: entry.1, timeSignature: entry.2, accents: entry.3)
        return library.addSong(name: entry.0, settings: settings, now: now)
    }
}

/// Plays nothing. Starting reports one beat, so the screen shows it sounding and stays still;
/// one that repeats goes on reporting a beat at the tempo until stopped. One that clocks the track
/// reports a file time that runs with the clock from where the run starts, negative during the
/// count-in, and follows seeks and tempo changes.
@MainActor
private final class ScreenshotEngine: ClickEngine {
    var onBeat: ((ScheduledBeat) -> Void)?
    var onStopped: (() -> Void)?
    private let soundingBeat: Int
    private let repeats: Bool
    private let clocksTrack: Bool
    private var ticker: Task<Void, Never>?
    private var settings = MetronomeSettings()
    /// The file time at `clockStart`; nil unless playing with a track.
    private var trackStart: TimeInterval?
    private var clockStart = ContinuousClock.now

    init(soundingBeat: Int, repeats: Bool = false, clocksTrack: Bool = false) {
        self.soundingBeat = soundingBeat
        self.repeats = repeats
        self.clocksTrack = clocksTrack
    }

    func start(with settings: MetronomeSettings) throws {
        self.settings = settings
        let first = ScheduledBeat(
            beat: soundingBeat, isAccented: settings.accents.contains(soundingBeat), sampleTime: 0
        )
        guard repeats else {
            // After start returns, as from the audio engine: the model counts as playing by then.
            Task { @MainActor [weak self] in self?.onBeat?(first) }
            return
        }
        let firstBeat = soundingBeat
        ticker = Task { @MainActor [weak self] in
            var beat = firstBeat
            while !Task.isCancelled, let self {
                let current = self.settings
                let scheduled = ScheduledBeat(
                    beat: beat, isAccented: current.accents.contains(beat), sampleTime: 0
                )
                self.onBeat?(scheduled)
                beat = beat % current.timeSignature.beatsPerBar + 1
                try? await Task.sleep(for: .seconds(60 / Double(max(current.bpm, 1))))
            }
        }
    }

    var onTrackEnded: (() -> Void)?
    var trackTime: TimeInterval? {
        guard let trackStart else { return nil }
        let elapsed = ContinuousClock.now - clockStart
        return trackStart + Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
    }

    func start(with settings: MetronomeSettings, track: TrackPlayback) throws {
        if clocksTrack {
            trackStart = track.startTime
            clockStart = .now
        }
        try start(with: settings)
    }

    func update(_ settings: MetronomeSettings, startNewBar: Bool) {
        self.settings = settings
    }

    func seekTrack(to time: TimeInterval) {
        guard trackStart != nil else { return }
        trackStart = time
        clockStart = .now
    }
    func setOffset(_ offset: TimeInterval) {}
    func setMix(clickGain: Float, trackGain: Float) {}
    func setMuted(_ muted: Bool) {}
    func setSound(_ sound: ClickSound) {}
    func preview(_ sound: ClickSound) {}

    func stop() {
        ticker?.cancel()
        ticker = nil
        trackStart = nil
    }
}

@MainActor
private struct NoHaptics: HapticsPlaying {
    func beat(accented: Bool) {}
    func selection() {}
    func transport() {}
    func success() {}
}
#endif
