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
}
