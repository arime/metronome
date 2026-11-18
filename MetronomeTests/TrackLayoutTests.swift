import CoreGraphics
import Testing
@testable import Metronome

/// Heights are the usable height (inside the safe areas). The track screen stacks the
/// header (48), 12, the dial, 26, the Sync row (60), 22, the tiles, at least 16 and the
/// player card (192, or 222 with the next-up line); the compact step makes both gaps 16.
/// Sync mode's parts take 514 pt plus the tiles; the tap pads take the rest.
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
        #expect(layout.dialDiameter == 296)
        #expect(layout.showsNextLine)
        #expect(layout.cardHeight == 222)
        #expect(layout.rowTopGap == 26)
        #expect(layout.rowBottomGap == 22)
        #expect(layout.tileHeight == 76)
        #expect(trackScreen(width: 402, height: 778, hasBottomInset: true, beats: 9, hasSetlist: true).dialDiameter == 274)
        #expect(trackScreen(width: 402, height: 778, hasBottomInset: true).dialDiameter == 326)
        #expect(trackScreen(width: 402, height: 778, hasBottomInset: true, beats: 12).dialDiameter == 304)
    }

    @Test func theTrackScreenOnAnIPhoneSE() {
        let layout = trackScreen(height: 647, hasSetlist: true)
        #expect(layout.showsNextLine == false)
        #expect(layout.cardHeight == 192)
        #expect(layout.dialDiameter == 215)
        #expect(layout.rowTopGap == 16)
        #expect(layout.rowBottomGap == 16)
        #expect(layout.tileHeight == 56)
        #expect(trackScreen(height: 647, beats: 9, hasSetlist: true).dialDiameter == 173)
    }

    @Test func theTrackScreenWithDisplayZoom() {
        #expect(trackScreen(width: 320, height: 548, hasSetlist: true).dialDiameter == 116)
        #expect(trackScreen(width: 320, height: 548, hasSetlist: true).showsNextLine == false)
        #expect(trackScreen(width: 320, height: 548, beats: 9, hasSetlist: true).dialDiameter == 74)
    }

    @Test func theDialGrowsTo340AndNoWiderThanTheMargins() {
        #expect(trackScreen(width: 402, height: 900, hasBottomInset: true).dialDiameter == 340)
        #expect(trackScreen(width: 375, height: 900, hasBottomInset: true).dialDiameter == 327)
    }

    @Test func theNextUpLineIsLeftOutBelowA200Dial() {
        // With the line and the compact step the fixed parts are 168 + 56 + 222 = 446.
        #expect(trackScreen(height: 446 + 200, hasBottomInset: true, hasSetlist: true).showsNextLine)
        #expect(trackScreen(height: 446 + 199, hasBottomInset: true, hasSetlist: true).showsNextLine == false)
    }

    @Test func theDialShrinksTo240BeforeTheGapsGiveWay() {
        // Without the line the fixed parts are 184 + 76 + 192 = 452 with the full gaps.
        let roomy = trackScreen(height: 452 + 240, hasBottomInset: true)
        #expect(roomy.dialDiameter == 240)
        #expect(roomy.tileHeight == 76)
        let compact = trackScreen(height: 452 + 239, hasBottomInset: true)
        #expect(compact.tileHeight == 56)
        #expect(compact.rowTopGap == 16)
    }

    @Test func anImpossiblyShortScreenKeepsTheSmallestDial() {
        #expect(trackScreen(height: 200).dialDiameter == TrackScreenLayout.minimumDial)
    }

    @Test func theTrackScreenFillsTheHeightOrLeavesSpareAboveTheCard() {
        for height in stride(from: CGFloat(560), through: 900, by: 17) {
            for beats in [4, 7, 9, 12] {
                let layout = trackScreen(height: height, hasBottomInset: true, beats: beats, hasSetlist: true)
                let used = TrackScreenLayout.headerHeight + TrackScreenLayout.dialTopGap + layout.dialDiameter
                    + layout.rowTopGap + TrackScreenLayout.rowHeight + layout.rowBottomGap + layout.tilesHeight
                    + TrackScreenLayout.cardTopGap + layout.cardHeight
                #expect(used <= height)
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
