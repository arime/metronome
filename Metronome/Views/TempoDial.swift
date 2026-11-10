import SwiftUI

/// The tempo gauge: tick ring, draggable knob, and the BPM number in the middle.
struct TempoDial: View {
    @Environment(MetronomeModel.self) private var model
    let diameter: CGFloat

    @State private var numberScale = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Everything is drawn for a 300 pt dial and scaled.
    private var scale: CGFloat { diameter / 300 }

    var body: some View {
        ZStack {
            BeatGlow(lastBeat: model.lastBeat, bpm: model.settings.bpm, diameter: diameter)
            RippleLayer(lastBeat: model.lastBeat, diameter: diameter)
            DialRing(fraction: Tempo.arcFraction(for: model.settings.bpm))
            readout
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
        .onChange(of: model.lastBeat) { _, beat in
            guard beat != nil, !reduceMotion else { return }
            // The number jumps up on the beat and settles within half the beat interval.
            numberScale = 1.04
            withAnimation(.easeOut(duration: BeatPulse.decay(bpm: model.settings.bpm))) { numberScale = 1 }
        }
    }

    private var readout: some View {
        VStack(spacing: 6 * scale) {
            Text("\(model.settings.bpm)")
                .font(.system(size: 112 * scale, weight: .heavy))
                .tracking(-5.6 * scale)
                .monospacedDigit()
                .foregroundStyle(Theme.dialWhite)
                // Wide numbers such as 200 shrink a little so they stay clear of the knob.
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 208 * scale, height: 112 * scale)
                .scaleEffect(numberScale)
            HStack(spacing: 8) {
                SectionLabel(text: "BPM", color: Theme.amber)
                // On a small dial the tempo name does not fit inside the ring.
                if DialGeometry.showsTempoName(dialDiameter: diameter) {
                    Circle().fill(Theme.muted).frame(width: 3, height: 3)
                    Text(model.tempoName)
                        .font(.system(size: 15).italic())
                        .foregroundStyle(Theme.muted)
                }
            }
        }
    }

    private var ringDrag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let centre = diameter / 2
                // Classified from the start location on every change rather than remembered,
                // so a cancelled gesture cannot leave a stale answer for the next touch.
                let startedOnRing = DialGeometry.startsDrag(
                    dx: value.startLocation.x - centre,
                    dy: value.startLocation.y - centre,
                    dialDiameter: diameter
                )
                guard startedOnRing else { return }
                let fraction = DialGeometry.arcFraction(dx: value.location.x - centre, dy: value.location.y - centre)
                model.setBPM(Tempo.bpm(forArcFraction: fraction))
            }
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
                    with: .color(tickFraction <= fraction + 0.0001 ? Theme.amber : Theme.line),
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
