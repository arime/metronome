import Foundation

/// The library plus what is loaded and shown: everything about presets that is kept between launches.
struct LibraryState: Codable, Equatable, Sendable {
    var library = Library()
    var loadedPresetID: UUID?
    /// The setlist the loaded preset was loaded from. Always one that contains it.
    var loadedFromSetlistID: UUID?
    /// What the library sheet shows; nil means all presets.
    var selectedSetlistID: UUID?

    /// Drops anything that points at a preset or setlist that is no longer there.
    func sanitized() -> LibraryState {
        var copy = self
        copy.library = library.sanitized()
        if let id = copy.loadedPresetID, copy.library.preset(id: id) == nil {
            copy.loadedPresetID = nil
        }
        if let id = copy.loadedFromSetlistID {
            let members = copy.library.setlist(id: id)?.presetIDs ?? []
            if copy.loadedPresetID.map(members.contains) != true {
                copy.loadedFromSetlistID = nil
            }
        }
        if let id = copy.selectedSetlistID, copy.library.setlist(id: id) == nil {
            copy.selectedSetlistID = nil
        }
        return copy
    }
}

/// The library as the app stored it before records carried change times.
private struct StoredLegacyState: Decodable {
    struct Contents: Decodable {
        var presets: [Preset]
        var setlists: [Setlist]
    }

    var library: Contents
    var loadedPresetID: UUID?
    var loadedFromSetlistID: UUID?
    var selectedSetlistID: UUID?

    /// The same library as records, every part at SyncClock.legacy.
    var converted: LibraryState {
        LibraryState(
            library: Library(legacyPresets: library.presets, legacySetlists: library.setlists),
            loadedPresetID: loadedPresetID,
            loadedFromSetlistID: loadedFromSetlistID,
            selectedSetlistID: selectedSetlistID
        )
    }
}

/// Remembers the library between launches, on this device only.
struct LibraryStore: @unchecked Sendable {
    private static let key = "metronome.library.v2"
    /// Where the library was kept before sync. Read when there is no v2 value, and never changed.
    private static let legacyKey = "metronome.library.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Returns an empty library when nothing usable is stored. The result is always sanitized.
    /// A library saved by an earlier version is converted when there is no current one.
    func load() -> LibraryState {
        if let data = defaults.data(forKey: Self.key) {
            guard let stored = try? JSONDecoder().decode(LibraryState.self, from: data) else { return LibraryState() }
            return stored.sanitized()
        }
        guard let data = defaults.data(forKey: Self.legacyKey),
              let old = try? JSONDecoder().decode(StoredLegacyState.self, from: data)
        else { return LibraryState() }
        return old.converted.sanitized()
    }

    func save(_ state: LibraryState) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(state) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
