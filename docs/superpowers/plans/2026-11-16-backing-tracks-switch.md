# Backing Tracks Switch and Player Card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make backing tracks an app-wide mode switched from the header, replace the track strip and Start row with one player card, and save a tempo set in the Sync sheet into the song.

**Architecture:** The model gains one stored flag, `backingTracksOn`, kept by `SettingsStore`. `isTrackPlayable` and `isTrackMissing` are narrowed to "the track is in use", so every existing stop rule, layout test and view follows the switch without its own check. The Sync sheet calls two new tempo methods that write the song's tempo part and use the existing deferred save. `ScreenLayout` swaps the strip and the Start row for the card's height; the views swap `TrackStrip` and the footer for `PlayerCard`.

**Tech Stack:** Swift 6, SwiftUI, Observation, Swift Testing. Build with `scripts/build.sh`, test with `scripts/test.sh`.

**Spec:** `docs/specification.md` — sections 4, 5, 5.1, 6.1, 6.12, 6.13, 7.6, 7.9, 7.10, 7.11, 7.12, 12, 13 and the "Backing tracks" group of section 14. The spec is the authority; where this plan and the spec disagree, the spec wins.

## Global Constraints

- The spec is one living document with no history: no "now", "new", "previously", dates, or references to tasks, reviews or agents. The same goes for code comments.
- Terms: "a track is in use" = Backing tracks is on and the loaded song has a backing track (file here or missing). "Playable" = the file is on this device.
- No new visible strings. VoiceOver: the switch reads `Backing tracks, on` / `Backing tracks, off`; the card's buttons read `Start` / `Stop`, `Previous song`, `Next song`, and Rewind / Fast-forward keep their labels.
- The plain layout (switch off, or a song without a track) must stay exactly as it is: every existing `ScreenLayoutTests` figure for `hasTrack: false` must still pass unchanged.
- The switch is never amber. On: circle `#3A3A40`, cream note. Off: circle as the mute button, cream note.
- No new compiler warnings. `scripts/build.sh` and the full `scripts/test.sh` pass at the end of every task.
- Tests build models through `TrackTestBench` or the shared temporary-store helper; never the default `TrackFileStore()`.
- Commits: imperative subject, capitalised, no trailing period, at most 72 characters, body wrapped at 72 saying why, no Conventional Commits prefix, no backticks, no attribution lines. Write the message to a scratch file and commit with `git commit -F`.
- Shell: single quotes, no `cd` before git, no `git -C`, no `$(...)`, no backslash line continuations.
- Do not read `.env.*` or `.appsettings.*` files.
- Section 14 of the spec: a line is ticked only when every claim in it is covered by a named unit test or was seen in the simulator; otherwise it stays unticked with a note saying which part is covered.

## Review Focus

1. The switch tapped while playing: nothing changes, no haptic. (Task 1)
2. Switch off, song with a playable track: Start has no count-in, the engine is started without a track, loading it while another song plays does not stop playback. (Task 1)
3. Switch turned off and on again after stopping at 1:10: the position is still 1:10; after loading another song it is 0:00. (Task 1)
4. Relaunch with the switch off: still off, and the loaded song with a track is plain. (Task 1)
5. Sync sheet tempo changed while the time signature already differs from the song: the tempo part is saved, the song is still edited and the Save button stays. (Task 2)
6. Sync sheet tempo changed when the tempo already differed and was the only difference: the song is no longer edited and the Save button goes at once. (Task 2)

---

### Task 1: The switch in the model

**Files:**
- Modify: `Metronome/Model/SettingsStore.swift`
- Modify: `Metronome/MetronomeModel.swift`
- Test: `MetronomeTests/SettingsStoreTests.swift`, new `MetronomeTests/TrackSwitchModelTests.swift`

**Interfaces:**
- Produces, `SettingsStore`: `func loadBackingTracksOn() -> Bool` (true when nothing is stored), `func saveBackingTracksOn(_ on: Bool)`, key `metronome.backingTracksOn.v1`.
- Produces, `MetronomeModel`:
  - `private(set) var backingTracksOn: Bool` — loaded in `init` before `refreshTrackFile()`.
  - `var isTrackInUse: Bool { backingTracksOn && loadedTrack != nil }`
  - `func toggleBackingTracks()` — does nothing while `isPlaying`; otherwise flips the flag, saves it, calls `refreshTrackFile()` (not `loadedTrackReplaced()`, so `trackPosition` is kept) and plays `haptics?.selection()`.
- Changes meaning: `isTrackPlayable` is true only when the track is in use and its file is here; `isTrackMissing` is `isTrackInUse && !isTrackPlayable`. The private `isPlayable(_ track:)` returns false while the switch is off. `hasTrackFile(for:)` keeps reporting the file alone (the song sheet needs it with the switch off), so it must stop going through `isPlayable`.
- `start(countIn:)` takes the track path only when `isTrackPlayable`.

- [ ] **Step 1: Write the failing store tests** in `SettingsStoreTests.swift`: `backingTracksAreOnWhenNothingIsStored` (`loadBackingTracksOn() == true`), `backingTracksOffIsRemembered` (save false, a new store on the same defaults loads false).
- [ ] **Step 2: Run** `scripts/test.sh`; expect these two to fail to compile.
- [ ] **Step 3: Implement** the two store functions, in the style of `loadHapticsEnabled`.
- [ ] **Step 4: Write the failing model tests** in `TrackSwitchModelTests.swift`, using `TrackTestBench` (its `settingsStore` is shared by `relaunch`, so a relaunch sees the saved flag):
  - `theSwitchIsOnAtFirstLaunch`: `backingTracksOn`, `isTrackInUse`, `isTrackPlayable` all true.
  - `switchedOffTheSongIsPlain`: after `toggleBackingTracks()`: `backingTracksOn == false`, `isTrackInUse == false`, `isTrackPlayable == false`, `isTrackMissing == false`, `loadedTrack != nil`; `togglePlayback()` starts the fake engine with no track (assert on the fake's recorded start, as `TrackModelTests` does) and `isPlayingTrack == false`.
  - `switchedOffAMissingFileIsNotReportedMissing`: bench model with `missing: true`, toggle off, `isTrackMissing == false`; toggle on, `isTrackMissing == true`.
  - `theSwitchDoesNothingWhilePlaying`: start, `toggleBackingTracks()`, flag unchanged, no extra selection haptic recorded.
  - `theSwitchTicks`: stopped, one toggle records one selection haptic.
  - `thePositionSurvivesOffAndOn`: `seekTrack(to: 70)`, toggle off, toggle on, `trackPosition == 70`.
  - `loadingAnotherSongWhileOffResetsThePosition`: seek to 70, toggle off, load a second song and the first again, toggle on, `trackPosition == 0`.
  - `theSwitchIsRememberedAcrossLaunches`: toggle off, `bench.relaunch()`, `backingTracksOn == false` and `isTrackPlayable == false`.
  - `loadingASongNeverChangesTheSwitch`: off, load a song with a track, still off; on, load a song without, still on.
  - `switchedOffLoadingATrackSongDoesNotStopPlayback`: two songs, the second with a playable track; off; start; `loadSong` the second; `isPlaying` still true.
  - `switchedOffATrackArrivingBySyncDoesNotStopPlayback`: follow the arrival tests in `TrackSongModelTests` (track replaced on another device while playing) with the switch off: playback carries on and no haptic plays.
  - `theSongSheetStillSeesTheFileWhileOff`: off, `hasTrackFile(for: loadedSong)` is true.
- [ ] **Step 5: Run** `scripts/test.sh`; expect the new tests to fail to compile.
- [ ] **Step 6: Implement** the model changes listed under Interfaces. Read every use of `isTrackPlayable`, `isTrackMissing`, `isPlayable(` and `loadedTrack` in `MetronomeModel.swift` and check each against spec 7.6, 7.9, 7.10, 7.12, 10.1 and 10.2 with the switch off; the Sync sheet's setters (`nudgeFirstBeat`, `setCountIn`, `setMix`) keep working on `loadedTrack`. Per 7.12, attaching, replacing or picking a file with the switch off still sets the position to 0:00.
- [ ] **Step 7: Run** `scripts/build.sh` and `scripts/test.sh`; all pass, including every existing track test unchanged.
- [ ] **Step 8: Commit** with subject `Make backing tracks a mode kept on the device`.

### Task 2: Saving the Sync sheet's tempo

**Files:**
- Modify: `Metronome/Model/SyncRecords.swift`, `Metronome/Model/Library.swift`, `Metronome/MetronomeModel.swift`, `Metronome/Views/SyncSheet.swift`
- Test: `MetronomeTests/SyncRecordsTests.swift` or `LibraryTests.swift`, `MetronomeTests/TrackModelTests.swift`

**Interfaces:**
- Produces, `SongRecord`: `mutating func setTempo(_ settings: MetronomeSettings, now: Date)` — stamps only the tempo part, only when its value differs (the first line of today's `setSettings`).
- Produces, `Library`: `mutating func updateSongTempo(_ id: UUID, bpm: Int, now: Date)` — takes the saved song's settings, sets their tempo to `bpm`, sanitises, and calls `setTempo`. The meter part and its time are not touched.
- Produces, `MetronomeModel`: `func nudgeSyncTempo(by delta: Int)` and `func tapSyncTempo(at time: TimeInterval)`. They behave as `nudgeBPM(by:)` and `tapTempo(at:)` (same haptics, same engine update), and when the tempo changed and a song is loaded they also call `library.updateSongTempo` and `persistSoon()`. The library is written before the Save offer is worked out, and when the song is then not edited `isSaveOffered` becomes false at once (no `saveOfferDelay`), as after `saveChanges()`.
- Consumes: `persistSoon()`, `savePendingChanges()`, `syncSettingSaveDelay` from the existing deferred save.

- [ ] **Step 1: Write the failing tests.**
  - Record level: `settingTheTempoLeavesTheMeterPartsTimeAlone` — a song saved at time T; `updateSongTempo(id, bpm: 130, now: T + 10)`; the saved song reads 130, the tempo part's time is later than T, the meter part's time is unchanged. `settingTheSameTempoStampsNothing`.
  - Model level, in `TrackModelTests.swift` with `TrackTestBench`:
    - `aSyncSheetTempoIsSavedIntoTheSong`: `nudgeSyncTempo(by: 1)`; `loadedSong?.settings.bpm == 121`, `settings.bpm == 121`, `isEdited == false`, `isSaveOffered == false`.
    - `aSyncSheetTempoLeavesOtherChangesUnsaved`: `selectTimeSignature` to another signature first; `nudgeSyncTempo(by: 1)`; the saved song has the new tempo and its old time signature; `isEdited == true`, `isSaveOffered == true`.
    - `aTempoChangedBeforeTheSheetStaysUnsavedUntilTouched`: `nudgeBPM(by: 5)`; saved song still 120 and `isEdited`; then `nudgeSyncTempo(by: 1)`: saved song 126, `isEdited == false`, `isSaveOffered == false` at once.
    - `aTappedSyncTempoIsSaved`: two or more `tapSyncTempo(at:)` calls spaced for 100 BPM; saved song reads 100.
    - `severalSyncTempoStepsSaveOnce`: follow `severalNudgesInARowSaveOnceWithTheLastValue` (it polls; do not sleep a fixed time): five `nudgeSyncTempo(by: 1)` cause one library save holding 125.
    - `aSyncTempoSurvivesARelaunchAfterAFlush`: nudge, `savePendingChanges()`, `bench.relaunch()`, the song reads the new tempo.
    - `aSyncTempoReachesAPlayingEngine`: while playing the track, nudge; the fake engine received the updated settings.
- [ ] **Step 2: Run** `scripts/test.sh`; expect compile failures.
- [ ] **Step 3: Implement** `setTempo`, `updateSongTempo` and the two model methods. Share the body with `applyBPM` through one private function taking a flag, so the order "write the library, then work out the Save offer" is in one place.
- [ ] **Step 4: Point the Sync sheet at them:** in `SyncSheet.swift` the tempo row's `Slower` / `Faster` call `nudgeSyncTempo(by:)` and its Tap tempo pill calls `tapSyncTempo(at:)`. The metronome screen's own controls keep `nudgeBPM` / `tapTempo`.
- [ ] **Step 5: Run** `scripts/build.sh` and `scripts/test.sh`; all pass.
- [ ] **Step 6: Commit** with subject `Save a tempo set in the Sync sheet into the song`.

### Task 3: The layout with the player card

**Files:**
- Modify: `Metronome/Views/MetronomeScreen.swift` (`ScreenLayout` only)
- Test: `MetronomeTests/ScreenLayoutTests.swift`

**Interfaces:**
- `ScreenLayout.init` keeps its signature; `hasTrack` means "a track is in use".
- Produces: `static let playerCardHeight: CGFloat = 192` (12 + 30 + 12 + 40 + 12 + 68 + 18), `static let playerNextLineHeight: CGFloat = 30` (18 + 12), `static let playerCardTopGap: CGFloat = 16`.
- Removes: `stripTopGap`, `trackStripHeight` and the `Gaps.stripTopGap` field.
- With `hasTrack`, the fixed parts are: header 8 + 40, dial top 12, row gap 10, row 56, gap 12, tiles (76 roomy, 56 compact), 16, card 192, plus 30 with the next-up line. There is no separate Start row or `buttonTopGap` + 68 term. Without `hasTrack` nothing changes.

- [ ] **Step 1: Replace the track-layout tests** in `ScreenLayoutTests.swift` (those passing `hasTrack: true`) with these, asserting within 0.5 pt:
  - iPhone 17 Pro, 402 × 778, bottom inset, 4 beats: dial 340; with `hasSetlist: true` dial 326 and `showsNextLine == true`.
  - Height 680, width 402, bottom inset, 4 beats: dial 258, tile height 76. Height 661: tile height 56, dial 259.
  - iPhone SE, 375 × 647, no bottom inset, 4 beats: dial 229, tile height 56; with `hasSetlist: true`: `showsNextLine == false`, dial 229. 9 beats: dial 187.
  - Display Zoom, 320 × 548, no bottom inset, 4 beats: dial 130; 9 beats: dial 88; `hasSetlist: true`: `showsNextLine == false`.
  - `fixedHeight + dialDiameter + bottomPadding <= height` for each case above.
  Leave every `hasTrack: false` test as it is.
- [ ] **Step 2: Run** `scripts/test.sh`; the new figures fail.
- [ ] **Step 3: Implement** the change in `ScreenLayout`. If a figure above differs from what the spec's derivation gives by more than 0.5 pt, the spec's text for 6.12 is the authority: report the difference rather than bending the code.
- [ ] **Step 4:** `MetronomeScreen.body` still references `layout.stripTopGap`; replace that padding with `ScreenLayout.playerCardTopGap` as a stopgap so the target builds. Task 4 rewrites this part of the body.
- [ ] **Step 5: Run** `scripts/build.sh` and `scripts/test.sh`; all pass.
- [ ] **Step 6: Commit** with subject `Size the track layout around the player card`.

### Task 4: The switch and the player card on screen

**Files:**
- Create: `Metronome/Views/TrackSwitchButton.swift`
- Modify: `Metronome/Views/TrackControls.swift` (replace `TrackStrip` with `PlayerCard`), `Metronome/Views/MetronomeScreen.swift`, `Metronome/Views/SyncSheet.swift` only if 6.13 requires it, `Metronome/Screenshots/ScreenshotScene.swift`, `docs/specification.md` (section 14 only)

**Interfaces:**
- Consumes: `model.backingTracksOn`, `model.isTrackInUse`, `model.toggleBackingTracks()`, `model.isTrackMissing`, `model.togglePlayback()`, `model.skipTrack(by:)`, `model.canSkipForward`, `model.goToPrevious()`, `model.goToNext()`, `model.canGoPrevious`, `model.canGoNext`, `model.position`, `model.nextSong`, `ScreenLayout.playerCardHeight`, `TrackProgressBar`, `NextUpLine`.
- Produces: `struct TrackSwitchButton: View` (no parameters, reads the model from the environment); `struct PlayerCard: View` with `init(showsNextLine: Bool, onSync: @escaping () -> Void)`.

- [ ] **Step 1: `TrackSwitchButton`** per spec 6.1 and 7.12: 40 pt circle, `music.note` at 20 pt, the two fills, dimmed and not hit-testable while `model.isPlaying`, 44 pt touch area, VoiceOver label `Backing tracks` with value `on` / `off`. Follow `MuteButton.swift` for structure.
- [ ] **Step 2: Header.** In `MetronomeScreen.header`, show `TrackSwitchButton()` between the Save button and `MuteButton()` when `model.loadedTrack != nil`.
- [ ] **Step 3: `PlayerCard`** per spec 6.12, in `TrackControls.swift`: the file-name row with Sync (lift from `TrackStrip`), `TrackProgressBar` at full inner width, the transport row, and `NextUpLine` when `showsNextLine`. Transport row: Previous song and Next song (`backward.end`, `forward.end`, 20 pt, no fill, 44 pt) only when `model.position != nil`; Rewind and Fast-forward (the existing `SkipButton`); a 68 pt round play / stop button with the states in 6.12. With three buttons they keep their five-button places. Missing-file state as in 6.12. Remove `TrackStrip`. The card's height is `ScreenLayout.playerCardHeight`, plus `playerNextLineHeight` with the line.
- [ ] **Step 4: Screen body.** `let hasTrack = model.isTrackInUse`. In the track branch, after the accent tiles: `Spacer(minLength: ScreenLayout.playerCardTopGap)`, then `PlayerCard(showsNextLine: layout.showsNextLine) { isSyncShown = true }` with the bottom padding; the footer is used only in the plain branch. Add `.animation` on `hasTrack` only if the spec asks for one; 7.12 says the layout changes at once.
- [ ] **Step 5: Haptics and accessibility** per spec 12 and 13: the card's play / stop goes through `togglePlayback()` (its haptic is already there); check the reading order of the card.
- [ ] **Step 6: Debug scenes.** `trackScreen` and `trackSync` in `ScreenshotScene.swift` must show the card: make sure the scene's model has Backing tracks on.
- [ ] **Step 7: Run** `scripts/build.sh` and `scripts/test.sh`; all pass.
- [ ] **Step 8: See it in the simulator** on an iPhone 17 Pro (`xcrun simctl launch booted com.metsahalme.metronome -screenshotScene trackScreen`), and save screenshots to the plan's workspace: the card stopped; playing (stop symbol, progress moving); the switch tapped off (plain layout, switch dark) and on again; the switch dimmed while playing; a song outside a setlist (three buttons); the edited state with Save beside the switch. Compare each with spec 6.1 and 6.12 and fix differences.
- [ ] **Step 9: Section 14.** For each backing-track line touched by this plan, tick it only if every claim is covered by a unit test from Tasks 1 to 3 or was seen in Step 8, and write the note accordingly. Update section 15's list of what is not built.
- [ ] **Step 10: Commit** in two commits: `Add the Backing tracks switch and the player card`, then `Tick what is verified for the switch and the card`.

## Not in this plan

- The plain layout's Start pill and bare-arrow Previous / Next stay as they are.
- Spec 6.8's figures for iPhone SE and Display Zoom.
- Anything that needs a listener or a real iPhone; those checklist lines stay unticked.
