import Foundation

/// The Songs tab's order, chosen in its menu and remembered on this device (8.6).
enum SongOrder: String, Codable, CaseIterable, Sendable {
    case name, recentlyAdded, recentlyPlayed

    var title: String {
        switch self {
        case .name: "Name"
        case .recentlyAdded: "Recently added"
        case .recentlyPlayed: "Recently played"
        }
    }
}

/// The Setlists tab's order, chosen in its menu and remembered on this device (8.6).
enum SetlistOrder: String, Codable, CaseIterable, Sendable {
    case recentlyUsed, name

    var title: String {
        switch self {
        case .recentlyUsed: "Recently used"
        case .name: "Name"
        }
    }
}

extension Library {
    /// Every song in the order. Under `recentlyPlayed` the songs with a time come first,
    /// latest first, and the songs without one after them by name; equal times go by name.
    func songs(orderedBy order: SongOrder, lastPlayed: [UUID: Date]) -> [Song] {
        switch order {
        case .name:
            return sortedSongs
        case .recentlyAdded:
            return songs.reversed()
        case .recentlyPlayed:
            let byName = sortedSongs
            let played = byName.enumerated()
                .compactMap { offset, song in lastPlayed[song.id].map { (offset: offset, song: song, time: $0) } }
                .sorted { $0.time != $1.time ? $0.time > $1.time : $0.offset < $1.offset }
                .map(\.song)
            return played + byName.filter { lastPlayed[$0.id] == nil }
        }
    }

    /// The songs as a list shows them while it stays on screen: in `kept`, the order taken
    /// when it appeared or an order was chosen (8.6), so that a song played meanwhile keeps its
    /// place. The songs come from `live`, the library's songs in the chosen order now, so
    /// edits show and deleted songs go; a song not in `kept` is put in at its place in `live`.
    static func songs(_ live: [Song], keptIn kept: [UUID]) -> [Song] {
        let byID = Dictionary(uniqueKeysWithValues: live.map { ($0.id, $0) })
        var shown = kept.compactMap { byID[$0] }
        let known = Set(kept)
        for (index, song) in live.enumerated() where !known.contains(song.id) {
            shown.insert(song, at: min(index, shown.count))
        }
        return shown
    }

    /// Every setlist in the order. Under `name` setlists with the same name are most
    /// recently used first.
    func setlists(orderedBy order: SetlistOrder) -> [Setlist] {
        switch order {
        case .recentlyUsed:
            return setlistsByRecency
        case .name:
            return setlists.enumerated().sorted { first, second in
                Self.inNameOrder(first.element.name, second.element.name) {
                    first.element.lastUsed != second.element.lastUsed
                        ? first.element.lastUsed > second.element.lastUsed
                        : first.offset < second.offset
                }
            }.map(\.element)
        }
    }
}
