import Foundation

enum Tempo {
    static let range: ClosedRange<Int> = 30...250
    static let defaultBPM = 120

    static func clamp(_ bpm: Int) -> Int {
        min(max(bpm, range.lowerBound), range.upperBound)
    }

    static func name(for bpm: Int) -> String {
        switch bpm {
        case ..<40: "Grave"
        case 40..<60: "Largo"
        case 60..<66: "Larghetto"
        case 66..<76: "Adagio"
        case 76..<108: "Andante"
        case 108..<120: "Moderato"
        case 120..<156: "Allegro"
        case 156..<176: "Vivace"
        case 176..<200: "Presto"
        default: "Prestissimo"
        }
    }

    private static var span: Double { Double(range.upperBound - range.lowerBound) }

    /// Position of a tempo along the dial arc, 0 at 30 BPM and 1 at 250 BPM.
    static func arcFraction(for bpm: Int) -> Double {
        Double(clamp(bpm) - range.lowerBound) / span
    }

    static func bpm(forArcFraction fraction: Double) -> Int {
        let clamped = min(max(fraction, 0), 1)
        return clamp(range.lowerBound + Int((clamped * span).rounded()))
    }
}

enum DialGeometry {
    /// Degrees clockwise from 12 o'clock where the arc starts (the 7:30 position).
    static let arcStartDegrees = 225.0
    /// The arc runs clockwise over the top and ends at 4:30.
    static let arcSweepDegrees = 270.0

    /// Offset of the touch from the dial centre, y pointing down.
    /// Touches in the bottom gap clamp to the nearer end of the arc.
    static func arcFraction(dx: Double, dy: Double) -> Double {
        let clockwiseFromTop = atan2(dx, -dy) * 180 / .pi
        var relative = (clockwiseFromTop - arcStartDegrees).truncatingRemainder(dividingBy: 360)
        if relative < 0 { relative += 360 }
        if relative <= arcSweepDegrees { return relative / arcSweepDegrees }
        let gapMiddle = arcSweepDegrees + (360 - arcSweepDegrees) / 2
        return relative < gapMiddle ? 1 : 0
    }

    /// Below this dial size the tempo name no longer fits inside the ring.
    static let tempoNameMinimumDiameter = 180.0

    static func showsTempoName(dialDiameter: Double) -> Bool {
        dialDiameter >= tempoNameMinimumDiameter
    }

    /// The knob is 28 pt on the full 300 pt dial and scales down with it,
    /// but never below 0.6 of that, so it stays easy to see and grab.
    static func knobDiameter(dialDiameter: Double) -> Double {
        28 * min(1, max(0.6, dialDiameter / 300))
    }

    /// True when the touch starts on the ring: between 0.35 and 0.55 dial diameters
    /// from the centre (105 pt and 165 pt on the 300 pt dial).
    static func startsDrag(dx: Double, dy: Double, dialDiameter: Double) -> Bool {
        let distance = (dx * dx + dy * dy).squareRoot()
        let tolerance = 1e-9
        return distance >= 0.35 * dialDiameter - tolerance && distance <= 0.55 * dialDiameter + tolerance
    }
}
