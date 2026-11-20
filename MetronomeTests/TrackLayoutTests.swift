import CoreGraphics
import Testing
@testable import Metronome

/// Heights are the usable height (inside the safe areas). Sync mode's parts take 514 pt plus
/// the tiles; the tap pads take the rest.
struct TrackLayoutTests {
    private func syncMode(
        width: CGFloat = 375, height: CGFloat, hasBottomInset: Bool = false, beats: Int = 4
    ) -> SyncModeLayout {
        SyncModeLayout(width: width, height: height, hasBottomInset: hasBottomInset, beats: beats)
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
