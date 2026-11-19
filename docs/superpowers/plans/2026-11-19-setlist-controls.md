# Setlist Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give a setlist's view the tabs' controls line (search and +) in place of its Add song row, a select mode with Add to setlist and Remove (with one Undo for the group), and give the Add song screen a search field.

**Architecture:** Removing several songs with one Undo, and the numbering of rows found by a search, are model code with pure, unit-tested functions; `MetronomeModel` keeps owning the setlist changes. The views reuse the Songs tab's parts (`ControlsLine`, `SearchField`, `AddButton`, `SelectHeader`, `SelectActionBar`, `SelectionTick`, `SongSelection`), generalised where they are Songs-tab-only today. `SongListView` in `LibrarySheet.swift` keeps drawing both the Songs tab and a setlist; to make room in that 987-line file, the row views move out to a new file first.

**Tech Stack:** Swift, SwiftUI, Swift Testing. Build with `scripts/build.sh`, test with `scripts/test.sh` (extra arguments go to xcodebuild, e.g. `scripts/test.sh -only-testing:MetronomeTests/SetlistSearchTests`). New files need no project edit: the project uses file-system synchronised groups.

**Spec:** `docs/specification.md`, sections 2, 5, 5.1 (only to confirm nothing new syncs), 7.9, 8 (intro), 8.1, 8.2, 8.3, 8.5, 8.7, 8.8, 9.2, 9.3, 13, 14, 15, and the intro paragraph about the Paper page *Setlist controls (draft)*. Read them before each task; the spec's sizes, colours and copy are binding. The Paper boards *Setlist — search and +*, *Setlist — searching*, *Setlist — select mode* and *Add song — search* draw the result; where they and the spec differ, the spec holds.

## Global Constraints

- Work only in `/Users/arime/metronome/.claude/worktrees/setlist-controls` on branch `setlist-controls`. Never switch branches, never push.
- The iCloud format number stays 2 and nothing new is synced. `SongRecord`, `SetlistRecord`, `LibrarySync`, `LibraryState` and their coding keys do not change. A group removal and its Undo are ordinary membership and order changes made through the existing `Library.remove`, `Library.add` and `Library.reorder`.
- UI copy exactly as in the spec: `Select`, `Add song`, `Rename setlist`, `Duplicate setlist`, `Delete setlist`, `Select songs`, `3 selected`, `Done`, `Add to setlist`, `Remove`, `New setlist`, `Search`, `No matches`, `Removed <song name>`, `Removed 3 songs`, `Undo`. VoiceOver names: `Search this setlist`, `Add song` (the setlist's +), `Search songs` (the Add song screen's field), `Clear search`, `Remove`. Terse UI copy: no explanatory footnotes, hints or helper lines on screen; the names say it.
- Colours and sizes only from `Theme` and the spec; no new colour literals. Remove is `Theme.dialWhite`, not red.
- Shell: single quotes, no `$(...)`, no backticks, no `cd` before git, no backslash line continuations. Read files with the Read tool.
- Commits: write the message to a file in the scratchpad named in your brief and run `git commit -F <file>`. Imperative, capitalised subject of at most 72 characters, no trailing period, no Conventional Commits prefix, body wrapped at 72 explaining why, no backticks, no attribution lines of any kind.
- Spec changes go where they belong (8.3 the setlist view, 8.5 Undo, 8.8 a setlist's select mode, 9.3 Add song, 13 VoiceOver); this plan needs none beyond section 14 and 15 updates, and any wording a task finds wrong is fixed in its own section, every mention brought in line.
- `docs/specification.md` is one living document: no history wording ('no longer', 'previously', 'now', 'was moved', 'new' for a change). In section 14 tick an item only when a unit test covers it or it was seen in the simulator, and say which in its note, as the existing items do; split an item when only part of it is verified. Remove from section 15 only what is built.
- Never read `.env.*` or `.appsettings.*` files.

## Review Focus

1. **Undo after a group removal when the setlist changed meanwhile** (a song added, or one of the removed songs deleted from the library): the songs still in the library go back at the end in the order they had, and nothing is duplicated. Pinned in Task 1 (`undoingSeveralAfterTheSetlistChangedPutsThemAtTheEnd`, `undoingSeveralSkipsASongDeletedMeanwhile`).
2. **The loaded song removed as part of a group**: it stays loaded on its own, and Undo brings back its position and Previous / Next; a removed song that was not the loaded one must not give the loaded song a setlist. Pinned in Task 1 (`removingSeveralKeepsTheLoadedSongLoadedOnItsOwn`, `undoingSeveralBringsBackTheLoadedSongsPlace`).
3. **Position numbers during a search after a removal**: found rows carry their number in the setlist as it is now, not as it was. Pinned in Task 1 (`numbersFollowTheSetlistAfterARemoval`).
4. **A ticked song that leaves the setlist through sync during select mode** must leave the ticks and the title's count; the view must watch the setlist's members, not the library's songs, or a song taken out of the setlist but still in the library stays ticked. Pinned in Task 3 (`aTickedSongTakenOutElsewhereLeavesTheSelection`, against the in-memory iCloud stand-in).
5. **Add to setlist when every ticked song is already in the target**: the target is left exactly as it was (no reorder, no new times, nothing sent). Pinned in Task 3 (`addingSongsThatAreAllThereChangesNothing`).

---

### Task 1: Removing several songs, with one Undo, and numbered search rows

**Files:**
- Create: `Metronome/Model/SetlistSearch.swift`
- Modify: `Metronome/MetronomeModel.swift` (`SetlistRemoval`, `removeSong(_:fromSetlist:)`, `undo(_:)`, near lines 1115-1152), `Metronome/Views/LibrarySheet.swift` (the `UndoBar` call reads `removal.text`)
- Test: `MetronomeTests/SongModelTests.swift`, `MetronomeTests/SetlistSearchTests.swift` (new)

**Interfaces:**
- Consumes: `Library.remove`, `Library.add`, `Library.reorder`, `Song.matches(search:)`.
- Produces:
  - `MetronomeModel.SetlistRemoval: Equatable` becomes `{ let songIDs: [UUID]; let firstSongName: String; let setlistID: UUID; let order: [UUID]; let loadedSongID: UUID?; var text: String }`. `songIDs` are in the setlist's order whatever order they were asked in. `loadedSongID` is set only when the loaded song is among them and was loaded from this setlist. `text` is `Removed <first song name>` for one song and `Removed \(count) songs` otherwise.
  - `MetronomeModel.removeSongs(_ songIDs: [UUID], fromSetlist setlistID: UUID) -> SetlistRemoval?` (`@discardableResult`): takes out those of the songs that are in the setlist, saves once; nil when none is in it. A removed loaded song loaded from this setlist is then loaded on its own (as `setSong(_:inSetlist:included: false)` does today; do it without its per-song save).
  - `MetronomeModel.removeSong(_:fromSetlist:)` keeps its signature and calls `removeSongs([songID], fromSetlist:)`.
  - `MetronomeModel.undo(_:)`: does nothing when the setlist is gone or none of `songIDs` is still in the library; otherwise adds each of `songIDs` still in the library, in that order, then `library.reorder(setlist:to: removal.order)` (which refuses when the setlist changed meanwhile, leaving them at the end), then gives `loadedSongID` its setlist back when it is still the loaded song and has no loaded-from setlist; saves once.
  - `struct NumberedSong: Identifiable, Equatable { let number: Int; let song: Song; var id: UUID { song.id } }`
  - `enum SetlistSearch { static func rows(_ songs: [Song], matching query: String) -> [NumberedSong] }`: numbers each song by its 1-based place in `songs`, then keeps those matching `query` by `Song.matches(search:)`.

Decision: the group Undo keeps today's single-song rule that a song deleted from the library meanwhile does not come back (spec 8.5); its absence makes the old order invalid, so the rest go back at the end.

- [ ] **Step 1: Write the failing tests**

In `SetlistSearchTests.swift` (build songs with `Song(id: UUID(), name:, settings: MetronomeSettings())`):

```swift
@Test func anEmptySearchNumbersEverySong()
// songs A, B, C; rows(_, matching: "") -> numbers [1, 2, 3], names ["A", "B", "C"]
@Test func foundRowsKeepTheirPlaceInTheWholeSetlist()
// "Harbour Lights", "Copper Sky", "Seven Bridges", "Midnight Ferry", "Waltz for June",
// "Slow Burn", "Northern Line", "Last Orders"; matching "li" ->
// [(1, "Harbour Lights"), (7, "Northern Line")]
@Test func spacesOnlyFindEverySong()          // matching "   " -> all three, numbered 1...3
@Test func nothingFoundGivesNoRows()          // matching "zz" -> []
@Test func matchingIgnoresCaseAndAccents()    // "Häät" found by " HAAT " as number 1
```

In `SongModelTests.swift` (use `modelWithSetlist()`: Slow, Mid, Fast):

```swift
@Test func removingASongFromASetlistCanBeUndoneInPlace()   // existing; replace songName with
// removal?.text == "Removed Mid"
@Test func removingSeveralSongsCanBeUndoneInPlace()
// removeSongs([fast, slow]) -> setlist ["Mid"]; removal.songIDs == [slow, fast];
// removal.text == "Removed 2 songs"; undo -> ["Slow", "Mid", "Fast"]
@Test func removingSongsNotInTheSetlistGivesNothingToUndo()
// a song "Other" not in the setlist: removeSongs([other]) == nil;
// removeSongs([other, mid]) -> songIDs == [mid], text == "Removed Mid"
@Test func removingSeveralKeepsTheLoadedSongLoadedOnItsOwn()
// loadSong(mid, from: setlist); removeSongs([slow, mid]) -> loadedSongID == mid,
// loadedFromSetlistID == nil, position == nil, headerSubtitle == nil
@Test func undoingSeveralBringsBackTheLoadedSongsPlace()
// as above, then undo -> loadedFromSetlistID == setlist, position?.index == 1, count == 3
@Test func removingSeveralWithoutTheLoadedSongLeavesItsSetlist()
// loadSong(mid, from: setlist); removeSongs([slow, fast]) -> loadedFromSetlistID == setlist,
// removal.loadedSongID == nil, position?.index == 0, count == 1
@Test func undoingSeveralAfterTheSetlistChangedPutsThemAtTheEnd()
// removeSongs([slow, mid]); then add a new song "New" to the setlist; undo ->
// ["Fast", "New", "Slow", "Mid"]
@Test func undoingSeveralSkipsASongDeletedMeanwhile()
// removeSongs([slow, mid]); deleteSong(slow); undo -> ["Fast", "Mid"]
@Test func undoingWhenEverySongIsGoneDoesNothing()
// removeSongs([slow, mid]); deleteSongs([slow, mid]); let before = model.library; undo ->
// model.library == before
```

and the numbering against the model:

```swift
@Test func numbersFollowTheSetlistAfterARemoval()
// four songs A, B, C, D in a setlist; removeSong(B);
// SetlistSearch.rows(model.library.songs(inSetlist:), matching: "d") -> [(3, "D")]
```

- [ ] **Step 2: Run them and see them fail to compile**

Run: `scripts/test.sh -only-testing:MetronomeTests/SetlistSearchTests -only-testing:MetronomeTests/SongModelTests`
Expected: build errors for `SetlistSearch`, `removeSongs` and `text`.

- [ ] **Step 3: Write `SetlistSearch.swift`, the new `SetlistRemoval`, `removeSongs` and `undo`; point `UndoBar(text:)` in `LibrarySheet.swift` at `removal.text`**

- [ ] **Step 4: Run the whole suite**

Run: `scripts/test.sh`
Expected: `** TEST SUCCEEDED **`, with the new tests in the count. Any other test reading `songName` is moved to `text` and named in the report.

- [ ] **Step 5: Update section 14 and commit**

In the item for Remove in a setlist's select mode, the model parts are now unit tested; do not tick it (the view is not built), but replace its note with the tests that cover it and what is still missing. Section 15 stays. Commit `Metronome/Model/SetlistSearch.swift Metronome/MetronomeModel.swift Metronome/Views/LibrarySheet.swift MetronomeTests docs/specification.md` with subject `Remove several songs from a setlist with one Undo`.

---

### Task 2: A setlist's controls line, search and menu

Rows move out of `LibrarySheet.swift` first, with no change in behaviour, so the setlist's new parts do not grow that file past a thousand lines; the move is its own step so its diff stays readable.

**Files:**
- Create: `Metronome/Views/LibraryRows.swift` (moved: `SongRow`, `SongDetailLine`, the `Song` extension with `detail` and `spokenDescription`, `sheetRowMargin`, `SheetRow`, `SheetList`, the `sheetListWidth` environment entry and the `sheetRow()` / `sheetList()` / `isPresented(_:)` extension; `SongRow` and the modifiers go from `private` to internal), `Metronome/Views/SetlistControls.swift`
- Modify: `Metronome/Views/LibrarySheet.swift` (`SongListView`: `body`, `controls`, `list`, `editMode`, `moveAction`), `Metronome/Screenshots/ScreenshotScene.swift`
- Test: none new; the numbering is Task 1's. Verified by build and simulator.

**Interfaces:**
- Consumes: `SetlistSearch.rows(_:matching:)`, `NumberedSong`, `ControlsLine`, `AddButton`.
- Produces (in `SetlistControls.swift`, internal):
  - `struct SetlistControlsLine: View { @Binding var query: String; let showsAdd: Bool; let add: () -> Void }`: `ControlsLine(query:, searchName: "Search this setlist")` with `AddButton(accessibilityName: "Add song", action: add)` when `showsAdd`. Task 3 passes `showsAdd: false` in select mode.
  - `ScreenshotScene.setlistSearch`: the `setlist` scene with `li` typed in the setlist's field once per launch (as `librarySelect` ticks its songs once), so *Setlist — searching* can be compared.

What changes on screen (spec 8.3):

- In a setlist with songs: header, then `SetlistControlsLine`, then the list or `No matches`. An empty setlist keeps its empty state and no controls line.
- The count line goes from a setlist's view: remove the `SectionLabel(text: songs.count == 1 ? "1 SONG" : "\(songs.count) SONGS")` block in `SongListView.body` with its padding. It is plain text with no accessibility trait (no `.isHeader`, no label of its own), and nothing else reads it: VoiceOver simply stops reading "8 SONGS" before the first row, and no test refers to it. `SectionLabel` stays; the settings sheet, the tempo sheet and the Add song screen's `ADD TO` use it. The `setlist` scene is an App Store screenshot, so its picture changes with this; say so in the report.
- `SongListView.query` serves the setlist too. The list in a setlist is `SetlistSearch.rows(songs, matching: query)`; each `SongRow` gets `number: row.number`. The comment that says an index is the place in the setlist goes.
- The `ActionRow(text: "Add song", …)` after the last song goes. The + calls `addSongs`.
- `editMode` is `.active` only for a setlist with an empty (or spaces-only) query; otherwise `.inactive`, so the handles go. `moveAction` is nil while the query has text: `move(from:to:)` uses offsets into the whole setlist and must never get offsets of a filtered list.
- Leaving the setlist and opening Add song already rebuild `SongListView` (the `switch mode` in `LibrarySheet` and `.id(setlistID)`), which empties the query; confirm it in the simulator rather than adding code. The marked row's scroll happens again on coming back, which is what 8 says (the list first appears).
- The setlist's menu is unchanged in this task (Select comes with Task 3).

- [ ] **Step 1: Move the rows to `LibraryRows.swift`, build, run the suite**

Run: `scripts/build.sh` then `scripts/test.sh`
Expected: `** BUILD SUCCEEDED **`, `** TEST SUCCEEDED **`; `git diff --stat` shows lines moving, not changing.

- [ ] **Step 2: Write `SetlistControls.swift` and wire the controls line, numbering, handles and the removed row into `SongListView`**

- [ ] **Step 3: Add the `setlistSearch` scene**

- [ ] **Step 4: Build and run the suite**

Run: `scripts/build.sh` then `scripts/test.sh`
Expected: `** BUILD SUCCEEDED **`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Look at it in the simulator**

On the iPhone 16 simulator (UDID `4ADE7DFC-B616-44F2-BAB0-F2D88CCBDFD3`), launch with `-screenshotScene setlist` and `-screenshotScene setlistSearch`, and with `-screenshotScene emptyLibrary` for an empty setlist (make one with New setlist). See and screenshot: the controls line under the header with the list straight below its divider, no count line and no Add song row; the + opening Add song, and an empty field with the added song listed on coming back; `li` showing 1 Harbour Lights and 7 Northern Line with no handles; `zz` showing `No matches`; a found row's menu and Remove from setlist with the Undo bar; tapping a found row loading it with the header reading `· 7 of 8`; the handles back after ⓧ, and a drag; ‹ and back emptying the field; an empty setlist with no line and its large Add song button. Compare with the boards *Setlist — search and +* and *Setlist — searching*. Report what was and was not seen.

- [ ] **Step 6: Update section 14 and section 15, commit**

Tick or annotate the three controls-line and search items by what was seen. In section 15, drop the controls-line entry except its Select part, which stays until Task 3. Subject: `Give a setlist a search field and a + in place of its Add song row`.

---

### Task 3: Select mode in a setlist

**Files:**
- Modify: `Metronome/Views/SongSelectMode.swift` (`SelectActionBar`), `Metronome/Views/SetlistViews.swift` (`SetlistHeader`), `Metronome/Views/LibrarySheet.swift` (`SongListView`: header choice, action bar, the selection's `onChange`, the scene hook), `Metronome/Views/SetlistControls.swift`, `Metronome/Model/SongSelection.swift` (doc comment only: it serves a setlist too), `Metronome/Screenshots/ScreenshotScene.swift`
- Test: `MetronomeTests/SongModelTests.swift`, `MetronomeTests/SyncModelTests.swift`

**Interfaces:**
- Consumes: Task 1's `removeSongs(_:fromSetlist:)` and `SetlistRemoval`; Task 2's `SetlistControlsLine`; `SongSelection`, `SelectHeader`, `SelectionTick`, `MetronomeModel.addSongs(_:toSetlist:)`, `LibrarySheet.startCreating(with:)` (through `SongListView.newSetlist`).
- Produces:
  - `SelectActionBar` gains a second action in place of its fixed Delete: `struct SecondAction { let title: String; let color: Color; let action: () -> Void }` and `let second: SecondAction`; the Songs tab passes `("Delete", Theme.red, deleteSelection)`, a setlist `("Remove", Theme.dialWhite, removeSelection)`. Its `setlists` stays whatever the caller passes.
  - `SetlistHeader` gains `let select: (() -> Void)?`; nil hides Select. The menu order is Select (`checkmark.circle`), Add song, Rename setlist, Duplicate setlist, Delete setlist.
  - `ScreenshotScene.setlistSelect`: the `setlist` scene with Copper Sky, Waltz for June and Slow Burn ticked once per launch, as on the board *Setlist — select mode*.

Behaviour (spec 8.8):

- `SongListView.selection` serves a setlist too. In a setlist the header is `SelectHeader(title: selection.title)` in place of `SetlistHeader`; Select passes `selectStarted()` (which takes the Undo bar away) as on the Songs tab. `SetlistHeader` gets `select: songs.isEmpty ? nil : { … }`.
- Controls line: `SetlistControlsLine(showsAdd: selection == nil)`. The query is kept on entering and leaving.
- Rows: `isTicked: selection?.contains(song.id)`, `number` as in Task 2, `editMode` `.inactive` and `moveAction` nil while selecting. A tap toggles; nothing loads.
- Action bar: `setlists: model.library.setlistsByRecency.filter { $0.id != setlist.id }`. Add: `model.addSongs(selection.ordered(in: songs), toSetlist:)` with `songs` the whole setlist, then `selection = nil`; the library stays. New setlist: `newSetlist(selection.ordered(in: songs))`, which already works from inside a setlist (the row menu's New setlist does it). Remove: `removeSongs(selection.ordered(in: songs), fromSetlist:)`, `selection = nil`, then `removed(removal)` so the Undo bar shows.
- The selection's `onChange` follows the list's members: on the Songs tab the library's song ids as today, in a setlist `setlist.songIDs`. Empty ends the mode; otherwise `keep(only:)`.
- `onDisappear` already ends it; a setlist deleted elsewhere changes `mode` and so ends it too.

- [ ] **Step 1: Write the failing tests**

In `SongModelTests.swift`:

```swift
@Test func addingSongsThatAreAllThereChangesNothing()
// a second setlist "Other" holding mid and fast; let before = model.library;
// addSongs([mid, fast], toSetlist: other) -> model.library == before
@Test func addingFromASetlistKeepsThatSetlistsOrder()
// selection ticks fast then slow; addSongs(selection.ordered(in: songs(inSetlist: setlist)),
// toSetlist: other) where other holds [mid] -> other is ["Mid", "Slow", "Fast"]
```

In `SyncModelTests.swift`:

```swift
@Test func aTickedSongTakenOutElsewhereLeavesTheSelection()
// device A makes songs S1, S2, S3 and a setlist holding them; B receives them.
// On B: var ticks = SongSelection(); tick S1 and S2.
// A removes S2 from the setlist; cloud.send(.changed, toDevice: 1).
// ticks.keep(only: Set(b.model.library.setlist(id:)!.songIDs)) -> ticks.ids == [S1],
// ticks.title == "1 selected"
```

- [ ] **Step 2: Run them**

Run: `scripts/test.sh -only-testing:MetronomeTests/SongModelTests -only-testing:MetronomeTests/SyncModelTests`
Expected: they pass on the existing model (they pin behaviour the views rely on); if `addingSongsThatAreAllThereChangesNothing` fails, fix `addSongs` to change nothing for songs already in the setlist before going on, and say so in the report.

- [ ] **Step 3: Generalise `SelectActionBar`, add `select` to `SetlistHeader`, wire select mode into `SongListView`, add the `setlistSelect` scene**

- [ ] **Step 4: Build and run the suite**

Run: `scripts/build.sh` then `scripts/test.sh`
Expected: `** BUILD SUCCEEDED **`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Look at it in the simulator**

On the iPhone 16 simulator, with `-screenshotScene setlistSelect` and `-screenshotScene setlist`, see and screenshot: the setlist's menu with Select first, and an empty setlist's without it; select mode's header, the search alone in the line, no count line, numbered rows with rings and no handles; ticking and unticking, the loaded Seven Bridges keeping its amber number and `· loaded`; a search hiding a ticked song with the title unchanged; the dimmed bar with nothing ticked; Add to setlist's menu without Friday gig, and with no other setlist New setlist alone; adding to another setlist ending the mode in Friday gig, and the songs at the target's end afterwards; New setlist opening for naming with the ticked songs in Friday gig's order; Remove with three ticked showing `Removed 3 songs`, and with one `Removed <name>`; Undo putting them back in place; Remove including the loaded song, the header then showing the name alone, and Undo bringing back `3 of 8`; a drag after a Remove taking the bar away; removing every song ending the mode on the empty setlist; Done; closing the library with songs ticked and reopening with the mode off. Compare with *Setlist — select mode*. Report what was and was not seen; a song leaving through sync cannot be seen on one simulator.

- [ ] **Step 6: Update section 14 and section 15, commit**

Tick or annotate the menu, select-mode, Remove and ending items. Drop the select-mode and group-removal entries, and what is left of the controls-line entry, from section 15. Subject: `Add a select mode to a setlist`.

---

### Task 4: Search on the Add song screen

**Files:**
- Modify: `Metronome/Views/SetlistViews.swift` (`AddSongsView`)
- Test: none new; matching is `Song.matches(search:)`, tested already. Verified by build and simulator.

**Interfaces:**
- Consumes: `ControlsLine` with an empty trailing view, `Song.matches(search:)`, `SelectionTick`.
- Produces: `AddSongsView` gains `@State private var query = ""` and `@State private var songIDsBeforeNewSong: Set<UUID>`.

Behaviour (spec 9.3):

- With songs in the library: header, `ControlsLine(query: $query, searchName: "Search songs") { EmptyView() }`, then the A–Z list filtered by the query with the `New song` row always at its end. When nothing matches, the list holds the `New song` row alone and `No matches` (as `EmptyListMessage(title: "No matches", text: nil)` draws it: 17 pt semibold dial white) stands centred in the space below it; the row must not be swapped out for the message as on the tabs. One way: a `VStack` of the one-row list sized to its content and the message filling the rest, or the message as the list's background below the row; whichever keeps the row at the same place it has in a full list. The empty library keeps its message and no line. `.scrollDismissesKeyboard(.immediately)` as on the tabs.
- The query starts empty because the view is made afresh each time the screen opens.
- New song: record the library's song ids when the sheet opens; in the sheet's `onDismiss`, empty the query when the setlist holds a song that was not in the library before (a song made here goes straight into the setlist), so it is listed. Cancel leaves the text.
- Update the `ActionRow` comment, which points at the setlist's Add song row.

- [ ] **Step 1: Add the search to `AddSongsView`**

- [ ] **Step 2: Build and run the suite**

Run: `scripts/build.sh` then `scripts/test.sh`
Expected: `** BUILD SUCCEEDED **`, `** TEST SUCCEEDED **`.

- [ ] **Step 3: Look at it in the simulator**

With `-screenshotScene setlist`, open Add song with the + and see: the field under the header and the divider; `s` narrowing the A–Z list with New song still last; ticking and unticking a found song and the setlist changing; `zz` showing the New song row alone with `No matches` centred below it; New song tapped from that row with `zz` typed, saving `Zed`, and the field empty with Zed listed and ticked; Cancel in New song leaving the text; Done and opening Add song again with an empty field; the empty-library screen with no field (`-screenshotScene emptyLibrary`, a new setlist, its Add song button). Compare with *Add song — search*. Report what was and was not seen.

- [ ] **Step 4: Update section 14 and section 15, commit**

Tick or annotate the Add song search item, and add the Add song screen to the note of the music-note mark item if it was seen there. Drop the Add song entry from section 15; with every entry gone, section 15's list goes and its first line is followed by `Every part specified above is built.` Subject: `Add a search field to the Add song screen`.

---

## Self-review notes

- Spec 8.3 "rows cannot be reordered while searching": Task 2, by `moveAction` nil and edit mode off; no unit test, seen in the simulator. A filtered list with a live `onMove` would hand `move(from:to:)` offsets of the wrong list, so this is the place a reviewer should read the code.
- Spec 8.3 "Previous / Next follow the whole setlist": nothing to build; the model never sees the search. Checked by loading a found row and reading the header's `7 of 8`.
- Spec 8.5 group Undo and the drag rule: Task 1 for Undo; the drag dismissal is the existing `orderChanged` and needs no change.
- Spec 8.8 "a ticked song that leaves the setlist" relies on the view observing the setlist's members, which Task 3 switches from the library's song ids; the pure part is pinned in Task 3, the wiring only by reading it.
- Spec 13 names: Tasks 2 to 4. VoiceOver itself is not run by anyone, and the section 14 notes must say so.
- Nothing in this plan touches `LibraryState`, sync records or the format number.
