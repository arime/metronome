import CoreGraphics
import Foundation

/// Stage mode for one setlist (9.4): which setlist it shows and which song is marked next.
/// Nothing of it is kept between launches.
struct StageMode: Equatable {
    let setlistID: UUID
    var nextSongID: UUID?

    /// The loaded song is marked next when it was loaded from this setlist and is still in
    /// it; otherwise the setlist's first song is.
    static func entering(_ setlist: Setlist, loadedSongID: UUID?, loadedFromSetlistID: UUID?) -> StageMode {
        let next: UUID?
        if loadedFromSetlistID == setlist.id, let loadedSongID, setlist.songIDs.contains(loadedSongID) {
            next = loadedSongID
        } else {
            next = setlist.songIDs.first
        }
        return StageMode(setlistID: setlist.id, nextSongID: next)
    }

    /// Only a setlist with songs, and only while the metronome is stopped.
    static func canEnter(songCount: Int, isPlaying: Bool) -> Bool {
        songCount > 0 && !isPlaying
    }

    /// The song after this one, nil after the last or when it is not in the list.
    static func following(_ songID: UUID, in songIDs: [UUID]) -> UUID? {
        guard let index = songIDs.firstIndex(of: songID), index + 1 < songIDs.count else { return nil }
        return songIDs[index + 1]
    }

    /// What a tap on a tile does.
    enum Tap: Equatable {
        case start(UUID)
        case stop
        case nothing
    }

    /// While stopped any tile starts its song; while playing only the playing tile acts,
    /// and stops it.
    static func tap(on songID: UUID, playingSongID: UUID?, isPlaying: Bool) -> Tap {
        guard isPlaying else { return .start(songID) }
        return songID == playingSongID ? .stop : .nothing
    }

    /// `Done` works unless a tile plays; a playing song without a tile does not hold it.
    static func canLeave(playingSongID: UUID?) -> Bool {
        playingSongID == nil
    }

    /// The setlist's songs as tiles, in the given order. `playingSongID` is the playing
    /// tile's song, nil when no tile plays.
    func tiles(for songs: [Song], playingSongID: UUID?, isPlaying: Bool) -> [StageTile] {
        songs.enumerated().map { index, song in
            let mark: StageTile.Mark =
                if song.id == playingSongID {
                    .playing
                } else if !isPlaying && song.id == nextSongID {
                    .next
                } else {
                    .none
                }
            return StageTile(
                number: index + 1, song: song, mark: mark,
                isDimmed: isPlaying && song.id != playingSongID)
        }
    }
}

/// One song's tile in stage mode.
struct StageTile: Equatable, Identifiable {
    enum Mark: Equatable {
        case none, next, playing
    }

    /// The song's place in the setlist, from 1.
    let number: Int
    let song: Song
    let mark: Mark
    /// Drawn at 40 % while the metronome plays another song.
    let isDimmed: Bool

    var id: UUID { song.id }

    /// For example "3, Seven Bridges, 168 beats per minute, 7/8, backing track, playing".
    var accessibilityLabel: String {
        let state =
            switch mark {
            case .none: ""
            case .next: ", next"
            case .playing: ", playing"
            }
        return "\(number), " + song.spokenDescription + state
    }

    /// For example "0:31 / 3:42".
    static func trackTimeLabel(_ time: TimeInterval, of length: TimeInterval) -> String {
        TrackTime.label(time) + " / " + TrackTime.label(length)
    }
}

/// The playing tile's row of beat dots, one per beat of the bar.
enum StageBeatDots {
    struct Layout: Equatable {
        let diameters: [CGFloat]
        let gap: CGFloat

        /// The row's width: every dot and the gaps between them.
        var width: CGFloat {
            diameters.reduce(0, +) + gap * CGFloat(max(diameters.count - 1, 0))
        }
    }

    /// 12 pt accented and 8 pt plain dots 5 pt apart; 8 and 5 pt, 3 pt apart, in 9/8 and 12/8.
    /// Scaled down alike, never up, to fit the available width.
    static func layout(beatsPerBar: Int, accents: Set<Int>, availableWidth: CGFloat) -> Layout {
        guard beatsPerBar > 0 else { return Layout(diameters: [], gap: 0) }
        let isLong = [TimeSignature.nineEight, .twelveEight].map(\.beatsPerBar).contains(beatsPerBar)
        let accented: CGFloat = isLong ? 8 : 12
        let plain: CGFloat = isLong ? 5 : 8
        let full = Layout(
            diameters: (0..<beatsPerBar).map { accents.contains($0 + 1) ? accented : plain },
            gap: isLong ? 3 : 5)
        let scale = min(1, max(availableWidth, 0) / full.width)
        return Layout(diameters: full.diameters.map { $0 * scale }, gap: full.gap * scale)
    }
}
