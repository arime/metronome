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

    /// The offset Tap on beat 1 sets (7.11): `time` moved back or forward by whole bars at `bpm`
    /// and `beatsPerBar` to the earliest place not before 0:00, in hundredths. Within 1e-9 bar of a
    /// downbeat counts as on it, as in `firstIndex`, and a place that rounds to a whole bar is the
    /// downbeat at 0.00: never the bar length itself.
    static func foldedOffset(_ time: TimeInterval, bpm: Int, beatsPerBar: Int) -> Int {
        let barLength = 60 * TimeInterval(beatsPerBar) / TimeInterval(Tempo.clamp(bpm))
        let bars = (time / barLength + 1e-9).rounded(.down)
        let hundredths = Int(((time - bars * barLength) * 100).rounded())
        guard TimeInterval(hundredths) < barLength * 100 else { return 0 }
        return max(hundredths, 0)
    }
}
