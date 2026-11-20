import Foundation

/// Places grid beats on the player's timeline. File time `startTime` sounds at `startSampleTime`.
///
/// Each beat's sample time is worked out from its own index on the grid, so rounding never
/// accumulates into drift, and the grid may change from call to call.
struct TrackBeatClock: Sendable {
    private let sampleRate: Double
    private let startSampleTime: Int64
    private let startTime: TimeInterval
    private let firstClickIndex: Int
    private var lastSampleTime: Int64?

    init(sampleRate: Double, startSampleTime: Int64, startTime: TimeInterval, firstClickIndex: Int) {
        self.sampleRate = sampleRate
        self.startSampleTime = startSampleTime
        self.startTime = startTime
        self.firstClickIndex = firstClickIndex
    }

    /// The sample time at which a file time sounds.
    func sampleTime(forFileTime time: TimeInterval) -> Int64 {
        startSampleTime + Int64(((time - startTime) * sampleRate).rounded())
    }

    /// The file time sounding at a sample time.
    func fileTime(atSampleTime sampleTime: Int64) -> TimeInterval {
        startTime + Double(sampleTime - startSampleTime) / sampleRate
    }

    /// In order, every grid beat not yet returned that falls before `horizon` and not before `earliest`.
    /// Only beats with index >= firstClickIndex and file time < endTime are returned.
    /// A beat less than half a beat interval after the last returned beat is skipped, so beats never bunch up.
    mutating func beats(
        before horizon: Int64,
        notBefore earliest: Int64,
        endTime: TimeInterval,
        grid: TrackGrid,
        accents: Set<Int>
    ) -> [ScheduledBeat] {
        let minimumGap = grid.beatInterval / 2 * sampleRate
        var result: [ScheduledBeat] = []
        while true {
            var lowest = fileTime(atSampleTime: earliest)
            if let lastSampleTime {
                lowest = max(lowest, fileTime(atSampleTime: lastSampleTime) + grid.beatInterval / 2)
            }
            var index = max(firstClickIndex, grid.firstIndex(atOrAfter: lowest))
            // firstIndex allows a hair either side; settle it on whole samples.
            while !isLateEnough(sampleTime(forFileTime: grid.time(ofBeat: index)), earliest: earliest, minimumGap: minimumGap) {
                index += 1
            }
            let time = grid.time(ofBeat: index)
            let sampleTime = sampleTime(forFileTime: time)
            guard sampleTime < horizon, time < endTime else { break }
            let beat = grid.barBeat(ofBeat: index)
            result.append(
                ScheduledBeat(beat: beat, isAccented: accents.contains(beat), sampleTime: sampleTime, isCountIn: index < 0)
            )
            lastSampleTime = sampleTime
        }
        return result
    }

    private func isLateEnough(_ sampleTime: Int64, earliest: Int64, minimumGap: Double) -> Bool {
        guard sampleTime >= earliest else { return false }
        guard let lastSampleTime else { return true }
        return Double(sampleTime - lastSampleTime) >= minimumGap
    }
}
