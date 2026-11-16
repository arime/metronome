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
}
