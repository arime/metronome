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

    // MARK: Entering

    @Test func enteringMarksTheLoadedSongWhenItCameFromThisSetlist() {
        let setlist = setlist
        let stage = StageMode.entering(setlist, loadedSongID: b, loadedFromSetlistID: setlist.id)
        #expect(stage.setlistID == setlist.id)
        #expect(stage.nextSongID == b)
    }

    @Test func enteringMarksTheFirstSongOtherwise() {
        let setlist = setlist
        let fromAnother = StageMode.entering(setlist, loadedSongID: b, loadedFromSetlistID: UUID())
        let onItsOwn = StageMode.entering(setlist, loadedSongID: b, loadedFromSetlistID: nil)
        let nothingLoaded = StageMode.entering(setlist, loadedSongID: nil, loadedFromSetlistID: nil)
        #expect(fromAnother.nextSongID == a)
        #expect(onItsOwn.nextSongID == a)
        #expect(nothingLoaded.nextSongID == a)
    }

    @Test func onlyAStoppedSetlistWithSongsCanBeEntered() {
        #expect(!StageMode.canEnter(songCount: 0, isPlaying: false))
        #expect(!StageMode.canEnter(songCount: 3, isPlaying: true))
        #expect(StageMode.canEnter(songCount: 3, isPlaying: false))
    }

    // MARK: Playing

    @Test func theFollowingSongIsTheNextInOrder() {
        #expect(StageMode.following(a, in: [a, b, c]) == b)
        #expect(StageMode.following(c, in: [a, b, c]) == nil)
        #expect(StageMode.following(x, in: [a, b, c]) == nil)
    }

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
        let stage = StageMode(setlistID: setlist.id, nextSongID: b)
        let tiles = stage.tiles(for: songs, playingSongID: nil, isPlaying: true)
        #expect(tiles.map(\.isDimmed) == [true, true, true])
        #expect(tiles.map(\.mark) == [.none, .none, .none])
    }

    @Test func doneDoesNothingWhileATilePlays() {
        #expect(!StageMode.canLeave(playingSongID: b))
    }

    // MARK: Tiles

    @Test func tilesAreNumberedInTheSetlistsOrder() {
        let tiles = StageMode(setlistID: setlist.id, nextSongID: nil)
            .tiles(for: songs, playingSongID: nil, isPlaying: false)
        #expect(tiles.map(\.number) == [1, 2, 3])
        #expect(tiles.map(\.id) == [a, b, c])
    }

    @Test func stoppedTheNextTileIsMarked() {
        let tiles = StageMode(setlistID: setlist.id, nextSongID: b)
            .tiles(for: songs, playingSongID: nil, isPlaying: false)
        #expect(tiles.map(\.mark) == [.none, .next, .none])
        #expect(tiles.map(\.isDimmed) == [false, false, false])
    }

    @Test func playingOnlyThePlayingTileIsUndimmed() {
        let tiles = StageMode(setlistID: setlist.id, nextSongID: b)
            .tiles(for: songs, playingSongID: c, isPlaying: true)
        #expect(tiles.map(\.mark) == [.none, .none, .playing])
        #expect(tiles.map(\.isDimmed) == [true, true, false])
    }

    @Test func aNextSongNotInTheSetlistMarksNothing() {
        let tiles = StageMode(setlistID: setlist.id, nextSongID: x)
            .tiles(for: songs, playingSongID: nil, isPlaying: false)
        #expect(tiles.map(\.mark) == [.none, .none, .none])
    }

    @Test func aTileReadsNumberNameTempoAndState() {
        let track = BackingTrack(fileID: UUID(), fileName: "Bridges.m4a", offset: 0, bpm: 168)
        let songs = [
            song(a, "Harbour Lights", bpm: 96),
            song(b, "Copper Sky", bpm: 120),
            song(c, "Seven Bridges", bpm: 168, .sevenEight, track: track),
        ]
        let stopped = StageMode(setlistID: setlist.id, nextSongID: b)
            .tiles(for: songs, playingSongID: nil, isPlaying: false)
        #expect(stopped[0].accessibilityLabel == "1, Harbour Lights, 96 beats per minute, 4/4")
        #expect(stopped[1].accessibilityLabel == "2, Copper Sky, 120 beats per minute, 4/4, next")
        let playing = StageMode(setlistID: setlist.id, nextSongID: b)
            .tiles(for: songs, playingSongID: c, isPlaying: true)
        #expect(
            playing[2].accessibilityLabel
                == "3, Seven Bridges, 168 beats per minute, 7/8, backing track, playing")
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
