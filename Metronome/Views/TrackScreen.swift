import SwiftUI

/// The track screen under the header (6.12): the dial as a locked gauge, at the plain screen's
/// place and size, the accent tiles below it and the player card pinned to the bottom. Height
/// left over stays above the card.
struct TrackScreenContent: View {
    let layout: TrackScreenLayout

    init(layout: TrackScreenLayout) {
        self.layout = layout
    }

    var body: some View {
        VStack(spacing: 0) {
            TrackDial(diameter: layout.dialDiameter)
                .padding(.top, TrackScreenLayout.dialTopGap)
            // Two-row signatures keep their 44 pt tiles whatever the single-row height is.
            AccentTiles(singleRowTileHeight: layout.tileHeight)
                .padding(.top, layout.tilesTopGap)
            Spacer(minLength: TrackScreenLayout.cardTopGap)
            PlayerCard(showsNextLine: layout.showsNextLine)
        }
    }
}

/// The dial as a gauge of the tempo in effect: the ticks lit to it, a flat disc and the
/// number. It never changes the tempo; a tap opens Sync mode, stopped or playing, and does
/// nothing while the file is missing, as Sync needs the file. While playing the number marks
/// every beat as on the plain screen (section 12).
struct TrackDial: View {
    @Environment(MetronomeModel.self) private var model
    let diameter: CGFloat

    var body: some View {
        ZStack {
            DialRing(fraction: Tempo.arcFraction(for: model.tempoInEffect), style: .gauge)
            // Stopped, there is no glow, even mid-fade.
            BeatGlow(lastBeat: model.lastBeat, bpm: model.tempoInEffect, diameter: diameter)
                .opacity(model.isPlaying ? 1 : 0)
            DialNumber(bpm: model.tempoInEffect, diameter: diameter)
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        // A tap gesture rather than a button: a finger that travels, a drag or a brush on
        // stage, opens nothing. There is no pressed state, and disabled the dial keeps its
        // look (6.12).
        .onTapGesture { model.enterSyncMode() }
        .disabled(model.isTrackMissing)
        // VoiceOver gets a real button, so it reads the dial as dimmed while the file is
        // missing, as the tap gesture alone cannot say (13).
        .accessibilityRepresentation {
            Button("Tempo") { model.enterSyncMode() }
                .accessibilityValue("\(model.tempoInEffect) beats per minute")
                .accessibilityHint("Opens Sync mode")
                .disabled(model.isTrackMissing)
        }
    }
}
