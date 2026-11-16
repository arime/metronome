import SwiftUI

/// Lines the click up with the backing track (specification 6.13, 7.11): playback, the tempo,
/// the offset, the count-in and the mix. Changes apply at once; closing leaves playback as it is.
struct SyncSheet: View {
    @Environment(MetronomeModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    /// The sheet's height. Starts near the usual height, then follows the content.
    @State private var sheetHeight: CGFloat = 640

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Sync")
                        .font(.system(size: 26, weight: .heavy))
                        .tracking(-0.52)
                        .foregroundStyle(Theme.dialWhite)
                    Spacer()
                }
                // An overlay, so its 44 × 44 touch area does not make the title row taller.
                .overlay(alignment: .trailing) { doneButton }
                HStack(spacing: 10) {
                    PlayStopButton()
                    TrackSkipButton(isForward: false)
                    TrackProgressBar()
                        // The line, not the times below it, lines up with the buttons' centres.
                        .alignmentGuide(VerticalAlignment.center) { _ in TrackProgressBar.bandHeight / 2 }
                    TrackSkipButton(isForward: true)
                }
                group("TEMPO") {
                    tempoRow
                }
                group("OFFSET") {
                    offsetRow
                    TapBeatOnePill()
                        .padding(.top, 10)
                }
                group("COUNT-IN") {
                    HStack(spacing: 8) {
                        ForEach(CountIn.allCases, id: \.self, content: countInOption)
                    }
                }
                group("MIX") {
                    HStack(spacing: 12) {
                        Text("Click")
                        MixSlider(position: model.loadedTrack?.mix ?? 0) { model.setMix($0) }
                        Text("Track")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.dialWhite)
                    .frame(height: 44)
                }
            }
            .padding(.horizontal, Theme.sideMargin)
            .padding(.top, 36)
            .padding(.bottom, 24)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height.rounded(.up)
            } action: { height in
                sheetHeight = height
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Theme.surface)
        .preferredColorScheme(.dark)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(Theme.surface)
        // There is nothing to sync once the file cannot play, for example when another
        // device removed the track.
        .onChange(of: model.isTrackPlayable) { _, isPlayable in
            if !isPlayable { dismiss() }
        }
        // However the sheet closes, what was set in it is saved and sent now.
        .onDisappear { model.savePendingChanges() }
    }

    /// The text is drawn as before, at the row's right edge; the touch area is at least 44 × 44.
    private var doneButton: some View {
        Button { dismiss() } label: {
            Text("Done")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.amber)
                .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// A label 8 pt above its row.
    private func group(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: label)
                .padding(.bottom, 8)
            content()
        }
    }

    /// − and + around a value with its unit in amber; − and + repeat while held. For VoiceOver
    /// the value is adjustable, one step at a time.
    private func valueRow(
        _ name: String, value: String, unit: String, spokenValue: String,
        less: (label: String, step: () -> Void), more: (label: String, step: () -> Void)
    ) -> some View {
        HStack(spacing: 12) {
            StepButton(symbol: "minus", label: less.label, size: 56, fill: Theme.surfaceRaised, step: less.step)
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.system(size: 48, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(Theme.dialWhite)
                Text(unit)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.amber)
            }
            .lineLimit(1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(name)
            .accessibilityValue(spokenValue)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: more.step()
                case .decrement: less.step()
                @unknown default: break
                }
            }
            Spacer(minLength: 0)
            StepButton(symbol: "plus", label: more.label, size: 56, fill: Theme.surfaceRaised, step: more.step)
        }
        .frame(height: 56)
    }

    private var tempoRow: some View {
        let bpm = model.loadedTrack?.bpm ?? model.tempoInEffect
        return valueRow(
            "Tempo", value: "\(bpm)", unit: "BPM", spokenValue: "\(bpm) beats per minute",
            less: ("Slower", { model.nudgeTrackTempo(by: -1) }),
            more: ("Faster", { model.nudgeTrackTempo(by: 1) })
        )
    }

    private var offsetRow: some View {
        let seconds = Self.seconds(model.loadedTrack?.offset ?? 0)
        return valueRow(
            "Offset", value: seconds, unit: "s", spokenValue: "\(seconds) seconds",
            less: ("Earlier", { model.nudgeOffset(by: -1) }),
            more: ("Later", { model.nudgeOffset(by: 1) })
        )
    }

    /// Hundredths of a second with two decimals, worked out in whole numbers: 48 is `0.48`, 130 is `1.30`.
    private static func seconds(_ hundredths: Int) -> String {
        let fraction = hundredths % 100
        return "\(hundredths / 100).\(fraction < 10 ? "0" : "")\(fraction)"
    }

    private func countInOption(_ countIn: CountIn) -> some View {
        let isSelected = model.loadedTrack?.countIn == countIn
        let title = switch countIn {
        case .off: "Off"
        case .oneBar: "1 bar"
        case .twoBars: "2 bars"
        }
        return Button {
            model.setCountIn(countIn)
        } label: {
            Text(title)
                .font(.system(size: 16, weight: isSelected ? .heavy : .bold))
                .foregroundStyle(isSelected ? Theme.ink : Theme.dialWhite)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    isSelected ? Theme.amber : Theme.surfaceRaised,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .shadow(color: isSelected ? Theme.amber.opacity(0.35) : .clear, radius: 14)
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Count-in, \(title)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Plays from the position with no count-in, or stops. 52 pt round.
private struct PlayStopButton: View {
    @Environment(MetronomeModel.self) private var model

    var body: some View {
        let isPlaying = model.isPlaying
        Button {
            model.toggleTrackPlaybackWithoutCountIn()
        } label: {
            Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(isPlaying ? Theme.amber : Theme.ink)
                .frame(width: 52, height: 52)
                .background(isPlaying ? Theme.surface : Theme.amber, in: Circle())
                .overlay(Circle().strokeBorder(Theme.amber, lineWidth: 1.5).opacity(isPlaying ? 1 : 0))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? "Stop" : "Play")
    }
}

/// Marks the place being heard as a downbeat of the tap run. Dimmed and without touches unless
/// the file itself is playing, so not during the count-in's click alone.
private struct TapBeatOnePill: View {
    @Environment(MetronomeModel.self) private var model

    var body: some View {
        // Whether the count-in is over is read from the engine and not observed, so it is
        // read again while playing.
        if model.isPlaying {
            TimelineView(.periodic(from: .now, by: 0.1)) { _ in pill }
        } else {
            pill
        }
    }

    private var pill: some View {
        let isEnabled = model.canTapDownbeat
        return Button {
            model.tapDownbeat()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "hand.tap")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.amber)
                Text("Tap on beat 1")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.dialWhite)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.4)
        .allowsHitTesting(isEnabled)
        .disabled(!isEnabled)
        .accessibilityLabel("Tap on beat 1")
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

    private static let knobSize: CGFloat = 24
    private static let lineHeight: CGFloat = 4

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
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .position(x: knobX, y: midY)
                    .gesture(knobDrag(knobX: knobX, inset: inset, travel: travel))
            }
        }
        .frame(height: 44)
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
