import Foundation

/// What the engine needs to play a file with the click.
struct TrackPlayback: Equatable, Sendable {
    let fileURL: URL
    /// Seconds into the file where beat 1 of bar 1 falls.
    var firstBeat: TimeInterval
    /// Where playback starts in file time; negative while only the count-in sounds.
    let startTime: TimeInterval
    /// The lowest beat index that clicks: negative with a count-in, 0 without.
    let firstClickIndex: Int
    var clickGain: Float
    var trackGain: Float
}

/// What the screen model needs from whatever makes the clicks.
@MainActor
protocol ClickEngine: AnyObject {
    /// Called at the moment each beat sounds.
    var onBeat: ((ScheduledBeat) -> Void)? { get set }
    /// Called when playback ended for a reason other than `stop()`:
    /// an interruption, an audio route change or an engine failure.
    /// `trackTime` still answers while it runs, so the track's position can be kept.
    var onStopped: (() -> Void)? { get set }
    /// Called once when the file has played to its end. Not called after stop() or a seek.
    var onTrackEnded: (() -> Void)? { get set }

    /// Starts on beat 1 with the first click immediately.
    func start(with settings: MetronomeSettings) throws
    /// Starts the file and the click together. Throws at once when the file cannot be opened.
    func start(with settings: MetronomeSettings, track: TrackPlayback) throws
    /// Applies from the next beat that is not scheduled yet. With `startNewBar`,
    /// that beat is beat 1; otherwise the bar position is kept.
    func update(_ settings: MetronomeSettings, startNewBar: Bool)
    /// While playing with a track: carries on from this file time, with no click before the first beat.
    func seekTrack(to time: TimeInterval)
    /// While playing with a track: moves the grid from the next beat not yet scheduled.
    func setFirstBeat(_ firstBeat: TimeInterval)
    /// Applies at once, also to audio already scheduled.
    func setMix(clickGain: Float, trackGain: Float)
    /// The file time being heard now, allowing for output delay; negative during a count-in. nil unless playing with a track.
    /// When playback ends from outside it still answers while `onStopped` runs, with the time heard last; nil afterwards.
    var trackTime: TimeInterval? { get }
    /// Silences or restores the click at once, without stopping. Beats keep being
    /// reported through `onBeat`, and the setting stays across stop and start.
    func setMuted(_ muted: Bool)
    /// Changes the click sound from the next beat that is not scheduled yet.
    /// The setting stays across stop and start.
    func setSound(_ sound: ClickSound)
    /// Plays an accented and then a normal click of the sound. Only while stopped;
    /// it plays even when muted, and a new preview cuts the previous one short.
    func preview(_ sound: ClickSound)
    /// Silences at once and cancels scheduled clicks and pending `onBeat` calls.
    func stop()
}
