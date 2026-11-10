import CoreGraphics
import Testing
@testable import Metronome

/// Heights are the usable height (inside the safe area). Everything but the dial takes
/// 294 pt plus the two gaps and the tiles: 418 pt roomy and 382 pt compact with one row
/// of tiles, 440 pt and 424 pt with two rows.
struct ScreenLayoutTests {
    private func layout(
        width: CGFloat = 375, height: CGFloat, hasBottomInset: Bool = false, beats: Int = 4
    ) -> ScreenLayout {
        ScreenLayout(width: width, height: height, hasBottomInset: hasBottomInset, beats: beats)
    }

    private func isRoomy(_ layout: ScreenLayout) -> Bool {
        layout.settingsTopGap == 26 && layout.sectionGap == 22 && layout.tileHeight == 76
    }

    private func isCompact(_ layout: ScreenLayout) -> Bool {
        layout.settingsTopGap == 16 && layout.sectionGap == 16 && layout.tileHeight == 56
    }

    @Test func tallPhoneGetsTheFullDesign() {
        let layout = layout(width: 402, height: 778, hasBottomInset: true)
        #expect(layout.dialDiameter == 300)
        #expect(isRoomy(layout))
        #expect(layout.bottomPadding == 0)
        #expect(layout.fixedHeight == 418)
        #expect(!layout.needsScrolling)
    }

    @Test func dialShrinksFirstDownTo240() {
        let layout = layout(height: 658, hasBottomInset: true)
        #expect(layout.dialDiameter == 240)
        #expect(isRoomy(layout))
        #expect(!layout.needsScrolling)
    }

    @Test func gapsAndTilesShrinkOnceTheDialWouldGoBelow240() {
        let layout = layout(height: 657, hasBottomInset: true)
        #expect(isCompact(layout))
        #expect(layout.dialDiameter == 275)
        #expect(!layout.needsScrolling)
    }

    @Test func iPhoneSEIsCompactAndFits() {
        let layout = layout(height: 647)
        #expect(isCompact(layout))
        #expect(layout.bottomPadding == 16)
        #expect(layout.fixedHeight == 382)
        #expect(layout.dialDiameter == 249)
        #expect(!layout.needsScrolling)
        #expect(layout.fixedHeight + layout.dialDiameter + layout.bottomPadding <= 647)
    }

    @Test func iPhoneSEWithTwelveBeatsStillFits() {
        let layout = layout(height: 647, beats: 12)
        #expect(layout.settingsTopGap == 16)
        #expect(layout.sectionGap == 16)
        #expect(layout.fixedHeight == 424)
        #expect(layout.dialDiameter == 207)
        #expect(!layout.needsScrolling)
        #expect(layout.fixedHeight + layout.dialDiameter + layout.bottomPadding <= 647)
    }

    @Test func dialStopsAt200ExactlyWhenItJustFits() {
        let layout = layout(height: 582, hasBottomInset: true)
        #expect(isCompact(layout))
        #expect(layout.dialDiameter == 200)
        #expect(!layout.needsScrolling)
    }

    @Test func scrollsOnceTheSmallestLayoutIsTooTall() {
        let layout = layout(height: 581, hasBottomInset: true)
        #expect(isCompact(layout))
        #expect(layout.dialDiameter == 200)
        #expect(layout.needsScrolling)
    }

    @Test(arguments: [4, 12])
    func displayZoomScrollsWithTheSmallestDial(beats: Int) {
        let layout = layout(width: 320, height: 548, beats: beats)
        #expect(layout.settingsTopGap == 16)
        #expect(layout.sectionGap == 16)
        #expect(layout.tileHeight == 56)
        #expect(layout.dialDiameter == 200)
        #expect(layout.bottomPadding == 16)
        #expect(layout.needsScrolling)
    }

    @Test func sideMarginsNarrowBelow360() {
        #expect(layout(width: 320, height: 548).sideMargin == 16)
        #expect(layout(width: 359, height: 647).sideMargin == 16)
        #expect(layout(width: 360, height: 647).sideMargin == 24)
        #expect(layout(width: 375, height: 647).sideMargin == 24)
        #expect(layout(width: 402, height: 778, hasBottomInset: true).sideMargin == 24)
    }
}
