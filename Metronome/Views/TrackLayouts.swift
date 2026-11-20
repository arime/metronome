import CoreGraphics

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
        sideMargin = width < MetronomeLayout.narrowWidth ? MetronomeLayout.narrowSideMargin : Theme.sideMargin
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
