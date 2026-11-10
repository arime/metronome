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

/// Remembers the library between launches, on this device only.
struct LibraryStore: @unchecked Sendable {
    private static let key = "metronome.library.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Returns an empty library when nothing usable is stored. The result is always sanitized.
    func load() -> LibraryState {
        guard let data = defaults.data(forKey: Self.key),
              let stored = try? JSONDecoder().decode(LibraryState.self, from: data)
        else { return LibraryState() }
        return stored.sanitized()
    }

    func save(_ state: LibraryState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
