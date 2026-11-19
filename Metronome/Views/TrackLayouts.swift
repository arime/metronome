import CoreGraphics

/// The track screen's sizes (6.12), taken from the plain layout (6.8) for the same screen,
/// time signature and setlist: the side margins, the bottom padding, the dial's diameter, the
/// single-row tile height, the gap above the tiles and whether the next-up line shows. So the
/// dial has the same place and size on both screens. The plain layout always leaves room, as
/// the tiles and the player card need less height than the plain screen's parts below its
/// dial; height left over stays between the tiles and the card.
struct TrackScreenLayout {
    let sideMargin: CGFloat
    let bottomPadding: CGFloat
    let dialDiameter: CGFloat
    /// Between the dial and the accent tiles.
    let tilesTopGap: CGFloat
    /// Single-row accent tiles; two rows keep their 44 pt whatever this is.
    let tileHeight: CGFloat
    /// The player card, with the next-up line when it is shown.
    let cardHeight: CGFloat
    /// The accent tiles at `tileHeight`.
    let tilesHeight: CGFloat
    /// True when the next-up line is shown inside the player card.
    let showsNextLine: Bool

    /// The header of 6.1: 8 + 40.
    static let headerHeight: CGFloat = 48
    static let dialTopGap: CGFloat = 12
    /// The least space kept between the accent tiles and the player card.
    static let cardTopGap: CGFloat = 16
    /// The player card without the next-up line: 12 + 30 + 12 + 40 + 12 + 68 + 18.
    static let playerCardHeight: CGFloat = 192
    /// The next-up line inside the player card with its gap: 18 + 12.
    static let playerNextLineHeight: CGFloat = 30

    init(width: CGFloat, height: CGFloat, hasBottomInset: Bool, beats: Int, hasSetlist: Bool) {
        let plain = ScreenLayout(
            width: width, height: height, hasBottomInset: hasBottomInset, beats: beats, hasSetlist: hasSetlist
        )
        sideMargin = plain.sideMargin
        bottomPadding = plain.bottomPadding
        dialDiameter = plain.dialDiameter
        tilesTopGap = plain.settingsTopGap
        tileHeight = plain.tileHeight
        showsNextLine = plain.showsNextLine
        tilesHeight = AccentTiles.height(forBeats: beats, singleRowTileHeight: plain.tileHeight)
        cardHeight = Self.playerCardHeight + (plain.showsNextLine ? Self.playerNextLineHeight : 0)
    }
}

/// Sync mode's sizes (6.13). The tap pads take the height the other parts leave, down to
/// 72 pt; below that single-row tiles shrink, and then the area between the header and
/// the playback card scrolls.
struct SyncModeLayout {
    let sideMargin: CGFloat
    let bottomPadding: CGFloat
    /// Single-row accent tiles; two rows keep their 44 pt whatever this is.
    let tileHeight: CGFloat
    let padHeight: CGFloat
    /// How far the area between the header and the playback card scrolls; 0 when it fits.
    let scrollOverflow: CGFloat
    /// The hand icon is left out on a short pad.
    let showsHandIcon: Bool

    /// The sheet's title row: room for the grabber above it, then `Sync` and the file name.
    static let headerHeight: CGFloat = 78
    static let headerTopGap: CGFloat = 28
    static let rowTopGap: CGFloat = 16
    /// The time signature row of 6.4.
    static let rowHeight: CGFloat = 60
    static let tilesTopGap: CGFloat = 14
    /// Above and below the tap pads.
    static let padGap: CGFloat = 14
    /// The label, 6 and the 48 pt pill.
    static let stepperHeight: CGFloat = 70
    static let countInTopGap: CGFloat = 14
    static let countInHeight: CGFloat = 40
    static let mixTopGap: CGFloat = 10
    static let mixHeight: CGFloat = 32
    /// The least space kept between the mix row and the playback card.
    static let cardTopGap: CGFloat = 16
    static let playbackCardHeight: CGFloat = 136
    static let minimumPad: CGFloat = 72
    static let handIconMinimumPad: CGFloat = 120
    static let fullTileHeight: CGFloat = 76
    static let compactTileHeight: CGFloat = 56

    /// Everything but the tap pads and the bottom padding: 514 pt plus the tiles.
    static func partsHeight(tilesHeight: CGFloat) -> CGFloat {
        headerHeight + rowTopGap + rowHeight + tilesTopGap + tilesHeight + padGap * 2 + stepperHeight
            + countInTopGap + countInHeight + mixTopGap + mixHeight + cardTopGap + playbackCardHeight
    }

    init(width: CGFloat, height: CGFloat, hasBottomInset: Bool, beats: Int) {
        sideMargin = width < ScreenLayout.narrowWidth ? ScreenLayout.narrowSideMargin : Theme.sideMargin
        // Phones with a home indicator already have the design's bottom margin.
        let bottomPadding: CGFloat = hasBottomInset ? 0 : 16
        self.bottomPadding = bottomPadding

        func pad(tileHeight: CGFloat) -> CGFloat {
            let tiles = AccentTiles.height(forBeats: beats, singleRowTileHeight: tileHeight)
            return height - bottomPadding - Self.partsHeight(tilesHeight: tiles)
        }

        var tileHeight = Self.fullTileHeight
        var padHeight = pad(tileHeight: tileHeight)
        if padHeight < Self.minimumPad {
            tileHeight = Self.compactTileHeight
            padHeight = pad(tileHeight: tileHeight)
        }
        self.tileHeight = tileHeight
        scrollOverflow = max(0, Self.minimumPad - padHeight)
        self.padHeight = max(Self.minimumPad, padHeight)
        showsHandIcon = self.padHeight >= Self.handIconMinimumPad
    }
}
