# Player Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Merge the plain layout and the track screen into one metronome screen: the same header, 264 pt dial, tempo controls, time signature row and tiles for every song, and a 188 pt player card at the bottom whose content is Metronome content (elapsed time, bar count, Previous / Start / Next) or Track content (today's player card without the next-up line); the header's Sound button and Backing tracks switch become look-alike toggles; while a track is in use the tempo controls set the track's tempo.

**Architecture:** The rules go into three pure types with their own tests: `MetronomeLayout` (the one layout's arithmetic, the small-screen steps and the centring), `PlayCount` (the elapsed time and bar count) and `HeaderToggle` (the toggles' states, icons and spoken labels). `MetronomeModel` routes the tempo controls to the tempo in effect, owns one `PlayCount` fed from `beatSounded` and the load / unload / start / stop paths, and says which content the player shows. The views stay thin: `MetronomeScreen` stacks the parts from `MetronomeLayout`, `PlayerCard` switches between `MetronomeContent` and `TrackContent`, and `TempoDial` is the only dial.

**Tech Stack:** Swift, SwiftUI, Swift Testing. Build with `scripts/build.sh`, test with `scripts/test.sh` (extra arguments go to xcodebuild, e.g. `scripts/test.sh -only-testing:MetronomeTests/PlayCountTests`). New files need no project edit: the project uses file-system synchronised groups.

**Spec:** `docs/specification.md`: the intro paragraph on the Paper page *Player with mode switch (draft)*, sections 4, 5 (Not kept, Edited), 6 (intro), 6.1 to 6.9, 6.11, 6.12, 6.13 (tiles stay 76 pt), 7.1, 7.2, 7.4 to 7.6, 7.10 to 7.13, 12, 13, 14, 15. Read them before each task; sizes, colours and copy are binding. The boards *Header switch — Metronome*, *Header switch — Track*, *Header switch — song without a track* and *Header toggles — same logic* draw the result; where they and the spec differ (the knob drawn as an overlay, the indicator further in, the card 30 pt above the edge, the controls centred below the dial's square, seven tiles 8 pt apart, the Sound button off-lit), the spec holds.

## Global Constraints

- Work only in `/Users/arime/metronome/.claude/worktrees/player-layout` on branch `player-layout`. Never switch branches, never push.
- Nothing new is kept or synced: `LibraryState`, `SongRecord`, `SetlistRecord`, `LibrarySync`, `SettingsStore` and the format number (2) do not change. The elapsed time and bar count are not kept between launches.
- UI copy exactly: `Start`, `Stop`, `0:00`, `1:02:07`, `Bar 1`. VoiceOver: `Click sound` / `Backing tracks` with value `on` / `off`; the readout `1 minute 24 seconds, bar 43`, `1 hour 2 minutes 7 seconds, bar 1240`; the dial stays `Tempo` with `120 beats per minute`. Terse UI copy: no hints, footnotes or helper lines on screen.
- Colours only from `Theme`; no new colour literals in views except the knob's shade, which lives in `DialRing` beside its existing knob colours.
- Sizes: header 48 pt (8 + 40); dial 264 pt at most, 4 pt below the header; number 92 pt on the 264 pt dial for every tempo; controls 60 / 16 / 60 / 16 / 68 pt (two rows of tiles 98 pt), compact 48 / 10 / 48 / 10 / 56 pt; knob's lower edge at 0.9 dial diameters; gaps around the controls equal, at least 16 pt (10 pt compact); player card 188 pt, corners 28, padding 12 top / 18 bottom / 16 sides; Track content rows 30 / 10 / 40 / 10 / 68; Metronome content readout 82 pt, 8 pt, transport 68 pt; elapsed 34 pt medium, tracking −0.02 em, monospaced digits, dial white, 26 pt from the card's edges; bar count 15 pt medium muted, monospaced digits; Start pill 68 pt, play icon 20 pt, 12 pt to `Start` 18 pt bold, glow amber 28 % radius 20; Previous / Next 44 pt, 12 pt from the pill; toggles 40 pt, 8 pt apart, icon 20 pt with 1.5 pt lines, on `Theme.surfaceSelected` + dial white, off `Theme.surface` + muted; side margins 24 pt, 16 pt below 360 pt width.
- Sync mode keeps its own layout (`SyncModeLayout`), with 76 pt tiles.
- Shell: single quotes, no `$(...)`, no backticks, no `cd` before git, no backslash line continuations. Read files with the Read tool.
- Commits: write the message to a file in the scratchpad named in your brief and run `git commit -F <file>`. Imperative, capitalised subject of at most 72 characters, no trailing period, no prefix such as 'feat:', no backticks, no attribution lines of any kind; a body only when the why is not obvious, wrapped at 72.
- `docs/specification.md` is one living document: no history wording ('now', 'previously', 'new', 'no longer'). Only the last task touches it, and only sections 14 and 15.
- Never read `.env.*` or `.appsettings.*` files, anything under `scripts/` named appstore or testflight, or any `.p8` file.

## Review Focus

1. **A dial turned while a track plays** sends a track-tempo change for every BPM passed: each must reach the engine without starting a bar, and the library must be written once after the turn, not once per step. Pinned in Task 3 (`aDialTurnWhilePlayingFollowsTheGridAndSavesOnce`).
2. **A song loaded while playing** starts a new bar, so a naive "beat 1 adds a bar" counts its first bar as bar 2. The count must start afresh at the next counted beat. Pinned in Task 2 (`restartCountsTheNextBeatAsBarOne`) and Task 3 (`loadingAnotherSongWhilePlayingCountsAfresh`).
3. **Count-in beats** look like any other beat to the model today; counted, they would put the readout one or two bars ahead and the time early. Pinned in Task 2 (`countInBeatsAreNotCounted`, `aBeatBeforeTheOffsetIsACountInBeat`).
4. **Tests and code that set the metronome's tempo while a track is in use** (`nudgeBPM` / `setBPM` with Backing tracks on) silently change meaning when the controls route to the track. Every such call must be found and rewritten to switch Backing tracks off first. Pinned in Task 3 (the four rewritten tests and `withBackingTracksOffTheDialSetsTheMetronomesTempo`).
5. **The smallest phone in 9/8 and 12/8** (320 × 568 with Display Zoom) gets a 64 pt dial; the layout must still fit to the point, never overflow into the card, and never give a negative gap. Pinned in Task 1 (`everythingFitsOnEveryPhone`, `displayZoomGetsASmallDial`).

---

### Task 1: The one layout's arithmetic

**Files:**
- Create: `Metronome/Views/MetronomeLayout.swift`
- Test: `MetronomeTests/MetronomeLayoutTests.swift` (new)

**Interfaces:**
- Consumes: `Theme.sideMargin`, `AccentTiles.twoRowTileHeight`, `AccentTiles.rowGap`.
- Produces (the old `ScreenLayout` stays until Task 5):
  - `struct MetronomeLayout: Equatable` with `let sideMargin, bottomPadding, dialDiameter, rowHeight, innerGap, tileHeight, controlsHeight, controlsGap: CGFloat` and `let isCompact: Bool`
  - `init(width: CGFloat, height: CGFloat, hasBottomInset: Bool, beats: Int)` (height inside the safe area)
  - `var dialFrameHeight: CGFloat { 0.9 * dialDiameter }`: the dial's height down to the knob's lower edge, the frame the screen stacks it in.
  - `static let headerHeight: CGFloat = 48`, `dialTopGap = 4`, `playerCardHeight = 188`, `maximumDial = 264`, `roomyMinimumDial = 200`, `minimumDial = 40`, `roomyGap = 16`, `compactGap = 10`, `narrowWidth = 360`, `narrowSideMargin = 16`.

Rule (6.8): `available = height − bottomPadding` (16 without a home indicator); fixed = 48 + 4 + 188. Roomy controls: rows 60, inner gaps 16, single-row tiles 68 (220 pt, or 250 with two rows). Roomy when `(available − fixed − controls − 2 × 16) / 0.9 ≥ 200`; then `dial = min(264, that)`. Otherwise compact: rows 48, inner gaps 10, tiles 56 (172 / 214 pt), `dial = min(264, max(40, (available − fixed − controls − 2 × 10) / 0.9))`. The dial is rounded down to whole points; `controlsGap = (available − fixed − 0.9 × dial − controls) / 2`.

- [ ] **Step 1: Write the failing tests**

```swift
struct MetronomeLayoutTests {
    // layout(width:height:inset:beats:) helper; fits(_:in:) = 48 + 4 + dialFrameHeight + 2 * controlsGap
    //   + controlsHeight + 188 + bottomPadding <= height + 0.001
    @Test func theDesignPhoneGetsTheFullDialAndEvenGaps()
    // (390, 763, true, 4): dial 264, !isCompact, rowHeight 60, innerGap 16, tileHeight 68,
    // controlsHeight 220, abs(controlsGap - 32.7) < 0.01
    @Test func anIPhone17ProSpendsTheSpareHeightOnTheGaps()
    // (402, 778, true, 4): dial 264, abs(gap - 40.2) < 0.01; beats 12: controlsHeight 250, abs(gap - 25.2) < 0.01
    @Test func theGapsShrinkTo16BeforeTheDial()
    // (390, 729.6, true, 4): dial 264, abs(gap - 16) < 0.01; (390, 719.6, true, 4): dial 252, gap >= 16
    @Test func theDialShrinksTo200BeforeTheControlsTurnCompact()
    // (390, 672, true, 4): dial 200, !isCompact; (390, 671, true, 4): isCompact
    @Test func anIPhoneSEIsCompact()
    // (375, 647, false, 4): bottomPadding 16, isCompact, rowHeight 48, innerGap 10, tileHeight 56,
    // controlsHeight 172, dial 221, gap >= 10; beats 12: controlsHeight 214, dial 174
    @Test func displayZoomGetsASmallDial()
    // (320, 548, false, 4): sideMargin 16, dial 111; beats 12: dial 64, controlsGap >= 10
    @Test func everythingFitsOnEveryPhone()
    // widths [320, 375, 390, 402, 440], heights stride(450, through: 960, by: 5), beats [2, 4, 7, 9, 12],
    // inset true and false: fits; dial <= 264; dial == dial.rounded(.down);
    // controlsGap >= (isCompact ? 10 : 16) - 0.001 whenever dial > 40
    @Test func theDialNeverCollapses()                 // (375, 300, false, 4).dialDiameter == 40
    @Test func sideMarginsNarrowBelow360()             // 320 -> 16, 359 -> 16, 360 -> 24, 402 -> 24
}
```

- [ ] **Step 2: Run them and see them fail to compile**

Run: `scripts/test.sh -only-testing:MetronomeTests/MetronomeLayoutTests`
Expected: build error for `MetronomeLayout`.

- [ ] **Step 3: Write `MetronomeLayout`**

- [ ] **Step 4: Run the whole suite**

Run: `scripts/test.sh`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

Subject `Add the metronome screen's one layout as a pure type`.

---

### Task 2: The elapsed time and bar count, as a pure type

**Files:**
- Create: `Metronome/Model/PlayCount.swift`
- Modify: `Metronome/Model/BeatClock.swift` (`ScheduledBeat`), `Metronome/Model/TrackBeatClock.swift`
- Test: `MetronomeTests/PlayCountTests.swift` (new), `MetronomeTests/TrackBeatClockTests.swift`

**Interfaces:**
- Consumes: `ScheduledBeat`, `TrackTime.spoken(_:)` (for minutes and seconds).
- Produces:
  - `ScheduledBeat` gains `let isCountIn: Bool` with `init(beat:isAccented:sampleTime:isCountIn: Bool = false)`, so every existing call compiles. `TrackBeatClock.beats(...)` sets it to `index < 0`.
  - `struct PlayCount: Equatable` with `private(set) var bar: Int` (1 at first), `mutating func restart()`, `mutating func count(_ beat: ScheduledBeat, at uptime: TimeInterval)`, `mutating func stop(at uptime: TimeInterval)`, `func elapsed(at uptime: TimeInterval) -> TimeInterval`, `func readout(at uptime: TimeInterval) -> PlayReadout`, `static func timeLabel(_ seconds: TimeInterval) -> String`, `static func barLabel(_ bar: Int) -> String`, `static func spoken(_ seconds: TimeInterval, bar: Int) -> String`.
  - `struct PlayReadout: Equatable { let time: String; let bar: String; let spoken: String }`.
  - `#if DEBUG` `init(runningSince firstBeat: TimeInterval, bar: Int)` for the screenshot scene (Task 7).

Rules (7.13): `restart()` goes to 0 and bar 1 and waits for the next counted beat; count-in beats are ignored; the first counted beat after a restart (or on a fresh value) records its uptime and is bar 1 whatever its beat number; after that every `beat == 1` adds a bar; `stop(at:)` freezes the elapsed time; before the first counted beat the time is 0. Labels: whole seconds rounded down, negatives 0; `m:ss` below an hour, `h:mm:ss` from 3600 s.

- [ ] **Step 1: Write the failing tests**

```swift
struct PlayCountTests {
    // b(_ n: Int, countIn: Bool = false) -> ScheduledBeat
    @Test func startsAtZeroAndBarOne()             // PlayCount(): elapsed(at: 100) == 0, bar == 1, readout time "0:00", bar "Bar 1"
    @Test func theTimeRunsFromTheFirstCountedBeat() // count(b(1), at: 10); elapsed(at: 94.9) == 84.9; readout(at: 94.9).time == "1:24"
    @Test func everyBeatOneAfterTheFirstCountsABar() // 1,2,3,4,1,2 -> bar 2; then 1 -> bar 3
    @Test func aBarCutShortStillCounts()           // 1,2,1 -> bar 2
    @Test func aStartMidBarMakesThatBarOne()       // 3,4 -> bar 1; then 1 -> bar 2
    @Test func countInBeatsAreNotCounted()
    // b(1..4, countIn: true) at 0, 0.5, 1, 1.5 -> elapsed(at: 2) == 0, bar 1; b(1) at 2 -> elapsed(at: 3) == 1, bar 1
    @Test func stopKeepsTheTimeAndTheBar()         // first beat at 10, a bar to 2, stop(at: 50) -> elapsed(at: 500) == 40, bar 2
    @Test func restartCountsTheNextBeatAsBarOne()
    // bar 3 playing; restart() -> elapsed 0, bar 1; count(b(1), at: 200) -> bar 1, elapsed(at: 201) == 1
    @Test func theTimeIsShownAsMinutesThenHours()
    // timeLabel(0) "0:00"; 3599.9 "59:59"; 3600 "1:00:00"; 3727 "1:02:07"; -5 "0:00"
    @Test func theBarReadsBarAndItsNumber()        // barLabel(1) "Bar 1"; barLabel(128) "Bar 128"
    @Test func theReadoutIsSpokenWithTheBar()
    // spoken(84, bar: 43) "1 minute 24 seconds, bar 43"; spoken(3727, bar: 1240) "1 hour 2 minutes 7 seconds, bar 1240";
    // spoken(0, bar: 1) "0 seconds, bar 1"; spoken(3600, bar: 2) "1 hour, bar 2"
}
// In TrackBeatClockTests:
@Test func aBeatBeforeTheOffsetIsACountInBeat()
// a clock with firstClickIndex -8: the first eight beats returned have isCountIn true, the ninth false
```

- [ ] **Step 2: Run them and see them fail**

Run: `scripts/test.sh -only-testing:MetronomeTests/PlayCountTests -only-testing:MetronomeTests/TrackBeatClockTests`
Expected: build errors for `PlayCount` and `isCountIn`.

- [ ] **Step 3: Add `isCountIn`, set it in `TrackBeatClock`, write `PlayCount`**

- [ ] **Step 4: Run the whole suite**

Run: `scripts/test.sh`
Expected: `** TEST SUCCEEDED **`; the engine and clock tests pass unchanged.

- [ ] **Step 5: Commit**

Subject `Count the time and the bars played since Start`.

---

### Task 3: The model: tempo controls on the tempo in effect, the readout, the player's content

**Files:**
- Modify: `Metronome/MetronomeModel.swift` (`// MARK: - Tempo`, `beatSounded`, `start`, `becomeStopped`, `load`, `saveAsNewSong`, `createSong`, `unloadSong`, `deleteWithoutSaving`, `exchangeWithCloud`, init)
- Test: `MetronomeTests/PlayerModelTests.swift` (new), `MetronomeTests/TrackTempoModelTests.swift`, `MetronomeTests/SyncModeModelTests.swift`, `MetronomeTests/SongModelTests.swift`

**Interfaces:**
- Consumes: Task 2's `PlayCount`, `PlayReadout`, `ScheduledBeat.isCountIn`.
- Produces on `MetronomeModel`:
  - init parameter `uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }`, last in the list.
  - `setBPM(_:)`, `nudgeBPM(by:)` and `tapTempo(at:)` act on the tempo in effect: while `isTrackInUse` they set the track's tempo through `applyTrackTempo` (the plain screen keeps its own `taps` series; `nudgeBPM` steps from `tempoInEffect`); otherwise unchanged. Ticks as today.
  - `enum PlayerContent: Equatable { case metronome, track }` (in `MetronomeModel.swift`) and `var playerContent: PlayerContent { isTrackInUse ? .track : .metronome }`.
  - `private(set) var playCount = PlayCount()` and `func readout() -> PlayReadout` (= `playCount.readout(at: uptime())`).
  - `#if DEBUG func showPlayCount(_ count: PlayCount)` for Task 7's scene.
  - `nextSong` is removed with its tests (`nextSongIsTheOneNextWouldLoad`); the view that reads it goes in Task 5, so keep the property until then only if the build needs it, and remove it there.

Wiring: `start()` calls `playCount.restart()` before the engine starts; `beatSounded` calls `playCount.count(beat, at: uptime())` after its `isPlaying` guard; `becomeStopped()` calls `playCount.stop(at: uptime())`; every place the loaded song's ID changes to another value or to nil (`load` when `isAnotherSong`, `saveAsNewSong`, `createSong` naming the settings, `unloadSong`, a deleted loaded song in `deleteWithoutSaving` and in `exchangeWithCloud`) calls `playCount.restart()`. Decision: one private `loadedSongChanged()` helper holds that call, so later paths cannot miss it.

- [ ] **Step 1: Rewrite the tests that set the metronome's tempo while a track is in use**

Run `grep -rn -E 'setBPM|nudgeBPM|tapTempo\(' MetronomeTests` and read each hit's model setup. Known ones: `anUnsavedMetronomeTempoIsNotEditedWhileTheTrackIsInUse`, `saveWritesTheMetronomesTempoToo`, `revertSetsBackTheMetronomesTempoAndLeavesTheTracks` (TrackTempoModelTests), `syncModeSavesAnEarlierAccentAndLeavesTheMetronomeTempo` (SyncModeModelTests) and `saveAsNewSongHasNoTrackAndStopsAPlayingTrack` (TrackSongModelTests, check whether it needs the metronome's tempo). Each sets the metronome's tempo with Backing tracks switched off (`toggleBackingTracks()` while stopped, nudge, switch on again) and keeps its assertions.

- [ ] **Step 2: Write the failing tests**

In `TrackTempoModelTests` (its `makeModel()` has a track at 90 on a song at 120):

```swift
@Test func theDialSetsTheTracksTempoWhileATrackIsInUse()
// setBPM(100): loadedTrack?.bpm == 100, settings.bpm == 120, tempoInEffect == 100, isSaveOffered == false,
// haptics.selectionCount == 1
@Test func minusAndPlusStepTheTracksTempo()        // nudgeBPM(by: 5): loadedTrack?.bpm == 95, settings.bpm == 120
@Test func tapTempoSetsTheTracksTempo()             // tapTempo(at: 0), tapTempo(at: 0.5): loadedTrack?.bpm == 120, settings.bpm == 120
@Test func theTracksTempoStaysInRange()             // setBPM(400): loadedTrack?.bpm == 300
@Test func aDialTurnWhilePlayingFollowsTheGridAndSavesOnce()
// bench model, play; setBPM(91...110 one by one); engine.lastUpdate?.bpm == 110, lastUpdateStartedNewBar == false;
// await bench.waitForASave(after:) -> exactly one more library write; the saved song's track bpm == 110
@Test func saveAndRevertLeaveATempoSetFromTheDial()
// setBPM(100), toggleAccent(beat: 2), discardChanges(): loadedTrack?.bpm == 100; same with saveChanges(): saved settings.bpm == 120
@Test func withTheFileMissingTheDialSetsTheTracksTempo() // missing: true; setBPM(100) -> loadedTrack?.bpm == 100
@Test func withBackingTracksOffTheDialSetsTheMetronomesTempo()
// toggleBackingTracks(); setBPM(100) -> settings.bpm == 100, loadedTrack?.bpm == 90, isEdited
@Test func aTimeSignatureWhileATrackIsInUseMakesTheSongEdited()
// selectTimeSignature(.threeFour): isEdited, isSaveOffered, saved song still .fourFour; saveChanges() -> saved .threeFour
@Test func thePlayerShowsTheTrackOnlyWhileATrackIsInUse()
// playerContent == .track; toggleBackingTracks() -> .metronome; toggle again, unloadSong() -> .metronome
```

In `PlayerModelTests` (`@MainActor struct`; `FakeClickEngine`, `FakeHaptics`, an `Uptime` class the test moves by hand; songs as in `SongModelTests.modelWithSetlist()`):

```swift
@Test func startSetsTheReadoutToZero()       // after a run at bar 3, togglePlayback twice -> readout() == "0:00", "Bar 1"
@Test func theReadoutRunsWithTheBeats()      // start; onBeat(1) at 10; uptime 94 -> "1:24"; beats 2,3,4,1 -> "Bar 2"
@Test func stopKeepsTheReadout()             // ... togglePlayback(); uptime 500 -> still "1:24", "Bar 2"
@Test func theEngineStoppingKeepsTheReadout() // engine.onStopped?() then same as above
@Test func loadingAnotherSongWhilePlayingCountsAfresh()
// at "Bar 3", loadSong(other); readout "0:00", "Bar 1"; onBeat(1) at 50, uptime 52 -> "0:02", "Bar 1"
@Test func unloadWhilePlayingCountsAfreshFromTheNextBeat()
// at bar 3, unloadSong(); onBeat(3) -> "Bar 1"; onBeat(4), onBeat(1) -> "Bar 2"
@Test func tappingTheLoadedSongsRowChangesNothing() // loadSong(loaded, from: same) -> readout unchanged
@Test func switchesAndMuteLeaveTheReadout()  // stopped at "Bar 2": toggleBackingTracks(), toggleMute() -> unchanged
@Test func aCountInIsNotCounted()            // onBeat(ScheduledBeat(..., isCountIn: true)) x4 -> "0:00", "Bar 1"
@Test func theReadoutIsNotKept()             // a second model on the same stores -> "0:00", "Bar 1"
@Test func theReadoutIsSpoken()              // at 84 s and bar 43 -> readout().spoken == "1 minute 24 seconds, bar 43"
```

- [ ] **Step 3: Run them and see them fail**

Run: `scripts/test.sh -only-testing:MetronomeTests/PlayerModelTests -only-testing:MetronomeTests/TrackTempoModelTests`
Expected: build errors for `readout`, `playerContent` and `uptime:`; the routing tests fail.

- [ ] **Step 4: Implement the routing, `PlayerContent`, the `PlayCount` wiring and `loadedSongChanged()`**

- [ ] **Step 5: Run the whole suite**

Run: `scripts/test.sh`
Expected: `** TEST SUCCEEDED **`. A failure in a suite not listed above that sets the tempo while a track is in use is fixed as in Step 1, never by weakening the routing.

- [ ] **Step 6: Commit**

Subject `Set the track's tempo from the dial and count the time and bars`. Body: while a track is in use the dial, - / +, tap tempo and the tempo sheet set the tempo the dial shows, the track's, saved at once as Sync mode does; the tests that made an unsaved metronome tempo with a track in use switch Backing tracks off to make it.

---

### Task 4: One dial for every mode

**Files:**
- Modify: `Metronome/Model/Tempo.swift` (`DialGeometry`), `Metronome/Views/TempoDial.swift`, `Metronome/Views/TrackScreen.swift` (uses `TempoDial` in place of `TrackDial`), `Metronome/Views/AccentTiles.swift` (number size)
- Test: `MetronomeTests/TempoTests.swift`

**Interfaces:**
- Consumes: `model.tempoInEffect`, `model.setBPM(_:)` (Task 3).
- Produces:
  - `DialGeometry.designDial = 264.0`, `DialGeometry.designNumberSize = 92.0`; `numberSize(bpm:dialDiameter:)` returns `92 × d / 264` for every tempo (the `bpm` parameter stays, unused, or is dropped with its call sites; implementer's choice).
  - `DialRing(fraction:)` has no `style`; `TrackDial` is deleted.
  - `TempoDial` reads and sets `model.tempoInEffect` everywhere it read `settings.bpm` (ring, glow, number, drag start, VoiceOver value, the tempo sheet's `current:`).
  - `BeatTile.numberSize`: 28 for `height >= 60`, 22 below, 20 on two rows.

Knob (6.2), drawn in the canvas's 300 pt space after the face and before the pointer: fill the knob circle with a radial gradient centred at 35 % across and 28 % down the knob's square, from black at 0.18 to black at 0.50 at a radius of 1.94 × knob radius; a 1 pt white-at-10 % highlight along the top inside edge; an inner shadow along the lower edge, black at 35 %, offset 10 and blur 18 on the 264 pt dial (× 300 / 264 in canvas units; `GraphicsContext.Filter.shadow` with `.invertsAlpha` inside a clip to the knob is the usual way). The outer shadow and the ridges stay as they are; the ridges end up under the shade, which gives the 5 % to 16 % of the spec. The pointer is drawn over the shade at full amber.

- [ ] **Step 1: Replace the number tests**

```swift
@Test func theDialNumberIs92ForEveryTempo()  // numberSize(bpm: 99 / 100 / 300, dialDiameter: 264) == 92
@Test func theDialNumberScalesWithTheDial()  // numberSize(bpm: 120, dialDiameter: 132) == 46; (60, 221) ≈ 77.015 (abs < 0.001)
```

Delete `theDialNumberIs114AndSmallerForThreeDigits`.

- [ ] **Step 2: Run them and see them fail**

Run: `scripts/test.sh -only-testing:MetronomeTests/TempoTests`
Expected: the two tests fail on 114-based values.

- [ ] **Step 3: Change `DialGeometry`, `DialNumber`'s frame height, `DialRing`, `TempoDial` and the tile number; delete `TrackDial`**

- [ ] **Step 4: Build and run the suite**

Run: `scripts/build.sh` then `scripts/test.sh`
Expected: `** BUILD SUCCEEDED **`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Look at it in the simulator**

On the iPhone 17 Pro simulator (UDID 5C51A102-4BAD-43B4-AEC8-9A5FC809A997) with `-screenshotScene edited` and `-screenshotScene trackScreen`: the knob darker, lit from the upper left, ridges visible, pointer bright amber, compared side by side with screenshots of the boards *Header switch — Metronome* and *Header switch — Track* (Paper file `01M7103E2WQFE2APCWJ6VE4EZN`, page `p-E-0`); the dial turns on the track song and the number follows. Number clear of the pointer at 75, 120, 255 and 300. Report what was and was not seen. The layout itself is still the old one at this task.

- [ ] **Step 6: Commit**

Subject `Draw one darker dial for every song and let it turn with a track`.

---

### Task 5: The one layout and the player card

**Files:**
- Modify: `Metronome/Views/MetronomeScreen.swift` (one stack; delete `NextUpLine`, `ScreenLayout`), `Metronome/Views/TrackControls.swift` (`PlayerCard` becomes the 188 pt container; its current body becomes `TrackContent`; `SongStepButton` becomes internal), `Metronome/Views/StartStopButton.swift` (the pill of 6.7), `Metronome/Views/SongTitle.swift` (delete `FooterRoundButton`), `Metronome/Views/TrackLayouts.swift` (delete `TrackScreenLayout`; `SyncModeLayout` uses `MetronomeLayout.narrowWidth` / `narrowSideMargin`), `Metronome/Views/StageModeView.swift` (same constants), `Metronome/MetronomeModel.swift` (delete `nextSong`)
- Create: `Metronome/Views/MetronomeContent.swift` (`MetronomeContent`, `PlayReadoutView`)
- Delete: `Metronome/Views/TrackScreen.swift`
- Test: delete `MetronomeTests/ScreenLayoutTests.swift`; in `MetronomeTests/TrackLayoutTests.swift` delete the track-screen tests (`theTrackScreen…`, `theSpareHeight…`, `theCardAlwaysHas…`) and keep the Sync mode ones; delete `nextSongIsTheOneNextWouldLoad` and any other `nextSong` test.

**Interfaces:**
- Consumes: `MetronomeLayout` (Task 1), `model.readout()`, `model.playerContent` (Task 3), `TempoDial` (Task 4).
- Produces:
  - `struct PlayerCard: View` (no parameters): surface, corners 28, height `MetronomeLayout.playerCardHeight`, padding 12 / 18 / 16; content `model.playerContent == .track ? TrackContent() : MetronomeContent()`.
  - `struct TrackContent: View`: today's rows with 10 pt spacing and no next-up line.
  - `struct MetronomeContent: View`: `PlayReadoutView` in the 82 pt above, 8 pt, the transport row: `SongStepButton(backward.end)`, 12, `StartStopButton()` taking the width, 12, `SongStepButton(forward.end)`; outside a setlist the two places are `Color.clear` 44 × 44, so the pill keeps its width.
  - `struct PlayReadoutView: View`: `TimelineView(.animation(minimumInterval: 0.25, paused: !model.isPlaying))` reading `model.readout()`; time left and bar right, 10 pt inside the card's padding; one accessibility element with `readout.spoken`.

Screen stack (6, 6.8), inside a `GeometryReader` with `MetronomeLayout(width:height:hasBottomInset:beats:)`: header (top padding 8, 40 tall); 4 pt; `TempoDial(diameter:)` in `.frame(height: layout.dialFrameHeight, alignment: .top)` so the square overflows downwards without taking room; `layout.controlsGap`; the controls (`TempoControls` at `layout.rowHeight`, `layout.innerGap`, `TimeSignatureRow` at `layout.rowHeight`, `layout.innerGap`, `AccentTiles(singleRowTileHeight: layout.tileHeight)`); `Spacer(minLength: layout.controlsGap)`; `PlayerCard()`; bottom padding `layout.bottomPadding`. `TempoControls` and `TimeSignatureRow` take a `height` (default 60) for the compact step; the round buttons follow it.

- [ ] **Step 1: Delete the tests of the deleted types**

- [ ] **Step 2: Build the views and delete the old ones**

- [ ] **Step 3: Build and run the suite**

Run: `scripts/build.sh` then `scripts/test.sh`
Expected: `** BUILD SUCCEEDED **`, `** TEST SUCCEEDED **`; `grep -rn -E 'NextUpLine|nextSong|TrackScreenLayout|ScreenLayout\b|TrackDial|FooterRoundButton' Metronome MetronomeTests` finds nothing.

- [ ] **Step 4: Look at it in the simulator**

On the iPhone 17 Pro with `-screenshotScene edited`, `trackScreen`, `trackSolo`, `trackMissing`, `trackFirst`, `trackLast` and `playing`, and on an iPhone SE (3rd generation): against the three *Header switch* boards, measure on screenshots (3 px per pt) the dial's square (264 pt), the equal gaps from the knob's lower edge to the tempo controls and from the tiles to the card (40.2 pt on the 17 Pro in 4/4, 25.2 in 9/8; on the SE 221 pt dial, gaps ≈ 10), the card's 188 pt and its place at the safe area's bottom, the readout's places, the Start pill 210 pt wide on the 402 pt wide 17 Pro (402 − 48 − 32 − 112; 198 pt on the 390 pt design), Previous / Next ends, the outside-a-setlist pill keeping its width; switching Backing tracks with the header button changes only the card and the dial's number, nothing moves; Start shows Stop, the readout runs (with the real engine the simulator may not play: use `trackSyncTimer`-style timer scenes or `playing`), Stop keeps it; the Sync pill opens Sync mode and a tap on the dial opens the tempo sheet. Report what was and was not seen.

- [ ] **Step 5: Commit**

Subject `Show every song in one layout with the player card at the bottom`.

---

### Task 6: The header toggles

**Files:**
- Create: `Metronome/Views/HeaderToggle.swift` (`HeaderToggle`, `HeaderToggleIcon` shapes, `HeaderToggleButton` view)
- Modify: `Metronome/Views/MuteButton.swift`, `Metronome/Views/TrackSwitchButton.swift` (both become thin users of `HeaderToggleButton`; rename `MuteButton` to `SoundButton` with its call site)
- Test: `MetronomeTests/HeaderToggleTests.swift` (new)

**Interfaces:**
- Consumes: `model.isMuted`, `model.backingTracksOn`, `model.isPlaying`, `toggleMute()`, `toggleBackingTracks()`.
- Produces:
  - `struct HeaderToggle: Equatable { enum Icon: Equatable { case speakerWithWaves, speakerWithCross, note, noteWithSlash }; let label: String; let isOn: Bool; let isDimmed: Bool; var icon: Icon; var accessibilityValue: String }`
  - `static func sound(isMuted: Bool) -> HeaderToggle`, `static func backingTracks(isOn: Bool, isPlaying: Bool) -> HeaderToggle`
  - `struct HeaderToggleButton: View { let toggle: HeaderToggle; let action: () -> Void }`: 40 pt circle, on `Theme.surfaceSelected` + `Theme.dialWhite`, off `Theme.surface` + `Theme.muted`, opacity 0.4 and no hit testing when dimmed, touch area inset −2, label and value for VoiceOver.

Icons: drawn as `Shape`s in a 24 pt grid stroked at 1.8 grid units (1.5 pt at 20 pt), round caps and joins, from the board's paths: speaker `M11 5 6 9H2v6h4l5 4V5z`; waves `M15.5 8.5a5 5 0 0 1 0 7`, `M19 5a10 10 0 0 1 0 14`; cross `M16 9l6 6M22 9l-6 6`; note `M9 18V5l11-2v13` with circles at (6, 18) and (17, 16), radius 3; slash `M3 3l18 18`, drawn after a 5-unit stroke of the button's fill along the same line to cut the gap. Decision: shapes, not SF Symbols, because no symbol pairs a note with a slash and the board's speaker with a cross matches no symbol exactly.

- [ ] **Step 1: Write the failing tests**

```swift
struct HeaderToggleTests {
    @Test func soundOnIsLitWithWaves()         // .sound(isMuted: false): isOn, icon .speakerWithWaves, label "Click sound", value "on", !isDimmed
    @Test func soundOffShowsTheCross()         // .sound(isMuted: true): !isOn, .speakerWithCross, value "off"
    @Test func backingTracksReadsLikeSound()   // .backingTracks(isOn: true, isPlaying: false): label "Backing tracks", value "on", .note
    @Test func backingTracksOffShowsTheSlash() // (false, false): .noteWithSlash, value "off"
    @Test func backingTracksIsDimmedWhilePlaying() // (true, true).isDimmed; (false, true).isDimmed; sound never dimmed
}
```

- [ ] **Step 2: Run them and see them fail**

Run: `scripts/test.sh -only-testing:MetronomeTests/HeaderToggleTests`
Expected: build error for `HeaderToggle`.

- [ ] **Step 3: Write the type, the shapes and the button; switch the two header buttons to it**

- [ ] **Step 4: Build and run the suite**

Run: `scripts/build.sh` then `scripts/test.sh`
Expected: `** BUILD SUCCEEDED **`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Look at it in the simulator**

On the iPhone 17 Pro with `-screenshotScene trackScreen`: the four combinations of *Header toggles — same logic* (tap each toggle), zoomed against the board; the switch dimmed while playing; nothing amber in the header but the badge (`-screenshotScene edited`). Report what was and was not seen.

- [ ] **Step 6: Commit**

Subject `Draw the Sound button and the Backing tracks switch as toggles`.

---

### Task 7: Screenshot scenes and the final look

**Files:**
- Modify: `Metronome/Screenshots/ScreenshotScene.swift`

**Interfaces:**
- Consumes: `MetronomeModel.showPlayCount(_:)`, `PlayCount(runningSince:bar:)` (Tasks 2, 3).
- Produces: the App Store `playing` scene shows a running readout: elapsed 134 s and the bar that fits the loaded song (`1 + Int(134 × bpm / 60) / beatsPerBar`), seeded after `togglePlayback()`. A scene `metronomeSolo` (not an App Store screenshot): the `edited` song loaded on its own, stopped, for the pill without Previous and Next.

Found while planning: `scripts/screenshots.sh` takes the scenes `playing library setlist timeSignature settings`; `playing` and `timeSignature` show the metronome screen, so those App Store screenshots change and must be taken again with the script; the script itself needs no change. The scene clocks are fixed (`now: { Self.date }`), which is why the readout needs the seed. The track scenes keep their names; `trackFirst` and `trackLast` still check Previous and Next at the ends. The App Store listing files are local and are not read here.

- [ ] **Step 1: Add the seed and the scene**

- [ ] **Step 2: Build and run the suite**

Run: `scripts/build.sh` then `scripts/test.sh`
Expected: `** BUILD SUCCEEDED **`, `** TEST SUCCEEDED **`.

- [ ] **Step 3: Look at the whole screen against the boards**

On the iPhone 17 Pro and an iPhone SE (3rd generation), and with Display Zoom if a simulator offers it: `playing`, `metronomeSolo`, `edited` in 7/8, `trackScreen`, `trackMissing`, a song switched to 12/8; compare with the three *Header switch* boards (exported with `get_screenshot`); the readout reading `2:14`-style time with a plausible bar; VoiceOver labels with the Accessibility Inspector if available. Run `scripts/screenshots.sh` and look at `screenshots/1-playing.png` and `screenshots/4-timeSignature.png`. Report what was and was not seen.

- [ ] **Step 4: Commit**

Subject `Show a running time in the playing screenshot scene`.

---

### Task 8: Sections 14 and 15

**Files:**
- Modify: `docs/specification.md` (sections 14 and 15 only)

- [ ] **Step 1: Update the lines marked *(Not built yet.)* in section 14**

The Metronome group's new lines (layout, sizes, toggles and their VoiceOver, Metronome content, the readout, no next-up line), the dial and small-screen lines, the Previous / Next line in Settings and click sounds, and the Backing tracks group's Track content, tempo-controls, time signature, Sync pill, beat-effect and switch lines. Tick a line only when a unit test covers it or it was seen in the simulator (Tasks 1 to 7's reports), and replace the note with the test names and what was seen, and what was not (VoiceOver, a real iPhone, Display Zoom). Split a line when only part of it is verified.

- [ ] **Step 2: Update section 15**

Drop the entry once every part of it is built. With no entry left, the first line is followed by `Every part specified above is built.`

- [ ] **Step 3: Check the wording**

Run: `git diff -U0 -- docs/specification.md`
Expected: no history wording ('now', 'previously', 'no longer', 'new' for a change), and only sections 14 and 15 changed.

- [ ] **Step 4: Commit**

Subject `Record what was verified of the one layout`.

---

## Self-review notes

- Spec 6 intro, 6.8: Task 1 (rules) and Task 5 (stack). 6.1, 6.9, 13 toggles: Task 6. 6.2, 6.5 numbers: Task 4. 6.3, 6.4 compact rows: Task 5. 6.7, 6.12: Task 5. 6.11 from the dial: Task 4 (`current:` is the tempo in effect) and Task 3 (`setBPM` routes). 7.1, 7.2, 7.10 tempo controls: Task 3. 7.11 Sync pill only: Task 5 (the dial no longer opens Sync mode; `enterSyncMode()` stays for the pill). 7.13 and 5 Not kept: Tasks 2 and 3. 12 beat effects: Task 4 (one dial with glow and pulse). 13 readout and dial labels: Tasks 4, 5, 6. 14, 15: Task 8.
- The time signature row while a track is in use needs no model change: `meterChanged()` already makes it edited outside Sync mode; Task 3 pins it.
- `loadSong`'s selection tick, stage mode and Sync mode's own layout are untouched.
- Known risks: the inner shadow in `GraphicsContext` (Task 4) may need a second clipped layer; the 64 pt dial on Display Zoom in 12/8 is small by design of 6.8; the toggles' custom shapes must match the board at 3 px per pt.
