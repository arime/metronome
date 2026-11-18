import SwiftUI

/// The track screen under the header (6.12): the dial as a locked gauge where the plain screen
/// has its dial, the Sync row where it has the time signature row, the accent tiles below it
/// and the player card pinned to the bottom. The layout sizes the dial by the plain screen's
/// rule; height still left over stays above the card.
struct TrackScreenContent: View {
    let layout: TrackScreenLayout

    init(layout: TrackScreenLayout) {
        self.layout = layout
    }

    var body: some View {
        VStack(spacing: 0) {
            TrackDial(diameter: layout.dialDiameter)
                .padding(.top, TrackScreenLayout.dialTopGap)
            SyncRow()
                .padding(.top, layout.rowTopGap)
            // Two-row signatures keep their 44 pt tiles whatever the single-row height is.
            AccentTiles(singleRowTileHeight: layout.tileHeight)
                .padding(.top, layout.rowBottomGap)
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
        // look, as only the Sync row is dimmed (6.12).
        .onTapGesture { model.enterSyncMode() }
        .disabled(model.isTrackMissing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tempo")
        .accessibilityValue("\(model.tempoInEffect) beats per minute")
        .accessibilityHint("Opens Sync mode")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { model.enterSyncMode() }
    }
}

/// Opens Sync mode, stopped or playing, from where the plain screen has the time signature
/// row, and built like it. Dimmed and doing nothing while the file is missing.
struct SyncRow: View {
    @Environment(MetronomeModel.self) private var model
    @ScaledMetric(relativeTo: .body) private var labelSize = 16.0

    var body: some View {
        let isMissing = model.isTrackMissing
        Button { model.enterSyncMode() } label: {
            HStack(spacing: 12) {
                Text("Sync backing track")
                    .font(.system(size: labelSize, weight: .medium))
                    .foregroundStyle(Theme.dialWhite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 16, height: 16)
            }
            .padding(.leading, 20)
            .padding(.trailing, 18)
            .frame(height: TrackScreenLayout.rowHeight)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .opacity(isMissing ? 0.4 : 1)
        .disabled(isMissing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sync backing track")
        .accessibilityAddTraits(.isButton)
    }
}
