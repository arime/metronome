import Foundation

/// Remembers the settings between launches.
struct SettingsStore: @unchecked Sendable {
    private static let key = "metronome.settings.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Returns the defaults when nothing usable is stored. The result is always sanitized.
    func load() -> MetronomeSettings {
        guard let data = defaults.data(forKey: Self.key),
              let stored = try? JSONDecoder().decode(MetronomeSettings.self, from: data)
        else { return MetronomeSettings() }
        return stored.sanitized()
    }

    func save(_ settings: MetronomeSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.key)
    }

    /// Kept apart from the settings above because songs store those, not the sound.
    private static let clickSoundKey = "metronome.clickSound.v1"

    /// Digital when nothing, or an unknown sound, is stored.
    func loadClickSound() -> ClickSound {
        defaults.string(forKey: Self.clickSoundKey).flatMap(ClickSound.init(rawValue:)) ?? .default
    }

    func saveClickSound(_ sound: ClickSound) {
        defaults.set(sound.rawValue, forKey: Self.clickSoundKey)
    }

    /// Kept apart from the settings for the same reason as the sound.
    private static let hapticsEnabledKey = "metronome.hapticsEnabled.v1"

    /// On when nothing is stored.
    func loadHapticsEnabled() -> Bool {
        defaults.object(forKey: Self.hapticsEnabledKey) as? Bool ?? true
    }

    func saveHapticsEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.hapticsEnabledKey)
    }

    /// Kept apart from the settings for the same reason as the sound.
    private static let keepScreenAwakeKey = "metronome.keepScreenAwake.v1"

    /// Off when nothing is stored.
    func loadKeepScreenAwake() -> Bool {
        defaults.bool(forKey: Self.keepScreenAwakeKey)
    }

    func saveKeepScreenAwake(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.keepScreenAwakeKey)
    }

    /// Kept apart from the settings for the same reason as the sound.
    private static let backingTracksOnKey = "metronome.backingTracksOn.v1"

    /// On when nothing is stored.
    func loadBackingTracksOn() -> Bool {
        defaults.object(forKey: Self.backingTracksOnKey) as? Bool ?? true
    }

    func saveBackingTracksOn(_ on: Bool) {
        defaults.set(on, forKey: Self.backingTracksOnKey)
    }

    /// The loaded song's track's offset, count-in and mix as set on the metronome, kept like the
    /// settings above so that unsaved ones survive a relaunch.
    private static let trackSettingsKey = "metronome.trackSettings.v1"

    /// nil when nothing usable is stored.
    func loadTrackSettings() -> TrackSettings? {
        guard let data = defaults.data(forKey: Self.trackSettingsKey) else { return nil }
        return try? JSONDecoder().decode(TrackSettings.self, from: data)
    }

    /// nil removes them.
    func saveTrackSettings(_ settings: TrackSettings?) {
        guard let settings, let data = try? JSONEncoder().encode(settings) else {
            defaults.removeObject(forKey: Self.trackSettingsKey)
            return
        }
        defaults.set(data, forKey: Self.trackSettingsKey)
    }
}
