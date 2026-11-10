import Foundation

/// Turns a series of taps into a tempo: the average of the last four intervals.
struct TapTempo {
    private static let maxIntervals = 4
    private static let seriesTimeout: TimeInterval = 2

    private var times: [TimeInterval] = []

    /// Returns the new BPM from the second tap on; nil for the first tap of a series.
    /// A pause longer than two seconds starts a new series.
    mutating func tap(at time: TimeInterval) -> Int? {
        if let last = times.last, time - last > Self.seriesTimeout {
            times.removeAll()
        }
        times.append(time)
        if times.count > Self.maxIntervals + 1 {
            times.removeFirst(times.count - Self.maxIntervals - 1)
        }
        guard let first = times.first, times.count >= 2 else { return nil }
        let average = (time - first) / Double(times.count - 1)
        guard average > 0 else { return Tempo.range.upperBound }
        let bpm = (60 / average).rounded()
        guard bpm < Double(Tempo.range.upperBound) else { return Tempo.range.upperBound }
        return Tempo.clamp(Int(bpm))
    }
}
