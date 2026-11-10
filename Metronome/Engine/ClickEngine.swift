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
    /// Applies from the next beat that is not scheduled yet. With `startNewBar`,
    /// that beat is beat 1; otherwise the bar position is kept.
    func update(_ settings: MetronomeSettings, startNewBar: Bool)
    /// Silences or restores the click at once, without stopping. Beats keep being
    /// reported through `onBeat`, and the setting stays across stop and start.
    func setMuted(_ muted: Bool)
    /// Silences at once and cancels scheduled clicks and pending `onBeat` calls.
    func stop()
}
