import CoreGraphics
import Testing
@testable import Metronome

/// Heights are the usable height (inside the safe area). Everything but the dial takes
/// 294 pt plus the two gaps and the tiles: 418 pt roomy and 382 pt compact with one row
/// of tiles, 440 pt and 424 pt with two rows.
struct ScreenLayoutTests {
    private func layout(
        width: CGFloat = 375, height: CGFloat, hasBottomInset: Bool = false, beats: Int = 4,
        hasSetlist: Bool = false
    ) -> ScreenLayout {
        ScreenLayout(
            width: width, height: height, hasBottomInset: hasBottomInset, beats: beats, hasSetlist: hasSetlist
        )
    }

    private func isRoomy(_ layout: ScreenLayout) -> Bool {
        layout.settingsTopGap == 26 && layout.sectionGap == 22 && layout.tileHeight == 76
    }

    private func isCompact(_ layout: ScreenLayout) -> Bool {
        layout.settingsTopGap == 16 && layout.sectionGap == 16 && layout.tileHeight == 56
    }

    /// Everything on the screen, top to bottom, must fit in the usable height.
    private func fits(_ layout: ScreenLayout, in height: CGFloat) -> Bool {
        layout.fixedHeight + layout.dialDiameter + layout.bottomPadding <= height
    }

    @Test func tallPhoneGetsTheFullDesignWithALargerDial() {
        let layout = layout(width: 402, height: 778, hasBottomInset: true)
        #expect(layout.dialDiameter == 340)
        #expect(isRoomy(layout))
        #expect(layout.bottomPadding == 0)
        #expect(layout.fixedHeight == 418)
    }

    @Test func dialGrowsOnlyAsFarAsTheSpareHeight() {
        #expect(layout(width: 402, height: 718, hasBottomInset: true).dialDiameter == 300)
        #expect(layout(width: 402, height: 738, hasBottomInset: true).dialDiameter == 320)
    }

    @Test func dialNeverGrowsWiderThanTheSpaceBetweenTheMargins() {
        #expect(layout(width: 375, height: 900, hasBottomInset: true).dialDiameter == 327)
        #expect(layout(width: 320, height: 900).dialDiameter == 300)
    }

    @Test func aSetlistAddsTheNextUpLine() {
        let layout = layout(width: 402, height: 778, hasBottomInset: true, hasSetlist: true)
        #expect(layout.showsNextLine)
        #expect(layout.fixedHeight == 450)
        #expect(layout.dialDiameter == 328)
        #expect(fits(layout, in: 778))
    }

    @Test func noSetlistNoNextUpLine() {
        #expect(layout(width: 402, height: 778, hasBottomInset: true).showsNextLine == false)
    }

    @Test func iPhoneSEKeepsTheNextUpLineWithASmallerDial() {
        let layout = layout(height: 647, hasSetlist: true)
        #expect(layout.showsNextLine)
        #expect(layout.dialDiameter == 217)
        #expect(fits(layout, in: 647))
    }

    @Test func nextUpLineIsLeftOutWhenTheDialWouldGoBelow200() {
        let layout = layout(height: 647, beats: 12, hasSetlist: true)
        #expect(layout.showsNextLine == false)
        #expect(layout.dialDiameter == 207)
        #expect(fits(layout, in: 647))
    }

    @Test func dialShrinksFirstDownTo240() {
        let layout = layout(height: 658, hasBottomInset: true)
        #expect(layout.dialDiameter == 240)
        #expect(isRoomy(layout))
    }

    @Test func gapsAndTilesShrinkOnceTheDialWouldGoBelow240() {
        let layout = layout(height: 657, hasBottomInset: true)
        #expect(isCompact(layout))
        #expect(layout.dialDiameter == 275)
    }

    @Test func iPhoneSEIsCompactAndFits() {
        let layout = layout(height: 647)
        #expect(isCompact(layout))
        #expect(layout.bottomPadding == 16)
        #expect(layout.fixedHeight == 382)
        #expect(layout.dialDiameter == 249)
        #expect(fits(layout, in: 647))
    }

    @Test func iPhoneSEWithTwelveBeatsStillFits() {
        let layout = layout(height: 647, beats: 12)
        #expect(layout.settingsTopGap == 16)
        #expect(layout.sectionGap == 16)
        #expect(layout.fixedHeight == 424)
        #expect(layout.dialDiameter == 207)
        #expect(fits(layout, in: 647))
    }

    @Test func dialKeepsShrinkingBelow200InsteadOfOverflowing() {
        let layout = layout(height: 581, hasBottomInset: true)
        #expect(isCompact(layout))
        #expect(layout.dialDiameter == 199)
        #expect(fits(layout, in: 581))
    }

    @Test func displayZoomFitsWithASmallDial() {
        let layout = layout(width: 320, height: 548)
        #expect(isCompact(layout))
        #expect(layout.bottomPadding == 16)
        #expect(layout.dialDiameter == 150)
        #expect(fits(layout, in: 548))
    }

    @Test func displayZoomWithTwelveBeatsFitsWithTheSmallestDial() {
        let layout = layout(width: 320, height: 548, beats: 12)
        #expect(layout.fixedHeight == 424)
        #expect(layout.dialDiameter == 108)
        #expect(fits(layout, in: 548))
    }

    @Test func dialNeverCollapsesOnAnImpossiblyShortScreen() {
        #expect(layout(height: 300).dialDiameter == 80)
    }

    @Test func sideMarginsNarrowBelow360() {
        #expect(layout(width: 320, height: 548).sideMargin == 16)
        #expect(layout(width: 359, height: 647).sideMargin == 16)
        #expect(layout(width: 360, height: 647).sideMargin == 24)
        #expect(layout(width: 375, height: 647).sideMargin == 24)
        #expect(layout(width: 402, height: 778, hasBottomInset: true).sideMargin == 24)
    }
}
