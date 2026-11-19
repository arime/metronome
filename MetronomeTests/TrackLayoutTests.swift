import CoreGraphics
import Testing
@testable import Metronome

/// Heights are the usable height (inside the safe areas). The track screen stacks the
/// header (48), 12, the dial, 26 (16 in the plain layout's compact step), the tiles, at
/// least 16 and the player card (192, or 222 with the next-up line), with the dial, the
/// tile height and the next-up line taken from the plain layout. Sync mode's parts take
/// 514 pt plus the tiles; the tap pads take the rest.
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
        #expect(layout.dialDiameter == 340)
        #expect(layout.showsNextLine)
        #expect(layout.cardHeight == 222)
        #expect(layout.tilesTopGap == 26)
        #expect(layout.tileHeight == 76)
        #expect(trackScreen(width: 402, height: 778, hasBottomInset: true, beats: 9, hasSetlist: true).dialDiameter == 332)
        #expect(trackScreen(width: 402, height: 778, hasBottomInset: true).dialDiameter == 340)
    }

    @Test func theTrackScreenOnAnIPhoneSE() {
        let layout = trackScreen(height: 647, hasSetlist: true)
        #expect(layout.dialDiameter == 243)
        #expect(layout.showsNextLine)
        #expect(layout.cardHeight == 222)
        #expect(layout.tilesTopGap == 16)
        #expect(layout.tileHeight == 56)
        #expect(trackScreen(height: 647, beats: 9, hasSetlist: true).dialDiameter == 201)
        #expect(trackScreen(height: 647).dialDiameter == 275)
    }

    @Test func theTrackScreenWithDisplayZoom() {
        let layout = trackScreen(width: 320, height: 548, hasSetlist: true)
        #expect(layout.dialDiameter == 176)
        #expect(layout.showsNextLine == false)
        #expect(layout.cardHeight == 192)
        #expect(trackScreen(width: 320, height: 548, beats: 9, hasSetlist: true).dialDiameter == 134)
    }

    @Test func theTrackScreenTakesItsSizesFromThePlainLayout() {
        for width in [CGFloat(320), 375, 402] {
            for height in stride(from: CGFloat(548), through: 900, by: 13) {
                for beats in [2, 4, 7, 9, 12] {
                    for hasSetlist in [false, true] {
                        for hasBottomInset in [false, true] {
                            let plain = ScreenLayout(
                                width: width, height: height, hasBottomInset: hasBottomInset, beats: beats, hasSetlist: hasSetlist
                            )
                            let track = trackScreen(
                                width: width, height: height, hasBottomInset: hasBottomInset, beats: beats, hasSetlist: hasSetlist
                            )
                            #expect(track.dialDiameter == plain.dialDiameter)
                            #expect(track.tileHeight == plain.tileHeight)
                            #expect(track.showsNextLine == plain.showsNextLine)
                            #expect(track.tilesTopGap == plain.settingsTopGap)
                            #expect(track.sideMargin == plain.sideMargin)
                            #expect(track.bottomPadding == plain.bottomPadding)
                        }
                    }
                }
            }
        }
    }

    @Test func theCardAlwaysHasAtLeast16AboveIt() {
        for width in [CGFloat(320), 375, 402] {
            for height in stride(from: CGFloat(548), through: 900, by: 13) {
                for beats in [2, 4, 7, 9, 12] {
                    for hasSetlist in [false, true] {
                        for hasBottomInset in [false, true] {
                            let layout = trackScreen(
                                width: width, height: height, hasBottomInset: hasBottomInset, beats: beats, hasSetlist: hasSetlist
                            )
                            let used = TrackScreenLayout.headerHeight + TrackScreenLayout.dialTopGap + layout.dialDiameter
                                + layout.tilesTopGap + layout.tilesHeight + TrackScreenLayout.cardTopGap + layout.cardHeight
                                + layout.bottomPadding
                            #expect(used <= height)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Sync mode (6.13)
    // Sync mode is a large sheet. The heights are its content's, measured in the simulator: 778 pt
    // on an iPhone 17 Pro (with the home indicator's 34 pt inset), 637 pt on an iPhone SE.

    @Test func syncModeOnAnIPhone17Pro() {
        let layout = syncMode(width: 402, height: 778, hasBottomInset: true)
        #expect(layout.padHeight == 188)
        #expect(layout.tileHeight == 76)
        #expect(layout.scrollOverflow == 0)
        #expect(layout.showsHandIcon)
        for beats in [9, 12] {
            let twoRows = syncMode(width: 402, height: 778, hasBottomInset: true, beats: beats)
            #expect(twoRows.padHeight == 166)
            #expect(twoRows.scrollOverflow == 0)
        }
    }

    @Test func syncModeOnAnIPhoneSE() {
        let layout = syncMode(width: 375, height: 637)
        #expect(layout.tileHeight == 56)
        #expect(layout.padHeight == 72)
        #expect(layout.scrollOverflow == 21)
        #expect(layout.showsHandIcon == false)
        for beats in [9, 12] {
            let twoRows = syncMode(width: 375, height: 637, beats: beats)
            #expect(twoRows.padHeight == 72)
            #expect(twoRows.scrollOverflow == 63)
        }
    }

    @Test func narrowPhonesGetTheNarrowMargins() {
        #expect(syncMode(width: 320, height: 548).sideMargin == 16)
        #expect(syncMode(width: 375, height: 637).sideMargin == Theme.sideMargin)
    }

    @Test func tallTilesStayWhileThePadHas72() {
        let tall = syncMode(width: 402, height: 662, hasBottomInset: true)
        #expect(tall.tileHeight == 76)
        #expect(tall.padHeight == 72)
        let compact = syncMode(width: 402, height: 661, hasBottomInset: true)
        #expect(compact.tileHeight == 56)
        #expect(compact.padHeight == 91)
    }

    @Test func theHandIconNeeds120() {
        let shown = syncMode(width: 402, height: 710, hasBottomInset: true)
        #expect(shown.padHeight == 120)
        #expect(shown.showsHandIcon)
        #expect(syncMode(width: 402, height: 709, hasBottomInset: true).showsHandIcon == false)
    }

    @Test func syncModeFitsOrScrollsByTheRest() {
        let cases: [(width: CGFloat, height: CGFloat, inset: Bool, beats: Int)] = [
            (402, 778, true, 4), (402, 778, true, 9),
            (375, 637, false, 4), (375, 637, false, 9), (375, 637, false, 12),
            (320, 548, false, 4), (320, 548, false, 9), (320, 548, false, 12),
            (402, 662, true, 4), (402, 661, true, 4),
            (402, 710, true, 4), (402, 709, true, 4),
        ]
        for c in cases {
            let layout = syncMode(width: c.width, height: c.height, hasBottomInset: c.inset, beats: c.beats)
            let tiles = AccentTiles.height(forBeats: c.beats, singleRowTileHeight: layout.tileHeight)
            let total = SyncModeLayout.partsHeight(tilesHeight: tiles) + layout.padHeight + layout.bottomPadding
            #expect(total == c.height + layout.scrollOverflow)
        }
    }
}
