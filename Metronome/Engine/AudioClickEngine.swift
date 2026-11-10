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
    /// The format the buffers were built for; nil until the engine has started once.
    private var format: AVAudioFormat?
    private var sound = ClickSound.default
    private var isMuted = false
    /// True while a preview owns the engine; playback never runs at the same time.
    private var isPreviewing = false
    private var previewToken = 0
    /// Time between the accented and the normal click of a preview.
    private static let previewGap = 0.5

    private var clock: BeatClock?
    /// True between `start` and the moment the audio session is active.
    private var isStarting = false
    private var settings = MetronomeSettings()
    /// Set when the next beat to be scheduled must be beat 1.
    private var newBarPending = false
    private var timer: Timer?
    /// Changes on every start and stop; late callbacks from an old run compare and bail out.
    private var runToken = 0
    private var observers: [NSObjectProtocol] = []
    private let session = AudioSessionGate()

    init() {
        engine.attach(player)
    }

    /// Returns at once. The audio session is activated off the main thread (it can block,
    /// worst on Bluetooth) and the first click is scheduled as soon as that is done.
    /// A failure after this point is reported through `onStopped`.
    func start(with settings: MetronomeSettings) throws {
        if clock != nil || isStarting { stop() }
        // Start wins over a preview. Its session deactivation is overtaken by the
        // activation below, so the session stays active.
        endPreview()

        self.settings = settings
        runToken += 1
        isStarting = true
        let token = runToken
        session.activate { [weak self] succeeded in
            // Stopped, or started again, while the session was being activated.
            guard let self, self.isStarting, self.runToken == token else { return }
            self.isStarting = false
            guard succeeded else {
                self.onStopped?()
                return
            }
            do {
                try self.beginPlaying()
            } catch {
                // Activating the session paused other apps' audio. Starting failed,
                // so give the audio back before reporting the failure.
                self.engine.stop()
                self.session.deactivate()
                self.onStopped?()
            }
        }
    }

    /// Runs once the session is active: no click may be scheduled before that.
    private func beginPlaying() throws {
        try startEngine()
        player.play()

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
        self.format = format
        buildBuffers()

        engine.connect(player, to: engine.mainMixerNode, format: format)
        try engine.start()
    }

    private func buildBuffers() {
        guard let format else { return }
        accentBuffer = ClickSynth.click(sound, accented: true, format: format)
        normalBuffer = ClickSynth.click(sound, accented: false, format: format)
    }

    /// Beats that are already scheduled keep the old sound; the next one uses the new one.
    func setSound(_ sound: ClickSound) {
        guard sound != self.sound else { return }
        self.sound = sound
        buildBuffers()
    }

    func update(_ settings: MetronomeSettings, startNewBar: Bool) {
        self.settings = settings
        if startNewBar { newBarPending = true }
    }

    func setMuted(_ muted: Bool) {
        isMuted = muted
        // A preview plays even when muted; the volume is restored when it ends.
        guard !isPreviewing else { return }
        // The player's own volume, so clicks that are already scheduled go quiet too.
        player.volume = muted ? 0 : 1
    }

    // MARK: - Preview

    func preview(_ sound: ClickSound) {
        guard clock == nil, !isStarting else { return }
        setSound(sound)
        previewToken += 1
        let token = previewToken
        isPreviewing = true
        if engine.isRunning {
            playPreview(token: token)
            return
        }
        session.activate { [weak self] succeeded in
            guard let self, self.isPreviewing, self.previewToken == token else { return }
            do {
                guard succeeded else { throw AudioClickEngineError.noOutput }
                try self.startEngine()
                self.playPreview(token: token)
            } catch {
                self.endPreview()
            }
        }
    }

    /// Schedules the accented and the normal click from a fresh player timeline, which
    /// also cuts a preview that is still sounding short.
    private func playPreview(token: Int) {
        player.stop()
        player.volume = 1
        player.play()
        let first = Int64(Self.startDelay * sampleRate)
        let second = first + Int64(Self.previewGap * sampleRate)
        if let accentBuffer { player.scheduleBuffer(accentBuffer, at: AVAudioTime(sampleTime: first, atRate: sampleRate)) }
        if let normalBuffer { player.scheduleBuffer(normalBuffer, at: AVAudioTime(sampleTime: second, atRate: sampleRate)) }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.startDelay + Self.previewGap + 0.3))
            guard let self, self.isPreviewing, self.previewToken == token else { return }
            self.endPreview()
        }
    }

    /// Stops the preview and gives the phone's audio back to other apps.
    private func endPreview() {
        guard isPreviewing else { return }
        isPreviewing = false
        previewToken += 1
        player.stop()
        engine.stop()
        player.volume = isMuted ? 0 : 1
        session.deactivate()
    }

    func stop() {
        guard clock != nil || isStarting else { return }
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
        if newBarPending {
            clock.startNewBar()
            newBarPending = false
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
        isStarting = false
        timer?.invalidate()
        timer = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        player.stop()
        engine.stop()
        // The sound is already off. Deactivating can block for a while (worst on
        // Bluetooth), so it happens off the main thread.
        session.deactivate()
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

/// Activates and deactivates the shared audio session off the main thread.
///
/// Both calls can block, so they run one at a time on a serial queue. Each request
/// takes a number; when its turn comes it runs only if it is still the newest request.
/// So after a quick Start then Stop (or Stop then Start) only the last one touches the
/// session, and an older request can never undo a newer one.
private final class AudioSessionGate: Sendable {
    private static let queue = DispatchQueue(label: "AudioSessionGate", qos: .userInitiated)
    /// The number of the newest request.
    private let newest = OSAllocatedUnfairLock(initialState: 0)

    /// Calls `completion` on the main actor with whether the session is now active.
    /// A request that was overtaken by a newer one never calls it.
    func activate(completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        let request = nextRequest()
        Self.queue.async { [newest] in
            guard newest.withLock({ $0 == request }) else { return }
            let session = AVAudioSession.sharedInstance()
            var succeeded = true
            do {
                // .playback: the click sounds even with the silent switch on.
                try session.setCategory(.playback, mode: .default)
                try session.setActive(true)
            } catch {
                succeeded = false
            }
            Task { @MainActor in completion(succeeded) }
        }
    }

    func deactivate() {
        let request = nextRequest()
        Self.queue.async { [newest] in
            guard newest.withLock({ $0 == request }) else { return }
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func nextRequest() -> Int {
        newest.withLock { number in
            number += 1
            return number
        }
    }
}

enum AudioClickEngineError: Error {
    case noOutput
}
