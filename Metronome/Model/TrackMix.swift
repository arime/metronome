import CoreGraphics
import Foundation

/// The mix between click and track: -1 is the Click end, 0 the centre, +1 the Track end.
/// Each half turns one side down, evenly in decibels; nothing is turned up.
enum TrackMix {
    /// dB at either end.
    static let range: Double = 24
    /// One accessibility step, 3 dB, so the centre and both ends are reached exactly.
    static let spokenStep: Double = 0.125
    /// Within this many points of the centre the knob rests exactly on it.
    private static let centreCatch: CGFloat = 6

    static func clickGain(at position: Double) -> Float {
        gain(decibels: -range * max(position, 0))
    }

    static func trackGain(at position: Double) -> Float {
        gain(decibels: range * min(position, 0))
    }

    /// The slider position for a knob at x on a line of the given width; 0 when within 6 pt of the centre.
    static func position(forKnobAt x: CGFloat, width: CGFloat) -> Double {
        let half = width / 2
        let offset = x - half
        guard half > 0, abs(offset) > centreCatch else { return 0 }
        return min(max(Double(offset / half), -1), 1)
    }

    /// The position rounded to steps of 0.5 dB, 48 on each side. The slider sets only these, so a
    /// drag saves the mix when it really changes rather than on every touch sample.
    static func quantised(_ position: Double) -> Double {
        (min(max(position, -1), 1) * dragSteps).rounded() / dragSteps
    }

    private static let dragSteps: Double = 48

    /// The next whole accessibility step up or down from a position, which may lie between steps.
    static func nextSpokenStep(from position: Double, upward: Bool) -> Double {
        let steps = position / spokenStep
        let next = upward ? (steps + 1e-9).rounded(.down) + 1 : (steps - 1e-9).rounded(.up) - 1
        return min(max(next * spokenStep, -1), 1)
    }

    static func spoken(_ position: Double) -> String {
        let decibels = Int((range * abs(position)).rounded())
        guard decibels > 0 else { return "Mix, centre" }
        let side = position < 0 ? "track" : "click"
        return "Mix, \(side) turned down \(decibels) \(decibels == 1 ? "decibel" : "decibels")"
    }

    private static func gain(decibels: Double) -> Float {
        Float(pow(10, decibels / 20))
    }
}
