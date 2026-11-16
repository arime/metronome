# Beats Screen and Sync Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the backing track its own tempo, set it and the offset from tapped downbeats, and replace the track screen's dial and the Sync sheet with the tempo reading and Sync mode of spec 6.12 and 6.13.

**Architecture:** `BackingTrack` gains `bpm`; the model's `settings` stay the metronome's own, and a derived `tempoInEffect` (the track's while a track is in use) is what the engine gets. A pure `TapRun` value does the bar numbers and the least-squares fit; the model owns one run and Sync mode as plain observable state. Two new layout types, `TrackScreenLayout` and `SyncModeLayout`, hold the arithmetic of 6.12 and 6.13 and are unit tested; the views then read them. The model lands first (Tasks 1 to 3), the arithmetic next (Task 4), the views last (Tasks 5 and 6).

**Tech Stack:** Swift 6, SwiftUI, Observation, AVAudioEngine, Swift Testing, no third-party dependencies, file-system-synchronized Xcode groups (a new file in `Metronome/` or `MetronomeTests/` is picked up without touching the project). Build with `scripts/build.sh`, test with `scripts/test.sh`.

**Spec:** `docs/specification.md` — sections 4, 5, 5.1, 6.1, 6.9, 6.12, 6.13, 7.1, 7.2, 7.5, 7.6, 7.9, 7.10, 7.11, 7.12, 10.3, 12, 13, the "Backing tracks" group of 14, and 15. Commit c0611a6 shows exactly what the redesign changed.

## Global Constraints

- The spec is the authority. Where this plan and the spec disagree, follow the spec and report the difference.
- A song without a track, and every song while Backing tracks is off, looks and behaves exactly as today: plain layout, dial, the metronome's tempo, every existing plain-layout `ScreenLayoutTests` figure unchanged.
- "First beat" is "offset" in Swift identifiers, UI copy, VoiceOver and comments. The stored key names do not change: the track part keeps `"firstBeat"` for the offset (a `CodingKeys` raw value), so data already on devices and in iCloud still reads. The new tempo is stored under `"bpm"`.
- Terms: "a track is in use" = Backing tracks on and the loaded song has a track (file here or missing). "Playable" = the file is here. "Tempo in effect" = the track's tempo while a track is in use, the metronome's otherwise (section 4).
- UI copy exactly as in the spec, VoiceOver strings exactly as in section 13. No explanatory text, footnotes or hints added.
- Comments say what and why; no history words ("now", "new", "previously", "no longer", task or review references). The same for the spec.
- Tests never sleep a fixed time; a test that waits for a deferred save polls as `severalNudgesInARowSaveOnceWithTheLastValue` does (deadline loop on `bench.libraryDefaults.writes`). Models are built through `TrackTestBench` or with `TrackFileStore.temporary()`; never the default `TrackFileStore()`.
- No new compiler warnings. `scripts/build.sh` and the full `scripts/test.sh` pass at the end of every task.
- Commits: imperative subject, capitalised, no trailing period, at most 72 characters, body wrapped at 72 saying why, no Conventional Commits prefix, no backticks, no attribution lines. Write the message to a scratch file and commit with `git commit -F`.
- Shell: single quotes, no `cd` before git, no `git -C`, no `$(...)`, no backslash line continuations.
- Do not read `.env.*` or `.appsettings.*` files.
- Nothing by ear, with VoiceOver, by feel or on a real iPhone can be verified by the implementer. Checklist lines that need any of these stay unticked, with a note saying what was covered.
- Section 14: a line is ticked only when every claim in it is covered by a named unit test or was seen in the simulator; otherwise it stays unticked with a note saying which parts are covered and how.

## Review Focus

1. A song whose track was stored by an earlier build (no `bpm` in the part) loaded at launch with Backing tracks on: it plays at the song's tempo, no Save button, and nothing is written or sent until the track really changes. (Task 1, `aTrackFromAnEarlierBuildIsReadWithoutBeingWritten`)
2. A tap, or the mean downbeat, falling exactly on a whole bar or rounding up to one: the offset is 0.00, never the bar length, and floating-point error never folds 4.00 s at 120 BPM in 4/4 to 2.00. (Task 2, `anExactBarFoldsToZero`, `aFoldThatRoundsToAWholeBarGivesZero`)
3. The app sent to the background while Sync mode is shown: playback stops, waiting changes are written at once, and Sync mode is still shown on return (it is only not kept across a relaunch). (Task 3, `leavingTheForegroundKeepsSyncModeAndSaves`)
4. A three-digit tempo and a two-digit offset such as `25.40` in the steppers on a 320 pt wide screen: the value fits between − and + (scaled down if it must), never cut or overlapping. (Task 6, scene `trackSyncWide` in the simulator step)
5. A touch on the tap pad that slides before it lifts, and a touch on Start over: one tap at touch-down and none on lift; Start over is never a tap. (Task 6, simulator step, and `tapDownbeat` as the pad's only entry)

---

### Task 1: The track's own tempo

Also renames "first beat" to "offset". The rename is done first, alone, with the suite green, then the tempo.

**Files:**
- Modify: `Metronome/Model/BackingTrack.swift`, `Metronome/Model/SyncRecords.swift`, `Metronome/Model/Library.swift`, `Metronome/Model/TrackGrid.swift`, `Metronome/Model/PickedFileReader.swift`, `Metronome/MetronomeModel.swift`, `Metronome/Engine/ClickEngine.swift`, `Metronome/Engine/AudioClickEngine.swift`, `Metronome/Views/SyncSheet.swift`, `Metronome/Views/TempoControls.swift`, `Metronome/Screenshots/ScreenshotScene.swift`
- Test: `MetronomeTests/MetronomeModelTests.swift` (the fake engine), `MetronomeTests/TrackTestBench.swift`, `MetronomeTests/BackingTrackRecordTests.swift`, `MetronomeTests/LibraryTests.swift`, `MetronomeTests/TrackModelTests.swift`, `MetronomeTests/TrackSongModelTests.swift`, new `MetronomeTests/TrackTempoModelTests.swift`, and the renames in `TrackGridTests`, `TrackBeatClockTests`, `TrackSwitchModelTests`, `SongSheetChangesTests`, `TrackFilesTests`

**Interfaces:**
- Produces, renames (identifiers and comments only):
  - `BackingTrack.firstBeat` → `offset: Int` (hundredths), `firstBeatSeconds` → `offsetSeconds`; `CodingKeys` with `case offset = "firstBeat"`.
  - `PickedTrack.firstBeat` → `offset`.
  - `TrackGrid(firstBeat:bpm:beatsPerBar:)` → `TrackGrid(offset:bpm:beatsPerBar:)`; `TrackGrid.firstBeat(forDownbeatAt:bpm:beatsPerBar:)` → `TrackGrid.offset(forDownbeatAt:bpm:beatsPerBar:)` (Task 2 removes it).
  - `TrackPlayback.firstBeat` → `offset`; `ClickEngine.setFirstBeat(_:)` → `setOffset(_ offset: TimeInterval)`; the engine's internal `firstBeat` field → `offset`.
  - `MetronomeModel.nudgeFirstBeat(by:)` → `nudgeOffset(by steps: Int)`.
  - Fake engine: `firstBeats` → `offsets`.
- Produces, tempo:
  - `BackingTrack.bpm: Int`, kept within 30…300 by `Tempo.clamp`, stored under `"bpm"`. `init(fileID: UUID, fileName: String, offset: Int, bpm: Int, countIn: CountIn = .twoBars, mix: Double = 0)`; `bpm` has no default.
  - `SongRecord.song`: a track part that is an object without a `"bpm"` field is read with the song's tempo filled into the object before decoding. `SongRecord.setTrack(_:now:)` returns without stamping when `song?.track == track`, so filling in never gives the part a new time.
  - `MetronomeModel.tempoInEffect: Int` — `loadedTrack.bpm` while `isTrackInUse`, else `settings.bpm`.
  - A private `settingsInEffect: MetronomeSettings` (settings with `bpm = tempoInEffect`) goes to `engine.start(with:)`, `engine.start(with:track:)`, `engine.update(_:startNewBar:)` and the `TrackGrid` in `start`.
  - `isEdited`: while `isTrackInUse`, only the time signature and the accents are compared; otherwise all of the settings, as today.
  - `func nudgeTrackTempo(by delta: Int)` — the Sync tempo stepper: clamps 30…300, writes the track's `bpm` through `saveLoadedTrack` (so `persistSoon`), sends `settingsInEffect` to a playing engine with `startNewBar: false`, plays a selection tick only when the value changed. Never touches `settings`.
  - `toggleBackingTracks()` also calls `syncSaveOffer()`, so the Save button comes and goes at once with the swap.
  - `loadedTrackArrived(replacing:)`: the same file with a new `bpm` sends `settingsInEffect` to the engine while playing (also with the file missing); a new offset calls `setOffset`.
  - A private `newTrack(_ picked: PickedTrack, bpm: Int, replacing old: BackingTrack?)`: `bpm` is `old?.bpm` when replacing, else the song's tempo as the sheet saves it (`newSettings.sanitized().bpm`) in `createSong`, `saveAsNewSong` and `editSong`. A file picked for a missing track keeps the part, its `bpm` included.
  - Fake engine: `startedSettings: [MetronomeSettings]`, appended by both `start` methods.
  - `TrackTestBench.makeTrack(bpm: Int = 120, countIn:mix:missing:)` and `makeModel(trackBPM: Int = 120, length:countIn:mix:missing:)`.
- Removes: `nudgeSyncTempo(by:)`, `tapSyncTempo(at:)`, the `savingIntoSong` flag of `applyBPM`, `Library.updateSongTempo`, `TapTempoPill.savesIntoSong`; `SongRecord.setTempo` becomes private (only `setSettings` uses it). The rule that a Sync tempo is written into the song's tempo is gone with them.

- [ ] **Step 1: Rename.** Apply the renames above across `Metronome/` and `MetronomeTests/`, test names included (`aNudgedFirstBeatRestampsOnlyTheTrackPart` → `aNudgedOffsetRestampsOnlyTheTrackPart`, and so on). UI copy in `SyncSheet.swift`: the group label `OFFSET`, the value's VoiceOver label `Offset`, read as "Offset, 0.48 seconds". Leave `BeatClock`'s "first beat" alone: it means beat 1 of the plain click.
- [ ] **Step 2: Run** `scripts/build.sh` and `scripts/test.sh`; all pass with the rename alone. No commit yet: the rename and the tempo land together at Step 9.
- [ ] **Step 3: Write the failing key-name test** in `BackingTrackRecordTests.swift`:

```swift
@Test func theTrackPartKeepsItsStoredKeyNames() throws {
    let value = try JSONValue(encoding: BackingTrack(fileID: UUID(), fileName: "a", offset: 48, bpm: 120))
    guard case .object(let fields) = value else { Issue.record("not an object"); return }
    #expect(fields["firstBeat"] == .number(48))
    #expect(fields["bpm"] == .number(120))
    #expect(fields["offset"] == nil)
}
```
- [ ] **Step 4: Write the failing record tests** in `BackingTrackRecordTests.swift` (helper: a record at `t(1)` for a song at 96 BPM whose track part is the raw object `["fileID": .string(id.uuidString), "fileName": .string("Song.m4a"), "firstBeat": .number(48), "countIn": .number(2), "mix": .number(0)]`):
  - `aTrackStoredWithoutATempoTakesTheSongsTempo`: `record.song?.track?.bpm == 96`, `offset == 48`.
  - `fillingInTheTempoStampsNothing`: `record.setTrack(try #require(record.song?.track), now: t(5))`; `record.parts["track"]` equals what it was.
  - `theNextTrackChangeWritesTheTempoIn`: the read track with `offset += 1`, set at `t(5)`; the part's time is `t(5)` and its object has `"bpm": .number(96)`.
  - `theTrackTempoIsKeptInRange`: `bpm: 10` reads 30, `bpm: 400` reads 300.
  - In `LibraryTests.swift` delete `settingTheTempoLeavesTheMeterPartsTimeAlone` and `settingTheSameTempoStampsNothing` (their API goes).
- [ ] **Step 5: Write the failing model tests** in `TrackTempoModelTests.swift` (bench model: song 120 BPM 4/4, `trackBPM: 90`):
  - `theClickPlaysAtTheTracksTempo`: `tempoInEffect == 90`, `settings.bpm == 120`; after `togglePlayback()`, `engine.startedSettings.last?.bpm == 90` and `engine.startedTracks.count == 1`.
  - `aMissingFilePlaysTheClickAtTheTracksTempo`: `missing: true`; start; `startedSettings.last?.bpm == 90`, `startedTracks.isEmpty`.
  - `switchedOffTheClickPlaysAtTheMetronomesTempo`: toggle off; `tempoInEffect == 120`; start; `startedSettings.last?.bpm == 120`.
  - `theSwitchSwapsTheTempoWithoutChangingEither`: off: `tempoInEffect == 120`; on: `90`; `loadedTrack?.bpm == 90` and `settings.bpm == 120` throughout.
  - `unloadPlaysAtTheMetronomesTempo`: `unloadSong()`; `tempoInEffect == 120`.
  - `anUnsavedMetronomeTempoIsNotEditedWhileTheTrackIsInUse`: `nudgeBPM(by: 5)`; `settings.bpm == 125`, `isEdited == false`, `isSaveOffered == false`, `tempoInEffect == 90`; toggle off: `isEdited`, `isSaveOffered` at once; toggle on: both false at once.
  - `anAccentOnTheTrackScreenShowsSave`: `toggleAccent(beat: 2)`; `isEdited`, `isSaveOffered`.
  - `saveWritesTheMetronomesTempoToo`: `nudgeBPM(by: 5)`, `toggleAccent(beat: 2)`, `saveChanges()`; `loadedSong?.settings.bpm == 125`, accents `[1, 2]`, `loadedTrack?.bpm == 90`.
  - `revertSetsBackTheMetronomesTempoAndLeavesTheTracks`: playing; `nudgeBPM(by: 5)`, `toggleAccent(beat: 2)`, `discardChanges()`; `settings.bpm == 120`, `engine.lastUpdate?.bpm == 90`, `loadedTrack?.bpm == 90`.
  - `editingTheSongsTempoLeavesTheTempoInEffect`: playing; `editSong(id, name: "Song", settings: 100 BPM 4/4 [1])`; `settings.bpm == 100`, `tempoInEffect == 90`, `engine.lastUpdate?.bpm == 90`.
  - `theTrackTempoStepsByOne`: `nudgeTrackTempo(by: 1)`; `loadedTrack?.bpm == 91`, `settings.bpm == 120`, `isEdited == false`, `isSaveOffered == false`, one more selection tick.
  - `theTrackTempoStaysInRange`: `trackBPM: 300`; `nudgeTrackTempo(by: 1)`; still 300, no tick.
  - `aTrackTempoStepReachesThePlayingEngine`: playing; step; `engine.lastUpdate?.bpm == 91`, `lastUpdateStartedNewBar == false`.
  - `aTrackTempoStepReachesTheClickOfAMissingFile`: `missing: true`, playing; step; `engine.lastUpdate?.bpm == 91`.
  - `severalTrackTempoStepsSaveOnce` (polls): five steps with `saveDelay: .milliseconds(20)`; exactly one more write; the saved track reads 95 and the saved song 120.
  - `aTrackTempoSurvivesARelaunch`: step, `savePendingChanges()`, `bench.relaunch()`; `loadedTrack?.bpm == 91`, `loadedSong?.settings.bpm == 120`.
  - `aTrackFromAnEarlierBuildIsReadWithoutBeingWritten` (Review Focus 1): save a library whose loaded song (96 BPM) has the raw track part of Step 4, relaunch; `tempoInEffect == 96`, `isSaveOffered == false`; start and stop; `bench.libraryDefaults.writes` unchanged since the relaunch.
- [ ] **Step 6: Write the failing song tests** in `TrackSongModelTests.swift` (give `other`'s track `bpm: 150` in `makeModel`):
  - `loadingASongWithATrackPlaysAtTheTracksTempo`: `loadSong(other)`: `tempoInEffect == 150`, `settings.bpm == 140`; `loadSong(plain)`: `tempoInEffect == 90`.
  - `attachingATrackGivesItTheSongsTempoAsSaved`: `editSong(plain.id, name: "Plain", settings: 95 BPM 4/4 [1], track: .attach(picked()))`; the saved track's `bpm == 95`.
  - `aNewSongsTrackTakesTheNewSongsTempo`: `createSong` and `saveAsNewSong` at 100 BPM with a picked file; each track's `bpm == 100`.
  - `replacingTheFileKeepsTheTracksTempo`: attach a new file to `other`; `bpm == 150`.
  - `pickingAFileForAMissingTrackKeepsItsTempo`: `missing: true`, `nudgeTrackTempo(by: 13)` first (120 to 133); attach a file for the missing one; `bpm == 133`.
  - `aTrackTempoArrivingFromAnotherDeviceReachesThePlayingEngine`: as `anOffsetArrivingFromAnotherDeviceMovesTheGrid` (the renamed `aFirstBeatArrivingFromAnotherDeviceMovesTheGrid`), with `a.nudgeTrackTempo(by: 2)`; `b.loadedTrack?.bpm == 102`, `bEngine.lastUpdate?.bpm == 102`, `b.isPlaying`, `bEngine.stopCount == 0`.
  - In `TrackModelTests.swift` delete the "Sync sheet's tempo" group (`aSyncSheetTempoIsSavedIntoTheSong` through `aSyncTempoReachesAPlayingEngine`).
- [ ] **Step 7: Run** `scripts/test.sh`; the new tests fail to compile.
- [ ] **Step 8: Implement** the Interfaces. Read every `settings` use in `MetronomeModel.swift` that reaches the engine or `TrackGrid` and switch it to `settingsInEffect`; `store.save(settings)` keeps the metronome's own. In `SyncSheet.swift` the tempo row shows `model.loadedTrack?.bpm` and calls `nudgeTrackTempo(by:)`, and its Tap tempo pill is removed (Sync has no tap tempo, 7.11). Add `bpm: 120` to the screenshot scenes' tracks (the demo file is 120 BPM). Then `scripts/build.sh` and `scripts/test.sh`; all pass.
- [ ] **Step 9: Commit** with subject `Give the backing track its own tempo`.

Between this task and Task 5 the track screen still shows the dial and the tempo row, which show and change the metronome's tempo while the click plays at the track's. That is expected; Task 5 removes them.

### Task 2: Tap runs

**Files:**
- Create: `Metronome/Model/TapRun.swift`, `MetronomeTests/TapRunTests.swift`, `MetronomeTests/TapRunModelTests.swift`
- Modify: `Metronome/Model/TrackGrid.swift` (remove `offset(forDownbeatAt:)`), `Metronome/MetronomeModel.swift`, `Metronome/Views/SyncSheet.swift` (the pill calls `tapDownbeat()`)
- Test: `MetronomeTests/TrackGridTests.swift` (move the fold tests), `MetronomeTests/TrackSongModelTests.swift` (replace the two `tapOnBeatOne` tests)

**Interfaces:**
- Consumes: `BackingTrack.bpm`, `.offset`, `nudgeTrackTempo(by:)`, `nudgeOffset(by:)`, `ClickEngine.setOffset(_:)`, `settingsInEffect` (Task 1).
- Produces, in `TapRun.swift`:
  - `struct TapFit: Equatable, Sendable { let bpm: Int; let offset: Int }` (offset in hundredths).
  - `struct TapRun: Equatable, Sendable` with `struct Tap: Equatable, Sendable { let bar: Int; let time: TimeInterval }`, `private(set) var taps: [Tap]`, `var isEmpty: Bool`.
  - `mutating func add(at time: TimeInterval, bpm: Int, beatsPerBar: Int)` — the first tap is bar 0; a later one is the previous bar plus `gap / L` rounded half up, at least 1, with `L = 60 × b / T` at the `bpm` given; a time not later than the last tap's starts a new run with this tap at bar 0.
  - `func fitted(bpm: Int, beatsPerBar: Int) -> TapFit?` — nil when empty; one tap: `TapFit(bpm: bpm, offset: fold(t, L))`; two or more: the least-squares slope of 7.11, tempo `60 × b / s` rounded half up and clamped 30…300, `L′` at that whole tempo, `d = t̄ − k̄ × L′`, offset `fold(d, L′)`.
  - `static func foldedOffset(_ time: TimeInterval, barLength: TimeInterval) -> Int` — hundredths of `time − L × ⌊time / L⌋`, rounded half up. The floor allows 1e-9 bar of floating error (as `TrackGrid.firstIndex` does), and a result that rounds to `L` itself gives 0, the earlier downbeat. Never negative.
  - `var countLine: String?` (`1 tap · 1 bar`, `4 taps · 6 bars`; bars = last bar + 1; nil when empty) and `var spokenCountLine: String?` (`5 taps, 12 bars`).
- Produces, `MetronomeModel`:
  - `private(set) var tapRun = TapRun()`.
  - `var canTapDownbeat: Bool { isPlayingTrack && !isCountingIn }` — reads the engine, so views poll it.
  - `func tapDownbeat()` — does nothing unless `canTapDownbeat` and `engine.trackTime` is at least 0; plays a selection tick; adds `engine.trackTime` to the run at the track's `bpm` and the time signature; writes the fit's `bpm` and `offset` together in one `saveLoadedTrack`; sends `settingsInEffect` to the engine when the tempo changed and `setOffset` when the offset changed.
  - `func startTapRunOver()` — empties the run; no haptic.
  - The run is emptied by an actual time signature change, by `nudgeTrackTempo` and `nudgeOffset` when they change the value, by a tempo or offset arriving from another device (`loadedTrackArrived`), and by `loadedTrackReplaced()` (a run belongs to one file). A mix or count-in change, an accent toggle and Stop leave it.
- Removes: `tapBeatOne()`, `TrackGrid.offset(forDownbeatAt:bpm:beatsPerBar:)`.

- [ ] **Step 1: Write the failing unit tests** in `TapRunTests.swift`. The worked example of 7.11, number for number:

```swift
@Test func theWorkedExample() {
    var run = TapRun()
    run.add(at: 10.11, bpm: 120, beatsPerBar: 4)
    #expect(run.fitted(bpm: 120, beatsPerBar: 4) == TapFit(bpm: 120, offset: 11))
    run.add(at: 12.01, bpm: 120, beatsPerBar: 4)
    #expect(run.taps.map(\.bar) == [0, 1])
    #expect(run.fitted(bpm: 120, beatsPerBar: 4) == TapFit(bpm: 126, offset: 58))
    run.add(at: 13.95, bpm: 126, beatsPerBar: 4)
    #expect(run.taps.map(\.bar) == [0, 1, 2])
    #expect(run.fitted(bpm: 126, beatsPerBar: 4) == TapFit(bpm: 125, offset: 50))
    run.add(at: 19.69, bpm: 125, beatsPerBar: 4)
    #expect(run.taps.map(\.bar) == [0, 1, 2, 5])
    #expect(run.fitted(bpm: 125, beatsPerBar: 4) == TapFit(bpm: 125, offset: 50))
    #expect(run.countLine == "4 taps · 6 bars")
    #expect(run.spokenCountLine == "4 taps, 6 bars")
}
```
  and, each at 120 BPM in 4/4 unless stated:
  - `oneTapSetsOnlyTheOffset`: a tap at 9.30 fits `TapFit(bpm: 120, offset: 130)`.
  - `aShortGapStillCountsOneBar`: taps 10.0 and 10.5: bars `[0, 1]`.
  - `halfABarRoundsUp`: taps 0.0 and 3.0: bars `[0, 2]`.
  - `aTapNotLaterThanTheLastStartsANewRun`: taps 10, 12, then 11: `taps == [Tap(bar: 0, time: 11)]`; another at 11: still one tap.
  - `anExactBarFoldsToZero`: `foldedOffset(4.0, barLength: 2.0) == 0`, `foldedOffset(6.0, barLength: 2.0) == 0`.
  - `aFoldThatRoundsToAWholeBarGivesZero`: `foldedOffset(3.998, barLength: 2.0) == 0`.
  - `aMeanDownbeatJustBeforeTheStartGoesForwardABar`: taps 0.0 and 1.7 fit `TapFit(bpm: 141, offset: 170)`.
  - `theFittedTempoStaysInRange`: at 300 BPM taps 0.0 and 0.1 fit `bpm == 300`; at 30 BPM in 12/8 taps 0 and 30 fit `bpm == 30`.
  - `theCountLineIsSingularAndPlural`: empty: `countLine == nil`; one tap: `"1 tap · 1 bar"`; bars `[0, 1]`: `"2 taps · 2 bars"`.
  - Move `tapOnBeatOneGoesBackWholeBars`, `tapOnBeatOneWithABarLongerThanTheTap` and the fold line of `tempoIsClampedInTheGrid` from `TrackGridTests` to `TapRunTests` as `foldedOffset` tests with the same figures (`9.30, 2.0 → 130`, `1.30, 2.0 → 130`, `0.004, 2.0 → 0`, `1.0, 24.0 → 100`, `9.0, 8.0 → 100`).
- [ ] **Step 2: Write the failing model tests** in `TapRunModelTests.swift` (bench model, playing, `engine.trackTime` set before each tap):
  - `oneTapOnThePadSetsTheOffsetFromTheHeardPlace`: 9.30; `loadedTrack?.offset == 130`, `bpm == 120`, `engine.offsets.last == 1.30`, one more selection tick, `tapRun.taps.count == 1`.
  - `theWorkedExampleOnThePad`: 10.11 then 12.01: `loadedTrack?.bpm == 126`, `offset == 58`, `engine.lastUpdate?.bpm == 126`; then 13.95 and 19.69: `bpm == 125`, `offset == 50`, `tapRun.countLine == "4 taps · 6 bars"`, `settings.bpm == 120`.
  - `thePadDoesNothingWhileStoppedOrCountingIn`: stopped: nothing; playing with `trackTime = -1`: nothing; no tick, `tapRun.isEmpty`.
  - `startOverForgetsTheRunAndKeepsTheValues`: two taps, `startTapRunOver()`; `tapRun.isEmpty`, bpm and offset unchanged, no tick.
  - `aTimeSignatureChangeEndsTheRun`: tap, `selectTimeSignature(.threeFour)`; empty. Selecting 4/4 again with a run: kept.
  - `steppingTheTempoOrTheOffsetEndsTheRun`: tap, `nudgeTrackTempo(by: 1)`: empty; tap, `nudgeOffset(by: 1)`: empty.
  - `theMixAccentsAndCountInKeepTheRun`: tap, `setMix(0.4)`, `toggleAccent(beat: 2)`, `setCountIn(.off)`; one tap left.
  - `severalTapsSaveOnce` (polls): three taps with `saveDelay: .milliseconds(20)`; exactly one more write.
  - In `TrackSongModelTests.swift`: `aTempoOrOffsetArrivingFromAnotherDeviceEndsTheRun` (B taps; A steps the offset and saves; after the arrival `b.tapRun.isEmpty`) and `aMixArrivingKeepsTheRun`. Replace `tapOnBeatOneSetsTheFirstBeatFromTheHeardPosition` and `tapOnBeatOneDoesNothingWhileStoppedOrCountingIn` with the tests above.
- [ ] **Step 3: Run** `scripts/test.sh`; the new tests fail to compile.
- [ ] **Step 4: Implement** `TapRun.swift` and the model's part. The least-squares slope and the fold are the only arithmetic; everything else follows from the signatures. Point `SyncSheet`'s Tap on beat 1 pill at `tapDownbeat()` with `canTapDownbeat` for its dimming.
- [ ] **Step 5: Run** `scripts/build.sh` and `scripts/test.sh`; all pass.
- [ ] **Step 6: Commit** with subject `Set the track's tempo and offset from tapped downbeats`.

### Task 3: Sync mode in the model

**Files:**
- Modify: `Metronome/MetronomeModel.swift`, `Metronome/Model/SyncRecords.swift`, `Metronome/Model/Library.swift`, `Metronome/Views/MetronomeScreen.swift`, `Metronome/Views/TrackControls.swift`, `Metronome/Views/SyncSheet.swift`
- Create: `MetronomeTests/SyncModeModelTests.swift`
- Test: `MetronomeTests/LibraryTests.swift`, `MetronomeTests/TrackModelTests.swift`, `MetronomeTests/TrackSongModelTests.swift`

**Interfaces:**
- Consumes: `tapRun`, `startTapRunOver()`, `nudgeTrackTempo`, `nudgeOffset`, `persistSoon`, `savePendingChanges` (Tasks 1 and 2).
- Produces, records: `SongRecord.setMeter(_ settings: MetronomeSettings, now: Date)` (stamps only the meter part, only when it differs; `setSettings` calls it) and `Library.updateSongMeter(_ id: UUID, settings: MetronomeSettings, now: Date)` (sanitises; the tempo part and its time are untouched).
- Produces, `MetronomeModel`:
  - `private(set) var isSyncModeShown = false` — not saved, so off at launch.
  - `func enterSyncMode()` — only while `isTrackPlayable`; empties the run; playback carries on; no haptic.
  - `func leaveSyncMode()` — `Done`: hides it, empties the run, `savePendingChanges()`; playback carries on; no haptic.
  - Sync mode ends by itself, as `leaveSyncMode()`, whenever `refreshTrackFile()` finds the track no longer playable: removed, replaced or the song deleted on another device (7.9, 7.11).
  - In Sync mode, `selectTimeSignature` and `toggleAccent` also call `library.updateSongMeter` with the current settings and `persistSoon()`, then take the Save offer away at once when nothing differs (`syncSaveOffer()`), otherwise `userChangedSettings()` as today. The metronome's tempo is never written.
  - `toggleBackingTracks()` does nothing while `isSyncModeShown`.
  - `func goToTrackStart()` — To the beginning: stopped, the position is 0:00; playing the file, `engine.seekTrack(to: 0)` (no count-in); during the count-in before the file starts, nothing. No haptic.
  - `func goToTrackEnd()` — To the end: does what `trackEnded()` does: playing, the engine stops and playback becomes stopped; either way the position is 0:00; the loaded song stays. No haptic (section 12 names only Start and Stop).
- Removes: `toggleTrackPlaybackWithoutCountIn()`. Sync mode's play / stop is `togglePlayback()`, which counts in at 0:00.
- Views, so the target builds and Sync still opens: `MetronomeScreen` drops `isSyncShown` and presents `SyncSheet` with `Binding(get: { model.isSyncModeShown }, set: { if !$0 { model.leaveSyncMode() } })`; `PlayerCard`'s Sync calls `model.enterSyncMode()`; `SyncSheet`'s Done calls `leaveSyncMode()`, its play / stop `togglePlayback()`, and its own `onChange(of: isTrackPlayable)` dismissal and `onDisappear` save go (the model does both). The `trackSync` scene calls `model.enterSyncMode()` in `makeModel`.

- [ ] **Step 1: Write the failing tests.**
  - `LibraryTests`: `settingTheMeterLeavesTheTempoPartsTimeAlone` (song saved at T; `updateSongMeter(id, settings: 3/4 [1], now: T + 10)`; the meter part's time is later than T, the tempo part's time is T) and `settingTheSameMeterStampsNothing`.
  - `SyncModeModelTests` (bench model, `trackBPM: 120` unless stated):
    - `syncModeIsOffAtLaunch`: `isSyncModeShown == false`; enter, relaunch: false.
    - `enteringAndLeavingLeavesPlaybackAsItIs`: playing; enter: shown, `isPlaying`, `engine.stopCount == 0`; leave: `isPlaying`; selection, transport and success counts unchanged.
    - `syncModeNeedsThePlayableFile`: `missing: true`: enter does nothing; switch off: enter does nothing.
    - `enteringStartsAFreshRun`: playing, a tap, leave, enter: `tapRun.isEmpty`.
    - `doneSavesAWaitingChangeAtOnce`: enter, `nudgeOffset(by: 1)`, leave; the store's saved track has offset 49.
    - `leavingTheForegroundKeepsSyncModeAndSaves` (Review Focus 3): enter, play, `nudgeOffset(by: 1)`, `appDidLeaveForeground()`; `isPlaying == false`, still shown, the saved offset is 49.
    - `theSwitchCannotBeTurnedInSyncMode`: enter, `toggleBackingTracks()`; still on, no tick.
    - `playInSyncModeCountsInAtZero`: enter, `togglePlayback()`; `startedTracks.last?.startTime == 0.48 - 4.0`, `firstClickIndex == -8`.
    - `toTheBeginningWhileStoppedGoesToZero`: `seekTrack(to: 70)`, `goToTrackStart()`; `trackPosition == 0`.
    - `toTheBeginningWhilePlayingCarriesOnWithoutCountIn`: playing, `trackTime = 30`; `engine.seeks.last == 0`, `isPlaying`, `startCount == 1`.
    - `toTheBeginningDuringTheCountInChangesNothing`: playing, `trackTime = -2`; `seeks.isEmpty`.
    - `toTheEndStopsAndGoesToZero`: playing, `trackTime = 30`; `goToTrackEnd()`; `isPlaying == false`, `trackPosition == 0`, the next start counts in (`startTime == 0.48 - 4.0`); stopped at 70: `trackPosition == 0`.
    - `aTimeSignatureInSyncModeIsSavedAtOnce`: enter, `selectTimeSignature(.threeFour)`; `loadedSong?.settings.timeSignature == .threeFour`, accents `[1]`, `isEdited == false`, `isSaveOffered == false`; after `savePendingChanges()` the store has it.
    - `anAccentInSyncModeIsSavedAtOnce`: the same for `toggleAccent(beat: 3)`.
    - `syncModeSavesAnEarlierAccentAndLeavesTheMetronomeTempo`: on the track screen `toggleAccent(beat: 2)` (`isSaveOffered`) and `nudgeBPM(by: 5)`; enter; `toggleAccent(beat: 3)`; saved accents `[1, 2, 3]`, saved song tempo 120, `isSaveOffered == false`; leave and switch off: `isEdited`, `isSaveOffered`.
    - `outsideSyncModeTheMeterIsNotSaved`: `selectTimeSignature(.threeFour)`; `loadedSong?.settings.timeSignature == .fourFour`, `isEdited`.
    - `severalSyncModeChangesSaveOnce` (polls): enter, three accent toggles and two offset steps with `saveDelay: .milliseconds(20)`; exactly one more write holding all five.
  - `TrackSongModelTests` (two devices, B in Sync mode): `syncModeEndsWhenTheTrackIsRemovedElsewhere`, `syncModeEndsWhenTheTrackIsReplacedElsewhere`, `syncModeEndsWhenTheSongIsDeletedElsewhere` — each: `b.isSyncModeShown == false` after the arrival; `aTrackTempoArrivingKeepsSyncModeShown`.
  - `TrackModelTests`: delete `theSheetsPlayNeverCountsIn`.
- [ ] **Step 2: Run** `scripts/test.sh`; the new tests fail to compile.
- [ ] **Step 3: Implement** the Interfaces, records first, then the model, then the stopgap view wiring.
- [ ] **Step 4: Run** `scripts/build.sh` and `scripts/test.sh`; all pass.
- [ ] **Step 5: Commit** with subject `Make Sync a mode of the track screen in the model`.

Until Task 6, Sync mode is shown as the old sheet driven by `isSyncModeShown`.

### Task 4: Layout arithmetic

New types rather than a third branch in `ScreenLayout`: the track screen has no dial, so `ScreenLayout`'s dial fit does not apply. `ScreenLayout`'s `hasTrack` branch stays until Task 5 moves the screen off it, so this task builds and passes alone and changes nothing on screen.

**Files:**
- Create: `Metronome/Views/TrackLayouts.swift`, `MetronomeTests/TrackLayoutTests.swift`

**Interfaces:**
- Consumes: `AccentTiles.height(forBeats:singleRowTileHeight:)`, `Theme.sideMargin`, `ScreenLayout.narrowWidth`, `ScreenLayout.narrowSideMargin`.
- Produces, `struct TrackScreenLayout` (6.12):
  - `init(width: CGFloat, height: CGFloat, hasBottomInset: Bool, beats: Int, hasSetlist: Bool)`; `height` is the height inside the safe areas.
  - `let sideMargin, bottomPadding, readingRoom, numberFontSize, cardHeight, tilesHeight: CGFloat`; `let showsNextLine: Bool`.
  - `static let headerHeight: CGFloat = 48` (8 + 40), `readingTopGap = 8`, `readingHeight = 152`, `fullNumberSize = 136`, `numberLineHeight = 108` (at the full size), `readingLineGap = 10`, `syncButtonHeight = 34`, `tileHeight = 76`, `cardTopGap = 16`, `playerCardHeight = 192`, `playerNextLineHeight = 30`, `nextLineMinimumRoom = 280`, `minimumNumberSize = 24` (a safety floor no supported phone nears).
  - `readingRoom = height − bottomPadding − 48 − 8 − tilesHeight − 16 − cardHeight`; `numberFontSize = min(136, max(24, (readingRoom − 44) × 136 / 108))`; the next-up line is shown only with a setlist and when it leaves at least 280 pt of room.
- Produces, `struct SyncModeLayout` (6.13):
  - `init(width: CGFloat, height: CGFloat, hasBottomInset: Bool, beats: Int)`.
  - `let sideMargin, bottomPadding, tileHeight, padHeight, scrollOverflow: CGFloat`; `let showsHandIcon: Bool`.
  - `static let headerHeight: CGFloat = 48`, `rowTopGap = 16`, `rowHeight = 60`, `tilesTopGap = 14`, `padGap = 14` (above and below), `stepperHeight = 70`, `countInTopGap = 14`, `countInHeight = 40`, `mixTopGap = 10`, `mixHeight = 32`, `cardTopGap = 16`, `playbackCardHeight = 136`, `minimumPad = 72`, `handIconMinimumPad = 120`, `compactTileHeight = 56`; `static func partsHeight(tilesHeight: CGFloat) -> CGFloat` (484 + tiles, so 560 with 76 pt tiles).
  - The pad takes `height − bottomPadding − partsHeight`; below 72 single-row tiles drop to 56 and it is worked out again; still below 72, it is 72 and `scrollOverflow` is the shortfall; `showsHandIcon == padHeight >= 120`.

- [ ] **Step 1: Write the failing tests** in `TrackLayoutTests.swift`, with `==` throughout (every figure is whole):
  - `theTrackScreenOnAnIPhone17Pro`: 402 × 778, bottom inset, 4 beats, setlist: `showsNextLine`, `readingRoom == 408`, `numberFontSize == 136`, `cardHeight == 222`, `bottomPadding == 0`; 9 and 12 beats: `readingRoom == 386`; no setlist: `readingRoom == 438`, `cardHeight == 192`.
  - `theTrackScreenOnAnIPhoneSE`: 375 × 647, no inset, setlist: `showsNextLine == false`, `readingRoom == 291`, `cardHeight == 192`, `bottomPadding == 16`, `numberFontSize == 136`; 9 and 12 beats: `readingRoom == 269`, `tilesHeight == 98`.
  - `theTrackScreenWithDisplayZoom`: 320 × 548, setlist: `showsNextLine == false`, `readingRoom == 192`, `sideMargin == 16`, `numberFontSize == 136`; 9 and 12 beats: `readingRoom == 170`.
  - `theNextUpLineNeeds280OfRoom`: 402 × 650, inset, setlist: shown, `readingRoom == 280`; 402 × 649: not shown, `readingRoom == 309`.
  - `theNumberScalesBelow152OfRoom`: 402 × 492, inset, no setlist: `readingRoom == 152`, `numberFontSize == 136`; 402 × 438: `readingRoom == 98`, `numberFontSize == 68`.
  - `anImpossiblyShortScreenKeepsTheSmallestNumber`: 375 × 300: `numberFontSize == 24`.
  - `theTrackScreenFillsTheHeight`: for every case above, `48 + 8 + readingRoom + tilesHeight + 16 + cardHeight + bottomPadding == height`.
  - `syncModeOnAnIPhone17Pro`: 402 × 778, inset, 4 beats: `padHeight == 218`, `tileHeight == 76`, `scrollOverflow == 0`, `showsHandIcon`; 9 beats: `padHeight == 196`.
  - `syncModeOnAnIPhoneSE`: 375 × 647, 4 beats: `tileHeight == 56`, `padHeight == 91`, `scrollOverflow == 0`, `showsHandIcon == false`; 9 and 12 beats: `padHeight == 72`, `scrollOverflow == 23`.
  - `syncModeWithDisplayZoom`: 320 × 548, 4 beats: `tileHeight == 56`, `padHeight == 72`, `scrollOverflow == 80`, `sideMargin == 16`; 9 and 12 beats: `scrollOverflow == 122`.
  - `tallTilesStayWhileThePadHas72`: 402 × 632, inset: `tileHeight == 76`, `padHeight == 72`; 402 × 631: `tileHeight == 56`, `padHeight == 91`.
  - `theHandIconNeeds120`: 402 × 680, inset: `padHeight == 120`, shown; 402 × 679: not shown.
  - `syncModeFitsOrScrollsByTheRest`: for every case above, `partsHeight(tilesHeight: AccentTiles.height(forBeats:singleRowTileHeight: tileHeight)) + padHeight + bottomPadding == height + scrollOverflow`.
- [ ] **Step 2: Run** `scripts/test.sh`; the new tests fail to compile.
- [ ] **Step 3: Implement** both types. If a spec figure cannot be met, the spec's text is the authority: report it rather than bending the code.
- [ ] **Step 4: Run** `scripts/build.sh` and `scripts/test.sh`; all pass.
- [ ] **Step 5: Commit** with subject `Size the track screen and Sync mode`.

### Task 5: Track screen views

**Files:**
- Create: `Metronome/Views/TrackScreen.swift`
- Modify: `Metronome/Views/MetronomeScreen.swift` (track branch; remove `ScreenLayout`'s `hasTrack` branch and its track constants), `Metronome/Views/TrackControls.swift` (remove `TrackTempoRow`; `PlayerCard` without Sync), `Metronome/Screenshots/ScreenshotScene.swift`
- Test: `MetronomeTests/ScreenLayoutTests.swift` (remove the track section and `trackLayout`; every plain test stays unchanged)

**Interfaces:**
- Consumes: `TrackScreenLayout` (Task 4), `model.tempoInEffect`, `model.lastBeat`, `model.isPlaying`, `model.isTrackMissing`, `model.enterSyncMode()`, `BeatPulse.decay(bpm:)`, `AccentTiles(singleRowTileHeight:)`.
- Produces: `struct TempoReading: View` with `init(numberFontSize: CGFloat)`; `struct TrackScreenContent: View` with `init(layout: TrackScreenLayout)` (reading, tiles, card); `PlayerCard` with `init(showsNextLine: Bool)` reading its heights from `TrackScreenLayout`.

- [ ] **Step 1: `TempoReading`** per 6.12: the number (`tempoInEffect`, heavy, tight digits as the dial's number, font `numberFontSize`, line height `numberFontSize × 108 / 136`, one line, never wider than the margins), 10 pt, then one centred line: the time signature (18 pt heavy, muted) and, 12 pt after it, the Sync pill (34 pt, 1 pt line outline, 18 pt sides, `Sync` 14 pt semibold dial white, 44 pt tall touch area), calling `model.enterSyncMode()`, dimmed to 40 % and disabled while `isTrackMissing`. The number and the time signature take no touches.
- [ ] **Step 2: The pulse** per section 12: on each `lastBeat` change while playing, a keyframe level jumps to 1 and decays over `BeatPulse.decay(bpm: tempoInEffect)`; the number's colour runs from amber at 1 to dial white at 0; behind it a 360 × 270 pt elliptical radial glow, amber at 20 % at the centre and clear from 68 % out, at the same level. No scale, so Reduce Motion changes nothing here. Stopped: dial white, no glow. Follow `BeatGlow`'s keyframe pattern.
- [ ] **Step 3: Accessibility** per 13: the number is text reading "Tempo, 168 beats per minute"; the time signature "Time signature, 7/8"; the Sync pill "Sync", dimmed when missing. Hide the glow.
- [ ] **Step 4: `PlayerCard`**: the file-name row is the icon and, 8 pt after it, the name (or `Track missing`) taking the rest of the row; the Sync pill and `onSync` go. Heights from `TrackScreenLayout.playerCardHeight` and `playerNextLineHeight`.
- [ ] **Step 5: `MetronomeScreen`**: with `model.isTrackInUse`, build a `TrackScreenLayout` and show the header, then `TrackScreenContent`: the reading centred in its room from 8 pt below the header, the tiles at 76 pt (two rows in 9/8 and 12/8) directly below it, at least 16 pt, the card, the bottom padding. Without a track, the plain branch is unchanged. Remove `TrackTempoRow`, `ScreenLayout`'s `hasTrack` parameter and its track constants, and the track tests in `ScreenLayoutTests`.
- [ ] **Step 6: Run** `scripts/build.sh` and `scripts/test.sh`; all pass.
- [ ] **Step 7: See it in the simulator** on iPhone 17 Pro: `scripts/build.sh`, `xcrun simctl install booted build/DerivedData/Build/Products/Debug-iphonesimulator/Metronome.app`, then `xcrun simctl launch booted com.metsahalme.metronome -screenshotScene trackScreen` (and `trackSolo`, `trackMissing`, `trackLast`). Save screenshots with `xcrun simctl io booted screenshot` to `build/screens/`. Check against 6.12: no dial, no − / +, no time signature row; the number at 136 pt and centred in its room; the time signature and Sync under it; tiles; the card without Sync and with the next-up line in the setlist scene; while playing, the number lighting amber on every beat with the glow behind it (take several screenshots in a row); `Track missing` with Sync dimmed and doing nothing; the switch off giving the plain layout with the dial. Repeat `trackScreen` on an iPhone SE simulator (find one with `xcrun simctl list devices available`; create one if missing): no next-up line, number at full size. Fix differences.
- [ ] **Step 8: Commit** with subject `Show the tempo reading on the track screen`.

Until Task 6, Sync still opens the old sheet.

### Task 6: Sync mode views

**Files:**
- Create: `Metronome/Views/SyncMode.swift` (the screen, its header and the tap pad), `Metronome/Views/SyncModeControls.swift` (the steppers, count-in, mix row with `MixSlider`, and the playback card)
- Delete: `Metronome/Views/SyncSheet.swift`
- Modify: `Metronome/Views/MetronomeScreen.swift`, `Metronome/Screenshots/ScreenshotScene.swift`, `docs/specification.md` (sections 14 and 15 only)

**Interfaces:**
- Consumes: `SyncModeLayout` (Task 4); `isSyncModeShown`, `leaveSyncMode()`, `goToTrackStart()`, `goToTrackEnd()` (Task 3); `tapRun`, `canTapDownbeat`, `tapDownbeat()`, `startTapRunOver()` (Task 2); `nudgeTrackTempo(by:)`, `nudgeOffset(by:)` (Task 1); `setCountIn(_:)`, `setMix(_:)`, `togglePlayback()`, `TrackProgressBar`, `TrackSkipButton`, `TimeSignatureRow`, `AccentTiles`, `StepButton`, `TrackMix`.
- Produces: `struct SyncModeView: View` (no parameters); `ScreenshotScene.trackSyncWide`, whose track has offset 2540 and bpm 288 (Review Focus 4).

- [ ] **Step 1: The screen.** In `MetronomeScreen`, while `model.isSyncModeShown` the header and the track content give way to `SyncModeView`; remove the sheet. `SyncModeView` builds a `SyncModeLayout` and stacks per 6.13: its header (`Sync` 20 pt heavy, the file name 13 pt medium muted 2 pt below, `Done` 17 pt semibold amber at the right with a 44 × 44 touch area, calling `leaveSyncMode()`); then, in a scroll view that scrolls only when `scrollOverflow > 0`, the time signature row (16 pt), the tiles at `tileHeight` (14 pt), the pad at `padHeight` (14 pt), the steppers (14 pt), count-in (14 pt) and mix (10 pt); then, fixed at the bottom at least 16 pt below, the playback card and the bottom padding. Margins from the layout.
- [ ] **Step 2: The tap pad**: amber tint, 1.5 pt amber outline, 24 pt corners. A touch counts at touch-down: a `DragGesture(minimumDistance: 0)` with `@GestureState`, calling `tapDownbeat()` when the state turns true, as `StepButton` does, so a slide or the lift adds nothing. Centred, 6 pt apart: the hand icon (26 pt amber, only when `showsHandIcon`), `Tap on beat 1` (22 pt heavy) and the count line (14 pt medium muted, monospaced digits, hidden while the run is empty). Without the icon the two lines stand left-aligned 16 pt in, centred vertically. Start over: a 30 pt pill, 1 pt `#3A3423` outline, 14 pt sides, 13 pt semibold, 12 pt from the top and 14 pt from the right, a 44 × 44 touch area that wins over the pad's gesture, calling `startTapRunOver()`. While `!canTapDownbeat` the whole pad is at 40 %, Start over included; while the run is empty Start over alone is. `canTapDownbeat` is read from the engine, so poll it in a `TimelineView` while playing, as the old pill did.
- [ ] **Step 3: Tempo and Offset steppers**: the label (11 pt semibold capitals, wide tracking, muted), 6 pt, a 48 pt surface capsule with 4 pt padding holding `StepButton(size: 40, fill: Theme.surfaceRaised)` −, the value (22 pt heavy, monospaced digits, `minimumScaleFactor` so it never overlaps the buttons) and +. Tempo shows `loadedTrack.bpm` with no unit; Offset shows two decimals and `s` (12 pt semibold amber, 3 pt after). Each value is an adjustable element: "Tempo, 168 beats per minute" stepping 1 BPM, "Offset, 0.48 seconds" stepping 0.01 s.
- [ ] **Step 4: Count-in and mix**: the 76 pt label column; three 40 pt options with 14 pt corners on surface, 6 pt apart, the selected one `#3A3A40`, nothing amber, read as "Count-in, 2 bars" with "selected"; the 32 pt mix row with `Click` and `Track` (13 pt medium) and `MixSlider` with a 22 pt band, a 14 pt knob and a 44 × 44 touch area; its catch, tick and spoken values stay as they are.
- [ ] **Step 5: The playback card**: 136 pt, 28 pt corners, padding 12 top, 14 bottom, 16 sides; `TrackProgressBar`, 14 pt, a 56 pt row of five spread evenly: To the beginning (`backward.end`, 44 pt, no fill, `goToTrackStart()`), Rewind, play / stop (56 pt amber circle, no glow, ink play symbol or a 20 pt ink square with 5 pt corners, `togglePlayback()`), Fast-forward, To the end (`forward.end`, `goToTrackEnd()`). VoiceOver: "To the beginning", "To the end", "Start" / "Stop". Neither end button is ever dimmed.
- [ ] **Step 6: Accessibility and haptics** per 12 and 13: the title is a heading "Sync" followed by the file name; the pad a button "Tap on beat 1" with `spokenCountLine` as its value, dimmed while it does nothing; Start over "Start over", dimmed while the run is empty. Haptics come from the model; check that Done, Start over, To the beginning and To the end play none.
- [ ] **Step 7: Scenes.** `trackSync` enters Sync mode (Task 3). Add `trackSyncWide`: the `trackSync` setup with the track's offset 2540 and bpm 288.
- [ ] **Step 8: Run** `scripts/build.sh` and `scripts/test.sh`; all pass.
- [ ] **Step 9: See it in the simulator** on iPhone 17 Pro and iPhone SE, screenshots to `build/screens/`: `trackSync` stopped (pad dimmed, Start over dimmed, hand icon on the 17 Pro and not on the SE); Start at 0:00 counting in (pad dimmed until `Count-in` ends); a few taps on the pad while playing (count line, steppers changing, the click following); a slide on the pad counting once; Start over; − / + held on both steppers; To the beginning and To the end, stopped and playing; 9/8 chosen from the row (on the SE the area scrolls, by 23 pt); Done back to the track screen with playback carrying on. `trackSyncWide` on the SE: `288` and `25.40 s` fit between − and +. If the SE simulator offers Display Zoom, check 4/4 and 9/8 there; if not, that part stays covered by `syncModeWithDisplayZoom` alone. Fix differences.
- [ ] **Step 10: Section 14 and 15.** For each "Backing tracks" line this plan touches, tick it only when every claim is covered by a unit test named in Tasks 1 to 4 or was seen in Step 9 or Task 5 Step 7, and write the note to say which; lines needing ears, VoiceOver, touch areas measured, a real iPhone or two devices stay unticked with what was covered. Remove the three items of section 15 that are now built.
- [ ] **Step 11: Commit** with subject `Show Sync mode in place of the track screen`.

## Not in this plan

- The plain layout, the dial, the tempo sheet and the song sheet.
- Anything that needs a listener, VoiceOver, a real iPhone or two devices on one iCloud account.
