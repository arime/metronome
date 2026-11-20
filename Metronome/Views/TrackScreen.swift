import SwiftUI

/// The track screen under the header (6.12): the dial at the plain screen's place and size,
/// the accent tiles below it and the player card pinned to the bottom. Height left over stays
/// above the card.
struct TrackScreenContent: View {
    let layout: TrackScreenLayout

    init(layout: TrackScreenLayout) {
        self.layout = layout
    }

    var body: some View {
        VStack(spacing: 0) {
            TempoDial(diameter: layout.dialDiameter)
                .padding(.top, TrackScreenLayout.dialTopGap)
            // Two-row signatures keep their 44 pt tiles whatever the single-row height is.
            AccentTiles(singleRowTileHeight: layout.tileHeight)
                .padding(.top, layout.tilesTopGap)
            Spacer(minLength: TrackScreenLayout.cardTopGap)
            PlayerCard(showsNextLine: layout.showsNextLine)
        }
    }
}
