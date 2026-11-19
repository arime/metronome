import Foundation

/// The songs ticked in the Songs tab's select mode (8.7). A ticked song stays ticked while a
/// search hides it; one that no longer exists drops out.
struct SongSelection: Equatable {
    private(set) var ids: Set<UUID> = []

    mutating func toggle(_ id: UUID) {
        if ids.remove(id) == nil { ids.insert(id) }
    }

    func contains(_ id: UUID) -> Bool {
        ids.contains(id)
    }

    var count: Int { ids.count }

    /// `Select songs` while nothing is ticked, otherwise for example `3 selected`.
    var title: String {
        count == 0 ? "Select songs" : "\(count) selected"
    }

    /// Drops the ticks of songs that are no longer in the library.
    mutating func keep(only existing: Set<UUID>) {
        ids.formIntersection(existing)
    }

    /// The ticked songs in the order of `songs`.
    func ordered(in songs: [Song]) -> [UUID] {
        songs.map(\.id).filter(ids.contains)
    }
}

/// The confirmation for deleting several ticked songs at once (8.7).
enum SongsDeletion {
    static func title(count: Int) -> String {
        "Delete \(count) songs?"
    }

    /// Nil when none of the songs is in a setlist: the confirmation then has no message.
    static func message(setlistCount: Int) -> String? {
        switch setlistCount {
        case 0: nil
        case 1: "They will also be removed from 1 setlist."
        default: "They will also be removed from \(setlistCount) setlists."
        }
    }
}
