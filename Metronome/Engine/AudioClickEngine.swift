import AVFoundation
import os

/// Plays the clicks with `AVAudioEngine`, scheduled on the audio clock.
///
/// A timer only decides *which* beats to hand to the audio engine a little ahead of
/// time; *when* each click sounds is fixed in sample time, so UI hiccups cannot
/// move a click.
@MainActor
final class AudioClickEngine: ClickEngine {
    var onBeat: ((ScheduledBeat) -> Void)?
    var onStopped: (() -> Void)?

    /// How far ahead of the audio clock beats are handed to the player.
    private static let lookahead = 0.150
    private static let tickInterval = 0.025
    /// Delay before the first click, so it is never scheduled in the past.
    private static let startDelay = 0.050
    /// A beat is never handed to the player closer to "now" than this.
    private static let schedulingMargin = 0.005

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var sampleRate = 48_000.0
    private var accentBuffer: AVAudioPCMBuffer?
    private var normalBuffer: AVAudioPCMBuffer?

    private var clock: BeatClock?
    private var settings = MetronomeSettings()
    private var timer: Timer?
    /// Changes on every start and stop; late callbacks from an old run compare and bail out.
    private var runToken = 0
    private var observers: [NSObjectProtocol] = []
    private let session = AudioSessionGate()

    init() {
        engine.attach(player)
    }

    func start(with settings: MetronomeSettings) throws {
        if clock != nil { stop() }

        // Synchronous: no click may be scheduled before the session is active.
        try session.activate()

        do {
            try startEngine()
        } catch {
            // Activating the session paused other apps' audio. Starting failed,
            // so give the audio back before reporting the failure.
            engine.stop()
            session.deactivateNow()
            throw error
        }
        player.play()

        self.settings = settings
        runToken += 1
        clock = BeatClock(sampleRate: sampleRate, startSampleTime: Int64(Self.startDelay * sampleRate))
        observeAudioChanges()

        let timer = Timer(timeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleDueBeats() }
        }
        // .common, so scheduling keeps running while the user drags the dial.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        scheduleDueBeats()
    }

    /// Builds the click buffers for the current output format and starts the engine.
    private func startEngine() throws {
        sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        guard sampleRate > 0,
              let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        else { throw AudioClickEngineError.noOutput }
        accentBuffer = ClickSynth.click(accented: true, format: format)
        normalBuffer = ClickSynth.click(accented: false, format: format)

        engine.connect(player, to: engine.mainMixerNode, format: format)
        try engine.start()
    }

    func update(_ settings: MetronomeSettings) {
        self.settings = settings
    }

    func stop() {
        guard clock != nil else { return }
        tearDown()
    }

    // MARK: - Scheduling

    private func scheduleDueBeats() {
        guard var clock else { return }
        // The engine can die without telling us (for example a media services reset).
        guard engine.isRunning else {
            stoppedExternally()
            return
        }
        let render = lastRender()
        let now = render.sampleTime
        let horizon = now + Int64(Self.lookahead * sampleRate)
        let beats = clock.beats(
            before: horizon,
            notBefore: now + Int64(Self.schedulingMargin * sampleRate),
            bpm: settings.bpm,
            beatsPerBar: settings.timeSignature.beatsPerBar,
            accents: settings.accents
        )
        self.clock = clock

        let latency = AVAudioSession.sharedInstance().outputLatency
        let hostNow = AVAudioTime.seconds(forHostTime: mach_absolute_time())
        let token = runToken
        for beat in beats {
            guard let buffer = beat.isAccented ? accentBuffer : normalBuffer else { continue }
            player.scheduleBuffer(buffer, at: AVAudioTime(sampleTime: beat.sampleTime, atRate: sampleRate))

            // Until the beat is heard. `now` is the last render cycle, which is already
            // some milliseconds old, so measure against the host clock when we can.
            let untilBeat = Double(beat.sampleTime - now) / sampleRate
            let sinceRender = render.hostSeconds.map { hostNow - $0 } ?? 0
            let delay = max(0, untilBeat - sinceRender + latency)
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                guard let self, self.runToken == token else { return }
                self.onBeat?(beat)
            }
        }
    }

    /// The last render cycle: where it was on the player's own timeline (which starts
    /// at zero when the player starts playing) and, when known, on the host clock.
    private func lastRender() -> (sampleTime: Int64, hostSeconds: Double?) {
        guard let nodeTime = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: nodeTime)
        else { return (0, nil) }
        let hostSeconds = nodeTime.isHostTimeValid ? AVAudioTime.seconds(forHostTime: nodeTime.hostTime) : nil
        return (playerTime.sampleTime, hostSeconds)
    }

    // MARK: - Stopping

    private func tearDown() {
        runToken += 1
        clock = nil
        timer?.invalidate()
        timer = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        player.stop()
        engine.stop()
        // The sound is already off. Deactivating can block for a while (worst on
        // Bluetooth), so it must not hold up the main thread.
        session.deactivateLater()
    }

    /// Playback ended from outside: stop cleanly and tell the model.
    private func stoppedExternally() {
        guard clock != nil else { return }
        tearDown()
        onStopped?()
    }

    private func observeAudioChanges() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()

        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification, object: session, queue: .main
        ) { [weak self] notification in
            let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            guard raw == AVAudioSession.InterruptionType.began.rawValue else { return }
            MainActor.assumeIsolated { self?.stoppedExternally() }
        })

        observers.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: session, queue: .main
        ) { [weak self] notification in
            let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            guard raw == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
            MainActor.assumeIsolated { self?.stoppedExternally() }
        })

        observers.append(center.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                // The engine stops itself when the change is real. If it is still
                // running (the format merely settled after start), keep playing.
                guard let self, !self.engine.isRunning else { return }
                self.stoppedExternally()
            }
        })

        observers.append(center.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification, object: session, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.stoppedExternally() }
        })
    }
}

/// Activates and deactivates the shared audio session, one call at a time.
///
/// Deactivation runs off the main thread, so it can still be waiting when the user
/// starts again. The lock keeps the two apart and the count tells a waiting
/// deactivation that a newer start has taken over the session.
private final class AudioSessionGate: Sendable {
    private static let queue = DispatchQueue(label: "AudioSessionGate", qos: .userInitiated)
    /// How many times the session has been activated.
    private let activations = OSAllocatedUnfairLock(initialState: 0)

    func activate() throws {
        try activations.withLock { count in
            let session = AVAudioSession.sharedInstance()
            // .playback: the click sounds even with the silent switch on.
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            // Counted only on success: after a failure a waiting deactivation must still run.
            count += 1
        }
    }

    func deactivateNow() {
        activations.withLock { _ in Self.deactivate() }
    }

    func deactivateLater() {
        let stopped = activations.withLock { $0 }
        Self.queue.async { [activations] in
            activations.withLock { count in
                // Started again since: the session now belongs to the new run.
                guard count == stopped else { return }
                Self.deactivate()
            }
        }
    }

    private static func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

enum AudioClickEngineError: Error {
    case noOutput
}
