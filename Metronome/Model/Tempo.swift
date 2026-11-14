import Foundation

enum Tempo {
    static let range: ClosedRange<Int> = 30...300
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

    /// Position of a tempo along the dial arc, 0 at 30 BPM and 1 at 300 BPM.
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

    /// True when the touch starts on the dial: anywhere within 0.55 dial diameters of the
    /// centre (165 pt on the 300 pt dial), number and knob included, as on a real knob.
    static func startsDrag(dx: Double, dy: Double, dialDiameter: Double) -> Bool {
        (dx * dx + dy * dy).squareRoot() <= 0.55 * dialDiameter + 1e-9
    }

    /// Radius of the circle at the centre where the finger's angle is ignored: 0.1 dial
    /// diameters (30 pt on the 300 pt dial). So close to the centre a tiny movement swings
    /// the angle a long way, and the tempo would jump.
    static func deadZoneRadius(dialDiameter: Double) -> Double {
        0.1 * dialDiameter
    }

    /// Degrees clockwise from 12 o'clock, for an offset from the dial centre with y pointing down.
    static func angle(dx: Double, dy: Double) -> Double {
        atan2(dx, -dy) * 180 / .pi
    }
}

/// A turn of the dial. It turns the knob by the angle the finger travels around the centre,
/// wherever on the dial it began, so a touch that does not move changes nothing and the
/// tempo never jumps to where the finger landed.
struct DialDrag: Equatable {
    /// Position along the arc, 0…1. Kept as a fraction so slow drags add up between whole BPM.
    private(set) var fraction: Double
    /// The finger's last angle, or nil while it is in the dead zone at the centre.
    private var lastAngle: Double?
    private let deadZoneRadius: Double

    init(startFraction: Double, dx: Double, dy: Double, dialDiameter: Double) {
        fraction = min(max(startFraction, 0), 1)
        deadZoneRadius = DialGeometry.deadZoneRadius(dialDiameter: dialDiameter)
        lastAngle = nil
        lastAngle = angle(dx: dx, dy: dy)
    }

    /// The finger's angle, or nil in the dead zone.
    private func angle(dx: Double, dy: Double) -> Double? {
        (dx * dx + dy * dy).squareRoot() < deadZoneRadius ? nil : DialGeometry.angle(dx: dx, dy: dy)
    }

    /// Moves the finger and returns the new position. The position stops at the ends of the
    /// arc, and turning back from an end takes effect at once. In the dead zone nothing
    /// changes, and on leaving it the turn carries on from where the finger comes out.
    @discardableResult
    mutating func move(dx: Double, dy: Double) -> Double {
        let current = angle(dx: dx, dy: dy)
        defer { lastAngle = current }
        guard let current, let lastAngle else { return fraction }
        var delta = current - lastAngle
        // The shorter way round, so crossing 6 o'clock is a small step and not a full turn.
        if delta > 180 { delta -= 360 } else if delta < -180 { delta += 360 }
        fraction = min(max(fraction + delta / DialGeometry.arcSweepDegrees, 0), 1)
        return fraction
    }
}

/// The digits typed into the tempo sheet.
struct TempoEntry: Equatable {
    private(set) var digits = ""

    var value: Int? { Int(digits) }

    /// True when the digits are a tempo the metronome can play.
    var isValid: Bool { value.map(Tempo.range.contains) ?? false }

    /// True when the digits are already above the range, so no further key can fix them.
    var isTooHigh: Bool { value.map { $0 > Tempo.range.upperBound } ?? false }

    /// Up to three digits, and no leading zero.
    mutating func append(_ digit: Int) {
        guard (0...9).contains(digit), digits.count < 3 else { return }
        if digits.isEmpty, digit == 0 { return }
        digits.append(String(digit))
    }

    mutating func deleteLast() {
        if !digits.isEmpty { digits.removeLast() }
    }
}
