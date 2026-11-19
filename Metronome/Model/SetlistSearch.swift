import Foundation

/// A setlist's row with its position number in the whole setlist.
struct NumberedSong: Identifiable, Equatable {
    let number: Int
    let song: Song
    var id: UUID { song.id }
}

/// The rows a setlist's search shows (8.3, 8.8).
enum SetlistSearch {
    /// Numbers each song by its 1-based place in `songs`, then keeps those the query finds,
    /// so a found row keeps its number in the whole setlist.
    static func rows(_ songs: [Song], matching query: String) -> [NumberedSong] {
        songs.enumerated()
            .map { NumberedSong(number: $0.offset + 1, song: $0.element) }
            .filter { $0.song.matches(search: query) }
    }
}
