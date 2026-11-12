import SwiftUI

/// The tempo gauge: tick ring, draggable knob, and the BPM number in the middle. While the
/// song has unsaved changes, the save controls stand in the gap at the bottom of the ring.
struct TempoDial: View {
    @Environment(MetronomeModel.self) private var model
    let diameter: CGFloat
    /// False on a dial too small for the save controls; the header then has them.
    var showsSaveControls = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isEntryShown = false
    /// The drag in progress, with the touch it belongs to.
    @State private var drag: (start: CGPoint, motion: DialMotion)?

    /// A drag on the ring turns the dial; one on the number slides the tempo up and down.
    private enum DialMotion {
        case turn(DialDrag)
        case slide(DialSlide)
    }

    /// Everything is drawn for a 300 pt dial and scaled.
    private var scale: CGFloat { diameter / 300 }

    var body: some View {
        ZStack {
            BeatGlow(lastBeat: model.lastBeat, bpm: model.settings.bpm, diameter: diameter)
            DialRing(fraction: Tempo.arcFraction(for: model.settings.bpm))
            readout
                .contentShape(Rectangle())
                .onTapGesture { isEntryShown = true }
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle().scale(1.1))
        .gesture(ringDrag)
        .accessibilityElement()
        .accessibilityLabel("Tempo")
        .accessibilityValue("\(model.settings.bpm) beats per minute, \(model.tempoName)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: model.nudgeBPM(by: 1)
            case .decrement: model.nudgeBPM(by: -1)
            @unknown default: break
            }
        }
        .accessibilityAction(named: "Type a tempo") { isEntryShown = true }
        // Added after the ring's gesture and accessibility element, so a touch on a control
        // never starts a drag, and VoiceOver finds the controls on their own.
        .overlay(alignment: .bottom) {
            if showsSaveControls && model.isSaveOffered {
                DialSaveControls()
                    .padding(.bottom, DialGeometry.saveControlsBottomInset)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: model.isSaveOffered)
        .sheet(isPresented: $isEntryShown) {
            TempoEntrySheet(current: model.settings.bpm) { model.setBPM($0) }
                .environment(model)
        }
    }

    /// Three-digit tempos are drawn a little smaller so they stay clear of the knob.
    private var numberSize: CGFloat {
        112 * scale * (model.settings.bpm >= 100 ? 0.88 : 1)
    }

    /// The digits are set tighter than normal, but only between digits. Tightening after
    /// the last digit as well (as the tracking modifier does) makes the text narrower than
    /// its ink, and the right edge of the last digit gets clipped.
    private var numberText: AttributedString {
        var text = AttributedString("\(model.settings.bpm)")
        text.kern = -0.05 * numberSize
        if let last = text.characters.indices.last {
            text[last...].kern = 0
        }
        return text
    }

    private var readout: some View {
        VStack(spacing: 6 * scale) {
            Text(numberText)
                .font(.system(size: numberSize, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(Theme.dialWhite)
                // Laid out at its natural width. Squeezing it into a fixed width with a
                // scale factor clipped the right edge of the last digit.
                .fixedSize()
                .frame(height: 112 * scale)
                // The number jumps up on the beat and settles within half the beat
                // interval. With Reduce Motion on, the trigger never changes.
                .keyframeAnimator(
                    initialValue: 1.0,
                    trigger: reduceMotion ? nil : model.lastBeat?.id
                ) { view, scale in
                    view.scaleEffect(scale)
                } keyframes: { _ in
                    MoveKeyframe(1.04)
                    CubicKeyframe(1.0, duration: BeatPulse.decay(bpm: model.settings.bpm))
                }
            // On a small dial the tempo name does not fit inside the ring.
            if DialGeometry.showsTempoName(dialDiameter: diameter) {
                Text(model.tempoName)
                    .font(.system(size: 15).italic())
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    /// On the ring, turns the dial by the angle the finger travels; on the number, slides the
    /// tempo up and down with the finger. The drag only begins once the finger has moved a
    /// little, so a tap or a brush against the dial changes nothing.
    private var ringDrag: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                let centre = diameter / 2
                let dx = value.location.x - centre
                let dy = value.location.y - centre
                // A drag is told apart by where its touch began rather than by an "ended"
                // flag, so a cancelled gesture cannot leave a stale drag for the next touch.
                guard let current = drag, current.start == value.startLocation else {
                    let startDX = value.startLocation.x - centre
                    let startDY = value.startLocation.y - centre
                    // Measured from here, not from where the touch began, so the first
                    // movement does not arrive as a jump.
                    if DialGeometry.startsDrag(dx: startDX, dy: startDY, dialDiameter: diameter) {
                        let turn = DialDrag(startFraction: Tempo.arcFraction(for: model.settings.bpm), dx: dx, dy: dy)
                        drag = (value.startLocation, .turn(turn))
                    } else if DialGeometry.startsSlide(dx: startDX, dy: startDY, dialDiameter: diameter) {
                        drag = (value.startLocation, .slide(DialSlide(startBPM: model.settings.bpm, y: value.location.y)))
                    }
                    return
                }
                switch current.motion {
                case .turn(var turn):
                    let fraction = turn.move(dx: dx, dy: dy)
                    drag = (current.start, .turn(turn))
                    model.setBPM(Tempo.bpm(forArcFraction: fraction))
                case .slide(var slide):
                    let bpm = slide.move(y: value.location.y)
                    drag = (current.start, .slide(slide))
                    model.setBPM(bpm)
                }
            }
            .onEnded { _ in drag = nil }
    }
}

/// Ticks, lit arc and knob. Drawn in a 300 pt coordinate space and scaled to fit.
private struct DialRing: View {
    let fraction: Double

    private static let tickCount = 48
    private static let outerRadius = 138.0
    private static let knobRadius = 131.0
    /// Extra canvas around the dial so the knob's glow is not clipped.
    private static let bleed = 24.0

    var body: some View {
        Canvas { context, size in
            let scale = (size.width - 2 * Self.bleed) / 300
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)

            func point(at arcFraction: Double, radius: Double) -> CGPoint {
                // Screen angle, clockwise from 3 o'clock: the arc starts at 135° (7:30).
                let angle = (135 + DialGeometry.arcSweepDegrees * arcFraction) * .pi / 180
                return CGPoint(
                    x: centre.x + radius * scale * cos(angle),
                    y: centre.y + radius * scale * sin(angle)
                )
            }

            for index in 0..<Self.tickCount {
                let tickFraction = Double(index) / Double(Self.tickCount - 1)
                let isMajor = index % 4 == 0
                var path = Path()
                path.move(to: point(at: tickFraction, radius: Self.outerRadius))
                path.addLine(to: point(at: tickFraction, radius: isMajor ? 124 : 129))
                context.stroke(
                    path,
                    with: .color(tickFraction <= fraction + 0.0001 ? Theme.amber : Theme.tick),
                    style: StrokeStyle(lineWidth: (isMajor ? 3 : 2) * scale, lineCap: .round)
                )
            }

            let knobCentre = point(at: fraction, radius: Self.knobRadius)
            let knobSize = DialGeometry.knobDiameter(dialDiameter: 300 * scale)
            let knobScale = knobSize / 28
            let knob = Path(ellipseIn: CGRect(
                x: knobCentre.x - knobSize / 2, y: knobCentre.y - knobSize / 2,
                width: knobSize, height: knobSize
            ))
            var glow = context
            glow.addFilter(.shadow(color: Theme.amber.opacity(0.6), radius: 9 * knobScale))
            glow.fill(knob, with: .color(Theme.amber))
            context.fill(knob, with: .color(Theme.ink))
            context.fill(knob.insetKnob(by: 5 * knobScale), with: .color(Theme.amber))
        }
        .padding(-Self.bleed)
    }
}

private extension Path {
    /// The same circle, smaller by `inset` on every side.
    func insetKnob(by inset: CGFloat) -> Path {
        Path(ellipseIn: boundingRect.insetBy(dx: inset, dy: inset))
    }
}
