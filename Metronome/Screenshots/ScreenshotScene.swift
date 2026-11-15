#if DEBUG
import AVFoundation
import Foundation

/// A screen set up with sample songs for the App Store screenshots. Debug builds only.
///
/// `scripts/screenshots.sh` launches the app with `-screenshotScene <name>`. The scene's
/// library and settings live in their own defaults domain, so the simulator's real data is
/// never touched, and there is no iCloud. The App Store scenes have no sound or haptics; the
/// two track scenes play and vibrate for real, so the click and the track can be heard together.
enum ScreenshotScene: String, CaseIterable {
    /// The metronome playing a song loaded from a setlist, with an accented beat sounding.
    case playing
    /// The library sheet showing all songs.
    case library
    /// The library sheet showing a setlist in its order.
    case setlist
    /// The time signature picker over the metronome.
    case timeSignature
    /// The settings sheet.
    case settings
    /// The track screen: a song with a playable backing track, loaded from the setlist and
    /// stopped. Not an App Store screenshot; for checking the screen in the simulator. The
    /// click and the track play for real, so their sync can be heard.
    case trackScreen
    /// The track screen with the Sync sheet open over it.
    case trackSync

    /// The scenes with a backing track. They write their own audio file at launch.
    var hasTrack: Bool {
        self == .trackScreen || self == .trackSync
    }

    /// The scene the app was launched with, if any.
    static let current: ScreenshotScene? = UserDefaults.standard
        .string(forKey: "screenshotScene")
        .flatMap(ScreenshotScene.init(rawValue:))

    /// The beat shown sounding in the playing scene; accented in the loaded song.
    private static let soundingBeat = 5
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

        var sample = SampleLibrary(now: Self.date)
        let trackFiles = TrackFileStore(
            directory: FileManager.default.temporaryDirectory.appending(path: "ScreenshotTracks", directoryHint: .isDirectory)
        )
        if hasTrack {
            sample.attachTrack(DemoTrack.make(in: trackFiles), now: Self.date)
        }
        libraryStore.save(LibraryState(
            library: sample.library,
            loadedSongID: sample.loadedSongID,
            // The library opens on the setlist its loaded song came from, so the scene
            // that shows all songs has the song loaded on its own.
            loadedFromSetlistID: self == .library ? nil : sample.setlistID,
            selectedSetlistID: self == .setlist ? sample.setlistID : nil
        ))
        settingsStore.save(sample.loadedSettings)
        settingsStore.saveClickSound(.woodblock)

        if hasTrack {
            return MetronomeModel(
                engine: AudioClickEngine(),
                store: settingsStore,
                haptics: Haptics(),
                libraryStore: libraryStore,
                now: { Self.date },
                trackFiles: trackFiles
            )
        }
        let model = MetronomeModel(
            engine: ScreenshotEngine(soundingBeat: Self.soundingBeat),
            store: settingsStore,
            haptics: NoHaptics(),
            libraryStore: libraryStore,
            now: { Self.date }
        )
        if self == .playing { model.togglePlayback() }
        return model
    }
}

/// A 30-second file to test sync by ear: half a second of silence, then from 0.50 s a tick every
/// half second (120 BPM), higher on each bar's first beat in 4/4, over a quiet low tone.
private enum DemoTrack {
    static let fileName = "Click test 120.wav"
    private static let sampleRate = 44_100.0
    private static let seconds = 30.0
    private static let firstBeat = 0.5
    private static let beatInterval = 0.5

    /// Stores the file under a new identifier and returns its track, with the first beat at 0.50 s.
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
        return BackingTrack(fileID: fileID, fileName: fileName, firstBeat: Int(firstBeat * 100))
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
        let start = Int(firstBeat * sampleRate)
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
    /// Copper Sky, at 120 BPM in 4/4 like the demo track.
    private var trackSongID: UUID?

    /// Gives Copper Sky a backing track and loads it in place of the third song.
    mutating func attachTrack(_ track: BackingTrack, now: Date) {
        guard let trackSongID, let song = library.song(id: trackSongID) else { return }
        library.setTrack(trackSongID, to: track, now: now)
        loadedSongID = trackSongID
        loadedSettings = song.settings
    }

    init(now: Date) {
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
            if index == 1 { trackSongID = song.id }
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

/// Plays nothing. Starting reports one beat, so the screen shows it sounding and stays still.
@MainActor
private final class ScreenshotEngine: ClickEngine {
    var onBeat: ((ScheduledBeat) -> Void)?
    var onStopped: (() -> Void)?
    private let soundingBeat: Int

    init(soundingBeat: Int) {
        self.soundingBeat = soundingBeat
    }

    func start(with settings: MetronomeSettings) throws {
        let beat = ScheduledBeat(
            beat: soundingBeat, isAccented: settings.accents.contains(soundingBeat), sampleTime: 0
        )
        // After start returns, as from the audio engine: the model counts as playing by then.
        Task { @MainActor [weak self] in self?.onBeat?(beat) }
    }

    var onTrackEnded: (() -> Void)?
    var trackTime: TimeInterval? { nil }

    func start(with settings: MetronomeSettings, track: TrackPlayback) throws {
        try start(with: settings)
    }

    func update(_ settings: MetronomeSettings, startNewBar: Bool) {}
    func seekTrack(to time: TimeInterval) {}
    func setFirstBeat(_ firstBeat: TimeInterval) {}
    func setMix(clickGain: Float, trackGain: Float) {}
    func setMuted(_ muted: Bool) {}
    func setSound(_ sound: ClickSound) {}
    func preview(_ sound: ClickSound) {}
    func stop() {}
}

@MainActor
private struct NoHaptics: HapticsPlaying {
    func beat(accented: Bool) {}
    func selection() {}
    func transport() {}
    func success() {}
}
#endif
