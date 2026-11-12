import Foundation

/// The library plus what is loaded and shown: everything about songs that is kept between launches.
struct LibraryState: Codable, Equatable, Sendable {
    var library = Library()
    var loadedSongID: UUID?
    /// The setlist the loaded song was loaded from. Always one that contains it.
    var loadedFromSetlistID: UUID?
    /// What the library sheet shows; nil means all songs.
    var selectedSetlistID: UUID?

    /// Drops anything that points at a song or setlist that is no longer there.
    func sanitized() -> LibraryState {
        var copy = self
        copy.library = library.sanitized()
        if let id = copy.loadedSongID, copy.library.song(id: id) == nil {
            copy.loadedSongID = nil
        }
        if let id = copy.loadedFromSetlistID {
            let members = copy.library.setlist(id: id)?.songIDs ?? []
            if copy.loadedSongID.map(members.contains) != true {
                copy.loadedFromSetlistID = nil
            }
        }
        if let id = copy.selectedSetlistID, copy.library.setlist(id: id) == nil {
            copy.selectedSetlistID = nil
        }
        return copy
    }
}

/// The library as the app stored it before records carried change times, when songs were called presets.
private struct StoredLegacyState: Decodable {
    struct Contents: Decodable {
        var songs: [Song]
        var setlists: [Setlist]

        private enum CodingKeys: String, CodingKey {
            case setlists
            case songs = "presets"
        }
    }

    var library: Contents
    var loadedSongID: UUID?
    var loadedFromSetlistID: UUID?
    var selectedSetlistID: UUID?

    private enum CodingKeys: String, CodingKey {
        case library, loadedFromSetlistID, selectedSetlistID
        case loadedSongID = "loadedPresetID"
    }

    /// The same library as records, every part at SyncClock.legacy.
    var converted: LibraryState {
        LibraryState(
            library: Library(legacySongs: library.songs, legacySetlists: library.setlists),
            loadedSongID: loadedSongID,
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
