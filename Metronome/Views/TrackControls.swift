import SwiftUI

/// The track arrangement's one row (6.12): −, the Tap pill, + and the time signature chip,
/// in place of the tempo controls and the time signature row.
struct TrackTempoRow: View {
    @Environment(MetronomeModel.self) private var model
    /// The screen's side margin, which the picker shares.
    var sideMargin: CGFloat = Theme.sideMargin
    @State private var isPickerShown = false

    private let height = ScreenLayout.trackRowHeight

    var body: some View {
        HStack(spacing: 8) {
            StepButton(symbol: "minus", label: "Slower", size: height) { model.nudgeBPM(by: -1) }
            // The shorter labels fit the narrower pill.
            TapTempoPill(
                idleLabel: "Tap", seriesLabel: "Again", height: height,
                iconSpacing: 6, horizontalPadding: 10, minimumScaleFactor: 0.6
            )
            StepButton(symbol: "plus", label: "Faster", size: height) { model.nudgeBPM(by: 1) }
            signatureChip
        }
        .frame(height: height)
    }

    /// The value and a chevron, with no label; opens the picker like the time signature row.
    private var signatureChip: some View {
        Button {
            isPickerShown = true
        } label: {
            HStack(spacing: 6) {
                Text(model.settings.timeSignature.rawValue)
                    .font(.system(size: 24, weight: .heavy))
                    .tracking(-0.48)
                    .foregroundStyle(Theme.amber)
                    .fixedSize()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 16, height: 16)
            }
            .padding(.leading, 14)
            .padding(.trailing, 10)
            .frame(height: height)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Time signature")
        .accessibilityValue(model.settings.timeSignature.rawValue)
        .accessibilityAddTraits(.isButton)
        .sheet(isPresented: $isPickerShown) {
            TimeSignaturePicker(selected: model.settings.timeSignature, sideMargin: sideMargin) { signature in
                model.selectTimeSignature(signature)
                isPickerShown = false
            }
        }
    }
}

/// The card below the tiles: the file's name and Sync, then the playback row.
/// Its height is fixed at `ScreenLayout.trackStripHeight`; it never shrinks.
struct TrackStrip: View {
    @Environment(MetronomeModel.self) private var model
    let openSync: () -> Void

    var body: some View {
        let isMissing = model.isTrackMissing
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "music.note")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.muted)
                    if isMissing {
                        Text("Track missing")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.amber)
                            .lineLimit(1)
                    } else {
                        Text(model.loadedTrack?.fileName ?? "")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.dialWhite)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(isMissing ? "Track missing" : "Backing track, \(model.loadedTrack?.fileName ?? "")")
                Spacer(minLength: 0)
                syncPill
                    .opacity(isMissing ? 0.4 : 1)
                    .allowsHitTesting(!isMissing)
                    .disabled(isMissing)
            }
            .frame(height: 30)
            TrackProgressBar()
        }
        .padding(.top, 12)
        .padding(.bottom, 12)
        .padding(.leading, 16)
        .padding(.trailing, 14)
        .frame(height: ScreenLayout.trackStripHeight)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var syncPill: some View {
        Button(action: openSync) {
            Text("Sync")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.dialWhite)
                .padding(.horizontal, 14)
                .frame(height: 30)
                .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
                // The pill is 30 pt tall; its touch area reaches 7 pt above and below.
                .contentShape(Capsule().inset(by: -7))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sync")
    }
}

/// Rewind, the line with its knob and times, and Fast-forward. Used by the track strip and
/// the Sync sheet. 44 pt tall.
struct TrackProgressBar: View {
    @Environment(MetronomeModel.self) private var model
    /// Where the knob has been dragged from and to. Gesture state goes back to nil when the
    /// drag is cancelled as well as when it ends, so the knob never sticks off the position.
    @GestureState private var drag: KnobDrag?
    /// The time the knob was last dragged to, sought when the finger lifts.
    @State private var dropTime: TimeInterval?

    private struct KnobDrag {
        let start: TimeInterval
        var time: TimeInterval
    }

    static let height: CGFloat = 44
    private static let skip: TimeInterval = 15
    private static let knobSize: CGFloat = 14
    private static let lineHeight: CGFloat = 4

    var body: some View {
        // The position is read from the engine and not observed, so it is redrawn while playing.
        if model.isPlaying {
            TimelineView(.periodic(from: .now, by: 0.1)) { _ in row }
        } else {
            row
        }
    }

    private var row: some View {
        let isMissing = model.isTrackMissing
        let canSkipForward = model.canSkipForward
        return HStack(spacing: 12) {
            SkipButton(symbol: "chevron.backward.2", label: "Back 15 seconds") {
                model.skipTrack(by: -Self.skip)
            }
            line(isMissing: isMissing)
            SkipButton(symbol: "chevron.forward.2", label: "Forward 15 seconds") {
                model.skipTrack(by: Self.skip)
            }
            .opacity(isMissing || canSkipForward ? 1 : 0.4)
            .disabled(!canSkipForward)
        }
        .frame(height: Self.height)
        .opacity(isMissing ? 0.4 : 1)
        .allowsHitTesting(!isMissing)
        .disabled(isMissing)
    }

    /// The line with the knob, and the times below it.
    private func line(isMissing: Bool) -> some View {
        let length = model.trackLength ?? 0
        let isCountingIn = model.isCountingIn
        let shown = drag?.time ?? model.trackTime
        let fraction = length > 0 ? min(max(shown / length, 0), 1) : 0
        return VStack(spacing: 0) {
            GeometryReader { proxy in
                // The knob's centre travels between the line's ends, so it never overhangs them.
                let travel = max(proxy.size.width - Self.knobSize, 1)
                let knobX = Self.knobSize / 2 + travel * fraction
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.line)
                        .frame(height: Self.lineHeight)
                    Capsule()
                        .fill(Theme.amber)
                        .frame(width: knobX, height: Self.lineHeight)
                    Circle()
                        .fill(Theme.dialWhite)
                        .frame(width: Self.knobSize, height: Self.knobSize)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .position(x: knobX, y: Self.knobSize / 2)
                        .gesture(knobDrag(travel: travel, length: length))
                }
                .frame(height: Self.knobSize)
            }
            .frame(height: Self.knobSize)
            .padding(.top, 15)
            HStack {
                if !isMissing {
                    Text(isCountingIn ? "Count-in" : TrackTime.label(shown))
                        .foregroundStyle(isCountingIn ? Theme.amber : Theme.muted)
                    Spacer(minLength: 8)
                    Text(TrackTime.label(length))
                        .foregroundStyle(Theme.muted)
                }
            }
            .font(.system(size: 13).monospacedDigit())
            .lineLimit(1)
            .frame(height: 15)
        }
        .frame(height: Self.height)
        .accessibilityElement(children: .ignore)
        .accessibilityValue(
            isCountingIn ? "Count-in" : "\(TrackTime.spoken(shown)) of \(TrackTime.spoken(length))"
        )
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: model.skipTrack(by: Self.skip)
            case .decrement: model.skipTrack(by: -Self.skip)
            @unknown default: break
            }
        }
    }

    /// The knob and the elapsed time follow the finger; the position changes on lift.
    private func knobDrag(travel: CGFloat, length: TimeInterval) -> some Gesture {
        func time(from start: TimeInterval, moved: CGFloat) -> TimeInterval {
            min(max(start + Double(moved / travel) * length, 0), length)
        }
        return DragGesture(minimumDistance: 1)
            .updating($drag) { value, state, _ in
                let start = state?.start ?? model.trackTime
                state = KnobDrag(start: start, time: time(from: start, moved: value.translation.width))
            }
            .onChanged { value in
                let start = drag?.start ?? model.trackTime
                dropTime = time(from: start, moved: value.translation.width)
            }
            .onEnded { _ in
                if let dropTime { model.seekTrack(to: dropTime) }
                dropTime = nil
            }
    }
}

/// Rewind and Fast-forward: 44 pt round on surface raised with a double chevron.
private struct SkipButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.dialWhite)
                .frame(width: 44, height: 44)
                .background(Theme.surfaceRaised, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
