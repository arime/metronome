import SwiftUI

/// One song's tile in stage mode (9.4): its number and the track mark or the track's time on the
/// top line, and the name with the tempo line or the beat dots at the bottom.
struct StageTileView: View {
    @Environment(MetronomeModel.self) private var model
    let tile: StageTile
    let tap: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            topLine
                .frame(height: 18)
            Spacer(minLength: 0)
            Text(tile.song.name)
                .font(.system(size: 20, weight: .heavy))
                .tracking(-0.4)  // -0.02 em of 20 pt
                .foregroundStyle(Theme.dialWhite)
                .lineLimit(2)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
            bottomLine
                .padding(.top, 8)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        // A two-line name makes the row 120 pt: 14 + 18 + two 24 pt lines + 8 + 18 + 14, the 18 pt lines fixed.
        .frame(maxWidth: .infinity, minHeight: 112, maxHeight: .infinity, alignment: .leading)
        .modifier(StageTilePulse(shape: shape, fill: fill, isPlaying: isPlaying, lastBeat: model.lastBeat))
        .overlay {
            if tile.mark != .none {
                shape.strokeBorder(Theme.amber, lineWidth: 1.5)
            }
        }
        .opacity(tile.isDimmed ? 0.4 : 1)
        .contentShape(shape)
        // Takes a hold, which the tap would otherwise take as a tap once released.
        .onLongPressGesture {}
        .rowTap(tap)
        .accessibilityLabel(tile.accessibilityLabel)
        .disabled(tile.isDimmed)
    }

    private var isPlaying: Bool { tile.mark == .playing }

    private var fill: Color {
        tile.mark == .none ? Theme.surface : Theme.amberTint
    }

    private var topLine: some View {
        HStack(spacing: 8) {
            Text("\(tile.number)")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(tile.mark == .none ? Theme.mutedDim : Theme.amber)
            Spacer(minLength: 0)
            if isPlaying {
                // The track's time is read from the engine and not observed, so it is redrawn
                // while playing, as the progress bar is.
                TimelineView(.animation(minimumInterval: 0.1, paused: !model.isPlaying)) { _ in
                    playingMark
                }
            } else {
                trackMark
            }
        }
    }

    /// The track's time while a playable track plays; otherwise the track mark.
    @ViewBuilder
    private var playingMark: some View {
        if model.isPlayingTrack, let length = model.trackLength {
            Text(StageTile.trackTimeLabel(model.trackTime, of: length))
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.dialWhite)
                .lineLimit(1)
        } else {
            trackMark
        }
    }

    /// The library rows' music note, in muted, while the song's backing track will be used.
    @ViewBuilder
    private var trackMark: some View {
        if tile.showsTrackMark {
            Image(systemName: "music.note")
                .font(.system(size: 16))
                .foregroundStyle(Theme.muted)
        }
    }

    @ViewBuilder
    private var bottomLine: some View {
        if isPlaying {
            StageBeatDotsView(
                beatsPerBar: model.settings.timeSignature.beatsPerBar,
                accents: model.settings.accents,
                currentBeat: model.currentBeat)
                .frame(height: 18)
        } else {
            Text(tile.song.detail)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
                .frame(height: 18)
        }
    }
}

/// The tile's fill and, on the playing tile, the beat pulse: on every beat an amber wash over the
/// fill flashes to 30 % on an accented beat and 16 % on a plain one, and the amber glow around the
/// tile to 50 %, both fading over 0.25 s, the glow to a resting 15 %. Driven by the beat, as the
/// dial's number pulse is; with Reduce Motion on, the trigger never changes, so the wash stays off
/// and the glow rests.
private struct StageTilePulse: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let shape: RoundedRectangle
    let fill: Color
    let isPlaying: Bool
    let lastBeat: BeatEvent?

    func body(content: Content) -> some View {
        let washPeak = lastBeat?.isAccented == true ? 0.30 : 0.16
        let restingGlow = 0.15, peakGlow = 0.5
        content
            .keyframeAnimator(
                initialValue: 0.0,
                trigger: isPlaying && !reduceMotion ? lastBeat?.id : nil
            ) { view, level in
                // `level` runs 1 → 0 after each beat.
                view
                    .background {
                        ZStack {
                            shape.fill(fill)
                            if isPlaying {
                                shape.fill(Theme.amber.opacity(washPeak * level))
                            }
                        }
                    }
                    .shadow(
                        color: isPlaying
                            ? Theme.amber.opacity(restingGlow + (peakGlow - restingGlow) * level)
                            : .clear,
                        radius: 14)
            } keyframes: { _ in
                MoveKeyframe(1.0)
                LinearKeyframe(0.0, duration: 0.25, timingCurve: .easeOut)
            }
    }
}

/// The playing tile's beat dots, in amber: the current beat solid, the others at 28 %. A dot lights
/// on its beat at once, without animation, Reduce Motion or not.
struct StageBeatDotsView: View {
    let beatsPerBar: Int
    let accents: Set<Int>
    let currentBeat: Int?

    var body: some View {
        GeometryReader { proxy in
            // Laid out only once there is a width, as the layout scales by it.
            if proxy.size.width > 0 {
                let layout = StageBeatDots.layout(
                    beatsPerBar: beatsPerBar, accents: accents, availableWidth: proxy.size.width)
                HStack(spacing: layout.gap) {
                    ForEach(Array(layout.diameters.enumerated()), id: \.offset) { index, diameter in
                        Circle()
                            .fill(Theme.amber)
                            .frame(width: diameter, height: diameter)
                            .opacity(currentBeat == index + 1 ? 1 : 0.28)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .leading)
                .transaction { $0.animation = nil }
            }
        }
        .accessibilityHidden(true)
    }
}
