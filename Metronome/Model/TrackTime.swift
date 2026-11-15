import Foundation

/// Times in a backing track, shown as m:ss and spoken in words. Both use whole seconds,
/// rounded down, and read negatives as 0.
enum TrackTime {
    /// "0:00", "3:42"; the minutes keep counting past 59, as "61:05".
    static func label(_ seconds: TimeInterval) -> String {
        let whole = wholeSeconds(seconds)
        let secs = whole % 60
        return "\(whole / 60):\(secs < 10 ? "0" : "")\(secs)"
    }

    /// "1 minute 24 seconds", "3 minutes", "0 seconds".
    static func spoken(_ seconds: TimeInterval) -> String {
        let whole = wholeSeconds(seconds)
        let minutes = whole / 60, secs = whole % 60
        let minutePart = minutes == 1 ? "1 minute" : "\(minutes) minutes"
        let secondPart = secs == 1 ? "1 second" : "\(secs) seconds"
        if minutes == 0 { return secondPart }
        return secs == 0 ? minutePart : "\(minutePart) \(secondPart)"
    }

    private static func wholeSeconds(_ seconds: TimeInterval) -> Int {
        seconds.isFinite ? max(Int(seconds.rounded(.down)), 0) : 0
    }
}
