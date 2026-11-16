import Foundation

/// The click's beats against file time. Beat index 0 falls at the offset; negative indices are the count-in.
struct TrackGrid: Equatable, Sendable {
    let offset: TimeInterval
    let bpm: Int
    let beatsPerBar: Int

    var beatInterval: TimeInterval { 60 / TimeInterval(Tempo.clamp(bpm)) }

    func time(ofBeat index: Int) -> TimeInterval {
        offset + TimeInterval(index) * beatInterval
    }

    /// The first beat at or after the time; a beat within 1e-9 beats of it counts as on it.
    func firstIndex(atOrAfter time: TimeInterval) -> Int {
        Int(((time - offset) / beatInterval - 1e-9).rounded(.up))
    }

    /// 1...beatsPerBar, so count-in beats read as the bars before the offset.
    func barBeat(ofBeat index: Int) -> Int {
        (index % beatsPerBar + beatsPerBar) % beatsPerBar + 1
    }

    /// Where playback starts in file time for Start at 0:00: min(0, offset - count-in length).
    func startTime(countIn: CountIn) -> TimeInterval {
        min(0, time(ofBeat: firstClickIndex(countIn: countIn)))
    }

    /// The lowest beat index that clicks from 0:00: -(bars * beatsPerBar).
    func firstClickIndex(countIn: CountIn) -> Int {
        -countIn.rawValue * beatsPerBar
    }

    /// Tap on beat 1: the tapped place moved back by whole bars to the earliest place not before 0, in hundredths.
    static func offset(forDownbeatAt tapped: TimeInterval, bpm: Int, beatsPerBar: Int) -> Int {
        let bar = TrackGrid(offset: 0, bpm: bpm, beatsPerBar: beatsPerBar).beatInterval * TimeInterval(beatsPerBar)
        var offset = tapped - (tapped / bar).rounded(.down) * bar
        // Rounding up to a whole bar lands on the next downbeat; the one before it is earlier.
        if (offset * 100).rounded() >= bar * 100 { offset -= bar }
        return max(Int((offset * 100).rounded()), 0)
    }
}
