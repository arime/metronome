import CoreGraphics

/// The track screen's sizes (6.12). Every part keeps its size; the tempo reading takes the
/// height that is left, its room, and its number scales down only when the room is less
/// than the reading's full 152 pt.
struct TrackScreenLayout {
    let sideMargin: CGFloat
    let bottomPadding: CGFloat
    /// The height between the gap under the header and the accent tiles; the reading is
    /// centred in it.
    let readingRoom: CGFloat
    let numberFontSize: CGFloat
    /// The player card, with the next-up line when it is shown.
    let cardHeight: CGFloat
    let tilesHeight: CGFloat
    /// True when the next-up line is shown inside the player card.
    let showsNextLine: Bool

    /// The header of 6.1: 8 + 40.
    static let headerHeight: CGFloat = 48
    static let readingTopGap: CGFloat = 8
    /// The number's line, the gap and the time signature and Sync line: 108 + 10 + 34.
    static let readingHeight: CGFloat = 152
    static let fullNumberSize: CGFloat = 136
    /// The number's line at the full size; it is 108/136 of the font size at any size.
    static let numberLineHeight: CGFloat = 108
    static let readingLineGap: CGFloat = 10
    static let syncButtonHeight: CGFloat = 34
    static let tileHeight: CGFloat = 76
    /// The least space kept between the accent tiles and the player card.
    static let cardTopGap: CGFloat = 16
    /// The player card without the next-up line: 12 + 30 + 12 + 40 + 12 + 68 + 18.
    static let playerCardHeight: CGFloat = 192
    /// The next-up line inside the player card with its gap: 18 + 12.
    static let playerNextLineHeight: CGFloat = 30
    /// The next-up line is left out when it would leave the reading less room than this.
    static let nextLineMinimumRoom: CGFloat = 280
    /// A safety floor only; no supported iPhone gets near it.
    static let minimumNumberSize: CGFloat = 24

    init(width: CGFloat, height: CGFloat, hasBottomInset: Bool, beats: Int, hasSetlist: Bool) {
        sideMargin = width < ScreenLayout.narrowWidth ? ScreenLayout.narrowSideMargin : Theme.sideMargin
        // Phones with a home indicator already have the design's bottom margin.
        let bottomPadding: CGFloat = hasBottomInset ? 0 : 16
        self.bottomPadding = bottomPadding
        let tilesHeight = AccentTiles.height(forBeats: beats, singleRowTileHeight: Self.tileHeight)
        self.tilesHeight = tilesHeight

        func room(cardHeight: CGFloat) -> CGFloat {
            height - bottomPadding - Self.headerHeight - Self.readingTopGap - tilesHeight - Self.cardTopGap
                - cardHeight
        }

        let roomWithLine = room(cardHeight: Self.playerCardHeight + Self.playerNextLineHeight)
        if hasSetlist && roomWithLine >= Self.nextLineMinimumRoom {
            showsNextLine = true
            cardHeight = Self.playerCardHeight + Self.playerNextLineHeight
            readingRoom = roomWithLine
        } else {
            showsNextLine = false
            cardHeight = Self.playerCardHeight
            readingRoom = room(cardHeight: Self.playerCardHeight)
        }

        // The number's line is 108/136 of its font size; the rest of the reading keeps its 44 pt.
        let otherReadingHeight = Self.readingHeight - Self.numberLineHeight
        let fittingSize = (readingRoom - otherReadingHeight) * Self.fullNumberSize / Self.numberLineHeight
        numberFontSize = min(Self.fullNumberSize, max(Self.minimumNumberSize, fittingSize))
    }
}

/// Sync mode's sizes (6.13). The tap pad takes the height the other parts leave, down to
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

    static let headerHeight: CGFloat = 48
    static let rowTopGap: CGFloat = 16
    /// The time signature row of 6.4.
    static let rowHeight: CGFloat = 60
    static let tilesTopGap: CGFloat = 14
    /// Above and below the tap pad.
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
    static let compactTileHeight: CGFloat = 56

    /// Everything but the tap pad and the bottom padding: 484 pt plus the tiles.
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

        var tileHeight = TrackScreenLayout.tileHeight
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
