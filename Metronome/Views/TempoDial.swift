import SwiftUI

/// The tempo dial: a scale of ticks around a knurled knob that turns with the finger, and the
/// BPM number on the knob's face.
struct TempoDial: View {
    @Environment(MetronomeModel.self) private var model
    let diameter: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isEntryShown = false
    /// The turn in progress, with the touch it belongs to.
    @State private var drag: (start: CGPoint, turn: DialDrag)?

    /// Everything is drawn for a 300 pt dial and scaled.
    private var scale: CGFloat { diameter / 300 }

    var body: some View {
        ZStack {
            DialRing(fraction: Tempo.arcFraction(for: model.settings.bpm))
            // Over the knob, so the beat lights up its face.
            BeatGlow(lastBeat: model.lastBeat, bpm: model.settings.bpm, diameter: diameter)
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
        .sheet(isPresented: $isEntryShown) {
            TempoEntrySheet(current: model.settings.bpm) { model.setBPM($0) }
                .environment(model)
        }
    }

    /// Sized to sit on the knob's face. Three-digit tempos are drawn a little smaller so
    /// they stay clear of its edge.
    private var numberSize: CGFloat {
        DialRing.numberSize * scale * (model.settings.bpm >= 100 ? 0.88 : 1)
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
                .frame(height: DialRing.numberSize * scale)
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

    /// Turns the knob by the angle the finger travels around the centre, from wherever on the
    /// dial the touch began. The turn only begins once the finger has moved a little, so a
    /// tap or a brush against the dial changes nothing.
    private var ringDrag: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                let centre = diameter / 2
                let dx = value.location.x - centre
                let dy = value.location.y - centre
                // A drag is told apart by where its touch began rather than by an "ended"
                // flag, so a cancelled gesture cannot leave a stale drag for the next touch.
                guard var current = drag, current.start == value.startLocation else {
                    let startedOnDial = DialGeometry.startsDrag(
                        dx: value.startLocation.x - centre,
                        dy: value.startLocation.y - centre,
                        dialDiameter: diameter
                    )
                    guard startedOnDial else { return }
                    // Measured from here, not from where the touch began, so the first
                    // movement does not arrive as a jump.
                    let turn = DialDrag(
                        startFraction: Tempo.arcFraction(for: model.settings.bpm),
                        dx: dx, dy: dy, dialDiameter: diameter
                    )
                    drag = (value.startLocation, turn)
                    return
                }
                let fraction = current.turn.move(dx: dx, dy: dy)
                drag = current
                model.setBPM(Tempo.bpm(forArcFraction: fraction))
            }
            .onEnded { _ in drag = nil }
    }
}

/// The scale of ticks and the knob inside it: a raised disc with a ridged edge and an amber
/// pointer, turned to the tempo. Drawn in a 300 pt coordinate space and scaled to fit.
private struct DialRing: View {
    let fraction: Double

    /// The BPM number on the knob's face, for two digits.
    static let numberSize = 90.0

    private static let tickCount = 48
    private static let tickOuter = 146.0
    private static let majorTickInner = 134.0
    private static let minorTickInner = 138.0

    private static let knobRadius = 120.0
    private static let faceRadius = 104.0
    private static let ridgeCount = 90
    private static let ridgeLength = 10.0
    /// The pointer on the face. It starts far enough out to stay clear of a three-digit
    /// number beside it.
    private static let pointerOuter = 101.0
    private static let pointerInner = 86.0

    private static let knobTop = Color(hex: 0x2C2C31)
    private static let knobBottom = Color(hex: 0x141416)
    private static let faceTop = Color(hex: 0x1D1D21)
    private static let faceBottom = Color(hex: 0x202024)

    /// Extra canvas around the dial so the knob's shadow and the pointer's glow are not clipped.
    private static let bleed = 24.0

    var body: some View {
        Canvas { context, size in
            let scale = (size.width - 2 * Self.bleed) / 300
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)

            /// Screen angle in radians, clockwise from 3 o'clock: the arc starts at 135° (7:30).
            func angle(at arcFraction: Double) -> Double {
                (135 + DialGeometry.arcSweepDegrees * arcFraction) * .pi / 180
            }
            func point(_ angle: Double, _ radius: Double) -> CGPoint {
                CGPoint(x: centre.x + radius * scale * cos(angle), y: centre.y + radius * scale * sin(angle))
            }
            func circle(_ radius: Double) -> Path {
                let r = radius * scale
                return Path(ellipseIn: CGRect(x: centre.x - r, y: centre.y - r, width: 2 * r, height: 2 * r))
            }
            func line(_ angle: Double, from inner: Double, to outer: Double) -> Path {
                var path = Path()
                path.move(to: point(angle, outer))
                path.addLine(to: point(angle, inner))
                return path
            }
            func vertical(_ top: Color, _ bottom: Color, radius: Double) -> GraphicsContext.Shading {
                .linearGradient(
                    Gradient(colors: [top, bottom]),
                    startPoint: CGPoint(x: centre.x, y: centre.y - radius * scale),
                    endPoint: CGPoint(x: centre.x, y: centre.y + radius * scale)
                )
            }

            // The scale.
            for index in 0..<Self.tickCount {
                let tickFraction = Double(index) / Double(Self.tickCount - 1)
                let isMajor = index % 4 == 0
                context.stroke(
                    line(angle(at: tickFraction), from: isMajor ? Self.majorTickInner : Self.minorTickInner, to: Self.tickOuter),
                    with: .color(tickFraction <= fraction + 0.0001 ? Theme.amber : Theme.tick),
                    style: StrokeStyle(lineWidth: (isMajor ? 3 : 2) * scale, lineCap: .round)
                )
            }

            // The knob's body, lit from above and standing off the background.
            let pointerAngle = angle(at: fraction)
            var knobBody = context
            knobBody.addFilter(.shadow(color: .black.opacity(0.7), radius: 12 * scale, y: 8 * scale))
            knobBody.fill(circle(Self.knobRadius), with: vertical(Self.knobTop, Self.knobBottom, radius: Self.knobRadius))
            context.stroke(circle(Self.knobRadius), with: .color(Theme.line), lineWidth: 1.5 * scale)

            // Ridges on the edge, turning with the knob, brighter towards the top.
            for index in 0..<Self.ridgeCount {
                let ridgeAngle = pointerAngle + Double(index) * 2 * .pi / Double(Self.ridgeCount)
                let light = 0.5 - 0.5 * sin(ridgeAngle)
                context.stroke(
                    line(ridgeAngle, from: Self.knobRadius - 1 - Self.ridgeLength, to: Self.knobRadius - 1),
                    with: .color(Theme.dialWhite.opacity(0.07 + 0.16 * light)),
                    lineWidth: 2 * scale
                )
            }

            // The face, a little darker than the edge, under the number.
            context.fill(circle(Self.faceRadius), with: vertical(Self.faceTop, Self.faceBottom, radius: Self.faceRadius))

            // The pointer.
            var glow = context
            glow.addFilter(.shadow(color: Theme.amber.opacity(0.7), radius: 5 * scale))
            glow.stroke(
                line(pointerAngle, from: Self.pointerInner, to: Self.pointerOuter),
                with: .color(Theme.amber),
                style: StrokeStyle(lineWidth: 5 * scale, lineCap: .round)
            )
        }
        .padding(-Self.bleed)
        .allowsHitTesting(false)
    }
}
