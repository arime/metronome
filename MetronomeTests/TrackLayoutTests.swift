import CoreGraphics
import Testing
@testable import Metronome

/// Heights are the usable height (inside the safe areas). The track screen stacks the
/// header (48), 8, the tempo reading's room, the tiles, 16 and the player card (192, or
/// 222 with the next-up line). Sync mode's parts take 484 pt plus the tiles; the tap pad
/// takes the rest.
struct TrackLayoutTests {
    private func trackScreen(
        width: CGFloat = 375, height: CGFloat, hasBottomInset: Bool = false, beats: Int = 4,
        hasSetlist: Bool = false
    ) -> TrackScreenLayout {
        TrackScreenLayout(
            width: width, height: height, hasBottomInset: hasBottomInset, beats: beats, hasSetlist: hasSetlist
        )
    }

    private func syncMode(
        width: CGFloat = 375, height: CGFloat, hasBottomInset: Bool = false, beats: Int = 4
    ) -> SyncModeLayout {
        SyncModeLayout(width: width, height: height, hasBottomInset: hasBottomInset, beats: beats)
    }

    // MARK: - The track screen (6.12)

    @Test func theTrackScreenOnAnIPhone17Pro() {
        let layout = trackScreen(width: 402, height: 778, hasBottomInset: true, hasSetlist: true)
        #expect(layout.showsNextLine)
        #expect(layout.readingRoom == 408)
        #expect(layout.numberFontSize == 136)
        #expect(layout.cardHeight == 222)
        #expect(layout.bottomPadding == 0)
        for beats in [9, 12] {
            #expect(
                trackScreen(width: 402, height: 778, hasBottomInset: true, beats: beats, hasSetlist: true)
                    .readingRoom == 386
            )
        }
        let noSetlist = trackScreen(width: 402, height: 778, hasBottomInset: true)
        #expect(noSetlist.readingRoom == 438)
        #expect(noSetlist.cardHeight == 192)
    }

    @Test func theTrackScreenOnAnIPhoneSE() {
        let layout = trackScreen(width: 375, height: 647, hasSetlist: true)
        #expect(layout.showsNextLine == false)
        #expect(layout.readingRoom == 291)
        #expect(layout.cardHeight == 192)
        #expect(layout.bottomPadding == 16)
        #expect(layout.numberFontSize == 136)
        for beats in [9, 12] {
            let twoRows = trackScreen(width: 375, height: 647, beats: beats, hasSetlist: true)
            #expect(twoRows.readingRoom == 269)
            #expect(twoRows.tilesHeight == 98)
        }
    }

    @Test func theTrackScreenWithDisplayZoom() {
        let layout = trackScreen(width: 320, height: 548, hasSetlist: true)
        #expect(layout.showsNextLine == false)
        #expect(layout.readingRoom == 192)
        #expect(layout.sideMargin == 16)
        #expect(layout.numberFontSize == 136)
        for beats in [9, 12] {
            #expect(trackScreen(width: 320, height: 548, beats: beats, hasSetlist: true).readingRoom == 170)
        }
    }

    @Test func theNextUpLineNeeds280OfRoom() {
        let shown = trackScreen(width: 402, height: 650, hasBottomInset: true, hasSetlist: true)
        #expect(shown.showsNextLine)
        #expect(shown.readingRoom == 280)
        let leftOut = trackScreen(width: 402, height: 649, hasBottomInset: true, hasSetlist: true)
        #expect(leftOut.showsNextLine == false)
        #expect(leftOut.readingRoom == 309)
    }

    @Test func theNumberScalesBelow152OfRoom() {
        let full = trackScreen(width: 402, height: 492, hasBottomInset: true)
        #expect(full.readingRoom == 152)
        #expect(full.numberFontSize == 136)
        let scaled = trackScreen(width: 402, height: 438, hasBottomInset: true)
        #expect(scaled.readingRoom == 98)
        #expect(scaled.numberFontSize == 68)
    }

    @Test func anImpossiblyShortScreenKeepsTheSmallestNumber() {
        #expect(trackScreen(width: 375, height: 300).numberFontSize == 24)
    }

    @Test func theTrackScreenFillsTheHeight() {
        let cases: [(width: CGFloat, height: CGFloat, inset: Bool, beats: Int, setlist: Bool)] = [
            (402, 778, true, 4, true), (402, 778, true, 9, true), (402, 778, true, 12, true),
            (402, 778, true, 4, false),
            (375, 647, false, 4, true), (375, 647, false, 9, true), (375, 647, false, 12, true),
            (320, 548, false, 4, true), (320, 548, false, 9, true), (320, 548, false, 12, true),
            (402, 650, true, 4, true), (402, 649, true, 4, true),
            (402, 492, true, 4, false), (402, 438, true, 4, false),
            (375, 300, false, 4, false),
        ]
        for c in cases {
            let layout = trackScreen(
                width: c.width, height: c.height, hasBottomInset: c.inset, beats: c.beats, hasSetlist: c.setlist
            )
            let total = TrackScreenLayout.headerHeight + TrackScreenLayout.readingTopGap + layout.readingRoom
                + layout.tilesHeight + TrackScreenLayout.cardTopGap + layout.cardHeight + layout.bottomPadding
            #expect(total == c.height)
        }
    }

    // MARK: - Sync mode (6.13)

    @Test func syncModeOnAnIPhone17Pro() {
        let layout = syncMode(width: 402, height: 778, hasBottomInset: true)
        #expect(layout.padHeight == 218)
        #expect(layout.tileHeight == 76)
        #expect(layout.scrollOverflow == 0)
        #expect(layout.showsHandIcon)
        #expect(syncMode(width: 402, height: 778, hasBottomInset: true, beats: 9).padHeight == 196)
    }

    @Test func syncModeOnAnIPhoneSE() {
        let layout = syncMode(width: 375, height: 647)
        #expect(layout.tileHeight == 56)
        #expect(layout.padHeight == 91)
        #expect(layout.scrollOverflow == 0)
        #expect(layout.showsHandIcon == false)
        for beats in [9, 12] {
            let twoRows = syncMode(width: 375, height: 647, beats: beats)
            #expect(twoRows.padHeight == 72)
            #expect(twoRows.scrollOverflow == 23)
        }
    }

    @Test func syncModeWithDisplayZoom() {
        let layout = syncMode(width: 320, height: 548)
        #expect(layout.tileHeight == 56)
        #expect(layout.padHeight == 72)
        #expect(layout.scrollOverflow == 80)
        #expect(layout.sideMargin == 16)
        for beats in [9, 12] {
            #expect(syncMode(width: 320, height: 548, beats: beats).scrollOverflow == 122)
        }
    }

    @Test func tallTilesStayWhileThePadHas72() {
        let tall = syncMode(width: 402, height: 632, hasBottomInset: true)
        #expect(tall.tileHeight == 76)
        #expect(tall.padHeight == 72)
        let compact = syncMode(width: 402, height: 631, hasBottomInset: true)
        #expect(compact.tileHeight == 56)
        #expect(compact.padHeight == 91)
    }

    @Test func theHandIconNeeds120() {
        let shown = syncMode(width: 402, height: 680, hasBottomInset: true)
        #expect(shown.padHeight == 120)
        #expect(shown.showsHandIcon)
        #expect(syncMode(width: 402, height: 679, hasBottomInset: true).showsHandIcon == false)
    }

    @Test func syncModeFitsOrScrollsByTheRest() {
        let cases: [(width: CGFloat, height: CGFloat, inset: Bool, beats: Int)] = [
            (402, 778, true, 4), (402, 778, true, 9),
            (375, 647, false, 4), (375, 647, false, 9), (375, 647, false, 12),
            (320, 548, false, 4), (320, 548, false, 9), (320, 548, false, 12),
            (402, 632, true, 4), (402, 631, true, 4),
            (402, 680, true, 4), (402, 679, true, 4),
        ]
        for c in cases {
            let layout = syncMode(width: c.width, height: c.height, hasBottomInset: c.inset, beats: c.beats)
            let tiles = AccentTiles.height(forBeats: c.beats, singleRowTileHeight: layout.tileHeight)
            let total = SyncModeLayout.partsHeight(tilesHeight: tiles) + layout.padHeight + layout.bottomPadding
            #expect(total == c.height + layout.scrollOverflow)
        }
    }
}
