import SwiftUI

/// The track screen under the header (6.12): the tempo reading centred in its room, the accent
/// tiles directly below it and the player card pinned to the bottom. Every part but the
/// reading keeps its size; the layout gives the reading what is left.
struct TrackScreenContent: View {
    let layout: TrackScreenLayout

    init(layout: TrackScreenLayout) {
        self.layout = layout
    }

    var body: some View {
        VStack(spacing: 0) {
            TempoReading(numberFontSize: layout.numberFontSize)
                .frame(maxWidth: .infinity)
                .frame(height: max(0, layout.readingRoom))
                .padding(.top, TrackScreenLayout.readingTopGap)
            // Two-row signatures keep their 44 pt tiles whatever the single-row height is.
            AccentTiles(singleRowTileHeight: TrackScreenLayout.tileHeight)
            Spacer(minLength: TrackScreenLayout.cardTopGap)
            PlayerCard(showsNextLine: layout.showsNextLine)
        }
    }
}

/// The tempo in effect as one large number, and under it the time signature and the Sync
/// button. The number and the time signature are readouts and take no touches. While
/// playing the number marks every beat as the dial's number does (section 12): the glow flashes
/// behind it and it pulses, the pulse left out with Reduce Motion. It stays dial white.
struct TempoReading: View {
    @Environment(MetronomeModel.self) private var model
    private let numberFontSize: CGFloat

    init(numberFontSize: CGFloat) {
        self.numberFontSize = numberFontSize
    }

    /// The number's line is 108/136 of its font size.
    private var numberLineHeight: CGFloat {
        numberFontSize * TrackScreenLayout.numberLineHeight / TrackScreenLayout.fullNumberSize
    }

    var body: some View {
        VStack(spacing: TrackScreenLayout.readingLineGap) {
            number
            signatureLine
        }
    }

    /// The dial's glow, sized for this number as the dial's glow is for the dial's number.
    private var glowDiameter: CGFloat {
        numberFontSize * 300 / DialGeometry.fullNumberSize
    }

    /// The digits are set tight between digits only, as on the dial, so the last one is not
    /// clipped. The number never grows wider than the margins.
    private var numberText: AttributedString {
        var text = AttributedString("\(model.tempoInEffect)")
        text.kern = -0.05 * numberFontSize
        if let last = text.characters.indices.last {
            text[last...].kern = 0
        }
        return text
    }

    private var number: some View {
        Text(numberText)
            .font(.system(size: numberFontSize, weight: .heavy))
            .monospacedDigit()
            .foregroundStyle(Theme.dialWhite)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            // Scaled for width only: the glyphs are taller than the 108/136 line they sit in.
            .fixedSize(horizontal: false, vertical: true)
            .modifier(NumberPulse(lastBeat: model.lastBeat, bpm: model.tempoInEffect))
            .frame(maxWidth: .infinity)
            .frame(height: numberLineHeight)
            .background {
                // Stopped, there is no glow, even mid-fade.
                BeatGlow(lastBeat: model.lastBeat, bpm: model.tempoInEffect, diameter: glowDiameter)
                    .opacity(model.isPlaying ? 1 : 0)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Tempo")
            .accessibilityValue("\(model.tempoInEffect) beats per minute")
    }

    /// The time signature and, 12 pt to its right, Sync; centred as one line.
    private var signatureLine: some View {
        HStack(spacing: 12) {
            Text(model.settings.timeSignature.rawValue)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(Theme.muted)
                .fixedSize()
                .accessibilityLabel("Time signature")
                .accessibilityValue(model.settings.timeSignature.rawValue)
            SyncButton()
        }
        .frame(height: TrackScreenLayout.syncButtonHeight)
    }
}

/// Opens Sync mode, stopped or playing. Dimmed and doing nothing while the file is missing,
/// as Sync needs the file.
private struct SyncButton: View {
    @Environment(MetronomeModel.self) private var model

    /// The pill is 34 pt tall; its touch area is 44 pt, reaching 5 pt above and below.
    private static let touchHeight: CGFloat = 44

    var body: some View {
        let isMissing = model.isTrackMissing
        Button { model.enterSyncMode() } label: {
            Text("Sync")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.dialWhite)
                .padding(.horizontal, 18)
                .frame(height: TrackScreenLayout.syncButtonHeight)
                .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
                .frame(height: Self.touchHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isMissing ? 0.4 : 1)
        .disabled(isMissing)
        .accessibilityLabel("Sync")
    }
}
