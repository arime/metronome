import AVFoundation
import os

/// Plays the clicks with `AVAudioEngine`, scheduled on the audio clock, and with a
/// backing track the file on the same clock.
///
/// A timer only decides *which* beats to hand to the audio engine a little ahead of
/// time; *when* each click sounds is fixed in sample time, so UI hiccups cannot
/// move a click.
@MainActor
final class AudioClickEngine: ClickEngine {
    var onBeat: ((ScheduledBeat) -> Void)?
    var onStopped: (() -> Void)?
    var onTrackEnded: (() -> Void)?

    /// How far ahead of the audio clock beats are handed to the player.
    private static let lookahead = 0.150
    private static let tickInterval = 0.025
    /// Delay before the first click, so it is never scheduled in the past.
    private static let startDelay = 0.050
    /// Delay before click and file start together, so the file's first audio is decoded in time.
    private static let trackStartDelay = 0.100
    /// A beat is never handed to the player closer to "now" than this.
    private static let schedulingMargin = 0.005

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    /// Plays the backing track, read from storage as it plays.
    private let trackPlayer = AVAudioPlayerNode()
    /// Sums click and track for the limiter during a track run.
    private let trackMixer = AVAudioMixerNode()
    /// Keeps click and track together below full scale. In the signal path only during a track run.
    private let limiter = AudioClickEngine.makeLimiter()
    private var sampleRate = 48_000.0
    private var accentBuffer: AVAudioPCMBuffer?
    private var normalBuffer: AVAudioPCMBuffer?
    /// The format the buffers were built for; nil until the engine has started once.
    private var format: AVAudioFormat?
    private var sound = ClickSound.default
    private var isMuted = false
    /// The mix's levels; the click's is 1 outside a track run.
    private var clickGain: Float = 1
    private var trackGain: Float = 1
    /// True while a preview owns the engine; playback never runs at the same time.
    private var isPreviewing = false
    private var previewToken = 0
    /// Time between the accented and the normal click of a preview.
    private static let previewGap = 0.5

    private var clock: BeatClock?
    /// The file of a track run, from `start(with:track:)` until the run ends; nil for a plain run.
    private var track: LoadedTrack?
    /// Places the click on the file's grid; set while a track run is playing.
    private var trackClock: TrackBeatClock?
    /// The host time, in seconds, at which both players start: sample time 0 on both timelines.
    private var trackStartHostSeconds: Double?
    /// The file time heard when playback ended from outside; set only while `onStopped` runs.
    private var trackTimeAtStop: TimeInterval?
    /// True between `start` and the moment the audio session is active.
    private var isStarting = false
    private var settings = MetronomeSettings()
    /// Set when the next beat to be scheduled must be beat 1.
    private var newBarPending = false
    private var timer: Timer?
    /// Changes on every start and stop; late callbacks from an old run compare and bail out.
    private var runToken = 0
    /// Changes whenever the players restart within a track run (a seek), so late callbacks
    /// from the schedule it replaced bail out too.
    private var trackGeneration = 0
    private var observers: [NSObjectProtocol] = []
    private let session = AudioSessionGate()

    private var isPlaying: Bool { clock != nil || trackClock != nil }

    init() {
        engine.attach(player)
        engine.attach(trackPlayer)
        engine.attach(trackMixer)
        engine.attach(limiter)
    }

    /// Returns at once. The audio session is activated off the main thread (it can block,
    /// worst on Bluetooth) and the first click is scheduled as soon as that is done.
    /// A failure after this point is reported through `onStopped`.
    func start(with settings: MetronomeSettings) throws {
        begin(with: settings, track: nil)
    }

    /// Opens the file before anything else, so a file that cannot be read leaves the
    /// current state untouched; then starts like `start(with:)`.
    func start(with settings: MetronomeSettings, track playback: TrackPlayback) throws {
        guard let file = try? AVAudioFile(forReading: playback.fileURL), file.length > 0 else {
            throw AudioClickEngineError.trackUnreadable
        }
        let track = LoadedTrack(
            file: file,
            length: Double(file.length) / file.processingFormat.sampleRate,
            firstBeat: playback.firstBeat,
            startTime: playback.startTime,
            firstClickIndex: playback.firstClickIndex
        )
        begin(with: settings, track: track, clickGain: playback.clickGain, trackGain: playback.trackGain)
    }

    private func begin(with settings: MetronomeSettings, track: LoadedTrack?, clickGain: Float = 1, trackGain: Float = 1) {
        if isPlaying || isStarting { stop() }
        // Start wins over a preview. Its session deactivation is overtaken by the
        // activation below, so the session stays active.
        endPreview()

        self.settings = settings
        self.track = track
        self.clickGain = clickGain
        self.trackGain = trackGain
        applyVolumes()
        runToken += 1
        isStarting = true
        let token = runToken
        session.activate { [weak self] succeeded in
            // Stopped, or started again, while the session was being activated.
            guard let self, self.isStarting, self.runToken == token else { return }
            self.isStarting = false
            guard succeeded else {
                self.forgetTrack()
                self.onStopped?()
                return
            }
            do {
                try self.beginPlaying()
            } catch {
                // Activating the session paused other apps' audio. Starting failed,
                // so give the audio back before reporting the failure.
                self.forgetTrack()
                self.engine.stop()
                self.session.deactivate()
                self.onStopped?()
            }
        }
    }

    /// Runs once the session is active: no click may be scheduled before that.
    private func beginPlaying() throws {
        try startEngine(track: track?.file)
        if let track {
            startPlayers(at: track.startTime, firstClickIndex: track.firstClickIndex)
        } else {
            player.play()
            clock = BeatClock(sampleRate: sampleRate, startSampleTime: Int64(Self.startDelay * sampleRate))
        }
        observeAudioChanges()

        let timer = Timer(timeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleDueBeats() }
        }
        // .common, so scheduling keeps running while the user drags the dial.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        scheduleDueBeats()
    }

    /// Builds the click buffers for the current output format, connects the players and
    /// starts the engine. With a file, click and track are summed and go through the
    /// limiter into the main mixer; without one the click goes straight to the main mixer.
    /// The main mixer's own connection to the output is left to the engine, which keeps
    /// it in step with the output's format.
    private func startEngine(track file: AVAudioFile? = nil) throws {
        sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        guard sampleRate > 0,
              let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let mixFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)
        else { throw AudioClickEngineError.noOutput }
        self.format = format
        buildBuffers()

        if let file {
            engine.connect(trackMixer, to: limiter, format: mixFormat)
            engine.connect(limiter, to: engine.mainMixerNode, format: mixFormat)
            engine.connect(player, to: trackMixer, format: format)
            // In the file's own format: the mixer converts it to the output's rate.
            engine.connect(trackPlayer, to: trackMixer, format: file.processingFormat)
        } else {
            engine.disconnectNodeOutput(trackPlayer)
            engine.disconnectNodeOutput(limiter)
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }
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

    /// During a track run the bar always follows from the first beat, so `startNewBar` is ignored.
    func update(_ settings: MetronomeSettings, startNewBar: Bool) {
        self.settings = settings
        if startNewBar, track == nil { newBarPending = true }
    }

    func setMuted(_ muted: Bool) {
        isMuted = muted
        applyVolumes()
    }

    func setMix(clickGain: Float, trackGain: Float) {
        // Outside a track run the click plays at full level; the next run brings its mix.
        guard track != nil else { return }
        self.clickGain = clickGain
        self.trackGain = trackGain
        applyVolumes()
    }

    /// The players' own volumes, so audio that is already scheduled follows at once.
    private func applyVolumes() {
        // A preview plays even when muted; the volume is restored when it ends.
        guard !isPreviewing else { return }
        player.volume = isMuted ? 0 : clickGain
        trackPlayer.volume = trackGain
    }

    // MARK: - Track

    /// Carries on from `time` with no count-in. While the session is still being
    /// activated, the run starts from there instead.
    func seekTrack(to time: TimeInterval) {
        guard track != nil else { return }
        guard trackClock != nil else {
            track?.startTime = time
            track?.firstClickIndex = 0
            return
        }
        // The engine can have stopped before its notification arrives; playing a node
        // of a stopped engine raises an exception.
        guard engine.isRunning else {
            stoppedExternally()
            return
        }
        startPlayers(at: time, firstClickIndex: 0)
        scheduleDueBeats()
    }

    /// Beats already handed to the player stay; the next one is on the moved grid.
    func setFirstBeat(_ firstBeat: TimeInterval) {
        track?.firstBeat = firstBeat
    }

    /// The last render cycle in file time, moved on by the time since on the host clock,
    /// less the delay until it is heard.
    var trackTime: TimeInterval? {
        if let trackTimeAtStop { return trackTimeAtStop }
        guard let trackClock else { return nil }
        let render = lastRender()
        let sinceRender = render.hostSeconds.map { Self.hostNow() - $0 } ?? 0
        return trackClock.fileTime(atSampleTime: render.sampleTime) + sinceRender - outputDelay
    }

    /// (Re)starts click and file from `fileTime`, both on one host time, so sample time 0
    /// of the click player and of the track player are the same instant. From there each
    /// timeline counts in its own rate (the output's for the click, the file's for the
    /// track), so file time `t` sounds `t - fileTime` seconds after that instant on both.
    private func startPlayers(at fileTime: TimeInterval, firstClickIndex: Int) {
        guard let track else { return }
        // Stopping a player calls the completion of the segment it drops; that one is stale.
        trackGeneration += 1
        player.stop()
        trackPlayer.stop()
        trackClock = TrackBeatClock(
            sampleRate: sampleRate, startSampleTime: 0, startTime: fileTime, firstClickIndex: firstClickIndex
        )
        scheduleFile(of: track, from: fileTime)

        let startHostTime = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: Self.trackStartDelay)
        trackStartHostSeconds = AVAudioTime.seconds(forHostTime: startHostTime)
        let start = AVAudioTime(hostTime: startHostTime)
        player.play(at: start)
        trackPlayer.play(at: start)
    }

    /// Schedules the file from `fileTime` to its end. During a count-in (`fileTime` < 0)
    /// the file starts from its beginning once the count-in has run for `-fileTime`.
    private func scheduleFile(of track: LoadedTrack, from fileTime: TimeInterval) {
        let rate = track.file.processingFormat.sampleRate
        let audibleFrom = max(0, fileTime)
        let startFrame = AVAudioFramePosition((audibleFrom * rate).rounded())
        let frameCount = min(track.file.length - startFrame, AVAudioFramePosition(AVAudioFrameCount.max))
        let token = runToken
        let generation = trackGeneration
        guard frameCount > 0 else {
            // Started at the very end: the file is over before it begins.
            Task { [weak self] in self?.trackFinished(token: token, generation: generation, heardToEnd: true) }
            return
        }
        // On the track player's timeline, which counts in the file's rate.
        let when = AVAudioTime(sampleTime: AVAudioFramePosition(((audibleFrom - fileTime) * rate).rounded()), atRate: rate)
        trackPlayer.scheduleSegment(
            track.file, startingFrame: startFrame, frameCount: AVAudioFrameCount(frameCount), at: when,
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            Task { @MainActor in self?.trackFinished(token: token, generation: generation) }
        }
    }

    /// The file has been heard to its end, or its segment was dropped by a stop, a seek or the
    /// system stopping the engine. The last can arrive before the interruption's notification,
    /// so it counts as the end only while the engine runs and the place heard is within
    /// `endTolerance` of the file's end; otherwise playback ended from outside and the position
    /// is kept. `heardToEnd` is set when the run started at or past the end.
    private func trackFinished(token: Int, generation: Int, heardToEnd: Bool = false) {
        guard runToken == token, trackGeneration == generation, trackClock != nil else { return }
        if !heardToEnd {
            guard engine.isRunning, let length = track?.length, let heard = trackTime,
                  heard >= length - Self.endTolerance
            else {
                stoppedExternally()
                return
            }
        }
        tearDown()
        onTrackEnded?()
    }

    /// How far before the file's end the place heard may be when the file's last audio has played.
    private static let endTolerance: TimeInterval = 0.5

    /// Back to a plain run's state: no file, and the click at full level.
    private func forgetTrack() {
        track = nil
        trackClock = nil
        trackStartHostSeconds = nil
        clickGain = 1
        trackGain = 1
        applyVolumes()
    }

    // MARK: - Preview

    func preview(_ sound: ClickSound) {
        guard !isPlaying, !isStarting else { return }
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
        applyVolumes()
        session.deactivate()
    }

    func stop() {
        guard isPlaying || isStarting else { return }
        tearDown()
    }

    // MARK: - Scheduling

    private func scheduleDueBeats() {
        guard isPlaying else { return }
        // The engine can die without telling us (for example a media services reset).
        guard engine.isRunning else {
            stoppedExternally()
            return
        }
        let render = lastRender()
        let now = render.sampleTime
        let beats = dueBeats(
            before: now + Int64(Self.lookahead * sampleRate),
            notBefore: now + Int64(Self.schedulingMargin * sampleRate)
        )

        let latency = outputDelay
        let hostNow = Self.hostNow()
        let token = runToken
        let generation = trackGeneration
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
                guard let self, self.runToken == token, self.trackGeneration == generation else { return }
                self.onBeat?(beat)
            }
        }
    }

    /// The next beats to hand to the player: from the file's grid during a track run,
    /// else from the free-running beat clock.
    private func dueBeats(before horizon: Int64, notBefore earliest: Int64) -> [ScheduledBeat] {
        if var trackClock, let track {
            let grid = TrackGrid(
                firstBeat: track.firstBeat, bpm: settings.bpm, beatsPerBar: settings.timeSignature.beatsPerBar
            )
            // Nothing before the players' shared start: it would not sound at its time.
            let beats = trackClock.beats(
                before: horizon, notBefore: max(earliest, 0), endTime: track.length,
                grid: grid, accents: settings.accents
            )
            self.trackClock = trackClock
            return beats
        }
        guard var clock else { return [] }
        if newBarPending {
            clock.startNewBar()
            newBarPending = false
        }
        let beats = clock.beats(
            before: horizon,
            notBefore: earliest,
            bpm: settings.bpm,
            beatsPerBar: settings.timeSignature.beatsPerBar,
            accents: settings.accents
        )
        self.clock = clock
        return beats
    }

    /// The last render cycle: where it was on the click player's own timeline (which
    /// starts at zero when the player starts playing) and, when known, on the host clock.
    /// Before a track run's players start, the timeline is counted back from their
    /// start on the host clock instead, as there is no player time to ask yet.
    private func lastRender() -> (sampleTime: Int64, hostSeconds: Double?) {
        if let trackStartHostSeconds {
            let hostNow = Self.hostNow()
            if hostNow < trackStartHostSeconds {
                return (Int64(((hostNow - trackStartHostSeconds) * sampleRate).rounded()), hostNow)
            }
        }
        guard let nodeTime = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: nodeTime)
        else { return (0, nil) }
        let hostSeconds = nodeTime.isHostTimeValid ? AVAudioTime.seconds(forHostTime: nodeTime.hostTime) : nil
        return (playerTime.sampleTime, hostSeconds)
    }

    /// From a render cycle to the ear: the output's latency, plus the limiter's
    /// look-ahead while it is in the signal path.
    private var outputDelay: TimeInterval {
        AVAudioSession.sharedInstance().outputLatency + (track != nil ? limiter.latency : 0)
    }

    private static func hostNow() -> Double {
        AVAudioTime.seconds(forHostTime: mach_absolute_time())
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
        trackPlayer.stop()
        engine.stop()
        forgetTrack()
        // The sound is already off. Deactivating can block for a while (worst on
        // Bluetooth), so it happens off the main thread.
        session.deactivate()
    }

    /// Playback ended from outside: stop cleanly and tell the model.
    /// The track time is read before the teardown and kept while `onStopped` runs,
    /// so the model can keep the position.
    private func stoppedExternally() {
        guard isPlaying else { return }
        let heard = trackTime
        tearDown()
        trackTimeAtStop = heard
        onStopped?()
        trackTimeAtStop = nil
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

    /// A look-ahead peak limiter. Its look-ahead (the attack time) lowers the gain before
    /// a peak arrives, so the click's attack keeps its shape; the whole output is delayed
    /// by that time instead, which `outputDelay` allows for.
    private static func makeLimiter() -> AVAudioUnitEffect {
        let limiter = AVAudioUnitEffect(audioComponentDescription: AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_PeakLimiter,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        ))
        // Attack 1 ms (range 0.5 to 30), release 40 ms (the longest, so it pumps least).
        AudioUnitSetParameter(limiter.audioUnit, kLimiterParam_AttackTime, kAudioUnitScope_Global, 0, 0.001, 0)
        AudioUnitSetParameter(limiter.audioUnit, kLimiterParam_DecayTime, kAudioUnitScope_Global, 0, 0.040, 0)
        return limiter
    }
}

/// A backing track opened for one run.
private struct LoadedTrack {
    let file: AVAudioFile
    /// The file's length in seconds; no click is placed at or after it.
    let length: TimeInterval
    var firstBeat: TimeInterval
    /// Where the run starts in file time, and the lowest beat index that clicks from there.
    var startTime: TimeInterval
    var firstClickIndex: Int
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
    /// The backing track's file cannot be opened as audio, or has no frames.
    case trackUnreadable
}
