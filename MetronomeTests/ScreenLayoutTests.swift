import CoreGraphics
import Testing
@testable import Metronome

/// Heights are the usable height (inside the safe area). Everything but the dial takes
/// 268 pt plus the two gaps and the tiles: 392 pt roomy and 356 pt compact with one row
/// of tiles, 414 pt and 398 pt with two rows.
struct ScreenLayoutTests {
    private func layout(
        width: CGFloat = 375, height: CGFloat, hasBottomInset: Bool = false, beats: Int = 4,
        hasSetlist: Bool = false
    ) -> ScreenLayout {
        ScreenLayout(
            width: width, height: height, hasBottomInset: hasBottomInset, beats: beats, hasSetlist: hasSetlist
        )
    }

    private func trackLayout(
        width: CGFloat = 375, height: CGFloat, hasBottomInset: Bool = false, beats: Int = 4,
        hasSetlist: Bool = false
    ) -> ScreenLayout {
        ScreenLayout(
            width: width, height: height, hasBottomInset: hasBottomInset, beats: beats, hasSetlist: hasSetlist,
            hasTrack: true
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
        #expect(layout.fixedHeight == 392)
    }

    @Test func dialGrowsOnlyAsFarAsTheSpareHeight() {
        #expect(layout(width: 402, height: 692, hasBottomInset: true).dialDiameter == 300)
        #expect(layout(width: 402, height: 712, hasBottomInset: true).dialDiameter == 320)
    }

    @Test func dialNeverGrowsWiderThanTheSpaceBetweenTheMargins() {
        #expect(layout(width: 375, height: 900, hasBottomInset: true).dialDiameter == 327)
        #expect(layout(width: 320, height: 900).dialDiameter == 300)
    }

    @Test func aSetlistAddsTheNextUpLine() {
        let layout = layout(width: 402, height: 752, hasBottomInset: true, hasSetlist: true)
        #expect(layout.showsNextLine)
        #expect(layout.fixedHeight == 424)
        #expect(layout.dialDiameter == 328)
        #expect(fits(layout, in: 752))
    }

    @Test func noSetlistNoNextUpLine() {
        #expect(layout(width: 402, height: 778, hasBottomInset: true).showsNextLine == false)
    }

    @Test func iPhoneSEKeepsTheNextUpLineWithASmallerDial() {
        let layout = layout(height: 647, hasSetlist: true)
        #expect(layout.showsNextLine)
        #expect(layout.dialDiameter == 243)
        #expect(fits(layout, in: 647))
    }

    @Test func nextUpLineIsLeftOutWhenTheDialWouldGoBelow200() {
        let layout = layout(height: 645, beats: 12, hasSetlist: true)
        #expect(layout.showsNextLine == false)
        #expect(layout.dialDiameter == 231)
        #expect(fits(layout, in: 645))
    }

    @Test func dialShrinksFirstDownTo240() {
        let layout = layout(height: 632, hasBottomInset: true)
        #expect(layout.dialDiameter == 240)
        #expect(isRoomy(layout))
    }

    @Test func gapsAndTilesShrinkOnceTheDialWouldGoBelow240() {
        let layout = layout(height: 631, hasBottomInset: true)
        #expect(isCompact(layout))
        #expect(layout.dialDiameter == 275)
    }

    @Test func iPhoneSEIsCompactAndFits() {
        let layout = layout(height: 647)
        #expect(isCompact(layout))
        #expect(layout.bottomPadding == 16)
        #expect(layout.fixedHeight == 356)
        #expect(layout.dialDiameter == 275)
        #expect(fits(layout, in: 647))
    }

    @Test func iPhoneSEWithTwelveBeatsStillFits() {
        let layout = layout(height: 647, beats: 12)
        #expect(layout.settingsTopGap == 16)
        #expect(layout.sectionGap == 16)
        #expect(layout.fixedHeight == 398)
        #expect(layout.dialDiameter == 233)
        #expect(fits(layout, in: 647))
    }

    @Test func dialKeepsShrinkingBelow200InsteadOfOverflowing() {
        let layout = layout(height: 555, hasBottomInset: true)
        #expect(isCompact(layout))
        #expect(layout.dialDiameter == 199)
        #expect(fits(layout, in: 555))
    }

    @Test func displayZoomFitsWithASmallDial() {
        let layout = layout(width: 320, height: 548)
        #expect(isCompact(layout))
        #expect(layout.bottomPadding == 16)
        #expect(layout.dialDiameter == 176)
        #expect(fits(layout, in: 548))
    }

    @Test func displayZoomWithTwelveBeatsFitsWithTheSmallestDial() {
        let layout = layout(width: 320, height: 548, beats: 12)
        #expect(layout.fixedHeight == 398)
        #expect(layout.dialDiameter == 134)
        #expect(fits(layout, in: 548))
    }

    @Test func dialNeverCollapsesOnAnImpossiblyShortScreen() {
        #expect(layout(height: 300).dialDiameter == 80)
    }

    // MARK: - A song with a backing track (6.12)
    //
    // Everything but the dial takes 420 pt roomy and 396 pt compact with one row of tiles,
    // 442 pt and 438 pt with two rows; the next-up line adds 32 pt.

    @Test func theTrackLayoutFitsTheDesignScreenWithALargeDial() {
        let layout = trackLayout(width: 390, height: 763, hasBottomInset: true, beats: 7, hasSetlist: true)
        #expect(layout.dialDiameter >= 280)
        #expect(layout.stripTopGap == 14)
        #expect(layout.tileHeight == 76)
        #expect(layout.showsNextLine)
        #expect(fits(layout, in: 763))
    }

    @Test func theTrackLayoutShrinksTheDialFirst() {
        let layout = trackLayout(height: 680, hasBottomInset: true)
        #expect(layout.dialDiameter == 260)
        #expect(layout.stripTopGap == 14)
        #expect(layout.tileHeight == 76)
        #expect(layout.settingsTopGap == 10)
        #expect(layout.sectionGap == 12)
    }

    @Test func theTrackLayoutGoesCompactBelow240() {
        let layout = trackLayout(height: 659, hasBottomInset: true)
        #expect(layout.stripTopGap == 10)
        #expect(layout.tileHeight == 56)
        #expect(layout.settingsTopGap == 10)
        #expect(layout.sectionGap == 12)
        #expect(layout.dialDiameter == 263)
    }

    @Test(arguments: [4, 12], [false, true])
    func theTrackLayoutFitsAnIPhoneSE(beats: Int, hasSetlist: Bool) {
        let layout = trackLayout(height: 647, beats: beats, hasSetlist: hasSetlist)
        #expect(fits(layout, in: 647))
        #expect(layout.dialDiameter >= ScreenLayout.minimumDial)
    }

    @Test(arguments: [4, 12], [false, true])
    func theTrackLayoutFitsDisplayZoom(beats: Int, hasSetlist: Bool) {
        let layout = trackLayout(width: 320, height: 548, beats: beats, hasSetlist: hasSetlist)
        #expect(fits(layout, in: 548))
        #expect(layout.dialDiameter >= ScreenLayout.minimumDial)
    }

    @Test func withoutATrackTheLayoutIsUnchanged() {
        let sizes: [(width: CGFloat, height: CGFloat, inset: Bool, beats: Int, setlist: Bool)] = [
            (402, 778, true, 4, false), (375, 647, false, 12, true), (320, 548, false, 7, false),
        ]
        for size in sizes {
            let before = layout(
                width: size.width, height: size.height, hasBottomInset: size.inset, beats: size.beats,
                hasSetlist: size.setlist
            )
            let after = ScreenLayout(
                width: size.width, height: size.height, hasBottomInset: size.inset, beats: size.beats,
                hasSetlist: size.setlist, hasTrack: false
            )
            #expect(after.dialDiameter == before.dialDiameter)
            #expect(after.sectionGap == before.sectionGap)
            #expect(after.settingsTopGap == before.settingsTopGap)
            #expect(after.tileHeight == before.tileHeight)
            #expect(after.bottomPadding == before.bottomPadding)
            #expect(after.sideMargin == before.sideMargin)
            #expect(after.fixedHeight == before.fixedHeight)
            #expect(after.showsNextLine == before.showsNextLine)
            #expect(after.stripTopGap == 0)
        }
    }

    @Test func sideMarginsNarrowBelow360() {
        #expect(layout(width: 320, height: 548).sideMargin == 16)
        #expect(layout(width: 359, height: 647).sideMargin == 16)
        #expect(layout(width: 360, height: 647).sideMargin == 24)
        #expect(layout(width: 375, height: 647).sideMargin == 24)
        #expect(layout(width: 402, height: 778, hasBottomInset: true).sideMargin == 24)
    }
}
