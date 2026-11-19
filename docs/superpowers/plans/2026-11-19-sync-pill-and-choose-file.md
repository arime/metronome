# Sync Pill and Choose File Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On the track screen, move Sync into a pill on the player card, drop the Sync row so the dial is exactly the plain screen's size, let a missing track's file be chosen from the card, and let a picked file rename the track.

**Architecture:** `TrackScreenLayout` stops fitting its own dial and takes the dial's diameter, the tile height, the gap and the next-up decision from `ScreenLayout`, the plain screen's layout. The model gains one function that stores a file for the loaded song's missing track at once; it and `editSong` share the rule for a pick that renames the track. The player card's file-name row ends in one pill: `Sync`, or `Choose file` while the file is missing.

**Tech Stack:** Swift, SwiftUI, Swift Testing. Xcode project `Metronome.xcodeproj`, scheme `Metronome`. File-system synchronised groups: new files need no project edit.

**Spec:** `docs/specification.md` on this branch: 5.1 (the file and iCloud), 6.8, 6.12 (track screen, player card, Missing file, Small screens), 6.13, 7.9, 7.10, 7.11, 10.3, 13, 14, 15. Design boards: Paper file "Snappy Metronome", page *Track screen with dial (draft)*, boards *Track — dial as gauge, Sync in the card* and *Track — file missing, Choose file*.

## Global Constraints

- Work only in the worktree `/Users/arime/metronome/.claude/worktrees/screen-menu` on branch `screen-menu`. Never switch the main checkout.
- Build with `scripts/build.sh`, test with `scripts/test.sh`. A task is not done until `scripts/test.sh` ends with `** TEST SUCCEEDED **` and no `warning:` line from files this plan touches.
- Colours only from `Theme`.
- UI copy, exactly: `Sync`, `Choose file`. Alerts, exactly as the song sheet has them: `This file can't be played` and `The track couldn't be saved`, each with `OK`.
- The pills (spec 6.12): fully rounded, `Theme.surfaceRaised`, 30 pt tall, label 13 pt semibold in `Theme.dialWhite`, touch area at least 44 pt tall, 8 pt after the file name. `Sync` has 14 pt padding at the sides, `Choose file` 12 pt.
- Track screen stack (spec 6.12): header 48 pt, 12 pt, the dial, 26 pt (16 pt in the plain layout's compact step), the accent tiles, the spare height (never less than 16 pt), the player card 192 pt (222 pt with the next-up line). The dial's diameter, the single-row tile height and whether the next-up line shows are the plain layout's for the same screen, beats and setlist.
- VoiceOver, exactly (spec 13): the file-name row reads `Backing track, <file name>`, or `Track missing, <file name>` while the file is missing; the pills read `Sync` and `Choose file`, as buttons.
- A file picked for a missing track (spec 5.1, 10.3): stored under the identifier the track already has. Same name as the track carries: the part is not changed and nothing is sent. Another name: the part takes that name and syncs; its identifier, tempo, offset, count-in and mix stay. The song does not become edited either way.
- Shell: single quotes, no `cd` before git, no `git -C`, no command substitution, no backticks in commit messages.
- Commits: imperative subject, capitalised, no trailing period, at most 72 characters, no Conventional Commits prefix, no Claude attribution. Write the message to a scratch file and commit with `git commit -F <file>`.
- Spec section 14: tick a line only when every claim in it is covered by a named unit test or was seen in the simulator; otherwise leave it unticked with a note saying which part is covered. Remove an entry from section 15 only when it is built.

## Review Focus

1. **A file chosen from the card while the track's click is playing.** Playback must stop and the position be 0:00, the card then showing its usual state. Pinned in Task 1.
2. **A file that cannot be stored (the phone is full).** Nothing changes: the track is still missing, its name is unchanged, and the user is told. Pinned in Task 1; the alert in Task 3.
3. **Choose file when the track is not missing** (the file arrived, or the song changed, while the picker was open). The pick must not replace a file that is there or attach a track to another song. Pinned in Task 1.
4. **The smallest phones.** The card and tiles must fit under the plain screen's dial on every screen where the plain layout fits, with at least 16 pt above the card. Pinned in Task 2's sweep.
5. **A long file name beside a pill.** The name is cut with an ellipsis; the pill keeps its full width and is never pushed off the card. Seen in the simulator in Task 3.

---

### Task 1: Model: a picked file renames the track, and a pick from the card

**Files:**
- Modify: `Metronome/MetronomeModel.swift` (`editSong`, about line 914; a new function beside it)
- Modify: `Metronome/Views/SongSheetChanges.swift` (`TrackRowState.init`, about lines 36 to 52)
- Test: `MetronomeTests/TrackSongModelTests.swift`, `MetronomeTests/SongSheetChangesTests.swift`

**Interfaces:**
- Produces: `@discardableResult func chooseFileForLoadedTrack(_ picked: PickedTrack) -> Bool` on `MetronomeModel`. Returns false only when the file cannot be stored. Returns true and does nothing when no song is loaded, the loaded song has no track, or its file is on this device.

- [ ] **Step 1: Write the failing tests.** Read `MetronomeTests/TrackTestBench.swift` and the existing tests `pickingAFileForAMissingTrackChangesNoPart` and `pickingAFileForAMissingTrackKeepsItsTempo` first, and build the new ones from the same helpers. In `TrackSongModelTests`:
  - Rename `pickingAFileForAMissingTrackChangesNoPart` to `pickingAFileWithTheSameNameForAMissingTrackChangesNoPart` and make its picked file carry the track's own file name; keep its assertions that the part and its change time are untouched.
  - `pickingAFileWithAnotherNameRenamesTheTrackAndKeepsTheRest`: a missing track, `editSong` with a picked file of another name. Assert the track's `fileName` is the picked name; its `fileID`, `bpm`, `offset`, `countIn` and `mix` are unchanged; the part's change time is the edit's time; the song's settings part is untouched.
  - `choosingAFileFromTheCardStoresItAtOnce`: a loaded song with a missing track, Backing tracks on, stopped. After `chooseFileForLoadedTrack` with a same-named file: it returned true, `isTrackMissing` is false, `isTrackPlayable` is true, `trackPosition` is 0, `isEdited` is false and `isSaveOffered` is false, and the part is unchanged.
  - `choosingAFileWithAnotherNameFromTheCardRenamesTheTrack`: as above with another name: `loadedTrack?.fileName` is the picked name and the other five properties are unchanged; `isEdited` is false.
  - `choosingAFileWhilePlayingStopsPlayback`: playing with the file missing, Backing tracks on; after the call `isPlaying` is false and `trackPosition` is 0.
  - `choosingAFileThatCannotBeStoredChangesNothing`: with the bench's unstorable file the call returns false, `isTrackMissing` is still true and the track's `fileName` is unchanged.
  - `choosingAFileWhenTheTrackIsNotMissingDoesNothing`: a loaded song with a playable track, and separately no song loaded: the call returns true and the stored file, the part and playback are unchanged.

  In `SongSheetChangesTests`, replace `aFilePickedForAMissingTrackKeepsTheSavedName` with `aFilePickedForAMissingTrackShowsThePickedName`: the row's state shows the picked file's name.

- [ ] **Step 2: Run and see them fail**

Run: `scripts/test.sh -only-testing:MetronomeTests/TrackSongModelTests -only-testing:MetronomeTests/SongSheetChangesTests`
Expected: build error for `chooseFileForLoadedTrack`.

- [ ] **Step 3: Implement.**
  - One private helper holds the rule for a file picked for a missing track: store it under the track's `fileID` (fail if it cannot be stored) and return the track with the picked `fileName` when the names differ, or no change when they are the same. `editSong`'s `.attach` branch for a missing track uses it, setting `newPart` only for a rename.
  - `chooseFileForLoadedTrack` uses the same helper. On success: with Backing tracks on, `stop()` when playing; `library.setTrack` only for a rename; `loadedTrackReplaced(replacing:)` so the file is found and the position is 0:00; `persistLibrary()`. It never touches the song's settings.
  - `TrackRowState`: a file picked for a missing track shows the picked file's name.
  - Update the doc comments on `editSong` and `TrackRowState` to the new rule.

- [ ] **Step 4: Run the tests**

Run: `scripts/test.sh`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

Subject: `Let a picked file rename a missing track, and pick from the card`

---

### Task 2: The track screen's dial at the plain screen's size, without the Sync row

**Files:**
- Modify: `Metronome/Views/TrackLayouts.swift` (`TrackScreenLayout`)
- Modify: `Metronome/Views/TrackScreen.swift` (`TrackScreenContent`; delete `SyncRow`)
- Test: `MetronomeTests/TrackLayoutTests.swift`

**Interfaces:**
- Produces: `TrackScreenLayout` with `sideMargin`, `bottomPadding`, `dialDiameter`, `tilesTopGap`, `tileHeight`, `tilesHeight`, `cardHeight`, `showsNextLine`. It no longer has `rowTopGap`, `rowBottomGap`, `rowHeight`, `minimumDial` or `nextLineMinimumDial`.

- [ ] **Step 1: Write the failing tests.** In `TrackLayoutTests`, replace the track screen tests (every test from `theTrackScreenOnAnIPhone17Pro` to `theTrackScreenFillsTheHeightOrLeavesSpareAboveTheCard`) with these. Leave the Sync mode tests alone.

```swift
@Test func theTrackScreenOnAnIPhone17Pro() {
    let layout = trackScreen(width: 402, height: 778, hasBottomInset: true, hasSetlist: true)
    #expect(layout.dialDiameter == 340)
    #expect(layout.showsNextLine)
    #expect(layout.cardHeight == 222)
    #expect(layout.tilesTopGap == 26)
    #expect(layout.tileHeight == 76)
    #expect(trackScreen(width: 402, height: 778, hasBottomInset: true, beats: 9, hasSetlist: true).dialDiameter == 332)
    #expect(trackScreen(width: 402, height: 778, hasBottomInset: true).dialDiameter == 340)
}

@Test func theTrackScreenOnAnIPhoneSE() {
    let layout = trackScreen(height: 647, hasSetlist: true)
    #expect(layout.dialDiameter == 243)
    #expect(layout.showsNextLine)
    #expect(layout.cardHeight == 222)
    #expect(layout.tilesTopGap == 16)
    #expect(layout.tileHeight == 56)
    #expect(trackScreen(height: 647, beats: 9, hasSetlist: true).dialDiameter == 201)
    #expect(trackScreen(height: 647).dialDiameter == 275)
}

@Test func theTrackScreenWithDisplayZoom() {
    let layout = trackScreen(width: 320, height: 548, hasSetlist: true)
    #expect(layout.dialDiameter == 176)
    #expect(layout.showsNextLine == false)
    #expect(layout.cardHeight == 192)
    #expect(trackScreen(width: 320, height: 548, beats: 9, hasSetlist: true).dialDiameter == 134)
}

@Test func theTrackScreenTakesItsSizesFromThePlainLayout() {
    for width in [CGFloat(320), 375, 402] {
        for height in stride(from: CGFloat(548), through: 900, by: 13) {
            for beats in [2, 4, 7, 9, 12] {
                for hasSetlist in [false, true] {
                    for hasBottomInset in [false, true] {
                        let plain = ScreenLayout(
                            width: width, height: height, hasBottomInset: hasBottomInset, beats: beats, hasSetlist: hasSetlist
                        )
                        let track = trackScreen(
                            width: width, height: height, hasBottomInset: hasBottomInset, beats: beats, hasSetlist: hasSetlist
                        )
                        #expect(track.dialDiameter == plain.dialDiameter)
                        #expect(track.tileHeight == plain.tileHeight)
                        #expect(track.showsNextLine == plain.showsNextLine)
                        #expect(track.tilesTopGap == plain.settingsTopGap)
                        #expect(track.sideMargin == plain.sideMargin)
                        #expect(track.bottomPadding == plain.bottomPadding)
                    }
                }
            }
        }
    }
}

@Test func theCardAlwaysHasAtLeast16AboveIt() {
    for width in [CGFloat(320), 375, 402] {
        for height in stride(from: CGFloat(548), through: 900, by: 13) {
            for beats in [2, 4, 7, 9, 12] {
                for hasSetlist in [false, true] {
                    for hasBottomInset in [false, true] {
                        let layout = trackScreen(
                            width: width, height: height, hasBottomInset: hasBottomInset, beats: beats, hasSetlist: hasSetlist
                        )
                        let used = TrackScreenLayout.headerHeight + TrackScreenLayout.dialTopGap + layout.dialDiameter
                            + layout.tilesTopGap + layout.tilesHeight + TrackScreenLayout.cardTopGap + layout.cardHeight
                            + layout.bottomPadding
                        #expect(used <= height)
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Run and see them fail**

Run: `scripts/test.sh -only-testing:MetronomeTests/TrackLayoutTests`
Expected: build error for `tilesTopGap`.

- [ ] **Step 3: Rewrite `TrackScreenLayout.init`.** It makes a `ScreenLayout` with its own arguments and takes from it `sideMargin`, `bottomPadding`, `dialDiameter`, `tileHeight`, `showsNextLine` and, as `tilesTopGap`, its `settingsTopGap`. `cardHeight` is 192, plus 30 when the next-up line shows; `tilesHeight` is the tiles' height at `tileHeight`. Keep the constants `headerHeight`, `dialTopGap`, `cardTopGap`, `playerCardHeight`, `playerNextLineHeight`; remove the rest and the fitting code. Rewrite the doc comment: the track screen takes its sizes from the plain layout, which always leaves room, as the card and tiles need less height than the plain screen's parts below its dial.

  If `theCardAlwaysHasAtLeast16AboveIt` fails for some input, stop and report the input; do not change `ScreenLayout`.

- [ ] **Step 4: The screen.** `TrackScreenContent` is, from the top: `TrackDial` with 12 pt above it, `AccentTiles(singleRowTileHeight: layout.tileHeight)` with `layout.tilesTopGap` above it, `Spacer(minLength: TrackScreenLayout.cardTopGap)`, `PlayerCard`. Delete `SyncRow`. Update the file's doc comments, including `TrackDial`'s, which mentions the row.

- [ ] **Step 5: Run the tests**

Run: `scripts/test.sh`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: See it in the simulator** on an iPhone 17 Pro: scenes `trackScreen` and `trackSolo`, and `edited` for the plain screen. Save screenshots to the scratchpad. Check: no Sync row; the dial on the track screen is the same size and at the same height as on the plain screen (measure both in the screenshots and report the numbers); the tiles sit 26 pt below the dial; the card is at the bottom.

- [ ] **Step 7: Commit**

Subject: `Size the track screen's dial as the plain screen's, without a row`

---

### Task 3: Sync and Choose file on the player card

**Files:**
- Modify: `Metronome/Views/TrackControls.swift` (`PlayerCard.fileNameRow`)
- Modify: `Metronome/Model/PickedFileReader.swift` and `Metronome/Views/SongSheet.swift` (only to share the reading step, see Step 1)

**Interfaces:**
- Consumes: `MetronomeModel.chooseFileForLoadedTrack(_:)` (Task 1), `model.enterSyncMode()`, `model.isTrackMissing`, `model.loadedTrack?.fileName`, `PickedFileReader`.
- Produces: `PickedFileReader.readInBackground(_ url: URL) async -> Result<PickedTrack, Error>?`: copies and reads a picked file away from the main actor; nil when the task was cancelled, in which case any copy it made is discarded.

- [ ] **Step 1: Share the reading step.** `SongSheet` reads a picked file in a `.task(id:)` with `Task.detached` and discards the copy when cancelled. Move exactly that into `PickedFileReader.readInBackground` and call it from `SongSheet`, without changing what the sheet does.

- [ ] **Step 2: The row.** In `PlayerCard.fileNameRow`: the music-note icon; the track's file name taking the space left, one line, cut at the tail, in `Theme.dialWhite`, or in `Theme.amber` while the file is missing (the card does not say `Track missing`); then one pill as in Global Constraints: `Sync`, calling `model.enterSyncMode()`, or `Choose file` while the file is missing. The name's accessibility label is `Backing track, <name>` or `Track missing, <name>`; the pills are ordinary buttons with their titles as labels. The row stays 30 pt tall and the card's size does not change.

- [ ] **Step 3: Choosing a file.** `Choose file` opens `.fileImporter` for `.audio`. A picked URL is read with `PickedFileReader.readInBackground`; while it is read the pill is disabled. On success call `model.chooseFileForLoadedTrack`, then discard the reader's copy as `SongSheet` does after a save; when the model returns false show the alert `The track couldn't be saved`. When the file cannot be read show `This file can't be played`. Closing the picker without choosing shows nothing. Keep this in one small private view in `TrackControls.swift`.

- [ ] **Step 4: Build and test**

Run: `scripts/test.sh`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: See it in the simulator** on an iPhone 17 Pro, comparing with spec 6.12 and the two Paper boards:
  1. `trackScreen`: the file name and the `Sync` pill at the row's right end; a tap on the pill opens Sync mode; a tap on the dial still does.
  2. `trackMissing`: the file name in amber, `Choose file` in the pill's place, no `Track missing` text; the bar, Rewind and Fast-forward dimmed; a tap on the dial does nothing.
  3. `Choose file` opens the Files picker; closing it changes nothing.
  4. If a file can be picked in the simulator's Files app, pick one: the card shows its usual state with the picked file's name. If not, say so.
  5. A long file name is cut with an ellipsis and the pill keeps its place (edit a scene's file name locally to check, without committing that).

- [ ] **Step 6: Commit**

Subject: `Put Sync and Choose file on the player card`

---

### Task 4: Specification checklist

**Files:**
- Modify: `docs/specification.md` (sections 14 and 15 only)

- [ ] **Step 1:** For each line in section 14 about the track screen's layout and fit, the player card's row, entering Sync mode, the missing-file state, `Choose file`, a picked file renaming the track, and the VoiceOver readings this plan changed: tick it only if every claim was covered by a named unit test or seen in a simulator step of Tasks 1 to 3, and rewrite its note to say which tests and what was seen. Leave unticked, with a note, anything not tried.

- [ ] **Step 2:** Remove from section 15 the entries this plan built.

- [ ] **Step 3: Commit**

Subject: `Tick what is verified for the player card's pills`
