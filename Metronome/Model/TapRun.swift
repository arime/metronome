import Foundation

/// The track's tempo and offset as a run of tapped downbeats sets them. Offset in hundredths.
struct TapFit: Equatable, Sendable {
    let bpm: Int
    let offset: Int
}

/// Downbeats tapped along with the track (7.11): each tap's place in the file and its bar
/// number, counted from the run's first tap.
struct TapRun: Equatable, Sendable {
    struct Tap: Equatable, Sendable {
        let bar: Int
        let time: TimeInterval
    }

    private(set) var taps: [Tap] = []

    var isEmpty: Bool { taps.isEmpty }

    /// A tap this soon after the last one is a bounced finger, not a downbeat. The shortest bar
    /// the app allows, 2 beats at 300 BPM, is 0.4 s.
    static let bounceLimit: TimeInterval = 0.2

    /// Adds a downbeat tapped at `time`, with the bar length at the tempo and time signature in
    /// effect. A time not later than the last tap's starts a new run with this tap. Returns
    /// false, changing nothing, for a bounce: a gap shorter than `bounceLimit`, where within
    /// 1e-9 s of the limit counts as on it.
    @discardableResult
    mutating func add(at time: TimeInterval, bpm: Int, beatsPerBar: Int) -> Bool {
        guard let last = taps.last, time > last.time else {
            taps = [Tap(bar: 0, time: time)]
            return true
        }
        guard time - last.time > Self.bounceLimit - 1e-9 else { return false }
        let bars = ((time - last.time) / Self.barLength(bpm: bpm, beatsPerBar: beatsPerBar)).rounded()
        taps.append(Tap(bar: last.bar + max(Int(bars), 1), time: time))
        return true
    }

    /// One tap keeps the tempo and folds the tap into the first bar. Two or more fit a straight
    /// line through (bar, time) by least squares: its slope is the bar length, which gives the
    /// tempo, and the mean tapped downbeat at that whole tempo, folded, gives the offset.
    func fitted(bpm: Int, beatsPerBar: Int) -> TapFit? {
        guard let first = taps.first else { return nil }
        guard taps.count > 1 else {
            let bar = Self.barLength(bpm: bpm, beatsPerBar: beatsPerBar)
            return TapFit(bpm: bpm, offset: Self.foldedOffset(first.time, barLength: bar))
        }
        let count = TimeInterval(taps.count)
        let meanBar = taps.reduce(0) { $0 + TimeInterval($1.bar) } / count
        let meanTime = taps.reduce(0) { $0 + $1.time } / count
        var products: TimeInterval = 0
        var squares: TimeInterval = 0
        for tap in taps {
            let bar = TimeInterval(tap.bar) - meanBar
            products += bar * (tap.time - meanTime)
            squares += bar * bar
        }
        let slope = products / squares
        let fittedBPM = Tempo.clamp(Int((60 * TimeInterval(beatsPerBar) / slope).rounded()))
        let bar = Self.barLength(bpm: fittedBPM, beatsPerBar: beatsPerBar)
        let downbeat = meanTime - meanBar * bar
        return TapFit(bpm: fittedBPM, offset: Self.foldedOffset(downbeat, barLength: bar))
    }

    /// `time` moved back or forward by whole bars to the earliest place not before 0:00, in
    /// hundredths. Within 1e-9 bar of a downbeat counts as on it, as in `TrackGrid.firstIndex`, and
    /// a place that rounds to a whole bar is the downbeat at 0.00: never the bar length itself.
    static func foldedOffset(_ time: TimeInterval, barLength: TimeInterval) -> Int {
        let bars = (time / barLength + 1e-9).rounded(.down)
        let hundredths = Int(((time - bars * barLength) * 100).rounded())
        guard TimeInterval(hundredths) < barLength * 100 else { return 0 }
        return max(hundredths, 0)
    }

    /// `1 tap · 1 bar`, `4 taps · 6 bars`; nil before the first tap.
    var countLine: String? {
        counts.map { "\($0.taps) · \($0.bars)" }
    }

    /// The count line as VoiceOver reads it: `5 taps, 12 bars`.
    var spokenCountLine: String? {
        counts.map { "\($0.taps), \($0.bars)" }
    }

    /// The bars the run spans are its last bar number plus 1.
    private var counts: (taps: String, bars: String)? {
        guard let last = taps.last else { return nil }
        let bars = last.bar + 1
        return (
            taps.count == 1 ? "1 tap" : "\(taps.count) taps",
            bars == 1 ? "1 bar" : "\(bars) bars"
        )
    }

    private static func barLength(bpm: Int, beatsPerBar: Int) -> TimeInterval {
        60 * TimeInterval(beatsPerBar) / TimeInterval(Tempo.clamp(bpm))
    }
}
