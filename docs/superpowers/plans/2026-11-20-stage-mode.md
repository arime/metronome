# Stage Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build stage mode: a full-screen grid of a setlist's songs as tiles, where a tap starts a song from the top, a second tap stops it, the following song is then marked next, and nothing else can be changed.

**Architecture:** The rules (which tile is next, what a tap does, whether `Done` and the entry points work, tile text and spoken labels, the beat dots' sizes) live in a pure value type, `StageMode`, with its own tests. `MetronomeModel` owns one optional `StageMode` the way it owns `isSyncModeShown`: it enters and leaves it, turns a tile tap into load-and-start or stop, moves the next mark when playback stops for any reason, keeps the screen awake, and closes stage mode when sync empties or deletes its setlist. The views are thin: a `StageModeView` presented as a full-screen cover from `MetronomeScreen`, and two menu items.

**Tech Stack:** Swift, SwiftUI, Swift Testing. Build with `scripts/build.sh`, test with `scripts/test.sh` (extra arguments go to xcodebuild, e.g. `scripts/test.sh -only-testing:MetronomeTests/StageModeTests`). New files need no project edit: the project uses file-system synchronised groups.

**Spec:** `docs/specification.md`, section 9.4 above all, and 5 (Not kept), 6.8, 6.9, 6.13 (title row), 7.4 to 7.10, 7.12, 8 (intro), 8.2, 8.3, 12, 13, 14, 15 and the intro paragraph about the Paper page *Stage mode (draft)*. Read them before each task; sizes, colours and copy are binding. The boards *Stage — ready*, *Stage — playing* and *Stage — stopped, next marked* draw the result; where they and the spec differ, the spec holds.

## Global Constraints

- Work only in `/Users/arime/metronome/.claude/worktrees/stage-mode` on branch `stage-mode`. Never switch branches, never push.
- Nothing new is kept or synced: `LibraryState`, `SongRecord`, `SetlistRecord`, `LibrarySync` and the format number (2) do not change. Stage mode is not kept between launches.
- UI copy exactly: `Stage mode`, `Done`, `NEXT`, `96 BPM · 4/4`, `0:31 / 3:42`. VoiceOver: tile `3, Seven Bridges, 168 beats per minute, 7/8` + `, backing track` + `, next` / `, playing`; title is a heading reading the setlist's name then `Stage mode`. Terse UI copy: no hints, footnotes or helper lines on screen.
- Colours only from `Theme`; no new colour literals. Ink background, surface tiles, amber tint next tile, amber playing tile, muted dim numbers.
- Sizes: title row 48 pt, 6 pt below the safe area top; grid 20 pt below it; tiles 112 pt (120 pt for a row with a two-line name), radius 24, padding 14 top/bottom and 16 sides, 10 pt gaps; number 15 pt heavy; name 20 pt heavy, tracking -0.02 em, up to 2 lines; tempo 14 pt medium; `NEXT` 11 pt semibold, tracking 0.18 em; track time 13 pt semibold, monospaced digits; outline 1.5 pt; dimmed opacity 0.4; side margins as `ScreenLayout` (24 pt, 16 pt below 360 pt width).
- Shell: single quotes, no `$(...)`, no backticks, no `cd` before git, no backslash line continuations. Read files with the Read tool.
- Commits: write the message to a file in the scratchpad named in your brief and run `git commit -F <file>`. Imperative, capitalised subject of at most 72 characters, no trailing period, no prefix such as 'feat:', no backticks, no attribution lines of any kind; a body only when the why is not obvious, wrapped at 72.
- `docs/specification.md` is one living document: no history wording ('now', 'previously', 'new', 'no longer'). Section 14 lines are ticked only when unit tested or seen, with a note saying which; section 15 loses an entry only when it is built. Only the last task touches sections 14 and 15.
- Never read `.env.*` or `.appsettings.*` files, anything under `scripts/` named appstore or testflight, or any `.p8` file.

## Review Focus

1. **The loaded song's own tile after it was played and stopped mid-track.** `loadSong` treats the loaded song as "not a load" and keeps the track position, so a second play would start mid-file with no count-in. The tap must set the position to 0:00 itself. Pinned in Task 2 (`theSameTileAgainStartsFromTheTop`).
2. **Playback stopping without a tap** (interruption, route loss, app to background, end of track): the next mark must still move on, so the move belongs in the model's single stopped path, not in the view's tap handler. A start that fails must not move it. Pinned in Task 2 (`anInterruptionMarksTheFollowingSong`, `theEndOfTheTrackMarksTheFollowingSong`, `aFailedStartKeepsTheTappedTileNext`).
3. **The playing song leaving the setlist through sync** while it plays: no tile is playing, so without a rule the user would be stuck. `Done` must work, tiles must do nothing, and the next mark must not jump to a wrong song. Pinned in Task 1 (`aSongPlayingWithoutATileLeavesDoneWorking`) and Task 3 (`thePlayingSongLeavingTheSetlistLeavesDoneWorking`).
4. **Presenting the full-screen cover while the library sheet is still closing** (entry from the setlist's menu): SwiftUI refuses a second presentation over a dismissing sheet and drops it silently. The cover must be presented from the sheet's `onDismiss`. Not unit testable; seen in Task 4's simulator step, ten times in a row.
5. **Twelve dots on a narrow tile** (12/8 with many accents on a 320 pt phone): the row must scale down and never overflow or clip. Pinned in Task 1 (`twelveAccentedDotsFitANarrowTile`).

---

### Task 1: The rules of stage mode, as a pure type

**Files:**
- Create: `Metronome/Model/StageMode.swift`
- Test: `MetronomeTests/StageModeTests.swift` (new)

**Interfaces:**
- Consumes: `Setlist` (`id`, `songIDs`), `Song` (`id`, `name`, `settings`, `track`), `Song.detail` (in `LibraryRows.swift`), `TrackTime.label(_:)`.
- Produces:
  - `struct StageMode: Equatable { let setlistID: UUID; var nextSongID: UUID? }`
  - `static func StageMode.entering(_ setlist: Setlist, loadedSongID: UUID?, loadedFromSetlistID: UUID?) -> StageMode`: next is the loaded song when `loadedFromSetlistID == setlist.id` and it is in the setlist, else `setlist.songIDs.first`.
  - `static func StageMode.canEnter(songCount: Int, isPlaying: Bool) -> Bool`: `songCount > 0 && !isPlaying`.
  - `static func StageMode.following(_ songID: UUID, in songIDs: [UUID]) -> UUID?`: the next id, nil after the last or when absent.
  - `enum StageMode.Tap: Equatable { case start(UUID), stop, nothing }` and `static func StageMode.tap(on songID: UUID, playingSongID: UUID?, isPlaying: Bool) -> Tap`: stopped → `.start(songID)`; playing and `songID == playingSongID` → `.stop`; otherwise `.nothing`.
  - `static func StageMode.canLeave(playingSongID: UUID?) -> Bool`: true unless a tile plays.
  - `func tiles(for songs: [Song], playingSongID: UUID?, isPlaying: Bool) -> [StageTile]`: numbered 1...n in the given order; mark `.playing` for `playingSongID`, `.next` for `nextSongID` only while `!isPlaying`; `isDimmed` = `isPlaying && song.id != playingSongID`.
  - `struct StageTile: Equatable, Identifiable { enum Mark: Equatable { case none, next, playing }; let number: Int; let song: Song; let mark: Mark; let isDimmed: Bool; var id: UUID; var accessibilityLabel: String }`
  - `static func StageTile.trackTimeLabel(_ time: TimeInterval, of length: TimeInterval) -> String`: `TrackTime.label(time) + " / " + TrackTime.label(length)`.
  - `enum StageBeatDots { struct Layout: Equatable { let diameters: [CGFloat]; let gap: CGFloat; var width: CGFloat } ; static func layout(beatsPerBar: Int, accents: Set<Int>, availableWidth: CGFloat) -> Layout }`: 12 / 8 pt and a 5 pt gap up to 7 beats, 8 / 5 pt and 3 pt for 9 and 12; then everything multiplied by `min(1, availableWidth / width)`.

- [ ] **Step 1: Write the failing tests**

In `StageModeTests.swift` (`@Suite struct StageModeTests`; songs made with `Song(id: UUID(), name:, settings: MetronomeSettings(bpm:timeSignature:accents:))`, a setlist with `Setlist(id:name:songIDs:)` or however `Library.addSetlist` builds one):

```swift
@Test func enteringMarksTheLoadedSongWhenItCameFromThisSetlist()   // next == b
@Test func enteringMarksTheFirstSongOtherwise()
// loaded from another setlist, loaded on its own, nothing loaded -> next == a in all three
@Test func onlyAStoppedSetlistWithSongsCanBeEntered()
// canEnter(0,false) false; (3,true) false; (3,false) true
@Test func theFollowingSongIsTheNextInOrder()
// following(a,[a,b,c]) == b; following(c, ...) == nil; following(x, ...) == nil
@Test func aTapWhileStoppedStartsThatSong()          // tap(on: c, playing: nil, isPlaying: false) == .start(c)
@Test func aTapOnThePlayingTileStops()               // tap(on: b, playing: b, true) == .stop
@Test func otherTilesDoNothingWhileOnePlays()        // tap(on: a, playing: b, true) == .nothing
@Test func aSongPlayingWithoutATileLeavesDoneWorking()
// tap(on: a, playing: nil, isPlaying: true) == .nothing; canLeave(playingSongID: nil) == true;
// tiles(..., playingSongID: nil, isPlaying: true): every isDimmed true, no .next mark
@Test func doneDoesNothingWhileATilePlays()          // canLeave(playingSongID: b) == false
@Test func tilesAreNumberedInTheSetlistsOrder()      // numbers [1,2,3], ids [a,b,c]
@Test func stoppedTheNextTileIsMarked()              // next b, stopped -> marks [.none,.next,.none], none dimmed
@Test func playingOnlyThePlayingTileIsUndimmed()
// next b, playing c -> marks [.none,.none,.playing], isDimmed [true,true,false]
@Test func aNextSongNotInTheSetlistMarksNothing()     // next x -> every mark .none
@Test func aTileReadsNumberNameTempoAndState()
// "2, Copper Sky, 120 beats per minute, 4/4, next";
// with a track and playing: "3, Seven Bridges, 168 beats per minute, 7/8, backing track, playing";
// unmarked: "1, Harbour Lights, 96 beats per minute, 4/4"
@Test func theTrackTimeReadsPlaceAndLength()          // trackTimeLabel(31.7, of: 222) == "0:31 / 3:42"
@Test func dotsAreLargerOnAccentedBeats()
// 4/4 accents {1,3}, width 134 -> diameters [12,8,12,8], gap 5
@Test func twelveDotsUseTheSmallSizes()
// 12/8 accents {1}, width 134 -> diameters[0] == 8, rest 5, gap 3
@Test func twelveAccentedDotsFitANarrowTile()
// 12/8 accents 1...12, width 107 (a 320 pt phone) -> layout.width <= 107, all diameters equal, gap < 3
@Test func dotsAreNotScaledUp()                       // 2/4, width 300 -> diameters [12,8], gap 5
```

- [ ] **Step 2: Run them and see them fail to compile**

Run: `scripts/test.sh -only-testing:MetronomeTests/StageModeTests`
Expected: build errors for `StageMode`, `StageTile` and `StageBeatDots`.

- [ ] **Step 3: Write `StageMode.swift`**

The label reuses `Song.spokenDescription` (`"\(number), " + song.spokenDescription` + state). `layout.width` is the sum of diameters plus gaps.

- [ ] **Step 4: Run the whole suite**

Run: `scripts/test.sh`
Expected: `** TEST SUCCEEDED **`, with the new tests in the count.

- [ ] **Step 5: Commit**

`git add Metronome/Model/StageMode.swift MetronomeTests/StageModeTests.swift`; subject `Add the rules of stage mode as a pure type`.

---

### Task 2: Stage mode in the model

**Files:**
- Modify: `Metronome/MetronomeModel.swift` (new `// MARK: - Stage mode`; `screenStaysAwake`; `becomeStopped()`; `loadSong` split)
- Test: `MetronomeTests/StageModeModelTests.swift` (new)

**Interfaces:**
- Consumes: Task 1's `StageMode`, `StageTile`.
- Produces on `MetronomeModel`:
  - `private(set) var stageMode: StageMode?`
  - `func canEnterStageMode(setlistID: UUID) -> Bool` = `StageMode.canEnter(songCount:isPlaying:)` for that setlist (false for a missing one).
  - `func enterStageMode(setlistID: UUID)`: does nothing unless `canEnterStageMode`; sets `stageMode = .entering(...)`. Changes nothing else.
  - `var stagePlayingSongID: UUID?`: the loaded song while `isPlaying`, stage mode is shown, `loadedFromSetlistID == stageMode.setlistID` and the song is in that setlist.
  - `var stageTiles: [StageTile]`: `stageMode.tiles(for: library.songs(inSetlist:), playingSongID: stagePlayingSongID, isPlaying: isPlaying)`, `[]` without stage mode.
  - `var canLeaveStageMode: Bool`
  - `func tapStageTile(_ songID: UUID)`: by `StageMode.tap`: `.start(id)` plays `haptics?.transport()`, loads with the new private `load(_:from:)` (`loadSong` minus its selection haptic and start; `loadSong` calls it and keeps its behaviour), sets `trackPosition = 0`, sets `stageMode?.nextSongID = id`, then `start()`. `.stop` plays `haptics?.transport()` and calls `stop()`. `.nothing` does nothing and plays nothing.
  - `func leaveStageMode()`: nil when `canLeaveStageMode`; otherwise nothing.
  - `screenStaysAwake` becomes `isPlaying || keepScreenAwake || stageMode != nil`.
  - In `becomeStopped()`, when `isPlaying` was true, stage mode is shown and the loaded song is in its setlist: `stageMode?.nextSongID = StageMode.following(loadedSong, in: setlist.songIDs)`. A start that throws reaches `becomeStopped()` with `isPlaying` false, so the tapped song stays next.

Decision: the move of the next mark lives in `becomeStopped()` because Stop, the engine stopping (interruption, route), the end of the track and `appDidLeaveForeground()` all pass through it.

- [ ] **Step 1: Write the failing tests**

In `StageModeModelTests.swift` (`@MainActor struct`; a `makeModel()` and `modelWithSetlist()` like `SongModelTests`' with songs A 96, B 120, C 168; the track cases use `TrackTestBench`, putting its song into a setlist):

```swift
@Test func enteringFromTheLoadedSetlistMarksTheLoadedSong()   // load B from setlist; enter -> next == B
@Test func enteringWithASongFromElsewhereMarksTheFirst()      // load B on its own; enter -> next == A
@Test func enteringChangesNothingOnTheMetronome()
// setBPM(130) after loading B; enter -> settings.bpm == 130, isEdited, loadedSongID == B, engine.startCount == 0
@Test func stageModeCannotBeEnteredWhilePlayingOrEmpty()
// playing -> stageMode == nil; empty setlist -> nil
@Test func aTapLoadsFromTheSetlistAndStarts()
// tap C -> loadedSongID == C, loadedFromSetlistID == setlist, isPlaying, engine.startCount == 1,
// stagePlayingSongID == C, haptics.transportCount == 1, haptics.selectionCount unchanged
@Test func aTapDropsAnotherSongsUnsavedEdits()                 // load A, setBPM(99), tap B -> settings.bpm == 120
@Test func theLoadedSongsOwnTileKeepsItsEdits()                // load A, setBPM(99), tap A -> settings.bpm == 99, isPlaying
@Test func tappingThePlayingTileStopsAndMarksTheFollowing()     // tap B, tap B -> !isPlaying, next == C
@Test func stoppingTheLastSongMarksNothing()                    // tap C, tap C -> next == nil
@Test func otherTilesDoNothingWhileOnePlays()                   // tap A, tap C -> loaded A, isPlaying, startCount 1
@Test func doneDoesNothingWhileATilePlays()                     // tap A, leave -> stageMode != nil; stop via tap; leave -> nil, loadedSongID == A
@Test func anInterruptionMarksTheFollowingSong()               // tap A; engine.onStopped?() -> !isPlaying, next == B, stageMode != nil
@Test func leavingTheForegroundMarksTheFollowingSong()         // tap A; appDidLeaveForeground() -> next == B
@Test func aFailedStartKeepsTheTappedTileNext()                 // engine.startError = ...; tap B -> !isPlaying, next == B
@Test func theScreenStaysAwakeWhileStageModeIsShown()           // keepScreenAwake off; enter -> screenStaysAwake; leave -> false
// with TrackTestBench:
@Test func aTileWithATrackCountsIn()
// tap the track song -> startedTracks.last.startTime < 0 (count-in), isPlayingTrack
@Test func theSameTileAgainStartsFromTheTop()
// tap, engine.trackTime = 80, tap (stop: trackPosition == 80), tap -> startedTracks.last.startTime < 0
@Test func theEndOfTheTrackMarksTheFollowingSong()              // tap; engine.onTrackEnded?() -> next == following
@Test func aMissingFilePlaysTheClickAlone()                     // missing: true; tap -> isPlaying, startedTracks empty
```

- [ ] **Step 2: Run them and see them fail**

Run: `scripts/test.sh -only-testing:MetronomeTests/StageModeModelTests`
Expected: build errors for `enterStageMode`, `tapStageTile` and the rest.

- [ ] **Step 3: Implement the stage-mode section, the `load(_:from:)` split, `screenStaysAwake` and the hook in `becomeStopped()`**

- [ ] **Step 4: Run the whole suite**

Run: `scripts/test.sh`
Expected: `** TEST SUCCEEDED **`; the existing `loadSong` tests and `screenStaysAwake*` tests still pass unchanged.

- [ ] **Step 5: Commit**

Subject `Play a setlist's songs from stage mode in the model`. Body: the next mark moves in becomeStopped so that interruptions and the end of a track move it too.

---

### Task 3: Stage mode following sync

**Files:**
- Modify: `Metronome/MetronomeModel.swift` (`exchangeWithCloud()`, `becomeStopped()`)
- Test: `MetronomeTests/SyncModelTests.swift`

**Interfaces:**
- Consumes: Task 2's `stageMode`, `stageTiles`, `stagePlayingSongID`, `canLeaveStageMode`.
- Produces: `private func closeStageModeIfItsSetlistIsGone()`: sets `stageMode = nil` when its setlist is missing or empty and `!isPlaying`. Called at the end of `exchangeWithCloud()` (after the state is taken) and of `becomeStopped()`.

- [ ] **Step 1: Write the failing tests**

In `SyncModelTests.swift`, with `twoDevicesSharingASong()`-style setup: A makes songs S1, S2, S3 and setlist L; B receives them and enters stage mode for L.

```swift
@Test func stageModeFollowsAReorderFromAnotherDevice()
// A reorders L to S3, S1, S2; send -> B.stageTiles.map(\.song.id) == [S3,S1,S2], numbers [1,2,3], next still S1
@Test func theNextMarkGoesWhenItsSongLeavesTheSetlist()   // A removes S1 -> no tile marked .next
@Test func stageModeClosesWhenItsSetlistIsDeletedElsewhere() // stopped; A deletes L -> B.stageMode == nil
@Test func stageModeClosesWhenItsSetlistIsEmptiedElsewhere() // A removes all three -> nil
@Test func stageModeClosesOnceStoppedWhenItsSetlistGoesWhilePlaying()
// B taps S1; A deletes L -> B.stageMode != nil, isPlaying, canLeaveStageMode; B.stop() -> nil
@Test func thePlayingSongLeavingTheSetlistLeavesDoneWorking()
// B taps S2; A removes S2 -> B.isPlaying, stagePlayingSongID == nil, canLeaveStageMode,
// every tile dimmed; tapStageTile(S1) changes nothing (loadedSongID == S2)
```

- [ ] **Step 2: Run them**

Run: `scripts/test.sh -only-testing:MetronomeTests/SyncModelTests`
Expected: the closing tests fail; the others may already pass on Task 2 (they pin behaviour the view relies on).

- [ ] **Step 3: Add `closeStageModeIfItsSetlistIsGone()` and its two calls**

- [ ] **Step 4: Run the whole suite**

Run: `scripts/test.sh`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

Subject `Close stage mode when its setlist goes on another device`.

---

### Task 4: The entry points and the presentation

**Files:**
- Modify: `Metronome/Views/HeaderMenuItems.swift`, `Metronome/Views/HeaderMenuButton.swift`, `Metronome/Views/SetlistViews.swift` (`SetlistHeader`), `Metronome/Views/LibrarySheet.swift` (`SongListView` passes the action, `close`), `Metronome/Views/MetronomeScreen.swift`
- Create: `Metronome/Views/StageModeView.swift` with a placeholder body (title row and `Done` only) so the presentation can be seen; Task 5 fills it.
- Test: `MetronomeTests/HeaderMenuItemsTests.swift`

**Interfaces:**
- Consumes: Task 2's `enterStageMode(setlistID:)`, `canEnterStageMode(setlistID:)`, `stageMode`, `leaveStageMode()`.
- Produces:
  - `HeaderMenuItems.Item.stageMode`; `init(hasSong: Bool, isEdited: Bool, hasSetlist: Bool = false)`: with a song and `hasSetlist`, groups are `[[...song group], [.unload], [.stageMode], [.settings]]` (after Save changes / Revert when edited); `hasSetlist` without a song changes nothing.
  - `SetlistHeader` gains `let stageMode: () -> Void` and `let canEnterStageMode: Bool`; the menu's first item is `Label("Stage mode", systemImage: "music.mic")` disabled by `!canEnterStageMode`, then `Divider()`, then Select and the rest.
  - `struct StageModeView: View` (environment `MetronomeModel`).

Behaviour:
- Header menu: `HeaderMenuItems(hasSong:isEdited:hasSetlist: model.position != nil)`. The item calls `model.enterStageMode(setlistID:)` with `loadedFromSetlistID`, `.disabled(model.isPlaying)`.
- Setlist menu: `stageMode` calls `model.enterStageMode(setlistID:)` then `close()` (the library's `dismiss()`); `canEnterStageMode: model.canEnterStageMode(setlistID:)`.
- `MetronomeScreen` keeps `@State private var isStageShown = false` and `.fullScreenCover(isPresented: $isStageShown) { StageModeView().environment(model) }`. It sets `isStageShown = true` when `model.stageMode` becomes non-nil while no sheet is shown (`onChange(of: model.stageMode != nil)`), and from the library sheet's `onDismiss` when `model.stageMode != nil`; it sets it false when `model.stageMode` becomes nil. Presenting while the sheet is still closing is dropped by SwiftUI, which is why the sheet's `onDismiss` does it for that path.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func aSetlistSongOffersStageModeBeforeSettings()
// HeaderMenuItems(hasSong: true, isEdited: false, hasSetlist: true).groups ==
// [[.editSong, .saveAsNewSong, .addToSetlist], [.unload], [.stageMode], [.settings]]
@Test func anEditedSetlistSongKeepsSaveFirst()
// (true, true, true) == [[.saveChanges, .revert], [.editSong, .saveAsNewSong, .addToSetlist], [.unload], [.stageMode], [.settings]]
@Test func nothingLoadedNeverOffersStageMode()   // (false, false, true) == [[.saveAsNewSong], [.settings]]
```

The existing four tests keep passing with the default `hasSetlist: false`.

- [ ] **Step 2: Run them and see them fail**

Run: `scripts/test.sh -only-testing:MetronomeTests/HeaderMenuItemsTests`
Expected: build error for `hasSetlist` and `.stageMode`.

- [ ] **Step 3: Implement the item, the setlist menu item, the placeholder view and the presentation**

- [ ] **Step 4: Build and run the suite**

Run: `scripts/build.sh` then `scripts/test.sh`
Expected: `** BUILD SUCCEEDED **`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Look at it in the simulator**

On the iPhone 17 Pro simulator with `-screenshotScene setlist`: the setlist's menu with Stage mode first and a divider; tapping it closes the library and shows the placeholder full screen, ten times in a row (Review Focus 4); `Done` returns. On the metronome screen with a setlist song (`-screenshotScene edited`): the menu with Stage mode before Settings; while playing it is dimmed; for a song loaded on its own (`-screenshotScene trackSolo`) it is absent. An empty setlist's Stage mode is dimmed. Report what was and was not seen.

- [ ] **Step 6: Commit**

Subject `Open stage mode from the header menu and a setlist's menu`.

---

### Task 5: The stage mode screen

**Files:**
- Modify: `Metronome/Views/StageModeView.swift`
- Create: `Metronome/Views/StageTileView.swift` (`StageTileView`, `StageBeatDotsView`)
- Modify: `Metronome/Screenshots/ScreenshotScene.swift`, `Metronome/Views/MetronomeScreen.swift` (scene hook)
- Test: none new; the rules are Task 1's and Task 2's. Verified by build and simulator.

**Interfaces:**
- Consumes: `model.stageTiles`, `model.canLeaveStageMode`, `model.tapStageTile(_:)`, `model.leaveStageMode()`, `model.currentBeat`, `model.settings`, `model.isPlayingTrack`, `model.trackTime`, `model.trackLength`, `StageBeatDots.layout`, `StageTile.trackTimeLabel`, `ScreenLayout.narrowWidth` / `narrowSideMargin`, `Theme`.
- Produces:
  - `struct StageTileView: View { let tile: StageTile; let tap: () -> Void }`
  - `ScreenshotScene.stage` (the `setlist` sample, stage mode entered at launch for the sample setlist) and `ScreenshotScene.stagePlaying` (as `trackSyncTimer`'s timer engine with `clocksTrack: true`, stage mode entered and the track song's tile tapped at launch), neither an App Store screenshot.

Layout (spec 9.4): `Theme.ink` background; the title row as `SyncModeHeader` but 20 pt heavy name and 48 pt tall, 6 pt from the safe-area top, `Done` `.disabled(!model.canLeaveStageMode)` and at 0.4 opacity then. A `ScrollView` with a two-column `LazyVGrid` (`spacing: 10`, `GridItem(.flexible(), spacing: 10)` twice), 20 pt top padding, 16 pt bottom padding, side margin 24 pt or 16 pt below 360 pt. Each tile `.frame(minHeight: 112, maxHeight: .infinity)` so that a row with a two-line name grows both tiles; check it comes out 120 pt. The tile acts on `.rowTap` (a tap alone; a drag scrolls) and is one accessibility element with `tile.accessibilityLabel`, `.isButton`, and `.disabled(tile.isDimmed)` so it reads as dimmed. The playing tile's beat dots and the track time sit inside a `TimelineView(.animation(minimumInterval: 0.1, paused: !model.isPlaying))` as the progress bar does, since `trackTime` is not observed; the dots read `model.currentBeat` and light without animation. Glow: `Theme.amber.opacity(0.28)` shadow, radius 14. The track time shows only while `model.isPlayingTrack` and `model.trackLength != nil`; otherwise the mark, in ink on the playing tile.

- [ ] **Step 1: Write `StageTileView` and fill `StageModeView`**

- [ ] **Step 2: Add the `stage` and `stagePlaying` scenes**

- [ ] **Step 3: Build and run the suite**

Run: `scripts/build.sh` then `scripts/test.sh`
Expected: `** BUILD SUCCEEDED **`, `** TEST SUCCEEDED **`.

- [ ] **Step 4: Look at it in the simulator**

On the iPhone 17 Pro with `-screenshotScene stage` and `-screenshotScene stagePlaying`, and on an iPhone SE: compare with the three boards (title row, tile sizes and colours, `NEXT`, the playing tile's glow, dots and time); a long name on two lines with its row at 120 pt (rename a song first); 12/8 with all beats accented on the SE with Display Zoom if available; taps starting and stopping, the next mark moving, other tiles and `Done` doing nothing while playing; a scroll starting on a tile not starting it; the screen not locking (read the idle-timer flag as the Keep screen awake note in section 14 did). Report what was and was not seen; sync changes cannot be seen on one simulator, and VoiceOver is not run by anyone.

- [ ] **Step 5: Commit**

Subject `Draw stage mode's tiles, beat dots and track time`.

---

### Task 6: Sections 14 and 15

**Files:**
- Modify: `docs/specification.md` (sections 14 and 15 only)

- [ ] **Step 1: Update the Stage mode lines in section 14**

For each line, tick it only when a unit test covers it or it was seen in the simulator (Tasks 2 to 5's reports), and replace `*(Not built yet.)*` with a note naming the tests and what was seen, and what was not (VoiceOver, a real iPhone, two devices). Split a line when only part of it is verified.

- [ ] **Step 2: Update section 15**

Drop the Stage mode entry once every part of it is built. With no entry left, the list goes and the first line is followed by `Every part specified above is built.`

- [ ] **Step 3: Check the wording**

Run: `git diff -U0 -- docs/specification.md`
Expected: no history wording ('now', 'previously', 'no longer', 'new' for a change), and only sections 14 and 15 changed.

- [ ] **Step 4: Commit**

Subject `Record what was verified of stage mode`.

---

## Self-review notes

- Spec 9.4 Entering: Tasks 2 and 4. Layout: Task 5. Playing: Task 2 (rules) and Task 5 (taps). Leaving and staying awake: Task 2. Changes from other devices: Task 3. 7.5 mute: nothing to build (no mute button). 12 haptic: Task 2 (`aTapLoadsFromTheSetlistAndStarts` counts transport and no selection). 13 VoiceOver: Task 1 (labels) and Task 5 (traits).
- `loadSong` today plays a selection tick on every load, which section 12 does not list; stage mode's tile skips it through the `load(_:from:)` split, and `loadSong` itself is left as it is.
- No task touches `LibraryState`, sync records or the format number.
