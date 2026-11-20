import CoreGraphics
import Foundation

/// Stage mode for one setlist (9.4): which setlist it shows. Nothing of it is kept between launches.
struct StageMode: Equatable {
    let setlistID: UUID

    /// The active song: the loaded song when it was loaded from this setlist and is still in it.
    static func activeSongID(in setlist: Setlist, loadedSongID: UUID?, loadedFromSetlistID: UUID?) -> UUID? {
        guard loadedFromSetlistID == setlist.id, let loadedSongID, setlist.songIDs.contains(loadedSongID)
        else { return nil }
        return loadedSongID
    }

    /// Only a setlist with songs, and only while the metronome is stopped.
    static func canEnter(songCount: Int, isPlaying: Bool) -> Bool {
        songCount > 0 && !isPlaying
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

    /// The setlist's songs as tiles, in the given order. The active song's tile is the playing
    /// tile while the metronome plays, and marked while it is stopped. A song with a backing track
    /// shows the track mark only while backing tracks are on, whether or not its file is here.
    static func tiles(
        for songs: [Song], activeSongID: UUID?, isPlaying: Bool, backingTracksOn: Bool
    ) -> [StageTile] {
        songs.enumerated().map { index, song in
            let isActive = song.id == activeSongID
            let mark: StageTile.Mark = isActive ? (isPlaying ? .playing : .active) : .none
            return StageTile(
                number: index + 1, song: song, mark: mark, isDimmed: isPlaying && !isActive,
                showsTrackMark: backingTracksOn && song.track != nil)
        }
    }
}

/// One song's tile in stage mode.
struct StageTile: Equatable, Identifiable {
    enum Mark: Equatable {
        case none, active, playing
    }

    /// The song's place in the setlist, from 1.
    let number: Int
    let song: Song
    let mark: Mark
    /// Drawn at 40 % while the metronome plays another song.
    let isDimmed: Bool
    /// The music note: the song's backing track will be used.
    let showsTrackMark: Bool

    var id: UUID { song.id }

    /// For example "3, Seven Bridges, 168 beats per minute, 7/8, backing track, playing";
    /// "backing track" only with the track mark.
    var accessibilityLabel: String {
        let state =
            switch mark {
            case .none: ""
            case .active: ", loaded"
            case .playing: ", playing"
            }
        let settings = song.settings
        return "\(number), \(song.name), \(settings.bpm) beats per minute, \(settings.timeSignature.rawValue)"
            + (showsTrackMark ? ", backing track" : "") + state
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
