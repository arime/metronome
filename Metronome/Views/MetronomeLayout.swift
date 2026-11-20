import CoreGraphics

/// Fits the metronome screen into the height inside the safe area (specification 6.8). The
/// header and the player card never change; the spare height goes to the two equal gaps
/// around the controls. On a shorter screen the gaps shrink to 16 pt, then the dial to
/// 200 pt, then the controls turn compact, and then the dial shrinks as far as it must.
struct MetronomeLayout: Equatable {
    let sideMargin: CGFloat
    /// The margin kept below the player card on phones without a home indicator.
    let bottomPadding: CGFloat
    /// A whole number of points.
    let dialDiameter: CGFloat
    /// The tempo controls and the time signature row.
    let rowHeight: CGFloat
    /// Above the time signature row and above the accent tiles.
    let innerGap: CGFloat
    /// The height of a tile when all beats fit in one row.
    let tileHeight: CGFloat
    /// The tempo controls, the time signature row, the accent tiles and the gaps between them.
    let controlsHeight: CGFloat
    /// Above the controls, from the knob's lower edge, and below them, to the player card.
    let controlsGap: CGFloat
    let isCompact: Bool

    /// The header: 8 pt above its 40 pt row, and the row.
    static let headerHeight: CGFloat = 48
    /// The gap between the header and the dial's square.
    static let dialTopGap: CGFloat = 4
    static let playerCardHeight: CGFloat = 188
    static let maximumDial: CGFloat = 264
    /// The dial shrinks this far before the controls turn compact.
    static let roomyMinimumDial: CGFloat = 200
    /// A safety floor only; the smallest supported iPhone gets 64 pt.
    static let minimumDial: CGFloat = 40
    /// The least gap around the controls, roomy and compact.
    static let roomyGap: CGFloat = 16
    static let compactGap: CGFloat = 10
    /// Screens narrower than this get the narrow side margins.
    static let narrowWidth: CGFloat = 360
    static let narrowSideMargin: CGFloat = 16

    /// The knob's lower edge is 0.9 dial diameters below the dial's top.
    private static let dialFrameRatio: CGFloat = 0.9
    /// Absorbs floating-point error, so that a dial that fits exactly is not lost by rounding.
    private static let tolerance: CGFloat = 0.001

    /// The dial's height down to the knob's lower edge: the frame the screen stacks it in.
    var dialFrameHeight: CGFloat { Self.dialFrameRatio * dialDiameter }

    /// `height` is inside the safe area.
    init(width: CGFloat, height: CGFloat, hasBottomInset: Bool, beats: Int) {
        sideMargin = width < Self.narrowWidth ? Self.narrowSideMargin : Theme.sideMargin
        // Phones with a home indicator already have a margin below the card.
        bottomPadding = hasBottomInset ? 0 : 16
        let available = height - bottomPadding
        let fixed = Self.headerHeight + Self.dialTopGap + Self.playerCardHeight

        func controls(rowHeight: CGFloat, innerGap: CGFloat, tileHeight: CGFloat) -> CGFloat {
            2 * rowHeight + 2 * innerGap + AccentTiles.height(forBeats: beats, singleRowTileHeight: tileHeight)
        }
        /// The dial that fills the height left with the least gaps, before limits and rounding.
        func spareDial(controls: CGFloat, gap: CGFloat) -> CGFloat {
            (available - fixed - controls - 2 * gap) / Self.dialFrameRatio
        }

        let roomyControls = controls(rowHeight: 60, innerGap: 16, tileHeight: 68)
        let roomyDial = spareDial(controls: roomyControls, gap: Self.roomyGap)
        let dial: CGFloat
        if roomyDial + Self.tolerance >= Self.roomyMinimumDial {
            isCompact = false
            rowHeight = 60
            innerGap = 16
            tileHeight = 68
            controlsHeight = roomyControls
            dial = min(Self.maximumDial, roomyDial)
        } else {
            isCompact = true
            rowHeight = 48
            innerGap = 10
            tileHeight = 56
            controlsHeight = controls(rowHeight: 48, innerGap: 10, tileHeight: 56)
            let compactDial = spareDial(controls: controlsHeight, gap: Self.compactGap)
            dial = min(Self.maximumDial, max(Self.minimumDial, compactDial))
        }
        dialDiameter = (dial + Self.tolerance).rounded(.down)
        controlsGap = (available - fixed - Self.dialFrameRatio * dialDiameter - controlsHeight) / 2
    }
}
