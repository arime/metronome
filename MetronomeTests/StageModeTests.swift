import CoreGraphics
import Foundation
import Testing
@testable import Metronome

@Suite struct StageModeTests {
    private let a = UUID(), b = UUID(), c = UUID(), x = UUID()

    private func song(
        _ id: UUID, _ name: String = "Song", bpm: Int = 120, _ signature: TimeSignature = .fourFour,
        track: BackingTrack? = nil
    ) -> Song {
        Song(
            id: id, name: name, settings: MetronomeSettings(bpm: bpm, timeSignature: signature, accents: [1]),
            track: track)
    }

    private var setlist: Setlist {
        Setlist(id: UUID(), name: "Friday", songIDs: [a, b, c], lastUsed: .distantPast)
    }

    private var songs: [Song] { [song(a), song(b), song(c)] }

    // MARK: The active song

    @Test func theLoadedSongIsActiveWhenItCameFromThisSetlist() {
        let setlist = setlist
        #expect(StageMode.activeSongID(in: setlist, loadedSongID: b, loadedFromSetlistID: setlist.id) == b)
    }

    @Test func noSongIsActiveWhenTheLoadedSongCameFromElsewhere() {
        let setlist = setlist
        #expect(StageMode.activeSongID(in: setlist, loadedSongID: b, loadedFromSetlistID: UUID()) == nil)
        #expect(StageMode.activeSongID(in: setlist, loadedSongID: b, loadedFromSetlistID: nil) == nil)
        #expect(StageMode.activeSongID(in: setlist, loadedSongID: nil, loadedFromSetlistID: nil) == nil)
        #expect(StageMode.activeSongID(in: setlist, loadedSongID: x, loadedFromSetlistID: setlist.id) == nil)
    }

    @Test func onlyAStoppedSetlistWithSongsCanBeEntered() {
        #expect(!StageMode.canEnter(songCount: 0, isPlaying: false))
        #expect(!StageMode.canEnter(songCount: 3, isPlaying: true))
        #expect(StageMode.canEnter(songCount: 3, isPlaying: false))
    }

    // MARK: Playing

    @Test func aTapWhileStoppedStartsThatSong() {
        #expect(StageMode.tap(on: c, playingSongID: nil, isPlaying: false) == .start(c))
    }

    @Test func aTapOnThePlayingTileStops() {
        #expect(StageMode.tap(on: b, playingSongID: b, isPlaying: true) == .stop)
    }

    @Test func otherTilesDoNothingWhileOnePlays() {
        #expect(StageMode.tap(on: a, playingSongID: b, isPlaying: true) == .nothing)
    }

    @Test func aSongPlayingWithoutATileLeavesDoneWorking() {
        #expect(StageMode.tap(on: a, playingSongID: nil, isPlaying: true) == .nothing)
        #expect(StageMode.canLeave(playingSongID: nil))
        let tiles = StageMode.tiles(for: songs, activeSongID: nil, isPlaying: true, backingTracksOn: true)
        #expect(tiles.map(\.isDimmed) == [true, true, true])
        #expect(tiles.map(\.mark) == [.none, .none, .none])
    }

    @Test func doneDoesNothingWhileATilePlays() {
        #expect(!StageMode.canLeave(playingSongID: b))
    }

    // MARK: Tiles

    @Test func tilesAreNumberedInTheSetlistsOrder() {
        let tiles = StageMode.tiles(for: songs, activeSongID: nil, isPlaying: false, backingTracksOn: true)
        #expect(tiles.map(\.number) == [1, 2, 3])
        #expect(tiles.map(\.id) == [a, b, c])
    }

    @Test func stoppedTheActiveTileIsMarked() {
        let tiles = StageMode.tiles(for: songs, activeSongID: b, isPlaying: false, backingTracksOn: true)
        #expect(tiles.map(\.mark) == [.none, .active, .none])
        #expect(tiles.map(\.isDimmed) == [false, false, false])
    }

    @Test func playingOnlyThePlayingTileIsUndimmed() {
        let tiles = StageMode.tiles(for: songs, activeSongID: c, isPlaying: true, backingTracksOn: true)
        #expect(tiles.map(\.mark) == [.none, .none, .playing])
        #expect(tiles.map(\.isDimmed) == [true, true, false])
    }

    @Test func noActiveSongMarksNothing() {
        let tiles = StageMode.tiles(for: songs, activeSongID: nil, isPlaying: false, backingTracksOn: true)
        #expect(tiles.map(\.mark) == [.none, .none, .none])
    }

    @Test func aTileReadsNumberNameTempoAndState() {
        let track = BackingTrack(fileID: UUID(), fileName: "Bridges.m4a", offset: 0, bpm: 168)
        let songs = [
            song(a, "Harbour Lights", bpm: 96),
            song(b, "Copper Sky", bpm: 120),
            song(c, "Seven Bridges", bpm: 168, .sevenEight, track: track),
        ]
        let stopped = StageMode.tiles(for: songs, activeSongID: b, isPlaying: false, backingTracksOn: true)
        #expect(stopped[0].accessibilityLabel == "1, Harbour Lights, 96 beats per minute, 4/4")
        #expect(stopped[1].accessibilityLabel == "2, Copper Sky, 120 beats per minute, 4/4, loaded")
        let playing = StageMode.tiles(for: songs, activeSongID: c, isPlaying: true, backingTracksOn: true)
        #expect(
            playing[2].accessibilityLabel
                == "3, Seven Bridges, 168 beats per minute, 7/8, backing track, playing")
    }

    private var trackSongs: [Song] {
        let track = BackingTrack(fileID: UUID(), fileName: "Bridges.m4a", offset: 0, bpm: 168)
        return [song(a, "Harbour Lights"), song(b, "Seven Bridges", bpm: 168, .sevenEight, track: track)]
    }

    @Test func aTileWithATrackShowsTheMarkOnlyWithBackingTracksOn() {
        for (activeSongID, isPlaying) in [(nil, false), (b, false), (b, true)] as [(UUID?, Bool)] {
            let on = StageMode.tiles(
                for: trackSongs, activeSongID: activeSongID, isPlaying: isPlaying, backingTracksOn: true)
            #expect(on.map(\.showsTrackMark) == [false, true])
            let off = StageMode.tiles(
                for: trackSongs, activeSongID: activeSongID, isPlaying: isPlaying, backingTracksOn: false)
            #expect(off.map(\.showsTrackMark) == [false, false])
        }
    }

    @Test func withBackingTracksOffATileDoesNotReadBackingTrack() {
        let off = StageMode.tiles(for: trackSongs, activeSongID: b, isPlaying: true, backingTracksOn: false)
        #expect(off[1].accessibilityLabel == "2, Seven Bridges, 168 beats per minute, 7/8, playing")
        let on = StageMode.tiles(for: trackSongs, activeSongID: nil, isPlaying: false, backingTracksOn: true)
        #expect(on[1].accessibilityLabel == "2, Seven Bridges, 168 beats per minute, 7/8, backing track")
    }

    @Test func theTrackTimeReadsPlaceAndLength() {
        #expect(StageTile.trackTimeLabel(31.7, of: 222) == "0:31 / 3:42")
    }

    // MARK: Beat dots

    @Test func dotsAreLargerOnAccentedBeats() {
        let layout = StageBeatDots.layout(beatsPerBar: 4, accents: [1, 3], availableWidth: 134)
        #expect(layout.diameters == [12, 8, 12, 8])
        #expect(layout.gap == 5)
        #expect(layout.width == 55)
    }

    @Test func twelveDotsUseTheSmallSizes() {
        let layout = StageBeatDots.layout(beatsPerBar: 12, accents: [1], availableWidth: 134)
        #expect(layout.diameters.count == 12)
        #expect(layout.diameters[0] == 8)
        #expect(layout.diameters.dropFirst().allSatisfy { $0 == 5 })
        #expect(layout.gap == 3)
    }

    @Test func nineDotsUseTheSmallSizes() {
        let layout = StageBeatDots.layout(beatsPerBar: 9, accents: [1, 4, 7], availableWidth: 134)
        #expect(layout.diameters == [8, 5, 5, 8, 5, 5, 8, 5, 5])
        #expect(layout.gap == 3)
    }

    @Test func noWidthOrNoBeatsGiveNoNegativeOrNaNSizes() {
        for (beats, width) in [(4, -10), (4, 0), (12, -1), (0, 134), (0, 0), (-3, 134)] as [(Int, CGFloat)] {
            let layout = StageBeatDots.layout(beatsPerBar: beats, accents: [1], availableWidth: width)
            let values = layout.diameters + [layout.gap, layout.width]
            #expect(values.allSatisfy { !$0.isNaN && $0 >= 0 }, "\(beats) beats in \(width) pt")
        }
        #expect(StageBeatDots.layout(beatsPerBar: 0, accents: [], availableWidth: 134).diameters.isEmpty)
        #expect(StageBeatDots.layout(beatsPerBar: 0, accents: [], availableWidth: 134).width == 0)
    }

    @Test func twelveAccentedDotsFitANarrowTile() {
        let layout = StageBeatDots.layout(beatsPerBar: 12, accents: Set(1...12), availableWidth: 107)
        #expect(layout.width <= 107)
        #expect(Set(layout.diameters).count == 1)
        #expect(layout.gap < 3)
    }

    @Test func dotsAreNotScaledUp() {
        let layout = StageBeatDots.layout(beatsPerBar: 2, accents: [1], availableWidth: 300)
        #expect(layout.diameters == [12, 8])
        #expect(layout.gap == 5)
    }
}
