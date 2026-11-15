# Backing Tracks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a song carry a backing track, an audio file that plays locked to the click, with a count-in, a progress bar with 15-second skips, a Sync sheet for tempo, first beat, count-in and mix, and a row in the song sheet that attaches the file.

**Architecture:** The track's settings are one more part of the song record, so they sync like the rest; the audio file is copied into the app's own storage and never leaves the device. All timing is pure maths in small value types (`TrackGrid`, `TrackBeatClock`, `TrackMix`) that are unit tested to the sample. `AudioClickEngine` gains a second player node for the file on the same audio clock as the click, plus a limiter that is in the path only while a track plays. `MetronomeModel` owns the position and every rule about when playback stops, and is tested against the fake engine. Views are thin.

**Tech Stack:** Swift 6 language mode, SwiftUI, Observation, AVFoundation (`AVAudioEngine`, `AVAudioPlayerNode`, `AVAudioFile`), Swift Testing. No third-party dependencies. The Xcode project uses file-system-synchronized groups, so new files need no project edits.

**Spec:** `docs/specification.md`: sections 4, 5, 5.1 (Backing-track files), 6.12, 6.13, 7.10, 7.11, 8.2 (the mark), 10 and 10.3, the backing-track lines in 7.1 to 7.9, 11, 12, 13, the "Backing tracks" group in 14, and section 15. Design: Paper file "Snappy Metronome", page "Backing tracks (draft)", boards "Track · C — Ready", "Track · C — Sync sheet", "Track · Song sheet — Edit song, with track", "Track · Song sheet — Edit song, no track" and "Track · Library — Songs, track mark".

## Global Constraints

- Songs without a backing track, and the screen with nothing loaded, look and behave exactly as before. Every existing test keeps passing unchanged, apart from fakes gaining members.
- A **playable** track is one whose file is on this device. Every rule that stops playback keys off playable; the 6.12 layout keys off the song having a track at all.
- Tempo stays a whole number, `30...300`. There is no tempo map.
- First beat: steps of `0.01` s, from `0.00` to the file's length. Count-in: Off, 1 bar, 2 bars; a new track gets 2 bars. Mix: centre is full level for both; each half turns the other side down evenly in decibels, by up to `24` dB at the end; a new track starts at the centre.
- Rewind and Fast-forward move `15` seconds. Holding a step button repeats after `400` ms, `10` steps per second (the existing `StepButton`).
- Automatic first beat: the first moment the file's level rises above `-40` dB relative to full scale, rounded to `0.01` s.
- The mix knob rests on the centre when within `6` pt of it.
- The audio file is never synced. The backing-track part is one part: file identifier, name, first beat, count-in and mix together.
- First beat, count-in and mix are saved into the song the moment they are set and never make the song edited.
- The limiter is in the signal path only while a playable track is playing.
- Copy is exact: `Tap`, `Again`, `Sync`, `Track missing`, `Count-in`, `Done`, `TEMPO`, `Tap tempo`, `Tap again`, `FIRST BEAT`, `Tap on beat 1`, `COUNT-IN`, `Off`, `1 bar`, `2 bars`, `MIX`, `Click`, `Track`, `Add backing track`, `This file can't be played`, `OK`. No explanatory footnotes under controls.
- iOS 18.0 minimum. System font. Colours from spec 6.9 through `Theme`.
- Work in the worktree `.claude/worktrees/backing-tracks` on the branch `backing-tracks`. Commit with the `commit-commands:commit` skill; subjects are imperative, capitalized, no prefix, no attribution lines, no backticks.
- Run tests with `scripts/test.sh`. One suite: `scripts/test.sh -only-testing:MetronomeTests/<SuiteName>`. A passing run prints `** TEST SUCCEEDED **`.
- Shell commands: single quotes, no `$(...)`, no backslash-escaped spaces, never `cd` before git, never `git -C`. Never read `.env.*` or `.appsettings.*` files.

## Review Focus

1. **A callback from a run that has already ended.** Stop, a seek or a new Start followed by the old run's "file ended" or beat callback must not reset the position to 0:00 or light a tile. Pinned in Task 5 (run token) and Task 6 (`lateTrackEndAfterStopKeepsThePosition`).
2. **A file the maths did not expect:** silent from start to end, shorter than 15 seconds, or with the first beat at its very end. First beat is 0.00 for silence, Rewind and Fast-forward stay inside the file, and Start does not crash or hang. Pinned in Task 3 (`silentFileHasFirstSoundAtZero`) and Task 6 (`skipsStayInsideAShortFile`).
3. **A file that is gone or unreadable at Start although the song says it has one** (deleted behind the app's back, a restore without it). The song plays as the click alone for that run and the screen says `Track missing` when the file is absent. Pinned in Task 6 (`unreadableFileAtStartPlaysTheClickAlone`).
4. **Tempo or first beat changed many times a second while playing** (holding − / +, dragging the dial). Clicks never bunch up and never fall silent for more than one beat. Pinned in Task 4 (`rapidTempoChangesNeverBunchOrStall`).
5. **A file at a different sample rate than the output** (44.1 kHz file, 48 kHz phone). The click stays on the track's beats to the sample at the end of a long file. Pinned in Task 4 (`beatTimesDoNotDriftOverTenMinutes`) and stated for Task 5's manual check.

## File Structure

```
Metronome/
  Model/BackingTrack.swift       new; BackingTrack, CountIn
  Model/SyncRecords.swift        SongRecord gains the track part
  Model/Library.swift            Song.track; setTrack; referencedFileIDs
  Model/TrackGrid.swift          new; beats against file time, count-in, tap on beat 1
  Model/TrackMix.swift           new; gains, centre catch, spoken value
  Model/TrackTime.swift          new; m:ss and spoken times
  Model/TrackBeatClock.swift     new; which grid beats to hand to the player, in sample time
  Model/TrackFileStore.swift     new; the app's copies of the files
  Engine/TrackAudio.swift        new; a file's length and first sound
  Engine/ClickEngine.swift       protocol gains track playback
  Engine/AudioClickEngine.swift  second player, limiter, seek, mix, end of file
  MetronomeModel.swift           position, start/stop/skip/seek, stop rules, Sync sheet actions
  MetronomeApp.swift             wires TrackFileStore
  Views/MetronomeScreen.swift    ScreenLayout(hasTrack:), the 6.12 arrangement
  Views/TrackControls.swift      new; TrackTempoRow, TrackStrip, TrackProgressBar
  Views/SyncSheet.swift          new; the sheet and MixSlider
  Views/SongSheet.swift          Backing track row, Files picker, alert
  Views/SongSheetChanges.swift   a track change makes Save ready
  Views/LibrarySheet.swift       the mark on song rows
MetronomeTests/
  BackingTrackRecordTests.swift  new
  TrackGridTests.swift           new
  TrackMixTests.swift            new
  TrackBeatClockTests.swift      new
  TrackFilesTests.swift          new; TrackFileStore and TrackAudio
  TrackModelTests.swift          new; playing
  TrackSongModelTests.swift      new; changing songs, Sync sheet actions
  MetronomeModelTests.swift      FakeClickEngine gains the new members
  ScreenLayoutTests.swift        the track layout
  SongSheetChangesTests.swift    track changes
docs/specification.md            checklist ticks and section 15 at the end
```

---

### Task 1: The backing track in the song record

**Files:**
- Create: `Metronome/Model/BackingTrack.swift`
- Modify: `Metronome/Model/SyncRecords.swift` (SongRecord), `Metronome/Model/Library.swift` (Song, Library)
- Test: `MetronomeTests/BackingTrackRecordTests.swift`

**Interfaces:**
- Consumes: `SongRecord`, `Part`, `JSONValue`, `SyncClock`, `Library` as they are.
- Produces:

```swift
enum CountIn: Int, Codable, CaseIterable, Sendable { case off = 0, oneBar = 1, twoBars = 2 }  // rawValue = bars

struct BackingTrack: Codable, Equatable, Sendable {
    var fileID: UUID
    var fileName: String
    /// Hundredths of a second, so 0.01 s steps compare exactly.
    var firstBeat: Int
    var countIn: CountIn
    /// -1 (Click end) ... 0 (centre) ... +1 (Track end).
    var mix: Double
    init(fileID: UUID, fileName: String, firstBeat: Int, countIn: CountIn = .twoBars, mix: Double = 0)
    var firstBeatSeconds: TimeInterval { get }
}

struct Song { let id: UUID; var name: String; var settings: MetronomeSettings; var track: BackingTrack? }  // track defaults to nil

extension SongRecord {
    static let trackKey = "track"
    /// Stamps the part only when the value differs. nil writes JSON null.
    mutating func setTrack(_ track: BackingTrack?, now: Date)
}

extension Library {
    mutating func setTrack(_ id: UUID, to track: BackingTrack?, now: Date)
    mutating func addSong(name: String, settings: MetronomeSettings, track: BackingTrack? = nil, now: Date) -> Song?
    /// The file identifiers of every song that is not deleted.
    var referencedFileIDs: Set<UUID> { get }
}
```

`SongRecord.song` reads the track part when it is present and decodes; a missing, null or unreadable track part gives `track == nil` and never makes the song itself nil. `SongRecord.init` and `Library.init(legacySongs:)` write no track part for a song without one.

- [ ] **Step 1: Commit the specification and this plan** with the `commit-commands:commit` skill, subject `Specify backing tracks`.

- [ ] **Step 2: Write the failing tests** in `BackingTrackRecordTests` (`@Suite struct`, Swift Testing, `let t0 = Date(timeIntervalSince1970: 1_800_000_000)`):

```swift
@Test func aSongWithoutATrackPartHasNoTrack()            // record made by init: song?.track == nil, parts[trackKey] == nil
@Test func settingATrackRoundTrips()                      // setTrack(track) then song?.track == track
@Test func removingATrackWritesNullAndReadsAsNone()       // setTrack(nil) after a track: parts[trackKey]?.value == .null, song?.track == nil
@Test func settingTheSameTrackDoesNotRestampThePart()     // time unchanged on a second identical setTrack
@Test func aNudgedFirstBeatRestampsOnlyTheTrackPart()     // name, tempo, meter times unchanged
@Test func anUnreadableTrackPartLeavesTheSongReadable()   // parts[trackKey] = Part(time:, value: .string("x")): song != nil, song?.track == nil
@Test func theNewerTrackPartWinsWhenCombining()           // two copies, later first beat wins; a rename on the other copy also survives
@Test func aTrackRemovedLaterWinsOverAnOlderNudge()
@Test func referencedFileIDsLeaveOutDeletedSongsAndSongsWithoutTracks()
@Test func aLibraryWithTracksEncodesAndDecodesUnchanged() // JSONEncoder / JSONDecoder round trip of Library
@Test func mixAndFirstBeatAreKeptInRange()                // BackingTrack.init clamps mix to -1...1 and firstBeat to >= 0
```

- [ ] **Step 3: Run** `scripts/test.sh -only-testing:MetronomeTests/BackingTrackRecordTests`. Expected: build fails, `BackingTrack` not found.

- [ ] **Step 4: Implement** the interfaces above. The track part's value is `try JSONValue(encoding: track)`.

- [ ] **Step 5: Run** `scripts/test.sh`. Expected: `** TEST SUCCEEDED **`, all suites.

- [ ] **Step 6: Commit**, subject `Add the backing track to the song record`.

---

### Task 2: Grid, mix and time maths

**Files:**
- Create: `Metronome/Model/TrackGrid.swift`, `Metronome/Model/TrackMix.swift`, `Metronome/Model/TrackTime.swift`
- Test: `MetronomeTests/TrackGridTests.swift`, `MetronomeTests/TrackMixTests.swift`

**Interfaces:**
- Consumes: `Tempo.clamp`, `CountIn`.
- Produces:

```swift
/// The click's beats against file time. Beat index 0 is the first beat; negative indices are the count-in.
struct TrackGrid: Equatable, Sendable {
    let firstBeat: TimeInterval
    let bpm: Int
    let beatsPerBar: Int
    var beatInterval: TimeInterval { get }                 // 60 / clamped bpm
    func time(ofBeat index: Int) -> TimeInterval           // firstBeat + index * beatInterval
    func firstIndex(atOrAfter time: TimeInterval) -> Int   // ceil, with 1e-9 tolerance
    func barBeat(ofBeat index: Int) -> Int                 // 1...beatsPerBar, floor-mod so negatives work
    /// Where playback starts in file time for Start at 0:00: min(0, firstBeat - count-in length).
    func startTime(countIn: CountIn) -> TimeInterval
    /// The lowest beat index that clicks from 0:00: -(bars * beatsPerBar).
    func firstClickIndex(countIn: CountIn) -> Int
    /// Tap on beat 1: the tapped place moved back by whole bars to the earliest place not before 0, in hundredths.
    static func firstBeat(forDownbeatAt tapped: TimeInterval, bpm: Int, beatsPerBar: Int) -> Int
}

enum TrackMix {
    static let range: Double = 24                             // dB at either end
    static func clickGain(at position: Double) -> Float       // 1 for position <= 0; 10^(-24 * position / 20) above
    static func trackGain(at position: Double) -> Float       // 1 for position >= 0; 10^(24 * position / 20) below
    /// The slider position for a knob at x on a line of the given width; 0 when within 6 pt of the centre.
    static func position(forKnobAt x: CGFloat, width: CGFloat) -> Double
    static func spoken(_ position: Double) -> String          // "Mix, centre" / "Mix, track turned down 12 decibels" / "Mix, click turned down 6 decibels"
    static let spokenStep: Double = 0.125                     // 3 dB
}

enum TrackTime {
    static func label(_ seconds: TimeInterval) -> String      // "0:00", "3:42", "61:05"; negatives read as 0:00
    static func spoken(_ seconds: TimeInterval) -> String     // "1 minute 24 seconds", "3 minutes", "0 seconds"
}
```

- [ ] **Step 1: Write the failing tests.** `TrackGridTests`:

```swift
@Test func beatsFollowTheFirstBeatAtTheTempo()        // firstBeat 0.48, 120 BPM: time(ofBeat: 0) == 0.48, 1 -> 0.98, 8 -> 4.48
@Test func barBeatWrapsForwardsAndBackwards()         // 7 beats per bar: index 0 -> 1, 6 -> 7, 7 -> 1, -1 -> 7, -7 -> 1, -14 -> 1
@Test func firstIndexAtOrAfterATime()                 // firstBeat 0.48, 120 BPM: 0 -> 0, 0.48 -> 0, 0.49 -> 1, 60.48 -> 120
@Test func aShortIntroStartsTheClickFirst()           // firstBeat 0.48, 120 BPM 4/4, twoBars: startTime == 0.48 - 4.0, firstClickIndex == -8
@Test func aLongIntroStartsTheFileFirst()             // firstBeat 10, 120 BPM 4/4, twoBars: startTime == 0, firstClickIndex == -8, time(ofBeat: -8) == 6
@Test func countInOffClicksFromTheFirstBeat()         // startTime == 0, firstClickIndex == 0
@Test func tapOnBeatOneGoesBackWholeBars()            // 9.30 at 120 BPM 4/4 -> 130; 1.30 -> 130; 0.004 -> 0
@Test func tapOnBeatOneWithABarLongerThanTheTap()     // 1.0 at 30 BPM 12/8 (bar 24 s) -> 100
@Test func tempoIsClampedInTheGrid()                  // bpm 0 behaves as 30
```

`TrackMixTests`:

```swift
@Test func centreIsFullLevelForBoth()                 // gains 1, 1
@Test func towardsClickTurnsOnlyTheTrackDown()        // -1: trackGain ~ 0.0631 (-24 dB), clickGain 1; -0.5: -12 dB
@Test func towardsTrackTurnsOnlyTheClickDown()        // +1: clickGain ~ 0.0631, trackGain 1
@Test func neitherEndIsSilent()                       // gains > 0 at -1 and +1
@Test func theKnobCatchesWithinSixPointsOfTheCentre() // width 234: x 117 -> 0, 112 -> 0, 122 -> 0, 110 -> < 0, 0 -> -1, 234 -> 1, -20 -> -1
@Test func spokenValuesRoundToWholeDecibels()         // 0 -> "Mix, centre"; -0.5 -> "Mix, track turned down 12 decibels"; 0.25 -> "Mix, click turned down 6 decibels"
@Test func timesReadAsMinutesAndSeconds()             // 0 -> "0:00", 84 -> "1:24", 222.9 -> "3:42", 3665 -> "61:05", -2 -> "0:00"
@Test func spokenTimes()                              // 84 -> "1 minute 24 seconds", 180 -> "3 minutes", 1 -> "1 second"
```

- [ ] **Step 2: Run** both suites. Expected: build fails, types not found.
- [ ] **Step 3: Implement** the three files. `TrackTime.label` floors to whole seconds.
- [ ] **Step 4: Run** both suites. Expected: `** TEST SUCCEEDED **`.
- [ ] **Step 5: Commit**, subject `Add the grid, mix and time maths for backing tracks`.

---

### Task 3: The files and what is read from them

**Files:**
- Create: `Metronome/Model/TrackFileStore.swift`, `Metronome/Engine/TrackAudio.swift`
- Test: `MetronomeTests/TrackFilesTests.swift`

**Interfaces:**
- Produces:

```swift
/// The app's own copies of backing-track files, one per identifier, named <uuid>.<original extension>.
struct TrackFileStore: Sendable {
    /// Defaults to Application Support/BackingTracks, which the device backup includes. Created on first use.
    init(directory: URL = TrackFileStore.defaultDirectory)
    static var defaultDirectory: URL { get }
    func url(for fileID: UUID) -> URL?                      // nil when no copy is here
    func hasFile(_ fileID: UUID) -> Bool
    /// Copies the file in, replacing any copy under the same identifier. Keeps the source's extension.
    func store(_ source: URL, as fileID: UUID) throws
    /// Deletes every copy whose identifier is not in the set.
    func removeAll(except keep: Set<UUID>)
}

enum TrackAudioError: Error { case unreadable }

enum TrackAudio {
    /// The file's length in seconds. Throws `unreadable` when it cannot be opened as audio or has no frames.
    static func length(of url: URL) throws -> TimeInterval
    /// Hundredths of a second where the level first rises above -40 dB of full scale on any channel;
    /// 0 when it never does or when the file starts with sound.
    static func firstSound(in url: URL) throws -> Int
}
```

`TrackAudio` reads with `AVAudioFile` in chunks of 16,384 frames and stops at the first frame over the threshold (`pow(10, -40 / 20)`), so a long file is not read whole.

- [ ] **Step 1: Write the failing tests** in `TrackFilesTests`. A helper `makeWAV(seconds:sampleRate:silenceFor:)` writes a mono 16-bit WAV with `AVAudioFile` into a fresh temporary directory: silence, then a 440 Hz sine at amplitude 0.5.

```swift
@Test func aStoredFileIsFoundUnderItsIdentifier()        // store, then hasFile and url(for:) with the source's extension
@Test func storingAgainReplacesTheCopy()
@Test func removeAllExceptKeepsOnlyTheNamedFiles()
@Test func anUnknownIdentifierHasNoFile()
@Test func lengthOfAGeneratedFile()                      // 2.0 s at 44100 -> 2.0 within 0.001
@Test func firstSoundAfterLeadingSilence()               // 0.48 s of silence -> 48
@Test func aFileThatStartsWithSoundHasFirstSoundAtZero()
@Test func silentFileHasFirstSoundAtZero()               // Review Focus 2
@Test func aQuietRumbleBelowTheThresholdIsNotTheFirstSound() // amplitude 0.005 (-46 dB) for 1 s, then 0.5 -> 100
@Test func aTextFileIsUnreadable()                       // length and firstSound throw TrackAudioError.unreadable
@Test func firstSoundIsTheSameAt48kAnd44k()
```

- [ ] **Step 2: Run** `scripts/test.sh -only-testing:MetronomeTests/TrackFilesTests`. Expected: build fails.
- [ ] **Step 3: Implement** both files.
- [ ] **Step 4: Run** the suite. Expected: `** TEST SUCCEEDED **`.
- [ ] **Step 5: Commit**, subject `Store backing-track files and read their length and first sound`.

---

### Task 4: Which beats to hand to the player

**Files:**
- Create: `Metronome/Model/TrackBeatClock.swift`
- Test: `MetronomeTests/TrackBeatClockTests.swift`

**Interfaces:**
- Consumes: `TrackGrid`, `ScheduledBeat`.
- Produces:

```swift
/// Places grid beats on the player's timeline. File time `startTime` sounds at `startSampleTime`.
struct TrackBeatClock: Sendable {
    init(sampleRate: Double, startSampleTime: Int64, startTime: TimeInterval, firstClickIndex: Int)
    /// The sample time at which a file time sounds.
    func sampleTime(forFileTime time: TimeInterval) -> Int64
    /// The file time sounding at a sample time.
    func fileTime(atSampleTime sampleTime: Int64) -> TimeInterval
    /// In order, every grid beat not yet returned that falls before `horizon` and not before `earliest`.
    /// Only beats with index >= firstClickIndex and file time < endTime are returned.
    /// A beat less than half a beat interval after the last returned beat is skipped, so beats never bunch up.
    mutating func beats(before horizon: Int64, notBefore earliest: Int64, endTime: TimeInterval,
                        grid: TrackGrid, accents: Set<Int>) -> [ScheduledBeat]
}
```

Each beat's sample time is worked out from its own index (`startSampleTime + ((grid.time(ofBeat: n) - startTime) * sampleRate).rounded()`), never by adding intervals, so rounding cannot accumulate. `ScheduledBeat.beat` is `grid.barBeat(ofBeat: n)`.

- [ ] **Step 1: Write the failing tests** in `TrackBeatClockTests` (sample rate 48,000, `startSampleTime` 2,400):

```swift
@Test func theCountInEndsOnTheFirstBeat()             // firstBeat 0.48, 120 BPM 4/4, twoBars: 8 beats before sampleTime(forFileTime: 0.48), bar beats 1 2 3 4 1 2 3 4, then beat 1 exactly at it
@Test func noClickBeforeTheFirstBeatWithoutACountIn() // startTime 0, firstClickIndex 0, firstBeat 2.0: first returned beat is at file time 2.0
@Test func startingMidFileJoinsOnTheNextGridBeat()    // startTime 30.1, firstBeat 0.48, 120 BPM 7/8: first beat at file time 30.48, bar beat == grid.barBeat(ofBeat: 60)
@Test func accentsFollowTheBarBeat()
@Test func beatsAlreadyReturnedAreNotReturnedAgain()
@Test func aSlowerTempoMovesLaterBeatsOntoTheNewGrid() // 120 -> 60 after 4 beats: next beat is a multiple of 1 s after firstBeat
@Test func aNudgedFirstBeatMovesLaterBeats()          // firstBeat 0.48 -> 0.49: later beats are 480 samples later
@Test func aNewGridBeatRightAfterTheLastOneIsSkipped() // the next new-grid beat 0.1 interval after the last returned: skipped, the one after is returned
@Test func rapidTempoChangesNeverBunchOrStall()       // Review Focus 4: 200 calls stepping bpm 120...180...120 every 25 ms of horizon: gaps between consecutive beats all >= 0.5 * and <= 2.0 * the larger interval
@Test func beatTimesDoNotDriftOverTenMinutes()        // Review Focus 5: 44,100 Hz and 48,000 Hz, 137 BPM: beat 1370 is within 1 sample of the exact time
@Test func noBeatAtOrAfterTheEndOfTheFile()
@Test func aTimeSignatureChangeTakesTheBarFromTheFirstBeat() // 4/4 -> 3/4 mid-file: bar beat of the next beat == new grid.barBeat(ofBeat: n)
```

- [ ] **Step 2: Run** `scripts/test.sh -only-testing:MetronomeTests/TrackBeatClockTests`. Expected: build fails.
- [ ] **Step 3: Implement** `TrackBeatClock`. It remembers only the sample time of the last returned beat.
- [ ] **Step 4: Run** the suite. Expected: `** TEST SUCCEEDED **`.
- [ ] **Step 5: Commit**, subject `Place backing-track beats on the audio clock`.

---

### Task 5: Playing the file in the engine

**Files:**
- Modify: `Metronome/Engine/ClickEngine.swift`, `Metronome/Engine/AudioClickEngine.swift`, `MetronomeTests/MetronomeModelTests.swift` (FakeClickEngine only)

**Interfaces:**
- Consumes: `TrackBeatClock`, `TrackGrid`.
- Produces:

```swift
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

protocol ClickEngine {            // additions
    /// Called once when the file has played to its end. Not called after stop() or a seek.
    var onTrackEnded: (() -> Void)? { get set }
    /// Starts the file and the click together. Throws at once when the file cannot be opened.
    func start(with settings: MetronomeSettings, track: TrackPlayback) throws
    /// While playing with a track: carries on from this file time, with no click before the first beat.
    func seekTrack(to time: TimeInterval)
    /// While playing with a track: moves the grid from the next beat not yet scheduled.
    func setFirstBeat(_ firstBeat: TimeInterval)
    /// Applies at once, also to audio already scheduled.
    func setMix(clickGain: Float, trackGain: Float)
    /// The file time being heard now, allowing for output delay; negative during a count-in. nil unless playing with a track.
    var trackTime: TimeInterval? { get }
}
```

`FakeClickEngine` gains: `var onTrackEnded`, `var startedTracks: [TrackPlayback] = []`, `var trackStartError: Error?`, `var seeks: [TimeInterval] = []`, `var firstBeats: [TimeInterval] = []`, `var mixes: [(click: Float, track: Float)] = []`, `var trackTime: TimeInterval?`. Its `start(with:track:)` throws `trackStartError` when set, else appends and counts in `startCount`.

Engine design, in `AudioClickEngine`:

- A second `AVAudioPlayerNode`, `trackPlayer`, attached in `init` and connected to the main mixer in the file's processing format when a track starts.
- A limiter node (`AVAudioUnitEffect` with `kAudioUnitSubType_PeakLimiter`) attached in `init`. A track run connects main mixer → limiter → output; a plain run and a preview connect main mixer → output as today. Its settings are the builder's choice; the click's attack rule in spec 11.1 must still hold.
- `start(with:track:)` opens the `AVAudioFile` first and throws `AudioClickEngineError.trackUnreadable` on failure, then follows the existing path: run token, session activation off the main thread, `beginPlaying`.
- Both players start with `play(at:)` on the same host time, so their timelines share an origin. The file is scheduled with `scheduleSegment` from the frame for `max(0, startTime)`, at the player time for file time `max(0, startTime)`, with `completionCallbackType: .dataPlayedBack`.
- While a track runs, `scheduleDueBeats` asks a `TrackBeatClock` instead of `BeatClock`, with a `TrackGrid` built from the current settings and first beat, and `endTime` equal to the file's length. `update(_:startNewBar:)` ignores `startNewBar` during a track run.
- `seekTrack(to:)` stops both players, restarts them on a new shared host time and makes a new `TrackBeatClock` with `firstClickIndex: 0`. It bumps the run token's track generation so the old segment's completion is ignored.
- The completion callback hops to the main actor, checks the run token and generation, tears down and calls `onTrackEnded`.
- `trackTime` is `clock.fileTime(atSampleTime: lastRender) - outputLatency`, using the existing `lastRender()` and host-clock correction.
- `setMuted` and `setMix` together set `player.volume = muted ? 0 : clickGain`; `trackPlayer.volume = trackGain`. Outside a track run the click gain is 1.

- [ ] **Step 1: Add the protocol members and the fake's members.** Run `scripts/test.sh`. Expected: build fails in `AudioClickEngine` (does not conform).
- [ ] **Step 2: Implement** the engine as designed above.
- [ ] **Step 3: Run** `scripts/test.sh`. Expected: `** TEST SUCCEEDED **`; no existing test changes.
- [ ] **Step 4: Build for the simulator** with `scripts/build.sh`. Expected: `** BUILD SUCCEEDED **` with no new warnings.
- [ ] **Step 5: Commit**, subject `Play a backing track on the click's audio clock`.

Audio itself is checked by ear in Task 11.

---

### Task 6: Playing a song with a track in the model

**Files:**
- Modify: `Metronome/MetronomeModel.swift`, `Metronome/MetronomeApp.swift`
- Test: `MetronomeTests/TrackModelTests.swift`

**Interfaces:**
- Consumes: Task 1 to 5.
- Produces, on `MetronomeModel`:

```swift
init(engine:store:haptics:libraryStore:sync:now:saveOfferDelay:,
     trackFiles: TrackFileStore = TrackFileStore(),
     lengthOfTrack: @escaping (URL) -> TimeInterval? = { try? TrackAudio.length(of: $0) })

var loadedTrack: BackingTrack? { get }           // the loaded song's track, playable or not
var isTrackPlayable: Bool { get }                // loadedTrack != nil and its file is here
var isTrackMissing: Bool { get }                 // loadedTrack != nil and its file is not here
private(set) var trackLength: TimeInterval?      // read when a song with a playable track becomes the loaded one
private(set) var trackPosition: TimeInterval     // the position while stopped; 0 at launch and on load
var isPlayingTrack: Bool { get }                 // playing, and this run was started with the file
var trackTime: TimeInterval { get }              // engine.trackTime while playing a track, clamped to 0...length; else trackPosition
var isCountingIn: Bool { get }                   // playing a track and engine.trackTime < 0
var canSkipForward: Bool { get }                 // playable and trackTime < length - 15
func skipTrack(by seconds: TimeInterval)         // -15 or +15
func seekTrack(to time: TimeInterval)            // from the progress bar, on lift
func toggleTrackPlaybackWithoutCountIn()         // Play / Stop in the Sync sheet
```

Rules (spec 7.10):

- `togglePlayback()` on a playable track starts with `TrackPlayback(startTime:firstClickIndex:)` from `TrackGrid.startTime(countIn:)` and `firstClickIndex(countIn:)` when `trackPosition == 0`; otherwise `startTime: trackPosition, firstClickIndex: 0`. `toggleTrackPlaybackWithoutCountIn()` always uses `startTime: trackPosition, firstClickIndex: 0`. Gains come from `TrackMix`.
- If `engine.start(with:track:)` throws, the model calls the plain `engine.start(with:)` for that run; `isPlayingTrack` is false.
- `stop()` while playing a track stores `max(0, engine.trackTime ?? trackPosition)` into `trackPosition` before stopping the engine. `engine.onStopped` (an interruption) does the same.
- `engine.onTrackEnded` returns the model to stopped with `trackPosition = 0`. It is ignored unless `isPlayingTrack`.
- `skipTrack` and `seekTrack` clamp to `0...trackLength`. A skip back from within the first 15 seconds goes to 0. A skip forward does nothing unless `canSkipForward`. Stopped, they set `trackPosition`; playing a track, they call `engine.seekTrack(to:)`. They play no haptic.
- Tempo, time signature and accent changes while playing a track call `engine.update(settings, startNewBar: false)`.
- Mute is unchanged; `isMuted` goes to the engine as today.

`MetronomeApp` passes nothing new; the defaults wire the real store.

- [ ] **Step 1: Write the failing tests** in `TrackModelTests` (`@MainActor @Suite`). A helper builds a model with a `TrackFileStore` on a temporary directory, an injected `lengthOfTrack: { _ in 222 }`, and a loaded song at 120 BPM 4/4 whose track has `firstBeat: 48`, with a small real file stored under its identifier; `missing: true` skips storing the file.

```swift
@Test func startAtZeroPlaysTheCountIn()                  // startedTracks.last: startTime == 0.48 - 4.0, firstClickIndex == -8, firstBeat == 0.48, gains 1 and 1
@Test func countInOffStartsTheFileAtOnce()               // startTime 0, firstClickIndex 0
@Test func startAwayFromZeroSkipsTheCountIn()            // seekTrack(to: 30) stopped, then start: startTime 30, firstClickIndex 0
@Test func stopKeepsThePosition()                        // engine.trackTime = 84.2, stop: trackPosition == 84.2, stopCount 1
@Test func stoppingDuringTheCountInStaysAtZero()         // engine.trackTime = -1.5, stop: trackPosition == 0
@Test func theEndOfTheTrackStopsAndGoesBackToZero()
@Test func lateTrackEndAfterStopKeepsThePosition()       // Review Focus 1: stop at 84.2, then onTrackEnded(): trackPosition still 84.2, still stopped
@Test func anInterruptionKeepsThePosition()              // engine.trackTime = 50, engine.onStopped?(): stopped, trackPosition 50
@Test func rewindNearTheStartGoesToZero()                // position 9 -> 0
@Test func fastForwardIsRefusedInTheLastFifteenSeconds() // length 222, position 210: canSkipForward false, skip does nothing
@Test func skipsStayInsideAShortFile()                   // Review Focus 2: trackLength 8: skip +15 does nothing, skip -15 goes to 0, seek 100 -> 8
@Test func skippingWhilePlayingSeeksTheEngine()          // engine.trackTime = 40, skip +15: seeks == [55], still playing, startCount unchanged
@Test func skippingBackToZeroWhilePlayingPlaysNoCountIn() // engine.trackTime = 5, skip -15: seeks == [0]
@Test func aTempoChangeWhilePlayingKeepsTheBarOnTheTrack() // lastUpdateStartedNewBar == false after selectTimeSignature
@Test func muteLeavesTheTrackAlone()                     // engine.muted true, no setMix call, isPlayingTrack still true
@Test func unreadableFileAtStartPlaysTheClickAlone()     // Review Focus 3: trackStartError set: playing, isPlayingTrack false, startCount 1
@Test func aMissingFilePlaysLikeASongWithoutATrack()     // missing: true: isTrackMissing, togglePlayback uses the plain start
@Test func theSheetsPlayNeverCountsIn()                  // position 0, toggleTrackPlaybackWithoutCountIn: startTime 0, firstClickIndex 0
@Test func theMixSetsTheGainsAtStart()                   // mix -0.5: trackGain ~ 0.251, clickGain 1
@Test func thePositionIsZeroAtLaunch()                   // a new model on the same stores after a stop at 84.2
@Test func songsWithoutATrackStartAsBefore()
```

- [ ] **Step 2: Run** `scripts/test.sh -only-testing:MetronomeTests/TrackModelTests`. Expected: build fails.
- [ ] **Step 3: Implement** the model members and rules.
- [ ] **Step 4: Run** `scripts/test.sh`. Expected: `** TEST SUCCEEDED **`, all suites.
- [ ] **Step 5: Commit**, subject `Play, stop, skip and seek a backing track in the model`.

---

### Task 7: Changing songs, attaching files and the Sync sheet's actions

**Files:**
- Modify: `Metronome/MetronomeModel.swift`, `Metronome/Views/SongSheetChanges.swift`
- Test: `MetronomeTests/TrackSongModelTests.swift`, `MetronomeTests/SongSheetChangesTests.swift`

**Interfaces:**
- Consumes: Task 6.
- Produces:

```swift
/// A file chosen in the song sheet and already checked: readable, with its first sound found.
struct PickedTrack: Equatable, Sendable { let url: URL; let fileName: String; let firstBeat: Int }

enum TrackEdit: Equatable, Sendable { case keep, remove, attach(PickedTrack) }

// MetronomeModel
func editSong(_ id: UUID, name: String, settings: MetronomeSettings, track: TrackEdit = .keep)
@discardableResult func createSong(name: String, settings: MetronomeSettings, addingTo setlistID: UUID?, track: PickedTrack? = nil) -> Song?
@discardableResult func saveAsNewSong(name: String, settings: MetronomeSettings, track: PickedTrack? = nil) -> Song?
func nudgeFirstBeat(by steps: Int)     // each step 0.01 s; clamped to 0...length; a selection tick when it changed
func tapBeatOne()                      // only while isPlayingTrack and the file has started (engine.trackTime >= 0); a selection tick
func setCountIn(_ countIn: CountIn)    // a selection tick when it changed
func setMix(_ position: Double)        // clamped to -1...1; a selection tick when it arrives at 0 from elsewhere

// SongSheetChanges
func canSave(name: String, settings: MetronomeSettings, track: TrackEdit = .keep) -> Bool   // also true when track != .keep (and a name is present)
```

Rules:

- `.attach` on a song whose track's file is missing stores the file under the existing identifier and leaves the part as it is. Otherwise it stores the file under a new identifier and writes a new `BackingTrack` with the picked first beat, keeping the old track's count-in and mix when there was one.
- After every change to the library (`persistLibrary()` and `exchangeWithCloud()`), `trackFiles.removeAll(except: library.referencedFileIDs)` runs.
- Stop rules, each only for a playable track (spec 7.10): `loadSong` stops when the song being left or the one being loaded is playable, and always sets `trackPosition = 0` and refreshes `trackLength`; `unloadSong` and `deleteSong` of the loaded song stop when it was playing with its track; `saveAsNewSong` and the naming exception in `createSong` stop when either song is playable; `editSong` on the loaded song stops and goes to 0 when a file was attached, replaced, picked for a missing one, or a playable track was removed, and never for a missing-file track being removed or for tempo, time signature or accents.
- `exchangeWithCloud`: compares the loaded song's track before and after. A changed first beat, count-in or mix goes to the engine (`setFirstBeat`, `setMix`). A track that was playable and playing and is now removed or has another file identifier stops playback and goes to 0. Anything else leaves playback alone.
- `nudgeFirstBeat`, `tapBeatOne`, `setCountIn` and `setMix` write through `library.setTrack` and `persistLibrary()`, then tell the engine (`setFirstBeat` while playing a track; `setMix` always). None of them changes `isEdited`.
- `tapBeatOne` uses `TrackGrid.firstBeat(forDownbeatAt: engine.trackTime, bpm:beatsPerBar:)`.

- [ ] **Step 1: Write the failing tests.** `TrackSongModelTests` reuses Task 6's helper and adds a second song without a track and a third with a playable one.

```swift
@Test func loadingASongWithATrackWhilePlayingStops()
@Test func leavingASongWithATrackWhilePlayingStops()
@Test func twoSongsWithoutTracksKeepPlaying()
@Test func aMissingFileCountsAsNoTrackWhenLoading()            // playing a missing-file song, Next to a song without a track: still playing
@Test func loadingAlwaysGoesToZero()
@Test func unloadStopsOnlyAPlayingTrack()
@Test func deletingTheLoadedSongStopsItsPlayingTrackAndDeletesTheFile()
@Test func saveAsNewSongHasNoTrackAndStopsAPlayingTrack()
@Test func attachingAFileInEditStoresItAndGuessesNothingItself() // PickedTrack(firstBeat: 48): song.track?.firstBeat == 48, countIn .twoBars, mix 0, file stored
@Test func replacingTheFileKeepsCountInAndMixAndDropsTheOldFile()
@Test func removingTheTrackForgetsItAndDeletesTheFile()
@Test func pickingAFileForAMissingTrackChangesNoPart()         // the track part's time is unchanged; isTrackPlayable becomes true
@Test func editingTheLoadedSongsTrackStopsAndGoesToZero()
@Test func removingAMissingFileTrackKeepsPlaying()
@Test func editingOnlyTheTempoOfALoadedTrackSongKeepsPlaying()
@Test func aNewSongCanBeCreatedWithATrack()
@Test func nudgingTheFirstBeatSavesAtOnceWithoutEdited()        // +1: track.firstBeat 49, isEdited false, isSaveOffered false, firstBeats.last == 0.49 while playing
@Test func theFirstBeatStaysInsideTheFile()                     // -100 steps -> 0; length 2.0: +1000 steps -> 200
@Test func tapOnBeatOneSetsTheFirstBeatFromTheHeardPosition()   // engine.trackTime 9.30, 120 BPM 4/4 -> 130
@Test func tapOnBeatOneDoesNothingWhileStoppedOrCountingIn()
@Test func countInAndMixSaveAtOnce()                            // setCountIn(.off), setMix(-0.5): saved, mixes.last gains, isEdited false
@Test func theMixTicksOnlyOnArrivingAtTheCentre()               // selectionCount +1 for 0.3 -> 0, +0 for 0 -> 0 and 0.3 -> 0.2
@Test func aFirstBeatArrivingFromAnotherDeviceMovesTheGrid()    // uses FakeCloudStore and a second library as in SyncModelTests
@Test func aTrackRemovedOnAnotherDeviceStopsItsPlayingTrack()
@Test func aTrackAttachedOnAnotherDeviceArrivesMissingAndKeepsPlaying()
@Test func filesNoSongRefersToAreRemoved()
```

`SongSheetChangesTests` gains:

```swift
@Test func attachingOrRemovingATrackMakesSaveReady()   // editing: .attach and .remove true with nothing else changed; .keep false
@Test func aTrackAloneDoesNotReplaceTheName()          // newSong with an empty name and .attach: false
```

- [ ] **Step 2: Run** both suites. Expected: build fails.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `scripts/test.sh`. Expected: `** TEST SUCCEEDED **`, all suites.
- [ ] **Step 5: Commit**, subject `Apply the backing-track rules when songs change`.

---

### Task 8: The screen for a song with a track

**Files:**
- Create: `Metronome/Views/TrackControls.swift`
- Modify: `Metronome/Views/MetronomeScreen.swift`, `Metronome/Views/TimeSignatureRow.swift` (only if the picker's presentation must be shared)
- Test: `MetronomeTests/ScreenLayoutTests.swift`

**Interfaces:**
- Consumes: the model members of Task 6 and 7.
- Produces:

```swift
// ScreenLayout
init(width: CGFloat, height: CGFloat, hasBottomInset: Bool, beats: Int, hasSetlist: Bool = false, hasTrack: Bool = false)
let stripTopGap: CGFloat                 // 14, or 10 when compact; 0 without a track
static let trackRowHeight: CGFloat = 56
static let trackStripHeight: CGFloat = 108   // 12 + 30 + 10 + 44 + 12

struct TrackTempoRow: View               // −, Tap / Again pill, +, the time signature chip
struct TrackStrip: View { let openSync: () -> Void }
struct TrackProgressBar: View            // Rewind, the line with its knob and times, Fast-forward; used by the strip and the Sync sheet
```

Layout with a track (spec 6.12): header as today; dial; 10 pt; the 56 pt tempo and time signature row (8 pt between its parts; the chip has 18 pt corners and shows only the value at 24 pt heavy in amber with a chevron); 12 pt; accent tiles; `stripTopGap`; the strip (surface, 20 pt corners, padding 12 top and bottom, 16 leading, 14 trailing); at least 16 pt; the footer as today. `ScreenLayout` with `hasTrack` uses `settingsTopGap` 10 and `sectionGap` 12 in both the roomy and the compact fit; compact changes only `stripTopGap` to 10 and the tile height to 56. `MetronomeScreen` picks the arrangement from `model.loadedTrack != nil`.

`TrackStrip`: row 1 is the music-note symbol (16 pt, muted), the file name (14 pt medium, dial white, one line) or `Track missing` in amber, and the `Sync` pill (30 pt tall, 1 pt line-colour outline, 13 pt semibold; touch area 44 pt). Missing: the pill and the progress bar are at 40 % opacity and take no touches, and the times are hidden.

`TrackProgressBar`: the buttons are 44 pt round on surface raised with double chevrons (SF Symbols `chevron.backward.2` and `chevron.forward.2`), 12 pt from the line. The line is 4 pt in the line colour, the played part amber, the knob 14 pt dial white with a 44 × 44 pt touch area. Times are 13 pt muted with monospaced digits: `TrackTime.label(model.trackTime)` at the left, or `Count-in` in amber while `model.isCountingIn`; the length at the right. It redraws from a `TimelineView(.periodic(from: .now, by: 0.1))` while playing. Dragging the knob moves it and the left time with the finger and calls `model.seekTrack(to:)` on lift; a tap on the line does nothing. Fast-forward is at 40 % opacity when `!model.canSkipForward`.

VoiceOver (spec 13): chip "Time signature, 7/8"; name "Backing track, <file name>" or "Track missing"; "Sync"; "Back 15 seconds"; "Forward 15 seconds"; the bar is adjustable, value "<TrackTime.spoken(position)> of <TrackTime.spoken(length)>" or "Count-in", stepping 15 seconds; the `Tap` pill reads "Tap tempo".

- [ ] **Step 1: Write the failing tests** in `ScreenLayoutTests`:

```swift
@Test func theTrackLayoutFitsTheDesignScreenWithALargeDial()   // 390 x 763 (844 less the safe areas), 7 beats, setlist, track: dial >= 280, stripTopGap 14, tileHeight 76, fits
@Test func theTrackLayoutShrinksTheDialFirst()                  // a height where the roomy fit gives 240...279: stripTopGap 14, tileHeight 76
@Test func theTrackLayoutGoesCompactBelow240()                  // stripTopGap 10, tileHeight 56
@Test func theTrackLayoutFitsAnIPhoneSE()                       // 375 x 647, 4 beats and 12 beats, with and without a setlist: fits, dial >= ScreenLayout.minimumDial
@Test func theTrackLayoutFitsDisplayZoom()                      // 320 x 548: fits
@Test func withoutATrackTheLayoutIsUnchanged()                  // hasTrack false equals the existing initialiser's result for three sizes
```

`fits` here means `fixedHeight + dialDiameter + bottomPadding <= height`, as the existing helper does.

- [ ] **Step 2: Run** `scripts/test.sh -only-testing:MetronomeTests/ScreenLayoutTests`. Expected: build fails.
- [ ] **Step 3: Implement** the layout, the three views and the wiring in `MetronomeScreen`. The Sync button sets a `@State` flag that Task 9's sheet will use; until then it does nothing.
- [ ] **Step 4: Run** `scripts/test.sh`. Expected: `** TEST SUCCEEDED **`.
- [ ] **Step 5: Run the app** in the iPhone 17 Pro simulator with a song that has a track (attach one through a temporary debug seed, removed before committing, or wait for Task 10 and do this check then). Compare with the board "Track · C — Ready".
- [ ] **Step 6: Commit**, subject `Show the track strip and compact tempo row for songs with a track`.

---

### Task 9: The Sync sheet

**Files:**
- Create: `Metronome/Views/SyncSheet.swift`
- Modify: `Metronome/Views/MetronomeScreen.swift` (presents it)

**Interfaces:**
- Consumes: `TrackProgressBar`, `StepButton`, `TrackMix`, and from the model `toggleTrackPlaybackWithoutCountIn()`, `nudgeBPM(by:)`, `tapTempo(at:)`, `nudgeFirstBeat(by:)`, `tapBeatOne()`, `setCountIn(_:)`, `setMix(_:)`, `isPlaying`, `isPlayingTrack`, `isCountingIn`, `loadedTrack`, `settings.bpm`.
- Produces: `struct SyncSheet: View`, `struct MixSlider: View { let position: Double; let onChange: (Double) -> Void }`.

Layout (spec 6.13), presented like `SongSheet` (content height detent, 28 pt corners, surface background, visible grabber), scrolling when taller than the screen. Side padding 24, groups 14 apart, label 8 above its row, pill 10 below its row:

- Title `Sync` (26 pt heavy) and `Done` in amber.
- Playback row, parts 10 apart: Play / Stop, 52 pt round (stopped: amber fill, ink play symbol; playing: surface fill, 1.5 pt amber outline, amber stop square), then `TrackProgressBar`.
- `TEMPO` (13 pt semibold capitals, wide tracking, muted); `StepButton` − and + (56 pt, surface raised) around the tempo (48 pt heavy) with `BPM` (15 pt bold, amber); a 52 pt outlined pill with the hand symbol reading `Tap tempo`, and `Tap again` with a 1.5 pt amber outline during a series (the same two-second rule as `TempoControls`).
- `FIRST BEAT`; `StepButton` − and + around the value with two decimals (48 pt heavy) and `s` in amber; a 52 pt outlined pill reading `Tap on beat 1`, at 40 % opacity and without touches unless `model.isPlayingTrack && !model.isCountingIn`.
- `COUNT-IN`; `Off`, `1 bar`, `2 bars` side by side, 8 apart, 52 pt tall, 16 pt corners, surface raised; the selected one amber with a glow and heavy ink text.
- `MIX`; a 44 pt row with `Click` and `Track` (15 pt semibold) and the slider between them, 12 from each: a 4 pt line, a 2 × 12 pt centre mark in the tick colour, a 24 pt dial-white knob with a 44 × 44 pt touch area, and the line between centre and knob in amber. Dragging calls `onChange(TrackMix.position(forKnobAt:width:))`.

The Play / Stop button plays the transport haptic through `toggleTrackPlaybackWithoutCountIn()`; when the song is already playing it stops it. Closing the sheet leaves playback as it is.

VoiceOver: Play / Stop reads "Play" or "Stop"; first beat is adjustable, "First beat, 0.48 seconds", stepping one step; each count-in option reads "Count-in, 2 bars" with the selected trait; the slider is adjustable, value `TrackMix.spoken(position)`, stepping `TrackMix.spokenStep`.

- [ ] **Step 1: Implement** `SyncSheet` and `MixSlider`, and present the sheet from the strip's Sync button.
- [ ] **Step 2: Run** `scripts/test.sh`. Expected: `** TEST SUCCEEDED **` (no new tests; the rules are in Task 2 and 7).
- [ ] **Step 3: Compare** with the board "Track · C — Sync sheet" in the simulator, stopped and playing (this needs a song with a track; do it together with Task 10's check if none exists yet).
- [ ] **Step 4: Commit**, subject `Add the Sync sheet`.

---

### Task 10: Attaching a file in the song sheet, and the library's mark

**Files:**
- Modify: `Metronome/Views/SongSheet.swift`, `Metronome/Views/LibrarySheet.swift` (SongRow and the `spokenDescription` / `detail` helpers wherever they live)

**Interfaces:**
- Consumes: `TrackEdit`, `PickedTrack`, `TrackAudio`, `SongSheetChanges.canSave(name:settings:track:)`, the three model methods of Task 7.

Song sheet (spec 10.3): a Backing track row below the accent tiles and above the Add to setlist switch, 60 pt tall, surface raised, 16 pt corners, 16 pt leading padding; the music-note symbol (18 pt, muted), 10 pt, then the text (16 pt medium, dial white, one line); with a track, an × (18 pt, muted) in a 44 pt square at the trailing end.

| State | Text | Tap on the text | × |
|---|---|---|---|
| No track | `Add backing track` | Files picker | not shown |
| Track | the file name | Files picker | removes |
| File missing | `Track missing` in amber | Files picker | removes |

- The sheet keeps `@State private var trackEdit: TrackEdit = .keep` and shows the state that saving would give.
- The picker is `.fileImporter(isPresented:allowedContentTypes: [.audio])`. On a pick: start security-scoped access, copy the file into a new folder under `FileManager.default.temporaryDirectory` keeping its name, stop access, then call `TrackAudio.length(of:)` and `TrackAudio.firstSound(in:)`. On success `trackEdit = .attach(PickedTrack(url:fileName:firstBeat:))`. On any failure the row stays as it was and an alert with the title `This file can't be played` and one `OK` button is shown.
- `save()` passes `track: trackEdit` to `editSong`, and the picked track, when there is one, to `createSong` and `saveAsNewSong`.
- VoiceOver: "Backing track, <file name>", "Add backing track" or "Track missing"; the × reads "Remove backing track".

Library (spec 8.2): a song with a track shows a 13 pt music-note symbol in muted, 5 pt after the tempo and time signature, on the same line; `· loaded` follows the mark. The row's VoiceOver label gains ", backing track" before ", loaded". The mark is the same in a setlist and on the Add song screen.

- [ ] **Step 1: Implement** the row, the picker, the alert and the mark.
- [ ] **Step 2: Run** `scripts/test.sh`. Expected: `** TEST SUCCEEDED **`.
- [ ] **Step 3: In the simulator**, drag an audio file onto the simulator so it lands in Files, attach it to a song in Edit song, and check against the three boards "Track · Song sheet — Edit song, with track", "— no track" and "Track · Library — Songs, track mark". Then load the song and check Task 8's screen and Task 9's sheet against their boards.
- [ ] **Step 4: Commit**, subject `Attach a backing track in the song sheet and mark it in the library`.

---

### Task 11: Listening check and the specification

**Files:**
- Modify: `docs/specification.md` (section 14 "Backing tracks", section 15)

- [ ] **Step 1: Run** `scripts/test.sh`. Expected: `** TEST SUCCEEDED **`.
- [ ] **Step 2: In the simulator with a click-produced track**, by ear and eye: Start at 0:00 gives the count-in and the track's first beat lands on the beat after it; Stop keeps the place; Rewind and Fast-forward; the end returns to 0:00; the first-beat − and + move the click while it plays; the mix turns each side down; click and track at the centre do not distort. Note what was and was not checked.
- [ ] **Step 3: Update section 14.** Tick a line only when a unit test or this session's simulator check covers it, and replace *(Not built.)* with a note in the existing style saying how it was verified and what still needs a real iPhone (Bluetooth delay, the speaker, a second device, backup restore, VoiceOver).
- [ ] **Step 4: Update section 15** so it lists only what is still not built or not verified (the exact small-screen figures remain there unless Task 8's tests pin them, in which case put the figures into 6.12).
- [ ] **Step 5: Commit**, subject `Record what is verified for backing tracks`.
