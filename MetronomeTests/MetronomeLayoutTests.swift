import CoreGraphics
import Testing
@testable import Metronome

/// Heights are inside the safe area. The header, the 4 pt below it and the player card take
/// 240 pt; the dial takes 0.9 of its diameter; the controls take 220 pt (250 pt with two rows
/// of tiles), or 172 pt (214 pt) when compact.
struct MetronomeLayoutTests {
    private func layout(
        width: CGFloat = 390, height: CGFloat, inset: Bool = true, beats: Int = 4
    ) -> MetronomeLayout {
        MetronomeLayout(width: width, height: height, hasBottomInset: inset, beats: beats)
    }

    /// Everything on the screen, top to bottom, fits in the height.
    private func fits(_ layout: MetronomeLayout, in height: CGFloat) -> Bool {
        MetronomeLayout.headerHeight + MetronomeLayout.dialTopGap + layout.dialFrameHeight
            + 2 * layout.controlsGap + layout.controlsHeight + MetronomeLayout.playerCardHeight
            + layout.bottomPadding <= height + 0.001
    }

    @Test func theDesignPhoneGetsTheFullDialAndEvenGaps() {
        let layout = layout(width: 390, height: 763)
        #expect(layout.dialDiameter == 264)
        #expect(!layout.isCompact)
        #expect(layout.rowHeight == 60)
        #expect(layout.innerGap == 16)
        #expect(layout.tileHeight == 68)
        #expect(layout.controlsHeight == 220)
        #expect(abs(layout.controlsGap - 32.7) < 0.01)
    }

    @Test func anIPhone17ProSpendsTheSpareHeightOnTheGaps() {
        let fourBeats = layout(width: 402, height: 778)
        #expect(fourBeats.dialDiameter == 264)
        #expect(abs(fourBeats.controlsGap - 40.2) < 0.01)

        let twelveBeats = layout(width: 402, height: 778, beats: 12)
        #expect(twelveBeats.dialDiameter == 264)
        #expect(twelveBeats.controlsHeight == 250)
        #expect(abs(twelveBeats.controlsGap - 25.2) < 0.01)
    }

    @Test func theGapsShrinkTo16BeforeTheDial() {
        let atSixteen = layout(width: 390, height: 729.6)
        #expect(atSixteen.dialDiameter == 264)
        #expect(abs(atSixteen.controlsGap - 16) < 0.01)

        let shorter = layout(width: 390, height: 719.6)
        #expect(shorter.dialDiameter == 252)
        #expect(shorter.controlsGap >= 16)
    }

    @Test func theDialShrinksTo200BeforeTheControlsTurnCompact() {
        let smallestRoomy = layout(width: 390, height: 672)
        #expect(smallestRoomy.dialDiameter == 200)
        #expect(!smallestRoomy.isCompact)

        #expect(layout(width: 390, height: 671).isCompact)
    }

    @Test func anIPhoneSEIsCompact() {
        let fourBeats = layout(width: 375, height: 647, inset: false)
        #expect(fourBeats.bottomPadding == 16)
        #expect(fourBeats.isCompact)
        #expect(fourBeats.rowHeight == 48)
        #expect(fourBeats.innerGap == 10)
        #expect(fourBeats.tileHeight == 56)
        #expect(fourBeats.controlsHeight == 172)
        #expect(fourBeats.dialDiameter == 221)
        #expect(fourBeats.controlsGap >= 10)

        let twelveBeats = layout(width: 375, height: 647, inset: false, beats: 12)
        #expect(twelveBeats.controlsHeight == 214)
        #expect(twelveBeats.dialDiameter == 174)
    }

    @Test func displayZoomGetsASmallDial() {
        let fourBeats = layout(width: 320, height: 548, inset: false)
        #expect(fourBeats.sideMargin == 16)
        #expect(fourBeats.dialDiameter == 111)

        let twelveBeats = layout(width: 320, height: 548, inset: false, beats: 12)
        #expect(twelveBeats.dialDiameter == 64)
        #expect(twelveBeats.controlsGap >= 10)
    }

    @Test func everythingFitsOnEveryPhone() {
        for width: CGFloat in [320, 375, 390, 402, 440] {
            for height in stride(from: CGFloat(450), through: 960, by: 5) {
                for beats in [2, 4, 7, 9, 12] {
                    for inset in [true, false] {
                        let layout = layout(width: width, height: height, inset: inset, beats: beats)
                        let label = "\(width) × \(height), \(beats) beats, inset \(inset)"
                        #expect(fits(layout, in: height), "\(label)")
                        #expect(layout.dialDiameter <= MetronomeLayout.maximumDial, "\(label)")
                        #expect(layout.dialDiameter == layout.dialDiameter.rounded(.down), "\(label)")
                        if layout.dialDiameter > MetronomeLayout.minimumDial {
                            let leastGap = layout.isCompact ? MetronomeLayout.compactGap : MetronomeLayout.roomyGap
                            #expect(layout.controlsGap >= leastGap - 0.001, "\(label)")
                        }
                    }
                }
            }
        }
    }

    @Test func theDialNeverCollapses() {
        #expect(layout(width: 375, height: 300, inset: false).dialDiameter == 40)
    }

    @Test func sideMarginsNarrowBelow360() {
        #expect(layout(width: 320, height: 763).sideMargin == 16)
        #expect(layout(width: 359, height: 763).sideMargin == 16)
        #expect(layout(width: 360, height: 763).sideMargin == 24)
        #expect(layout(width: 402, height: 763).sideMargin == 24)
    }
}
