#if DEBUG
import Foundation

/// A screen set up with sample presets for the App Store screenshots. Debug builds only.
///
/// `scripts/screenshots.sh` launches the app with `-screenshotScene <name>`. The scene's
/// library and settings live in their own defaults domain, so the simulator's real data is
/// never touched, and there is no sound, haptics or iCloud.
enum ScreenshotScene: String, CaseIterable {
    /// The metronome playing a preset loaded from a setlist, with an accented beat sounding.
    case playing
    /// The library sheet showing all presets.
    case library
    /// The library sheet showing a setlist in its order.
    case setlist
    /// The time signature picker over the metronome.
    case timeSignature
    /// The settings sheet.
    case settings

    /// The scene the app was launched with, if any.
    static let current: ScreenshotScene? = UserDefaults.standard
        .string(forKey: "screenshotScene")
        .flatMap(ScreenshotScene.init(rawValue:))

    /// The beat shown sounding in the playing scene; accented in the loaded preset.
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

        let sample = SampleLibrary(now: Self.date)
        libraryStore.save(LibraryState(
            library: sample.library,
            loadedPresetID: sample.loadedPresetID,
            loadedFromSetlistID: sample.setlistID,
            selectedSetlistID: self == .setlist ? sample.setlistID : nil
        ))
        settingsStore.save(sample.loadedSettings)
        settingsStore.saveClickSound(.woodblock)

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

/// A gig setlist and a few practice presets, with the third song of the setlist loaded.
private struct SampleLibrary {
    private(set) var library = Library()
    private(set) var setlistID = UUID()
    private(set) var loadedPresetID: UUID?
    private(set) var loadedSettings = MetronomeSettings()

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
            guard let preset = add(entry, now: now) else { continue }
            library.add(preset.id, toSetlist: setlistID, now: now)
            if index == 2 {
                loadedPresetID = preset.id
                loadedSettings = preset.settings
            }
        }
        for entry in practice { add(entry, now: now) }
    }

    @discardableResult
    private mutating func add(_ entry: (String, Int, TimeSignature, Set<Int>), now: Date) -> Preset? {
        let settings = MetronomeSettings(bpm: entry.1, timeSignature: entry.2, accents: entry.3)
        return library.addPreset(name: entry.0, settings: settings, now: now)
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

    func update(_ settings: MetronomeSettings, startNewBar: Bool) {}
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
}
#endif
