import Foundation

/// What the player card's readout shows and VoiceOver reads (6.7, 13).
struct PlayReadout: Equatable {
    let time: String
    let bar: String
    let spoken: String
}

/// The time and the bars played since the last Start (7.13). Times are system uptimes.
struct PlayCount: Equatable {
    /// The bar being played, from 1.
    private(set) var bar = 1
    /// When the first counted beat sounded; nil until it has.
    private var firstBeat: TimeInterval?
    private var stoppedAt: TimeInterval?

    init() {}

    #if DEBUG
    /// A count already running, for screenshot scenes.
    init(runningSince firstBeat: TimeInterval, bar: Int) {
        self.firstBeat = firstBeat
        self.bar = bar
    }
    #endif

    /// Back to 0:00 and bar 1; the next counted beat starts the count.
    mutating func restart() {
        self = PlayCount()
    }

    /// Counts a beat that sounds at `uptime`. Count-in beats are skipped; the first counted
    /// beat is bar 1 whatever its beat number, and every beat 1 after it starts the next bar.
    mutating func count(_ beat: ScheduledBeat, at uptime: TimeInterval) {
        guard !beat.isCountIn else { return }
        if firstBeat == nil {
            firstBeat = uptime
        } else if beat.beat == 1 {
            bar += 1
        }
    }

    /// Freezes the time at `uptime`, until the next restart.
    mutating func stop(at uptime: TimeInterval) {
        if stoppedAt == nil { stoppedAt = uptime }
    }

    func elapsed(at uptime: TimeInterval) -> TimeInterval {
        guard let firstBeat else { return 0 }
        return max((stoppedAt ?? uptime) - firstBeat, 0)
    }

    func readout(at uptime: TimeInterval) -> PlayReadout {
        let seconds = elapsed(at: uptime)
        return PlayReadout(time: Self.timeLabel(seconds), bar: Self.barLabel(bar), spoken: Self.spoken(seconds, bar: bar))
    }

    /// "0:00", "59:59", and from an hour on "1:02:07".
    static func timeLabel(_ seconds: TimeInterval) -> String {
        let whole = wholeSeconds(seconds)
        guard whole >= 3600 else { return TrackTime.label(Double(whole)) }
        let minutes = whole / 60 % 60, secs = whole % 60
        return "\(whole / 3600):\(minutes < 10 ? "0" : "")\(minutes):\(secs < 10 ? "0" : "")\(secs)"
    }

    /// "Bar 1", "Bar 128".
    static func barLabel(_ bar: Int) -> String {
        "Bar \(bar)"
    }

    /// "1 minute 24 seconds, bar 43", "1 hour 2 minutes 7 seconds, bar 1240", "1 hour, bar 2".
    static func spoken(_ seconds: TimeInterval, bar: Int) -> String {
        let whole = wholeSeconds(seconds)
        let hours = whole / 3600, rest = whole % 3600
        let time: String
        if hours == 0 {
            time = TrackTime.spoken(Double(rest))
        } else {
            let hourPart = hours == 1 ? "1 hour" : "\(hours) hours"
            time = rest == 0 ? hourPart : "\(hourPart) \(TrackTime.spoken(Double(rest)))"
        }
        return "\(time), bar \(bar)"
    }

    private static func wholeSeconds(_ seconds: TimeInterval) -> Int {
        seconds.isFinite ? max(Int(seconds.rounded(.down)), 0) : 0
    }
}
