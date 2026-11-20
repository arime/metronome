import SwiftUI

/// The player card's Metronome content (6.7): the readout above the transport row of Previous,
/// the Start / Stop pill and Next.
struct MetronomeContent: View {
    @Environment(MetronomeModel.self) private var model

    var body: some View {
        VStack(spacing: 8) {
            PlayReadoutView()
                .frame(height: 82)
            transportRow
        }
    }

    /// Outside a setlist the places of Previous and Next stay empty, so the pill keeps its
    /// width and its place.
    private var transportRow: some View {
        let inSetlist = model.position != nil
        return HStack(spacing: 12) {
            if inSetlist {
                SongStepButton(symbol: "backward.end", label: "Previous song", isEnabled: model.canGoPrevious) {
                    model.goToPrevious()
                }
            } else {
                emptyPlace
            }
            StartStopButton()
            if inSetlist {
                SongStepButton(symbol: "forward.end", label: "Next song", isEnabled: model.canGoNext) {
                    model.goToNext()
                }
            } else {
                emptyPlace
            }
        }
        .frame(height: 68)
    }

    private var emptyPlace: some View {
        Color.clear.frame(width: SongStepButton.size, height: SongStepButton.size)
    }
}

/// The elapsed time at the left and the bar count at the right (6.7, 7.13), 26 pt in from the
/// card's edges. Read as one element; its changes are not announced.
struct PlayReadoutView: View {
    @Environment(MetronomeModel.self) private var model

    var body: some View {
        // The time runs with the clock, which is not observed, so it is read again while playing.
        TimelineView(.animation(minimumInterval: 0.25, paused: !model.isPlaying)) { _ in
            readout(model.readout())
        }
    }

    private func readout(_ readout: PlayReadout) -> some View {
        HStack(spacing: 8) {
            Text(readout.time)
                .font(.system(size: 34, weight: .medium).monospacedDigit())
                .tracking(-0.68)
                .foregroundStyle(Theme.dialWhite)
            Spacer(minLength: 0)
            Text(readout.bar)
                .font(.system(size: 15, weight: .medium).monospacedDigit())
                .foregroundStyle(Theme.muted)
        }
        .lineLimit(1)
        .padding(.horizontal, 10)
        .frame(maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(readout.spoken)
    }
}
