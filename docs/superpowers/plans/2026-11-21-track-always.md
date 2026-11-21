# Backing Tracks Switch For Every Song Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Backing tracks switch is in the header for every song and with nothing loaded. While it is on, the player card has Track content for every song: a song without a backing track shows a no-track state (`No track selected` and `Choose file`) and plays the click alone; nothing loaded shows `No track selected` without the button. `Choose file` there attaches the picked file to the loaded song as its backing track at once, as the missing-file state's `Choose file` stores a file at once. With nothing stored for it, the switch starts off, or on when the library already holds a song with a backing track, and that value is stored.

**Architecture:** Small. `SettingsStore.loadBackingTracksOn()` returns nil when nothing is stored, and `MetronomeModel.init` decides and stores the starting value. The model gains `attachFileToLoadedSong(_:for:)` and one entry point `chooseFile(_:for:)` over a `ChooseFileTarget`; the attach reuses `newTrack`, `Library.setTrack`, `loadedTrackReplaced()` and `persistLibrary()`, so the track part takes the song's tempo, the metronome takes the track's settings and the library syncs, exactly as for the song sheet. A pure `TrackCard` type says what Track content's file-name row shows (text, its colour, the pill, whether the file controls work, the VoiceOver label); the model exposes it as `trackCard`, and `playerContent` follows the switch alone. The views read `trackCard` and nothing else for that row; the header shows `TrackSwitchButton` always.

**Tech Stack:** Swift, SwiftUI, Swift Testing. Build with `scripts/build.sh`, test with `scripts/test.sh` (extra arguments go to xcodebuild, e.g. `scripts/test.sh -only-testing:MetronomeTests/TrackSwitchModelTests`). New files need no project edit: the project uses file-system synchronised groups.

**Spec:** `docs/specification.md`: the intro paragraph on the page *Player with mode switch (draft)*, sections 4, 5 (the table), 6 (intro), 6.1 (Backing tracks switch, the title's width), 6.7, 6.9 (muted), 6.12 (opening, File-name row, the line after the transport row, No track, Nothing loaded), 7.6 (Unload), 7.9, 7.10, 7.11, 7.12, 7.13, 10.2, 10.3, 13 (Track content), 14, 15. Read them before each task; the rules and copy are binding. The only new UI copy is `No track selected`; `Choose file` and both alerts exist already.

## Global Constraints

- Work only in `/Users/arime/metronome/.claude/worktrees/track-always` on branch `track-always`. Never switch branches, never push. Start from a commit that holds `docs/specification.md` as rewritten for this plan and this plan.
- Stage files by explicit path, never with `git add -A`, `git add .` or `git commit -a`.
- No library format change: `LibrarySync.format` stays 2, `SongRecord` and `LibraryState` do not change. The only stored value that changes meaning is device-local: `metronome.backingTracksOn.v1` is now written once at launch when it was missing (Task 1).
- The engine (`ClickEngine`, `AudioClickEngine`, `TrackGrid`, `TrackBeatClock`) does not change. No rule about stopping playback changes: they all ask `isTrackPlayable` / `isPlayable`, which a song without a track never is.
- The only new UI copy is `No track selected`. No helper text anywhere.
- Keep the rules in the model or in pure types with tests; the views only read `model.trackCard`, `model.playerContent` and call `model.chooseFile(_:for:)`.
- `docs/specification.md` is one living document: no history wording ('now', 'previously', 'new' for a change, 'no longer', 'any more'). Only the last task touches it, and only sections 14 and 15.
- Shell: single quotes, no `$(...)`, no backticks, no `cd` before git, no backslash line continuations. Read files with the Read tool.
- Commits: write the message to a file in the scratchpad named in your brief and run `git commit -F <file>`. Imperative, capitalised subject of at most 72 characters, no trailing period, no prefix such as 'feat:', no backticks, no attribution lines of any kind; a body only when the why is not obvious, wrapped at 72.
- Never read `.env.*` or `.appsettings.*` files, anything under `scripts/` named appstore or testflight, or any `.p8` file.
- Simulator: iPhone 17 Pro, UDID 5C51A102-4BAD-43B4-AEC8-9A5FC809A997. Build with `scripts/build.sh`; the app is `build/DerivedData/Build/Products/Debug-iphonesimulator/Metronome.app`, bundle id `com.metsahalme.metronome`; install with `xcrun simctl install 5C51A102-4BAD-43B4-AEC8-9A5FC809A997 build/DerivedData/Build/Products/Debug-iphonesimulator/Metronome.app` and launch a scene with `xcrun simctl launch 5C51A102-4BAD-43B4-AEC8-9A5FC809A997 com.metsahalme.metronome -screenshotScene <name>`. The real audio engine aborts on Start in this simulator: try Start only in scenes built on `ScreenshotEngine`.

## Review Focus

1. **The starting value of the switch.** It must be decided once, from the library as loaded at launch, and stored at once, so that a track attached or synced later never flips it; a stored value always wins. Test builders that start from a library without tracks but test the switch on must store `true` themselves rather than rely on a default (Task 1 lists the two known ones). Pinned in Task 1 (`aFreshInstallStartsWithTheSwitchOff`, `theStartingValueIsStoredSoALaterTrackKeepsIt`, `aStoredValueWins`).
2. **A pick that arrives for the wrong song.** `attachFileToLoadedSong` must do nothing unless the song is still the loaded one and still has no track; the view's read must be cancelled as the target goes. Pinned in Task 2 (`choosingAFileForASongThatIsNoLongerLoadedDoesNothing`, `choosingAFileForASongThatGotATrackMeanwhileDoesNothing`).
3. **Attaching is not an edit.** The metronome's tempo, time signature and accents and their badge stay; the track part takes the song's saved tempo, not the metronome's unsaved one; `trackSettings` becomes the new track's. Pinned in Task 2 (`choosingAFileForASongWithoutATrackKeepsUnsavedEdits`).
4. **One card type for three states.** `TrackProgressBar` and `TrackSkipButton` are shared with Sync mode's playback card; they must dim on `!model.trackCard.hasFile`, which is true whenever Sync mode can be shown. `isTrackMissing` stays for the model's rules and tests.
5. **The App Store scenes.** They have no track, so with the starting value of Task 1 their switch is off and their cards keep Metronome content; after Task 3 the switch shows, off, in the header of `playing`, `timeSignature` and `settings`. Task 4 retakes them.

---

### Task 1: The switch's starting value

The switch is off when nothing is stored, unless the library already holds a song with a backing track; the value is stored at once. Nothing visible changes in this task: the switch is still shown only for a song with a track.

**Files:**
- Modify: `Metronome/Model/SettingsStore.swift` (`loadBackingTracksOn`), `Metronome/MetronomeModel.swift` (`init`, the doc comment of `backingTracksOn`)
- Test: `MetronomeTests/SettingsStoreTests.swift`, `MetronomeTests/TrackSwitchModelTests.swift`, `MetronomeTests/TrackSongModelTests.swift` (`makeDevice`)

**Interfaces:**
- `SettingsStore.loadBackingTracksOn() -> Bool?`: the stored value; nil when nothing is stored. `saveBackingTracksOn(_:)` unchanged.
- `MetronomeModel.init`: after the library state is loaded, `let stored = store.loadBackingTracksOn()`, `backingTracksOn = stored ?? state.library.songs.contains { $0.track != nil }`, and when `stored == nil`, `store.saveBackingTracksOn(backingTracksOn)`. Move the assignment after `library = state.library` (a stored property must be set before `refreshTrackFile()` runs, which it already is).
- The doc comment on `backingTracksOn` says the starting rule.

- [ ] **Step 1: Write the tests**

`SettingsStoreTests`: rename `backingTracksAreOnWhenNothingIsStored` to `nothingStoredForBackingTracksReadsAsNil` with `#expect(store.loadBackingTracksOn() == nil)`; `backingTracksOffIsRemembered` stays (`== false`); add `backingTracksOnIsRemembered` (`saveBackingTracksOn(true)`, a new store on the same defaults reads `true`).

`TrackSwitchModelTests`: rename `theSwitchIsOnAtFirstLaunch` to `withATrackInTheLibraryTheSwitchStartsOn`, keeping its three asserts and adding `bench.settingsStore.loadBackingTracksOn() == true`. Add:

```swift
@Test func aFreshInstallStartsWithTheSwitchOff()
// bench.relaunch() with nothing stored: backingTracksOn == false, playerContent == .metronome,
// bench.settingsStore.loadBackingTracksOn() == false
@Test func aLibraryWithoutTracksStartsWithTheSwitchOff()
// library with one song without a track, loaded; relaunch: backingTracksOn == false, stored false
@Test func theStartingValueIsStoredSoALaterTrackKeepsIt()
// fresh: relaunch() -> off; createSong(name: "Song", settings: model.settings, addingTo: nil, track: picked)
// (it becomes the loaded one, as it names the current settings); relaunch(): backingTracksOn == false,
// isTrackInUse == false
@Test func aStoredValueWins()
// settingsStore.saveBackingTracksOn(false); bench.makeModel() (a library with a track): backingTracksOn == false;
// then a fresh bench: saveBackingTracksOn(true); relaunch() with an empty library: backingTracksOn == true
```

`picked` here is `PickedTrack(url: try bench.sourceFile(named: "Take.wav"), fileName: "Take.wav", offset: 48)`.

Fix the builders that start from an empty library and test the switch on: in `TrackSongModelTests.makeDevice()` and `TrackSwitchModelTests.makeDevice()`, build the `SettingsStore` first, call `saveBackingTracksOn(true)` on it, and pass it to the model. (`switchedOffATrackArrivingBySyncDoesNotStopPlayback` and `switchedOffATrackAttachedOnAnotherDeviceDoesNotStopPlayback` toggle the switch from on to off and must keep doing so.)

- [ ] **Step 2: Run them and see them fail**

Run: `scripts/test.sh -only-testing:MetronomeTests/SettingsStoreTests -only-testing:MetronomeTests/TrackSwitchModelTests`
Expected: `nothingStoredForBackingTracksReadsAsNil` fails to compile against `Bool` or fails (`true != nil`); the three new switch tests fail on `backingTracksOn == false`.

- [ ] **Step 3: Return nil from the store; decide and store the value in `init`**

- [ ] **Step 4: Run the whole suite**

Run: `scripts/build.sh` then `scripts/test.sh`
Expected: `** BUILD SUCCEEDED **`, `** TEST SUCCEEDED **`. Any other failure must be a model built over a library without tracks in a test about the switch being on; fix it the same way (store `true` in its builder) and name it in your report. Investigate anything else before touching it.

- [ ] **Step 5: Simulator**

None: nothing visible changes in this task. Launch `-screenshotScene trackScreen` and `-screenshotScene playing` once to see that the first still shows the switch on with Track content and the second has no switch and Metronome content with the running time; report it.

- [ ] **Step 6: Commit**

Subject `Start the Backing tracks switch off unless the library has a track`. Body: the switch is about to be in every header, and on it puts Track content in the card for every song; a new user, or one who never attached a track, should keep the time and bar readout. With nothing stored the switch starts on only when the library already holds a track, as it played for those users before, and the value is stored so a track added later does not flip it.

---

### Task 2: Choose file attaches a file to a song without a track

The model's side only; no view calls it yet.

**Files:**
- Modify: `Metronome/MetronomeModel.swift` (beside `PickedTrack` and `chooseFileForLoadedTrack`)
- Test: `MetronomeTests/TrackSongModelTests.swift` (section `// MARK: - Choose file on the player card`)

**Interfaces:**
- `enum ChooseFileTarget: Equatable, Sendable { case missingTrack(fileID: UUID), song(id: UUID) }`: what a `Choose file` pill was tapped for: the loaded song's missing track's file, or the loaded song without a track.
- `@discardableResult func attachFileToLoadedSong(_ picked: PickedTrack, for songID: UUID) -> Bool`: true, doing nothing, unless `loadedSongID == songID` and `loadedTrack == nil`; false when `newTrack(picked, replacing: nil)` cannot store the file, and then nothing changes; otherwise `if backingTracksOn, isPlaying { stop() }`, `library.setTrack(songID, to: track, now: now())`, `loadedTrackReplaced()`, `persistLibrary()`, true. The settings are not touched, so unsaved edits stay; `loadedTrackReplaced()` sets the position to 0:00 and `trackSettings` to the new track's. No haptic, as for a missing file.
- `@discardableResult func chooseFile(_ picked: PickedTrack, for target: ChooseFileTarget) -> Bool`: `.missingTrack(let fileID)` calls `chooseFileForLoadedTrack(picked, for: fileID)`, `.song(let id)` calls `attachFileToLoadedSong(picked, for: id)`.

- [ ] **Step 1: Write the tests**

In the suite's Setup, `plain` is the setlist's second song: 90 BPM, 4/4, no track. Each test loads it with `model.loadSong(setup.plain.id, from: setup.setlist)` first.

```swift
@Test func choosingAFileForASongWithoutATrackAttachesItAtOnce()
// writes = bench.libraryDefaults.writes; pick = picked(offset: 31); chooseFile(pick, for: .song(id: plain.id)) == true;
// loadedTrack: fileName "Take.wav", offset 31, countIn .twoBars, mix 0; trackFiles.hasFile(fileID);
// library.song(id: plain.id)?.track == loadedTrack; libraryDefaults.writes > writes;
// isTrackPlayable, isTrackInUse; trackSettings == loadedTrack?.settings; isEdited == false; isSaveOffered == false;
// trackPosition == 0; trackPartTempo(of: plain.id, in: model) == .number(90); pick's copy still exists
@Test func choosingAFileForASongWithoutATrackKeepsUnsavedEdits()
// setBPM(95); toggleAccent(beat: 2); chooseFile(.song): settings.bpm == 95, accents [1, 2], isEdited, isSaveOffered;
// library.song(id: plain.id)?.settings.bpm == 90; trackPartTempo(of: plain.id, in: model) == .number(90)
@Test func choosingAFileForASongWithoutATrackWhilePlayingStops()
// togglePlayback(); chooseFile(.song): isPlaying == false, engine.stopCount == 1, trackPosition == 0;
// togglePlayback(): engine.startedTracks.count == 1, its startTime < 0 (the count-in)
@Test func choosingAFileForASongWithoutATrackThatCannotBeStoredChangesNothing()
// togglePlayback(); library = model.library; chooseFile(unstorable(), for: .song) == false; library unchanged;
// loadedTrack == nil; isPlaying; engine.stopCount == 0
@Test func choosingAFileForASongThatIsNoLongerLoadedDoesNothing()
// target = .song(id: plain.id); loadSong(other.id, from: setlist); library = model.library;
// chooseFile(picked(), for: target) == true; library unchanged; then unloadSong(); chooseFile again: true, unchanged
@Test func choosingAFileForASongThatGotATrackMeanwhileDoesNothing()
// editSong(plain.id, name: "Plain", settings: plain.settings, track: .attach(picked("First.wav")));
// chooseFile(picked("Second.wav"), for: .song(id: plain.id)) == true; loadedTrack?.fileName == "First.wav"
@Test func chooseFileForAMissingTrackGoesThroughItsTarget()
// makeModel(missing: true); chooseFile(picked(), for: .missingTrack(fileID: song.track!.fileID)):
// isTrackPlayable, loadedTrack?.fileID unchanged
@Test func aFileChosenForASongWithoutATrackSyncs()
// a = makeDevice(), b = makeDevice(); a.createSong(name: "Song", settings: settings100, addingTo: nil) (no track);
// send to b; b.loadSong(song.id); a.loadSong(song.id); a.chooseFile(picked(), for: .song(id: song.id));
// cloud.send(.changed, toDevice: 1): b.loadedTrack?.fileName == "Take.wav", b.isTrackMissing, b.trackSettings == b.loadedTrack?.settings
```

- [ ] **Step 2: Run them and see them fail**

Run: `scripts/test.sh -only-testing:MetronomeTests/TrackSongModelTests`
Expected: build errors for `chooseFile(_:for:)` and `ChooseFileTarget`.

- [ ] **Step 3: Add the target, the attach and the entry point**

- [ ] **Step 4: Run the whole suite**

Run: `scripts/build.sh` then `scripts/test.sh`
Expected: `** BUILD SUCCEEDED **`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Simulator**

None: no view calls it yet.

- [ ] **Step 6: Commit**

Subject `Attach a file to a song without a track from the player card`. Body: like a file picked for a missing track, the file is stored and written into the song at once, not held as an unsaved edit, since a track is never part of the metronome's working copy; the song's unsaved tempo, time signature and accents stay unsaved.

---

### Task 3: Track content for every song while Backing tracks is on

**Files:**
- Create: `Metronome/Model/TrackCard.swift`
- Modify: `Metronome/MetronomeModel.swift` (`playerContent`, add `trackCard`), `Metronome/Views/MetronomeScreen.swift` (`header`), `Metronome/Views/TrackSwitchButton.swift` (doc comment), `Metronome/Views/TrackControls.swift` (`TrackContent.fileNameRow`, `ChooseFilePill`, `TrackProgressBar.bar`, `TrackSkipButton.button`), `Metronome/Screenshots/ScreenshotScene.swift`
- Test: create `MetronomeTests/TrackCardTests.swift`; modify `MetronomeTests/OneTempoModelTests.swift`, `MetronomeTests/TrackSwitchModelTests.swift`, `MetronomeTests/TrackSongModelTests.swift`

**Interfaces:**
- `TrackCard.swift`:

```swift
/// What the player card's Track content shows in its file-name row, and whether the track's file
/// can be played there (6.12). Read only while Backing tracks is on.
enum TrackCard: Equatable {
    case playable(fileName: String)
    case missing(fileName: String, fileID: UUID)
    case noTrack(songID: UUID)
    case nothingLoaded

    enum TextStyle: Equatable { case fileName, missingFileName, noTrack }   // dial white, amber, muted
    enum Pill: Equatable { case sync, chooseFile(ChooseFileTarget) }

    static func state(loadedSongID: UUID?, track: BackingTrack?, isPlayable: Bool) -> TrackCard
    var text: String              // the file name, or "No track selected"
    var textStyle: TextStyle
    var pill: Pill?               // nil with nothing loaded
    var hasFile: Bool             // only .playable: the bar, Rewind and Fast-forward work and are read
    var accessibilityLabel: String // "Backing track, <name>", "Track missing, <name>", "No track selected"
}
```

- `MetronomeModel.playerContent`: `backingTracksOn ? .track : .metronome`. `var trackCard: TrackCard { TrackCard.state(loadedSongID: loadedSongID, track: loadedTrack, isPlayable: isTrackPlayable) }`. `isTrackInUse` and `isTrackMissing` stay as they are, for the rules.
- `MetronomeScreen.header`: `TrackSwitchButton()` always, between `SongTitle` and `SoundButton`.
- `TrackContent.fileNameRow`: reads `model.trackCard` once: the icon; `Text(card.text)` coloured by `textStyle` (dial white, amber, muted), 14 pt medium, one line, cut at the tail, taking the space left; then `card.pill`: `.sync` the existing `CardPill("Sync")`, `.chooseFile(let target)` `ChooseFilePill(target: target)`, nil nothing. The row's VoiceOver label is `card.accessibilityLabel`.
- `ChooseFilePill(target: ChooseFileTarget)`: `chosenFor: ChooseFileTarget?` is set from `target` when the picker opens; the read is live only while `model.trackCard.pill == .chooseFile(chosenFor)`; on success it calls `model.chooseFile(picked, for: read.target)`. Everything else (dimmed while reading, the two alerts, cancel not an error, discarding the copy) stays.
- `TrackProgressBar.bar` and `TrackSkipButton.button`: `let isMissing = model.isTrackMissing` becomes `let hasNoFile = !model.trackCard.hasFile`, with the same dimming, hit testing and VoiceOver hiding.
- `ScreenshotScene`: two scenes, not App Store ones, built like `trackSyncTimer` on `ScreenshotEngine(soundingBeat: 1, repeats: true, clocksTrack: true)`, `NoHaptics()` and the scene's `trackFiles` (emptied first, as `trackMissing` does), with `settingsStore.saveBackingTracksOn(true)` before the model is made:
  - `trackNone`: the sample library without a track, Seven Bridges loaded from Friday gig, so the card's no-track state with Previous and Next.
  - `trackNothingLoaded`: the same library with `loadedSongID` and `loadedFromSetlistID` nil.
  Both go into neither `hasTrack` nor `scripts/screenshots.sh`.

- [ ] **Step 1: Write the tests**

`TrackCardTests` (pure, no model):

```swift
@Test func aPlayableTrackShowsItsNameAndSync()
// state(loadedSongID: id, track: t, isPlayable: true) == .playable(fileName: "Song.m4a"); text "Song.m4a";
// textStyle .fileName; pill .sync; hasFile; accessibilityLabel "Backing track, Song.m4a"
@Test func aMissingFileShowsItsNameAndChooseFile()
// isPlayable false: .missing(fileName: "Song.m4a", fileID: t.fileID); textStyle .missingFileName;
// pill .chooseFile(.missingTrack(fileID: t.fileID)); hasFile == false; label "Track missing, Song.m4a"
@Test func aSongWithoutATrackShowsNoTrackSelectedAndChooseFile()
// track nil: .noTrack(songID: id); text "No track selected"; textStyle .noTrack; pill .chooseFile(.song(id: id));
// hasFile == false; label "No track selected"
@Test func nothingLoadedShowsNoTrackSelectedWithoutAButton()
// loadedSongID nil, track nil: .nothingLoaded; text "No track selected"; pill == nil; hasFile == false;
// label "No track selected"
```

`OneTempoModelTests`: replace `thePlayerShowsTheTrackOnlyWhileATrackIsInUse` with

```swift
@Test func thePlayerFollowsTheSwitch()
// makeModel(): .track; toggleBackingTracks(): .metronome; toggleBackingTracks(); unloadSong(): .track,
// trackCard == .nothingLoaded; toggleBackingTracks(): .metronome
```

`TrackSwitchModelTests` (with `makeTwoSongs(secondHasTrack: false)`, whose library has a track, so the switch starts on):

```swift
@Test func aSongWithoutATrackHasTrackContentWithTheSwitchOn()
// loadSong(second.id): playerContent == .track, trackCard == .noTrack(songID: second.id), isTrackInUse == false;
// togglePlayback(): isPlaying, engine.startedTracks.isEmpty, engine.startedSettings.last?.bpm == 90
@Test func withTheSwitchOffEverySongHasMetronomeContent()
// toggleBackingTracks(): .metronome for first; loadSong(second.id): .metronome; unloadSong(): .metronome
@Test func theSwitchWorksForASongWithoutATrack()
// loadSong(second.id); ticks; toggleBackingTracks(): backingTracksOn == false, selectionCount == ticks + 1;
// togglePlayback(); toggleBackingTracks(): still false
```

`TrackSongModelTests`: in `aTrackAttachedOnAnotherDeviceArrivesMissingAndKeepsPlaying` add `b.model.trackCard == .noTrack(songID: song.id)` before the attach and `.missing(fileName: "Take.wav", fileID: ...)` after it; in `choosingAFileForASongWithoutATrackAttachesItAtOnce` add `trackCard == .playable(fileName: "Take.wav")`.

- [ ] **Step 2: Run them and see them fail**

Run: `scripts/test.sh -only-testing:MetronomeTests/TrackCardTests -only-testing:MetronomeTests/OneTempoModelTests -only-testing:MetronomeTests/TrackSwitchModelTests -only-testing:MetronomeTests/TrackSongModelTests`
Expected: build errors for `TrackCard` and `trackCard`.

- [ ] **Step 3: Add `TrackCard`, `trackCard` and the switch-only `playerContent`; change the header, the file-name row, the pill, the bar and the skip buttons; add the two scenes**

- [ ] **Step 4: Run the whole suite**

Run: `scripts/build.sh` then `scripts/test.sh`
Expected: `** BUILD SUCCEEDED **`, `** TEST SUCCEEDED **`; `grep -rn 'isTrackMissing' Metronome/Views` finds nothing.

- [ ] **Step 5: Look at it in the simulator**

On the iPhone 17 Pro:
- `-screenshotScene trackNone`: the header holds the title, the switch on, the Sound button and the menu button; the card holds the note icon, `No track selected` in muted and `Choose file` at the row's right end, the bar dimmed with no times, Rewind and Fast-forward dimmed, Previous and Next at the ends. Compare a screenshot with one of `-screenshotScene trackMissing`: nothing on the card at another place or size. Tap Rewind: nothing happens. Start: `Stop` and the tiles lighting, no `Count-in`; Stop.
- In the same scene, `Choose file`: the Files picker opens; close it: the card is as before, no alert. `Choose file` again and pick an audio file: the card shows its name in dial white, the Sync pill, the bar with `0:00` and the file's length, Rewind and Fast-forward undimmed, and no badge on the menu button; the Sync pill opens Sync mode, `Done` closes it; the library shows the music-note mark on Seven Bridges. If the picker offers no audio file, say so and do not report the pick as seen; do not copy files into the simulator's Files by any route the brief does not name.
- `trackNone` again: + once (the badge shows), then pick a file: the dial keeps its number and the badge stays.
- `trackNone` again: tap the switch off: Metronome content with `0:00` and `Bar 1`, the switch drawn off; on again: the no-track state.
- `-screenshotScene trackNothingLoaded`: the header `Library` / `No song loaded` with the switch on; the card's row holds the icon and `No track selected` with no button, no Previous or Next; Start plays and Stop stops.
- `-screenshotScene playing`: the switch, off, between the title and the Sound button; the card still Metronome content with the time running and `Bar 54`.

Report what was and was not seen, VoiceOver included (not run unless you run it).

- [ ] **Step 6: Commit**

Subject `Show Track content for every song while Backing tracks is on`. Body: the switch is in the header for every song and with nothing loaded; with it on, a song without a track shows No track selected with Choose file and plays the click alone, and with nothing loaded the row has no button, as a track belongs to a song.

---

### Task 4: Retake the App Store screenshots

`playing`, `timeSignature` and `settings` show the metronome screen's header, which now holds the switch, off. `library` and `setlist` cover the header.

**Files:**
- Modify: `screenshots/1-playing.png` to `screenshots/5-settings.png`, `site/shots/1-playing.png` to `site/shots/5-settings.png` (written by the script)

- [ ] **Step 1: Run the script**

Run: `scripts/screenshots.sh`
Expected: five `Saved screenshots/<n>-<scene>.png` lines and exit status 0. It uses its own simulator, `Metronome screenshots`, and creates it on the first run.

- [ ] **Step 2: Look at every picture**

Read each PNG. Expected: `1-playing`, `4-timeSignature` and `5-settings` show the switch off, a note with a slash on a surface circle, between `Seven Bridges` and the Sound button, the title not cut; `1-playing`'s card shows the running time and `Bar` with `Stop`; `2-library` and `3-setlist` look as before. Report anything else that changed.

- [ ] **Step 3: Commit**

Stage the ten PNG files by path. Subject `Retake the screenshots with the switch in every header`.

---

### Task 5: Sections 14 and 15

**Files:**
- Modify: `docs/specification.md` (sections 14 and 15 only)

- [ ] **Step 1: Update the lines marked *(Not built yet.)* and the notes that name unbuilt parts in section 14**

In the Songs and setlists group: the header line (the switch for every song and with nothing loaded). In the Backing tracks group: the content the card has with the switch on and off; the no-track and nothing-loaded states; `Choose file` attaching a file; the switch in the header of a song without a track and with nothing loaded; the switch's starting value; a track attached elsewhere turning the no-track state into the missing-file state. Tick a line only when a unit test covers it or it was seen in the simulator (Tasks 1 to 4's reports), and replace the note with the test names and what was seen, and what was not (VoiceOver, a real iPhone, two devices, the Files picker if no audio file was offered). Split a line when only part of it is verified.

- [ ] **Step 2: Update section 15**

Drop the entry *The Backing tracks switch for every song* once every part of it is built. With no entry left, the first line is followed by `Every part specified above is built.`

- [ ] **Step 3: Check the wording**

Run: `git diff -U0 -- docs/specification.md`
Expected: no history wording ('now', 'previously', 'no longer', 'any more', 'new' for a change), and only sections 14 and 15 changed.

- [ ] **Step 4: Commit**

Subject `Record what was verified of the switch for every song`.

---

## Self-review notes

- Spec 5 table and 7.12's starting value: Task 1. 6.12 `Choose file` in the no-track state, 7.10's attach rule, 10.3's bullet on `Choose file` in the no-track state: Task 2. 4, 6 intro, 6.1, 6.7, 6.9, 6.12 (opening, row, No track, Nothing loaded), 7.6 Unload, 7.9 arrivals, 7.11, 7.12 Off / On, 7.13, 13: Task 3. 14, 15: Task 5.
- Stop rules need no change: loading, Unload, Save as new song and deleting all ask `isTrackPlayable` / `isPlayable(track)`, false for a song without a track; `attachFileToLoadedSong` stops as `chooseFileForLoadedTrack` does.
- Sync mode needs no change: the Sync pill exists only for `.playable`, and `enterSyncMode()` still guards on `isTrackPlayable`.
- The library's track mark (8.2) and stage mode's marks and time (9.4) need no change: they already follow the song's track and the switch.
- If the user keeps the switch on by default instead (the decision flagged in the report), Task 1 changes to `stored ?? true` with no store write, its tests to match, and the App Store scenes must store `false` themselves, or `1-playing` loses its time and bar readout to `No track selected`.
- Known risks: a fresh install that later turns iCloud sync on gets its songs with tracks while the switch stays off, so their tracks do not play until it is tapped on; a user with tracks who loads a song without one sees `No track selected` in place of the time and bar readout.
