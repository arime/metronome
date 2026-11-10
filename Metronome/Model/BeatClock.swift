/// One click, placed on the audio clock.
struct ScheduledBeat: Equatable, Sendable {
    /// 1...beatsPerBar
    let beat: Int
    let isAccented: Bool
    let sampleTime: Int64
}

/// Works out when each beat falls, in audio sample time.
///
/// The running beat time is kept as a `Double` and rounded only when a beat is
/// handed out, so rounding never accumulates into drift.
struct BeatClock: Sendable {
    private let sampleRate: Double
    private let startSampleTime: Int64
    private var lastBeatTime: Double?
    private var lastBeat = 0

    /// The first beat is beat 1 at `startSampleTime`.
    init(sampleRate: Double, startSampleTime: Int64) {
        self.sampleRate = sampleRate
        self.startSampleTime = startSampleTime
    }

    /// Returns, in order, every beat not yet returned whose sample time is before `horizon`.
    ///
    /// `bpm`, `beatsPerBar` and `accents` apply to the beats this call produces; beats
    /// already returned are never changed. A new tempo sets the interval that follows
    /// the last returned beat, so the bar position is kept.
    ///
    /// No beat is placed before `earliest` (the audio clock's "now"). When a big tempo
    /// jump or a stalled caller would put the next beat in the past, that beat moves to
    /// `earliest` and the following ones space out from there, so beats never bunch up.
    mutating func beats(
        before horizon: Int64,
        notBefore earliest: Int64 = .min,
        bpm: Int,
        beatsPerBar: Int,
        accents: Set<Int>
    ) -> [ScheduledBeat] {
        let interval = 60 / Double(Tempo.clamp(bpm)) * sampleRate
        var result: [ScheduledBeat] = []
        while true {
            let ideal = lastBeatTime.map { $0 + interval } ?? Double(startSampleTime)
            let time = max(ideal, Double(earliest))
            let sampleTime = Int64(time.rounded())
            guard sampleTime < horizon else { break }
            let beat = lastBeat >= beatsPerBar ? 1 : lastBeat + 1
            result.append(ScheduledBeat(beat: beat, isAccented: accents.contains(beat), sampleTime: sampleTime))
            lastBeatTime = time
            lastBeat = beat
        }
        return result
    }
}
