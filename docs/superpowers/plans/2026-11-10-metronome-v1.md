# Metronome v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the single-screen iOS metronome described in the v1 specification, running in the simulator with placeholder click sounds.

**Architecture:** One SwiftUI app target. Pure value types hold the rules (tempo, time signature, accents, tap tempo, beat timing) and are unit tested. An `AVAudioEngine`-based engine schedules clicks on the audio clock from those types and reports each beat to an `@Observable` model, which drives the views, effects and haptics. The engine sits behind a protocol so the model is tested with a fake.

**Tech Stack:** Swift 6.2 (Swift 6 language mode), SwiftUI, Observation, AVFoundation, UIKit feedback generators, Swift Testing. Xcode 26. No third-party dependencies and no project generator: the Xcode project is hand-written using file-system-synchronized groups, so adding files never requires editing it.

**Spec:** `docs/specification.md`. Design: Paper file "Snappy Metronome", page "v1.0".

## Global Constraints

- iPhone only, portrait only, dark appearance only. Deployment target iOS 18.0.
- System font (SF Pro) everywhere; Inter in the Paper boards is a stand-in.
- Tempo is an integer in 30…250. Default 120.
- Time signatures: 2/4, 3/4, 4/4, 5/4, 6/8, 7/8, 9/8, 12/8. Beats per bar is the top number. One beat is one click.
- Accents: any subset of beats, including empty. Default {1}.
- Colours exactly as spec section 5.9. Amber `#FFB224` is the only accent colour.
- The header settings button is not built.
- Clicks are scheduled on the audio clock, never from a UI timer.
- Click sounds in this plan are generated placeholders. Final sounds are a later, separate piece of work.
- Placeholders until decided: product name `Metronome`, bundle identifier `me.arime.metronome`, no signing team, no app icon.
- All work happens on branch `v1-implementation`. Commit with the `commit-commands:commit` skill; subjects are imperative, capitalized, no prefix, no attribution lines.
- Test command prefix, called `TEST` below:
  `xcodebuild test -project Metronome.xcodeproj -scheme Metronome -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`

## Review Focus

1. **Audio route changes while playing** (headphones unplugged, Bluetooth connects): playback must stop cleanly and the screen must show Ready; it must never show Playing while silent. Pinned in Task 6 and Task 7.
2. **Stored settings that no longer make sense** (corrupt data, BPM out of range, an accent on beat 5 with 3/4 stored): the app launches with sanitized values, never crashes. Pinned in Task 3.
3. **Dragging the tempo fast while playing at high tempo:** no burst of clicks, no skipped beat, bar position kept. Pinned in Task 4.
4. **Extreme tap tempo input** (two taps 20 ms apart, taps exactly 2 s apart, a single tap): result clamps to 30…250, a single tap changes nothing. Pinned in Task 2.
5. **Start and Stop pressed in quick succession:** exactly one engine run, and no click sounds after Stop. Pinned in Task 6 and Task 7.

## File Structure

```
Metronome.xcodeproj/project.pbxproj     hand-written; app + unit test targets, shared scheme
Metronome/
  MetronomeApp.swift                    app entry, forces dark scheme
  Info.plist                            portrait only, iPhone only
  Assets.xcassets/                      AccentColor only
  Model/TimeSignature.swift             the eight signatures, beats per bar, hints
  Model/Tempo.swift                     range, clamp, names, arc mapping, dial geometry
  Model/TapTempo.swift                  tap averaging
  Model/MetronomeSettings.swift         bpm + signature + accents and their rules
  Model/SettingsStore.swift             UserDefaults persistence with sanitizing
  Model/BeatClock.swift                 pure beat timing in sample time
  Engine/ClickEngine.swift              protocol the model talks to
  Engine/ClickSynth.swift               placeholder click buffers
  Engine/AudioClickEngine.swift         AVAudioEngine implementation
  Engine/Haptics.swift                  beat and UI haptics
  MetronomeModel.swift                  @Observable screen state
  Views/Theme.swift                     colours and shared metrics
  Views/MetronomeScreen.swift           layout of the one screen
  Views/TempoDial.swift                 ticks, knob, number, drag gesture
  Views/BeatEffects.swift               ripples, glow, number pulse
  Views/TempoControls.swift             − / Tap tempo / +
  Views/TimeSignatureRow.swift          row + picker sheet
  Views/AccentTiles.swift               beat tiles, one or two rows
  Views/StartStopButton.swift
MetronomeTests/                         one test file per Model file, plus model tests
```

---

### Task 1: Project skeleton

**Files:**
- Create: `Metronome.xcodeproj/project.pbxproj`, `Metronome.xcodeproj/xcshareddata/xcschemes/Metronome.xcscheme`, `Metronome/MetronomeApp.swift`, `Metronome/Info.plist`, `Metronome/Assets.xcassets/Contents.json`, `Metronome/Assets.xcassets/AccentColor.colorset/Contents.json`, `MetronomeTests/SmokeTests.swift`

**Interfaces:**
- Produces: scheme `Metronome` with app target `Metronome` and unit test target `MetronomeTests` (hosted by the app, `@testable import Metronome`). Both targets use `PBXFileSystemSynchronizedRootGroup` for their folders, `SWIFT_VERSION = 6.0`, `IPHONEOS_DEPLOYMENT_TARGET = 18.0`, `TARGETED_DEVICE_FAMILY = 1`.

- [ ] **Step 1:** Create branch `v1-implementation`.
- [ ] **Step 2:** Write the project file, scheme, `Info.plist` (`UISupportedInterfaceOrientations` = portrait only, `UIUserInterfaceStyle` = Dark, `UILaunchScreen` empty dict) and an app entry showing a plain ink-coloured screen with `.preferredColorScheme(.dark)`.
- [ ] **Step 3:** Write `SmokeTests.swift` with one Swift Testing test: `#expect(Bundle.main.bundleIdentifier == "me.arime.metronome")`.
- [ ] **Step 4:** Run `TEST`. Expected: build succeeds, 1 test passes.
- [ ] **Step 5:** Commit: "Add Xcode project skeleton".

### Task 2: Tempo, time signature and tap tempo rules

**Files:**
- Create: `Metronome/Model/TimeSignature.swift`, `Metronome/Model/Tempo.swift`, `Metronome/Model/TapTempo.swift`
- Test: `MetronomeTests/TimeSignatureTests.swift`, `MetronomeTests/TempoTests.swift`, `MetronomeTests/TapTempoTests.swift`

**Interfaces:**
- Produces:

```swift
enum TimeSignature: String, CaseIterable, Codable, Sendable {
    case twoFour = "2/4", threeFour = "3/4", fourFour = "4/4", fiveFour = "5/4",
         sixEight = "6/8", sevenEight = "7/8", nineEight = "9/8", twelveEight = "12/8"
    var beatsPerBar: Int { get }   // top number
    var hint: String { get }       // spec 5.6 table
}

enum Tempo {
    static let range: ClosedRange<Int>            // 30...250
    static let defaultBPM: Int                    // 120
    static func clamp(_ bpm: Int) -> Int
    static func name(for bpm: Int) -> String      // spec 5.2 table
    static func arcFraction(for bpm: Int) -> Double          // (bpm - 30) / 220
    static func bpm(forArcFraction fraction: Double) -> Int  // rounded, clamped
}

enum DialGeometry {
    /// Offset of the touch from the dial centre, y pointing down.
    /// The arc starts at 7:30, runs clockwise over the top, ends at 4:30.
    /// Touches in the bottom gap clamp to the nearer end.
    static func arcFraction(dx: Double, dy: Double) -> Double
    /// True when the touch starts between 0.35 and 0.55 dial diameters from the centre
    /// (105 pt and 165 pt on the 300 pt dial).
    static func startsDrag(dx: Double, dy: Double, dialDiameter: Double) -> Bool
}

struct TapTempo {
    /// Returns the new BPM from the second tap on; nil for the first tap of a series.
    mutating func tap(at time: TimeInterval) -> Int?
}
```

- [ ] **Step 1: Write the failing tests.** Assertions:

```swift
// TimeSignatureTests
#expect(TimeSignature.allCases.map(\.rawValue) == ["2/4","3/4","4/4","5/4","6/8","7/8","9/8","12/8"])
#expect(TimeSignature.allCases.map(\.beatsPerBar) == [2,3,4,5,6,7,9,12])
#expect(TimeSignature.allCases.map(\.hint) == ["March","Waltz","Common","Odd","Compound","Odd","Compound","Compound"])

// TempoTests
#expect(Tempo.clamp(10) == 30); #expect(Tempo.clamp(999) == 250)
#expect([30,39,40,59,60,65,66,75,76,107,108,119,120,155,156,175,176,199,200,250].map(Tempo.name(for:)) ==
  ["Grave","Grave","Largo","Largo","Larghetto","Larghetto","Adagio","Adagio","Andante","Andante",
   "Moderato","Moderato","Allegro","Allegro","Vivace","Vivace","Presto","Presto","Prestissimo","Prestissimo"])
#expect(Tempo.arcFraction(for: 30) == 0); #expect(Tempo.arcFraction(for: 250) == 1)
#expect(Tempo.bpm(forArcFraction: 0.5) == 140)
#expect(Tempo.bpm(forArcFraction: -1) == 30); #expect(Tempo.bpm(forArcFraction: 2) == 250)
// every BPM survives a round trip through the arc
#expect((30...250).allSatisfy { Tempo.bpm(forArcFraction: Tempo.arcFraction(for: $0)) == $0 })

// DialGeometry (tolerance 1e-9)
arcFraction(dx: 0, dy: -1) ≈ 0.5        // straight up
arcFraction(dx: -1, dy: 0) ≈ 1.0/6      // left
arcFraction(dx: 1, dy: 0) ≈ 5.0/6       // right
arcFraction(dx: -0.1, dy: 1) == 0       // gap, left half
arcFraction(dx: 0.1, dy: 1) == 1        // gap, right half
startsDrag(dx: 0, dy: -104, dialDiameter: 300) == false
startsDrag(dx: 0, dy: -105, dialDiameter: 300) == true
startsDrag(dx: 165, dy: 0, dialDiameter: 300) == true
startsDrag(dx: 166, dy: 0, dialDiameter: 300) == false

// TapTempoTests
var t = TapTempo()
#expect(t.tap(at: 0) == nil)
#expect(t.tap(at: 0.5) == 120)
#expect(t.tap(at: 1.0) == 120)
// averages the last four intervals only
var u = TapTempo(); for time in [0, 1.0, 1.5, 2.0, 2.5] { _ = u.tap(at: time) }
#expect(u.tap(at: 3.0) == 120)                      // intervals 0.5 ×4; the 1.0 dropped
// a pause longer than 2 s starts a new series
var v = TapTempo(); _ = v.tap(at: 0); _ = v.tap(at: 0.5)
#expect(v.tap(at: 2.6) == nil)
// exactly 2 s is still the same series and clamps
var w = TapTempo(); _ = w.tap(at: 0); #expect(w.tap(at: 2.0) == 30)
// very fast taps clamp
var x = TapTempo(); _ = x.tap(at: 0); #expect(x.tap(at: 0.02) == 250)
// identical timestamps do not divide by zero
var y = TapTempo(); _ = y.tap(at: 1); #expect(y.tap(at: 1) == 250)
```

- [ ] **Step 2:** Run `TEST`. Expected: fails to compile (types missing).
- [ ] **Step 3:** Implement the three files.
- [ ] **Step 4:** Run `TEST`. Expected: all pass.
- [ ] **Step 5:** Commit: "Add tempo, time signature and tap tempo rules".

### Task 3: Settings and persistence

**Files:**
- Create: `Metronome/Model/MetronomeSettings.swift`, `Metronome/Model/SettingsStore.swift`
- Test: `MetronomeTests/MetronomeSettingsTests.swift`, `MetronomeTests/SettingsStoreTests.swift`

**Interfaces:**
- Consumes: `TimeSignature`, `Tempo` (Task 2).
- Produces:

```swift
struct MetronomeSettings: Codable, Equatable, Sendable {
    private(set) var bpm: Int                      // default 120
    private(set) var timeSignature: TimeSignature  // default .fourFour
    private(set) var accents: Set<Int>             // default [1]
    init()
    mutating func setBPM(_ bpm: Int)               // clamps
    mutating func toggleAccent(beat: Int)          // ignores beats outside 1...beatsPerBar
    /// Returns true when the signature changed; a change resets accents to [1].
    @discardableResult mutating func setTimeSignature(_ signature: TimeSignature) -> Bool
    /// Clamps bpm and drops accents outside the bar.
    func sanitized() -> MetronomeSettings
}

struct SettingsStore: Sendable {
    init(defaults: UserDefaults = .standard)       // key "metronome.settings.v1", JSON
    func load() -> MetronomeSettings               // defaults when missing or unreadable; always sanitized
    func save(_ settings: MetronomeSettings)
}
```

- [ ] **Step 1: Write the failing tests.** Assertions:

```swift
var s = MetronomeSettings()
#expect(s.bpm == 120 && s.timeSignature == .fourFour && s.accents == [1])
s.setBPM(999); #expect(s.bpm == 250)
s.toggleAccent(beat: 3); #expect(s.accents == [1, 3])
s.toggleAccent(beat: 1); s.toggleAccent(beat: 3); #expect(s.accents.isEmpty)   // none is allowed
s.toggleAccent(beat: 5); #expect(s.accents.isEmpty)                             // outside 4/4
s.toggleAccent(beat: 2)
#expect(s.setTimeSignature(.fourFour) == false); #expect(s.accents == [2])     // same: nothing changes
#expect(s.setTimeSignature(.sevenEight) == true); #expect(s.accents == [1])    // change: reset

// SettingsStoreTests, each with a fresh UserDefaults(suiteName: UUID().uuidString)
store.load() == MetronomeSettings()                                  // nothing stored
store.save(custom); store.load() == custom                           // round trip
defaults.set(Data("not json".utf8), forKey: "metronome.settings.v1"); store.load() == MetronomeSettings()
// stored JSON {"bpm":900,"timeSignature":"3/4","accents":[1,5]} loads as bpm 250, 3/4, accents [1]
// stored JSON with an unknown timeSignature "11/16" loads as defaults
```

- [ ] **Step 2:** Run `TEST`. Expected: fails to compile.
- [ ] **Step 3:** Implement both files.
- [ ] **Step 4:** Run `TEST`. Expected: all pass.
- [ ] **Step 5:** Commit: "Add settings rules and persistence".

### Task 4: Beat timing

**Files:**
- Create: `Metronome/Model/BeatClock.swift`
- Test: `MetronomeTests/BeatClockTests.swift`

**Interfaces:**
- Produces:

```swift
struct ScheduledBeat: Equatable, Sendable {
    let beat: Int            // 1...beatsPerBar
    let isAccented: Bool
    let sampleTime: Int64
}

struct BeatClock: Sendable {
    /// The first beat is beat 1 at startSampleTime.
    init(sampleRate: Double, startSampleTime: Int64)
    /// Returns, in order, every beat not yet returned whose sample time is before `horizon`.
    /// bpm, beatsPerBar and accents apply to beats produced by this call; beats already
    /// returned are never changed. A new bpm sets the interval after the last returned beat.
    mutating func beats(before horizon: Int64, bpm: Int, beatsPerBar: Int, accents: Set<Int>) -> [ScheduledBeat]
}
```

The next beat time is kept as a `Double` and rounded only when a beat is returned, so rounding never accumulates.

- [ ] **Step 1: Write the failing tests.** Assertions (sample rate 48000, start 0 unless stated):

```swift
// spacing and bar wrap at 120 BPM in 4/4, accents [1, 3]
beats(before: 120_001, ...) == [(1,true,0), (2,false,24_000), (3,true,48_000), (4,false,72_000), (1,true,96_000), (2,false,120_000)]
// a later call continues, never repeats
// horizon is exclusive: beats(before: 24_000, ...) returns only beat 1
// start offset: init(startSampleTime: 5_000) puts beat 1 at 5_000
// no drift: at 250 BPM the 2501st beat (the one 10 minutes after the first) is at exactly 28_800_000
// no drift at an uneven tempo: at 137 BPM every one of the first 5000 beats is within 1 sample of n * 60/137 * 48000
// tempo change: after beats at 0 and 24_000 at 120 BPM, switching to 60 BPM puts the next beat at 72_000
// accent change: a beat already returned as accented stays so; the same beat number in the next bar follows the new set
// signature shrink: after returning beat 4 of 4/4, calling with beatsPerBar 3 returns beat 1 next
// fast tempo dragging: calling with bpm alternating 30 and 250 on successive 512-sample horizons for 10 s
//   never returns two beats closer than 11_520 samples (the 250 BPM interval) and never skips a beat number
```

- [ ] **Step 2:** Run `TEST`. Expected: fails to compile.
- [ ] **Step 3:** Implement `BeatClock`.
- [ ] **Step 4:** Run `TEST`. Expected: all pass.
- [ ] **Step 5:** Commit: "Add drift-free beat clock".

### Task 5: Click engine

**Files:**
- Create: `Metronome/Engine/ClickEngine.swift`, `Metronome/Engine/ClickSynth.swift`, `Metronome/Engine/AudioClickEngine.swift`
- Test: `MetronomeTests/ClickSynthTests.swift`

**Interfaces:**
- Consumes: `BeatClock`, `ScheduledBeat`, `MetronomeSettings`.
- Produces:

```swift
@MainActor protocol ClickEngine: AnyObject {
    /// Called on the main actor at the moment each beat sounds.
    var onBeat: ((ScheduledBeat) -> Void)? { get set }
    /// Called when playback ended for a reason other than stop(): interruption, route change, engine failure.
    var onStopped: (() -> Void)? { get set }
    func start(with settings: MetronomeSettings) throws   // first click immediately, beat 1
    func update(_ settings: MetronomeSettings)            // applies from the next unscheduled beat
    func stop()                                           // silences at once, cancels scheduled clicks and pending onBeat calls
}

enum ClickSynth {
    /// Placeholder click: a 30 ms sine burst with exponential decay.
    /// Accented: 1760 Hz, peak 1.0. Normal: 1175 Hz, peak 0.6.
    static func click(accented: Bool, format: AVAudioFormat) -> AVAudioPCMBuffer
}

@MainActor final class AudioClickEngine: ClickEngine { init() }
```

`AudioClickEngine` details the signature does not determine:
- Audio session category `.playback` (plays with the silent switch on), activated in `start`, deactivated in `stop`.
- One `AVAudioEngine` with one `AVAudioPlayerNode`. A repeating 20 ms `DispatchSourceTimer` asks `BeatClock` for beats before `now + 100 ms` in the player's sample time and schedules each buffer with `scheduleBuffer(_:at:)`. The first beat is placed 50 ms after start.
- For each scheduled beat, `onBeat` is dispatched to the main actor for that beat's host time plus the session's output latency.
- A run token is incremented by `start` and `stop`; dispatched `onBeat` calls carrying an old token do nothing.
- `AVAudioSession.interruptionNotification` (began), `AVAudioSession.routeChangeNotification` (old device unavailable) and `AVAudioEngineConfigurationChange` each stop playback and call `onStopped`.

- [ ] **Step 1: Write the failing tests.** For both `accented` values at 48 kHz mono: frame length is 1440 (30 ms); peak absolute sample is within 0.01 of 1.0 / 0.6; the last sample's absolute value is below 0.01.
- [ ] **Step 2:** Run `TEST`. Expected: fails to compile.
- [ ] **Step 3:** Implement the three files.
- [ ] **Step 4:** Run `TEST`. Expected: all pass. The audio engine itself is verified by ear in Task 7.
- [ ] **Step 5:** Commit: "Add audio click engine with placeholder sounds".

### Task 6: Screen model

**Files:**
- Create: `Metronome/MetronomeModel.swift`, `Metronome/Engine/Haptics.swift`
- Test: `MetronomeTests/MetronomeModelTests.swift` (includes a `FakeClickEngine` recording calls)

**Interfaces:**
- Consumes: `ClickEngine`, `MetronomeSettings`, `SettingsStore`, `TapTempo`, `ScheduledBeat`.
- Produces:

```swift
@MainActor protocol HapticsPlaying { func beat(accented: Bool); func selection(); func transport() }
@MainActor final class Haptics: HapticsPlaying { init() }
// beat: light impact 0.5, or rigid impact 1.0 when accented. selection: selection tick. transport: medium impact.

struct BeatEvent: Equatable { let id: Int; let beat: Int; let isAccented: Bool }   // id increases by 1 per beat

@MainActor @Observable final class MetronomeModel {
    init(engine: ClickEngine, store: SettingsStore, haptics: HapticsPlaying)
    private(set) var settings: MetronomeSettings
    private(set) var isPlaying: Bool
    private(set) var currentBeat: Int?
    private(set) var lastBeat: BeatEvent?          // views animate on change of id
    var tempoName: String { get }

    func togglePlayback()
    func stop()
    func setBPM(_ bpm: Int)                        // selection haptic only when the value changes
    func nudgeBPM(by delta: Int)
    func tapTempo(at time: TimeInterval)
    func toggleAccent(beat: Int)
    func selectTimeSignature(_ signature: TimeSignature)
    func appDidLeaveForeground()                   // stops playback
}
```

Every settings change is saved to the store and, while playing, passed to `engine.update`. `tapTempo` and `toggleAccent` each play one selection haptic per call; starting and stopping by the user play the transport haptic.

- [ ] **Step 1: Write the failing tests.** Assertions:

```swift
// starts stopped with stored settings
// togglePlayback(): isPlaying true, engine.startCount == 1, haptics.transportCount == 1
// two togglePlayback() calls: isPlaying false, engine.stopCount == 1, currentBeat == nil
// engine.start throwing leaves isPlaying false
// engine.onBeat(ScheduledBeat(beat: 2, isAccented: false, sampleTime: 0)) while playing:
//   currentBeat == 2, lastBeat?.beat == 2, haptics.beats == [false]; a second beat has id + 1
// engine.onBeat after stop() changes nothing (late callback)
// engine.onStopped() while playing: isPlaying false, currentBeat nil, engine.stopCount unchanged
// setBPM(140) while playing: settings.bpm 140, engine.lastUpdate?.bpm == 140, isPlaying still true, store.load().bpm == 140
// setBPM(140) twice: haptics.selectionCount == 1
// nudgeBPM(by: -1) at 30 stays 30
// toggleAccent(beat: 3) while playing: accents [1, 3], isPlaying still true, engine updated
// selectTimeSignature(.threeFour) while playing: isPlaying false, accents [1], signature 3/4
// selectTimeSignature(.fourFour) while playing in 4/4: isPlaying true, accents unchanged
// tapTempo(at: 0) then tapTempo(at: 0.5): bpm 120, haptics.selectionCount == 2
// toggleAccent(beat: 2): haptics.selectionCount increases by 1
// appDidLeaveForeground() while playing: isPlaying false
```

- [ ] **Step 2:** Run `TEST`. Expected: fails to compile.
- [ ] **Step 3:** Implement `MetronomeModel` and `Haptics`.
- [ ] **Step 4:** Run `TEST`. Expected: all pass.
- [ ] **Step 5:** Commit: "Add screen model with playback rules".

### Task 7: Screen layout and controls

**Files:**
- Create: `Metronome/Views/Theme.swift`, `MetronomeScreen.swift`, `TempoDial.swift`, `TempoControls.swift`, `TimeSignatureRow.swift`, `AccentTiles.swift`, `StartStopButton.swift` (all under `Metronome/Views/`)
- Modify: `Metronome/MetronomeApp.swift`

**Interfaces:**
- Consumes: `MetronomeModel`, `Tempo`, `DialGeometry`, `TimeSignature`.
- Produces: `enum Theme` with the nine colours of spec 5.9 as `Color` constants named `ink, surface, surfaceRaised, line, dialWhite, muted, mutedDim, amber, amberTint`; `struct MetronomeScreen: View` taking the model from the environment.

Layout values are in spec section 5; exact sizes, radii and spacing not listed there are read from the Paper boards with `get_computed_styles`, never from screenshots. Decisions the spec leaves to this plan:

- The app creates one `MetronomeModel` with `AudioClickEngine`, `SettingsStore()` and `Haptics`, and calls `appDidLeaveForeground()` when `scenePhase` leaves `.active`. `UIApplication.shared.isIdleTimerDisabled` follows `isPlaying`.
- Dial: ticks, lit arc and knob drawn in one `Canvas`. The drag gesture starts only when `DialGeometry.startsDrag` is true for its start location, then calls `setBPM` with `Tempo.bpm(forArcFraction:)` on every change.
- − / +: a tap nudges by 1. A press held 400 ms repeats 10 times per second until release.
- Tap tempo passes `ProcessInfo.processInfo.systemUptime`.
- Picker: `.sheet` with `.presentationDetents([.height(...)])` fitted to content, grabber visible, 4 × 2 grid. Tapping an option calls `selectTimeSignature` and dismisses.
- Accent tiles: one row for up to 7 beats. 9 beats wrap 5 + 4 and 12 beats wrap 6 + 6, tile height 44 pt, mark omitted, 10 pt row gap.
- Small screens: the dial diameter is `min(300, available height − the fixed heights of everything else)`, floor 240. If content still does not fit at 240 (iPhone SE), the section gaps drop to 16 pt and single-row tile height to 56 pt.
- Header: `TEMPO` when stopped, amber dot + `PLAYING` when playing. No settings button; the header keeps a 40 pt height.

- [ ] **Step 1:** Build `Theme` and the static Ready layout with the model wired in.
- [ ] **Step 2:** Add the dial drag, − / + repeat, tap tempo, picker sheet, tile toggling and Start / Stop.
- [ ] **Step 3:** Run `TEST`. Expected: all earlier tests still pass.
- [ ] **Step 4:** Run in the iPhone 17 Pro simulator. Take a screenshot stopped and one playing; compare each against the Paper boards "v1.0 · Metronome — Ready" and "— Playing" side by side and fix differences in spacing, size and colour. Open the picker and compare against the picker board.
- [ ] **Step 5:** In the simulator verify by hand: ring drag, − / + hold, tap tempo and accent toggling all work while playing; choosing a new signature stops playback and resets accents; reselecting the current one and swiping the sheet away do neither; Start then immediate Stop leaves silence; clicks are audible and accented beats sound different.
- [ ] **Step 6:** Select 9/8 and 12/8 and screenshot the two-row tiles. Run on iPhone SE (3rd generation) and iPhone 17 Pro Max and screenshot; nothing may clip or overlap.
- [ ] **Step 7:** Commit: "Add metronome screen and controls".

### Task 8: Beat effects

**Files:**
- Create: `Metronome/Views/BeatEffects.swift`
- Modify: `Metronome/Views/TempoDial.swift`, `Metronome/Views/AccentTiles.swift`

**Interfaces:**
- Consumes: `MetronomeModel.lastBeat`, `currentBeat`, `settings.bpm`.
- Produces: `struct RippleLayer: View` and `struct BeatGlow: View`, both driven by `lastBeat`.

Values from spec section 8:
- Ripple: on each new `lastBeat.id` add a ring at the dial edge; scale 1.0 → 1.3 and opacity → 0 over 600 ms ease-out; line 1 pt, or 2 pt when accented; amber. Rings are removed when finished, so several can overlap.
- Glow: amber radial gradient behind the number, opacity 0.30 → 0 over `30 / bpm` seconds (half the beat interval).
- Number pulse: scale 1.0 → 1.04 → 1.0 within the same half interval.
- Tiles: the tile of `currentBeat` takes its sounding state with no animation; the tile it replaces returns to idle over 150 ms.
- With `accessibilityReduceMotion` on, ripples and the number pulse are not shown; the glow and tiles are unchanged.

- [ ] **Step 1:** Implement the effects and wire them into the dial and tiles.
- [ ] **Step 2:** Run `TEST`. Expected: all pass.
- [ ] **Step 3:** In the simulator, screenshot during playback at 60, 120 and 250 BPM. Check against the Playing board: rings leave the dial, the glow sits behind the number, the sounding tile is amber when accented and dial white when not. At 250 BPM several rings overlap and the frame rate stays smooth.
- [ ] **Step 4:** Turn on Reduce Motion in the simulator and confirm no ripples and no pulse.
- [ ] **Step 5:** Commit: "Add beat ripple, glow and tile effects".

### Task 9: Accessibility and final check

**Files:**
- Modify: `Metronome/Views/TempoDial.swift`, `AccentTiles.swift`, `TempoControls.swift`, `TimeSignatureRow.swift`, `StartStopButton.swift`, `docs/specification.md`

- [ ] **Step 1:** Dial: one accessibility element, label "Tempo", value "120 beats per minute, Allegro", `accessibilityAdjustableAction` stepping by 1 BPM.
- [ ] **Step 2:** Tiles: label "Beat 3", value "accented" or "not accented", button trait. Beat changes during playback post no announcements.
- [ ] **Step 3:** Row labels and picker text use Dynamic Type text styles capped at `.accessibility1`; the BPM number has a fixed size. Every control's hit area is at least 44 × 44 pt.
- [ ] **Step 4:** Run `TEST`. Expected: all pass.
- [ ] **Step 5:** Walk the acceptance checklist in spec section 10 in the simulator and tick each line that passes in `docs/specification.md`. Leave unticked, with a note: final click sounds, haptics, and the 10 minute drift check against a reference; the last two need a real iPhone.
- [ ] **Step 6:** Commit: "Add accessibility support".

## Not in this plan

Needed before the first TestFlight upload, and tracked in spec section 11 or raised here:
- Final click sounds.
- App name and bundle identifier.
- App icon (not designed yet).
- Signing team, App Store Connect record and the upload itself.
- Checks that need a real iPhone: haptics, timing against a reference metronome, the silent switch.
