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

    /// nil when nothing is stored; the model then decides the starting value.
    func loadBackingTracksOn() -> Bool? {
        defaults.object(forKey: Self.backingTracksOnKey) as? Bool
    }

    func saveBackingTracksOn(_ on: Bool) {
        defaults.set(on, forKey: Self.backingTracksOnKey)
    }

    /// The loaded song's track's offset, count-in and mix as set on the metronome, kept like the
    /// settings above so that unsaved ones survive a relaunch, with the identifier of the track's
    /// file they belong to.
    private static let trackSettingsKey = "metronome.trackSettings.v1"

    private struct StoredTrackSettings: Codable {
        let fileID: UUID
        let settings: TrackSettings
    }

    /// nil when nothing usable is stored, or when what is stored belongs to another file. A value
    /// stored without a file identifier belongs to none.
    func loadTrackSettings(for fileID: UUID) -> TrackSettings? {
        guard let data = defaults.data(forKey: Self.trackSettingsKey),
              let stored = try? JSONDecoder().decode(StoredTrackSettings.self, from: data),
              stored.fileID == fileID
        else { return nil }
        return stored.settings
    }

    func saveTrackSettings(_ settings: TrackSettings, for fileID: UUID) {
        guard let data = try? JSONEncoder().encode(StoredTrackSettings(fileID: fileID, settings: settings)) else { return }
        defaults.set(data, forKey: Self.trackSettingsKey)
    }

    func removeTrackSettings() {
        defaults.removeObject(forKey: Self.trackSettingsKey)
    }
}
