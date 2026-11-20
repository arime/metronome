import SwiftUI

/// One song's tile in stage mode (9.4): its number and the track mark, `NEXT` or the track's time
/// on the top line, and the name with the tempo line or the beat dots at the bottom.
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
                .foregroundStyle(isPlaying ? Theme.ink : Theme.dialWhite)
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
        .background(fill, in: shape)
        .overlay {
            if tile.mark != .none {
                shape.strokeBorder(Theme.amber, lineWidth: 1.5)
            }
        }
        .shadow(color: isPlaying ? Theme.amber.opacity(0.28) : .clear, radius: 14)
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
        switch tile.mark {
        case .none: Theme.surface
        case .next: Theme.amberTint
        case .playing: Theme.amber
        }
    }

    private var numberColor: Color {
        switch tile.mark {
        case .none: Theme.mutedDim
        case .next: Theme.amber
        case .playing: Theme.ink
        }
    }

    private var topLine: some View {
        HStack(spacing: 8) {
            Text("\(tile.number)")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(numberColor)
            Spacer(minLength: 0)
            switch tile.mark {
            case .next:
                Text("NEXT")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.98)  // 0.18 em of 11 pt
                    .foregroundStyle(Theme.amber)
            case .playing:
                // The track's time is read from the engine and not observed, so it is redrawn
                // while playing, as the progress bar is.
                TimelineView(.animation(minimumInterval: 0.1, paused: !model.isPlaying)) { _ in
                    playingMark
                }
            case .none:
                trackMark(color: Theme.muted)
            }
        }
    }

    /// The track's time while a playable track plays; otherwise the track mark, in ink.
    @ViewBuilder
    private var playingMark: some View {
        if model.isPlayingTrack, let length = model.trackLength {
            Text(StageTile.trackTimeLabel(model.trackTime, of: length))
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
        } else {
            trackMark(color: Theme.ink)
        }
    }

    /// The library rows' music note, for a song with a backing track, whether or not its file is here.
    @ViewBuilder
    private func trackMark(color: Color) -> some View {
        if tile.song.track != nil {
            Image(systemName: "music.note")
                .font(.system(size: 16))
                .foregroundStyle(color)
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

/// The playing tile's beat dots, in ink: the current beat solid, the others at 28 %. A dot lights
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
                            .fill(Theme.ink)
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
