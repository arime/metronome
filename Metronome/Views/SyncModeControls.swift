import SwiftUI

/// Sync mode's small spaced-out capitals: `TEMPO`, `OFFSET`, `COUNT-IN` and `MIX`.
private struct SyncLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(2)
            .foregroundStyle(Theme.muted)
            .lineLimit(1)
    }
}

/// The column the count-in and mix labels stand in, so their rows line up.
private let labelColumnWidth: CGFloat = 76

/// Tempo and Offset side by side, 10 pt apart, sharing the width equally. − and + repeat while
/// held; a change applies at once. Tapping the tempo value opens the tempo sheet for the track's
/// tempo.
struct SyncSteppers: View {
    @Environment(MetronomeModel.self) private var model
    @State private var isEntryShown = false

    var body: some View {
        let bpm = model.loadedTrack?.bpm ?? model.tempoInEffect
        let seconds = Self.seconds(model.loadedTrack?.offset ?? 0)
        HStack(spacing: 10) {
            SyncStepper(
                label: "TEMPO", value: "\(bpm)", unit: nil,
                spokenName: "Tempo", spokenValue: "\(bpm) beats per minute",
                less: ("Slower", { model.nudgeTrackTempo(by: -1) }),
                more: ("Faster", { model.nudgeTrackTempo(by: 1) }),
                typeValue: { isEntryShown = true }
            )
            SyncStepper(
                label: "OFFSET", value: seconds, unit: "s",
                spokenName: "Offset", spokenValue: "\(seconds) seconds",
                less: ("Earlier", { model.nudgeOffset(by: -1) }),
                more: ("Later", { model.nudgeOffset(by: 1) })
            )
        }
        .frame(height: SyncModeLayout.stepperHeight)
        .sheet(isPresented: $isEntryShown) {
            TempoEntrySheet(current: bpm) { model.setTrackTempo($0) }
                .environment(model)
        }
    }

    /// Hundredths of a second with two decimals, worked out in whole numbers: 48 is `0.48`, 2540 is `25.40`.
    static func seconds(_ hundredths: Int) -> String {
        let fraction = hundredths % 100
        return "\(hundredths / 100).\(fraction < 10 ? "0" : "")\(fraction)"
    }
}

/// A label and, 6 pt below it, a 48 pt surface capsule holding −, the value and +. The value is
/// scaled down rather than cut when it is wider than the room between the buttons. With
/// `typeValue`, tapping the value types a new one.
private struct SyncStepper: View {
    let label: String
    let value: String
    let unit: String?
    let spokenName: String
    let spokenValue: String
    let less: (label: String, step: () -> Void)
    let more: (label: String, step: () -> Void)
    var typeValue: (() -> Void)?

    private static let pillHeight: CGFloat = 48
    private static let buttonSize: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SyncLabel(text: label)
                .frame(height: SyncModeLayout.stepperHeight - 6 - Self.pillHeight, alignment: .leading)
            HStack(spacing: 0) {
                button("minus", less)
                valueText
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { typeValue?() }
                    .allowsHitTesting(typeValue != nil)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(spokenName)
                    .accessibilityValue(spokenValue)
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: more.step()
                        case .decrement: less.step()
                        @unknown default: break
                        }
                    }
                    .accessibilityActions {
                        if let typeValue { Button("Type a tempo", action: typeValue) }
                    }
                button("plus", more)
            }
            .padding(4)
            .frame(height: Self.pillHeight)
            .background(Theme.surface, in: Capsule())
        }
    }

    private func button(_ symbol: String, _ action: (label: String, step: () -> Void)) -> some View {
        StepButton(
            symbol: symbol, label: action.label, size: Self.buttonSize, fill: Theme.surfaceRaised, symbolSize: 18,
            step: action.step
        )
    }

    /// One text, so the value and its unit scale down together; the unit stands 3 pt after the value.
    private var valueText: some View {
        var number = AttributedString(value)
        if unit != nil, let last = number.characters.indices.last {
            number[last...].kern = 3
        }
        var text = Text(number)
            .font(.system(size: 22, weight: .heavy).monospacedDigit())
            .foregroundStyle(Theme.dialWhite)
        if let unit {
            text = text + Text(unit)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.amber)
        }
        return text
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}

/// `COUNT-IN` and the three options, 6 pt apart; the selected one is `#3A3A40`, nothing amber.
struct CountInRow: View {
    @Environment(MetronomeModel.self) private var model

    private static let selectedFill = Color(hex: 0x3A3A40)

    var body: some View {
        HStack(spacing: 12) {
            SyncLabel(text: "COUNT-IN")
                .frame(width: labelColumnWidth, alignment: .leading)
            HStack(spacing: 6) {
                ForEach(CountIn.allCases, id: \.self, content: option)
            }
        }
        .frame(height: SyncModeLayout.countInHeight)
    }

    private func option(_ countIn: CountIn) -> some View {
        let isSelected = model.loadedTrack?.countIn == countIn
        let title = switch countIn {
        case .off: "Off"
        case .oneBar: "1 bar"
        case .twoBars: "2 bars"
        }
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return Button {
            model.setCountIn(countIn)
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.dialWhite)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: SyncModeLayout.countInHeight)
                .background(isSelected ? Self.selectedFill : Theme.surface, in: shape)
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Count-in, \(title)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// `MIX`, then `Click`, the mix slider and `Track`, 12 pt apart.
struct MixRow: View {
    @Environment(MetronomeModel.self) private var model

    var body: some View {
        HStack(spacing: 12) {
            SyncLabel(text: "MIX")
                .frame(width: labelColumnWidth, alignment: .leading)
            Text("Click")
            MixSlider(position: model.loadedTrack?.mix ?? 0) { model.setMix($0) }
            Text("Track")
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Theme.dialWhite)
        .lineLimit(1)
        .frame(height: SyncModeLayout.mixHeight)
    }
}

/// The mix between click and track: a line with a centre mark, and a knob that catches at the
/// centre. The line between the centre and the knob is amber. It reports positions in steps of
/// 0.5 dB, and only when the step changes.
struct MixSlider: View {
    let position: Double
    let onChange: (Double) -> Void

    /// The knob's centre where the drag began; back to nil when the drag ends or is cancelled.
    @GestureState private var dragStart: CGFloat?

    private static let bandHeight: CGFloat = 22
    private static let knobSize: CGFloat = 14
    private static let lineHeight: CGFloat = 4
    private static let touchSize: CGFloat = 44

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let midY = proxy.size.height / 2
            // The knob's centre travels between the line's ends, so it never overhangs them.
            let inset = Self.knobSize / 2
            let travel = max(width - Self.knobSize, 1)
            let centre = width / 2
            let knobX = inset + travel * (min(max(position, -1), 1) + 1) / 2
            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(Theme.line)
                    .frame(width: width, height: Self.lineHeight)
                    .position(x: centre, y: midY)
                Rectangle()
                    .fill(Theme.amber)
                    .frame(width: abs(knobX - centre), height: Self.lineHeight)
                    .position(x: (knobX + centre) / 2, y: midY)
                Rectangle()
                    .fill(Theme.tick)
                    .frame(width: 2, height: 12)
                    .position(x: centre, y: midY)
                Circle()
                    .fill(Theme.dialWhite)
                    .frame(width: Self.knobSize, height: Self.knobSize)
                    // The touch area reaches past the band, to at least 44 × 44.
                    .frame(width: Self.touchSize, height: Self.touchSize)
                    .contentShape(Rectangle())
                    .position(x: knobX, y: midY)
                    .gesture(knobDrag(knobX: knobX, inset: inset, travel: travel))
            }
        }
        .frame(height: Self.bandHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityValue(TrackMix.spoken(position))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onChange(TrackMix.nextSpokenStep(from: position, upward: true))
            case .decrement: onChange(TrackMix.nextSpokenStep(from: position, upward: false))
            @unknown default: break
            }
        }
    }

    private func knobDrag(knobX: CGFloat, inset: CGFloat, travel: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .updating($dragStart) { _, start, _ in
                if start == nil { start = knobX }
            }
            .onChanged { value in
                let x = (dragStart ?? knobX) + value.translation.width
                let next = TrackMix.quantised(TrackMix.position(forKnobAt: x - inset, width: travel))
                if next != position { onChange(next) }
            }
    }
}

/// Sync mode's card at the bottom: the progress bar and, 14 pt below it, To the beginning,
/// Rewind, play / stop, Fast-forward and To the end, spread evenly with the outer two at the
/// edges. No file name, no Previous or Next song and no next-up line.
struct PlaybackCard: View {
    @Environment(MetronomeModel.self) private var model

    private static let transportHeight: CGFloat = 56

    var body: some View {
        VStack(spacing: 14) {
            TrackProgressBar()
            HStack(spacing: 0) {
                TrackEndButton(isEnd: false)
                Spacer(minLength: 0)
                TrackSkipButton(isForward: false)
                Spacer(minLength: 0)
                SyncPlayStopButton()
                Spacer(minLength: 0)
                TrackSkipButton(isForward: true)
                Spacer(minLength: 0)
                TrackEndButton(isEnd: true)
            }
            .frame(height: Self.transportHeight)
        }
        .padding(.top, 12)
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
        .frame(height: SyncModeLayout.playbackCardHeight, alignment: .top)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

/// To the beginning and To the end: the arrow against a bar of Previous and Next song, with no
/// fill. Never dimmed.
private struct TrackEndButton: View {
    @Environment(MetronomeModel.self) private var model
    let isEnd: Bool

    var body: some View {
        Button {
            if isEnd { model.goToTrackEnd() } else { model.goToTrackStart() }
        } label: {
            Image(systemName: isEnd ? "forward.end" : "backward.end")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.dialWhite)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isEnd ? "To the end" : "To the beginning")
    }
}

/// The playback card's Start / Stop: a 56 pt amber circle with no glow, an ink play symbol when
/// stopped and an ink square while playing.
private struct SyncPlayStopButton: View {
    @Environment(MetronomeModel.self) private var model

    private static let size: CGFloat = 56

    var body: some View {
        let isPlaying = model.isPlaying
        Button {
            model.togglePlayback()
        } label: {
            ZStack {
                if isPlaying {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Theme.ink)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        // The triangle's weight sits left of its frame's centre.
                        .offset(x: 2)
                }
            }
            .frame(width: Self.size, height: Self.size)
            .background(Theme.amber, in: Circle())
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? "Stop" : "Start")
    }
}
