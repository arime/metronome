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
/// playing the number lights amber on every beat, with a glow behind it, and fades back to
/// dial white before the next beat (section 12). It never scales, so Reduce Motion leaves
/// it as it is.
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
            KeyframeAnimator(initialValue: 0.0, trigger: model.lastBeat?.id) { level in
                // Stopped, the number is dial white with no glow, even mid-fade.
                number(level: model.isPlaying ? level : 0)
            } keyframes: { _ in
                // Replayed on every beat: jump to full, then decay. Setting a value and
                // animating it back in one update could be merged away before it was drawn.
                MoveKeyframe(1.0)
                CubicKeyframe(0.0, duration: BeatPulse.decay(bpm: model.tempoInEffect))
            }
            signatureLine
        }
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

    private func number(level: Double) -> some View {
        Text(numberText)
            .font(.system(size: numberFontSize, weight: .heavy))
            .monospacedDigit()
            .foregroundStyle(Theme.dialWhite.mix(with: Theme.amber, by: level))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            // Scaled for width only: the glyphs are taller than the 108/136 line they sit in.
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .frame(height: numberLineHeight)
            .background { ReadingGlow().opacity(level) }
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

/// The amber glow behind the tempo reading's number: an ellipse 360 × 270 pt, 20 % at its
/// centre and clear from 68 % of the way out. Its opacity is the pulse's level.
private struct ReadingGlow: View {
    var body: some View {
        EllipticalGradient(
            stops: [
                .init(color: Theme.amber.opacity(0.20), location: 0),
                .init(color: Theme.amber.opacity(0), location: 0.68),
            ],
            center: .center,
            startRadiusFraction: 0,
            endRadiusFraction: 0.5
        )
        .frame(width: 360, height: 270)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
