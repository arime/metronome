/// What the screen model needs from whatever makes the clicks.
@MainActor
protocol ClickEngine: AnyObject {
    /// Called at the moment each beat sounds.
    var onBeat: ((ScheduledBeat) -> Void)? { get set }
    /// Called when playback ended for a reason other than `stop()`:
    /// an interruption, an audio route change or an engine failure.
    var onStopped: (() -> Void)? { get set }

    /// Starts on beat 1 with the first click immediately.
    func start(with settings: MetronomeSettings) throws
    /// Applies from the next beat that is not scheduled yet.
    func update(_ settings: MetronomeSettings)
    /// Silences at once and cancels scheduled clicks and pending `onBeat` calls.
    func stop()
}
