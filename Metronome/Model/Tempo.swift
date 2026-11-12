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

    /// The save controls in the gap at the bottom of the ring: a round button, the Save
    /// pill and a round button, side by side. They keep their size on every dial, as
    /// touch targets, and stand this far above the bottom of the dial's frame.
    static let saveControlsButton = 38.0
    static let saveControlsPillWidth = 84.0
    static let saveControlsSpacing = 8.0
    static let saveControlsBottomInset = 6.0

    static var saveControlsWidth: Double {
        2 * saveControlsButton + saveControlsPillWidth + 2 * saveControlsSpacing
    }

    /// True when the save controls fit in the gap: a round button stays clear of the knob
    /// even with the knob at either end of the arc. On a smaller dial the controls go to
    /// the header instead.
    static func fitsSaveControls(dialDiameter: Double) -> Bool {
        let radius = saveControlsButton / 2
        let button = (
            x: saveControlsWidth / 2 - radius,
            y: dialDiameter / 2 - saveControlsBottomInset - radius
        )
        // The knob at the end of the arc, at 4:30 (or 7:30, which mirrors it).
        let knobOffset = 131 * dialDiameter / 300 / 2.0.squareRoot()
        let dx = knobOffset - button.x
        let dy = button.y - knobOffset
        let clearance = 4.0
        return (dx * dx + dy * dy).squareRoot() >= knobDiameter(dialDiameter: dialDiameter) / 2 + radius + clearance
    }

    /// Degrees clockwise from 12 o'clock, for an offset from the dial centre with y pointing down.
    static func angle(dx: Double, dy: Double) -> Double {
        atan2(dx, -dy) * 180 / .pi
    }
}

/// A drag on the ring. It turns the dial by the angle the finger travels around the centre,
/// wherever on the ring it began, so a touch that does not move changes nothing and the
/// tempo never jumps to where the finger landed.
struct DialDrag: Equatable {
    /// Position along the arc, 0…1. Kept as a fraction so slow drags add up between whole BPM.
    private(set) var fraction: Double
    private var lastAngle: Double

    init(startFraction: Double, dx: Double, dy: Double) {
        fraction = min(max(startFraction, 0), 1)
        lastAngle = DialGeometry.angle(dx: dx, dy: dy)
    }

    /// Moves the finger and returns the new position. The position stops at the ends of the
    /// arc, and turning back from an end takes effect at once.
    @discardableResult
    mutating func move(dx: Double, dy: Double) -> Double {
        let angle = DialGeometry.angle(dx: dx, dy: dy)
        var delta = angle - lastAngle
        // The shorter way round, so crossing 6 o'clock is a small step and not a full turn.
        if delta > 180 { delta -= 360 } else if delta < -180 { delta += 360 }
        lastAngle = angle
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
