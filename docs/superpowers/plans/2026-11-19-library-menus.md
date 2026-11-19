# Library Menus, Sorting and Select Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the library sheet a menu button and a search line with a + on both tabs, sort orders for songs and setlists, and a select mode that adds or deletes several songs at once.

**Architecture:** Ordering, last-played times and the selection are plain values with pure functions, unit tested; `MetronomeModel` owns them and persists them in the device-only `LibraryState`. The views in `LibrarySheet.swift` and `SetlistViews.swift` read the model and draw; new view pieces go into two new files so the 900-line sheet file does not grow.

**Tech Stack:** Swift, SwiftUI, Swift Testing. Build with `scripts/build.sh`, test with `scripts/test.sh` (extra arguments go to xcodebuild, e.g. `scripts/test.sh -only-testing:MetronomeTests/LibraryOrderTests`). New files need no project edit: the project uses file-system synchronised groups.

**Spec:** `docs/specification.md`, sections 2, 4, 5, 5.1, 6.9, 8, 8.1, 8.2, 8.3, 8.6, 8.7, 9.1, 13, 14, 15. Read them before each task; the spec's sizes, colours and copy are binding.

## Global Constraints

- Work only in `/Users/arime/metronome/.claude/worktrees/library-menus` on branch `library-menus`. Never switch branches, never push.
- Nothing about ordering or last played is synced: `Library`, `SongRecord`, `SetlistRecord`, `LibrarySync` and the format number (2) do not change, except `Library.touchSetlist` in Task 2.
- UI copy exactly as in the spec: `Select`, `New song`, `New setlist`, `Sort by`, `Name`, `Recently added`, `Recently played`, `Recently used`, `Select songs`, `3 selected`, `Done`, `Add to setlist`, `Delete`, `No matches`, `Delete 3 songs?`, `They will also be removed from 1 setlist.`, `They will also be removed from 2 setlists.`. No other explanatory text on screen.
- Colours and sizes only from `Theme` and the spec; no new colour literals.
- Shell: single quotes, no `$(...)`, no backticks, no `cd` before git, no backslash line continuations.
- Commits: write the message to a file in the scratchpad given in your brief and run `git commit -F <file>`. Imperative subject under 72 characters, capitalised, no trailing period, body wrapped at 72 explaining why, no Conventional Commits prefix, no backticks, no attribution lines of any kind.
- `docs/specification.md` is a living spec: no history wording. In section 14 tick an item only when a unit test covers it or it was seen in the simulator, and say which in its note. Remove from section 15 only what is built.
- Never read `.env.*` or `.appsettings.*` files.

## Review Focus

1. **A library saved by the current build has none of the new stored values.** Loading it must keep every song and setlist and give the defaults. Pinned in Task 1 (`aStateSavedWithoutTheNewValuesStillLoads`).
2. **A ticked song disappears** (deleted on another device, or by sync) while select mode is on: it must leave the selection and the count. Pinned in Task 4 (`aSongThatIsGoneLeavesTheSelection`).
3. **Deleting the loaded song among the ticked ones** must leave the metronome as a single delete does (settings kept, nothing loaded). Pinned in Task 4 (`deletingSeveralSongsUnloadsTheLoadedOne`).
4. **Songs with the same name or the same last-played time** must sort the same way every time. Pinned in Task 1 (`equalNamesAndTimesKeepAStableOrder`).
5. **Two setlists with the same last-used time** (a library made before sync has them): opening either must still make it the most recent. Pinned in Task 2 (`aTieStillSetsTheTime`).

---

### Task 1: Orders and last-played times in the model

**Files:**
- Create: `Metronome/Model/LibraryOrder.swift`
- Modify: `Metronome/Model/Library.swift` (reading section, lines 118-140), `Metronome/Model/LibraryStore.swift` (`LibraryState`), `Metronome/MetronomeModel.swift` (state load near line 95, `loadSong` near 770, `saveAsNewSong` near 863, `createSong` near 896, `currentLibraryState` near 1168, the cloud-applied state near 1216)
- Test: `MetronomeTests/LibraryOrderTests.swift` (new), `MetronomeTests/LibraryStoreTests.swift`, `MetronomeTests/SongModelTests.swift`

**Interfaces:**
- Produces:
  - `enum SongOrder: String, Codable, CaseIterable, Sendable { case name, recentlyAdded, recentlyPlayed }` with `var title: String` (`Name`, `Recently added`, `Recently played`)
  - `enum SetlistOrder: String, Codable, CaseIterable, Sendable { case recentlyUsed, name }` with `var title: String` (`Recently used`, `Name`)
  - `extension Library { func songs(orderedBy order: SongOrder, lastPlayed: [UUID: Date]) -> [Song]; func setlists(orderedBy order: SetlistOrder) -> [Setlist] }`
  - `extension Setlist { func matches(search query: String) -> Bool }`, same rule as `Song.matches(search:)`; share the comparison in one private helper.
  - `LibraryState` gains `var lastPlayed: [UUID: Date] = [:]`, `var songOrder = SongOrder.name`, `var setlistOrder = SetlistOrder.recentlyUsed`.
  - `MetronomeModel`: `private(set) var lastPlayed: [UUID: Date]`; `var songOrder: SongOrder` and `var setlistOrder: SetlistOrder`, each saved when set; `var orderedSongs: [Song]`; `var orderedSetlists: [Setlist]`.

Ordering rules (spec 8.6): `name` is today's `sortedSongs`. `recentlyAdded` is newest created first (`Library.songs` is in creation order). `recentlyPlayed` is latest time first, then the never-played songs in `name` order; equal times fall back to `name` order. Setlists by `name` compare like songs, ties most recently used first; `recentlyUsed` is `setlistsByRecency`.

- [ ] **Step 1: Write the failing tests in `LibraryOrderTests.swift`**

Build a library with `addSong(name:settings:now:)` using increasing `now` values. Tests and their assertions:

```swift
@Test func nameOrderIsTheSortedSongs()            // songs(orderedBy: .name, lastPlayed: [:]) == library.sortedSongs
@Test func recentlyAddedIsNewestFirst()           // names created A, C, B -> ["B", "C", "A"]
@Test func recentlyPlayedPutsNeverPlayedLastByName()
// songs A, B, C, D; lastPlayed [C: t2, A: t1] -> ["C", "A", "B", "D"]
@Test func equalNamesAndTimesKeepAStableOrder()
// two songs named "Same" created in order s1, s2: .name -> [s1, s2];
// both with the same last-played time: .recentlyPlayed -> [s1, s2]
@Test func setlistsByNameIgnoreCase()             // "beta", "Alpha" -> ["Alpha", "beta"]
@Test func setlistsWithTheSameNameAreMostRecentFirst()
@Test func recentlyUsedIsTheRecencyOrder()        // == library.setlistsByRecency
@Test func aSetlistMatchesLikeASong()
// Setlist "Friday gig": matches "fri", " GIG ", "" and "   "; not "sat".
// Setlist "Häät": matches "haat".
```

- [ ] **Step 2: Run them and see them fail to compile**

Run: `scripts/test.sh -only-testing:MetronomeTests/LibraryOrderTests`
Expected: build error, `SongOrder` not found.

- [ ] **Step 3: Write `LibraryOrder.swift` and the `Setlist.matches` extension**

- [ ] **Step 4: Run the tests**

Run: `scripts/test.sh -only-testing:MetronomeTests/LibraryOrderTests`
Expected: all pass.

- [ ] **Step 5: Write the failing store and model tests**

In `LibraryStoreTests.swift`:

```swift
@Test func aStateSavedWithoutTheNewValuesStillLoads()
// Encode a LibraryState with one song and one setlist, remove the keys "lastPlayed",
// "songOrder" and "setlistOrder" from the JSON object, store it under
// "metronome.library.v2", load: the song and setlist are there, lastPlayed is empty,
// songOrder == .name, setlistOrder == .recentlyUsed.
@Test func theNewValuesSurviveSavingAndLoading()
// lastPlayed [song.id: date], songOrder .recentlyPlayed, setlistOrder .name round-trip.
@Test func aLastPlayedTimeForAMissingSongIsDropped()
// sanitized() removes an entry whose id is not a song in the library.
```

In `SongModelTests.swift` (use the suite's `makeModel()` / `modelWithSetlist()` and its controllable clock):

```swift
@Test func loadingASongSetsItsLastPlayedTime()        // loadSong -> lastPlayed[id] == the clock's now
@Test func previousAndNextSetTheLastPlayedTime()
@Test func tappingTheLoadedSongAgainKeepsItsTime()    // advance the clock, loadSong same id -> unchanged
@Test func saveAsNewSongAndNamingTheSettingsSetTheTime()
// saveAsNewSong(...) -> time for the new song; createSong while nothing is loaded
// (the path that loads the new song) -> time for it; createSong from the library
// while a song is loaded (not loaded) -> no time.
@Test func restoringTheLoadedSongAtLaunchSetsNoTime() // a second model on the same stores: lastPlayed unchanged
@Test func deletingASongDropsItsLastPlayedTime()
@Test func theChosenOrdersAreRemembered()
// set songOrder = .recentlyAdded, setlistOrder = .name; a second model on the same
// stores has them.
@Test func orderedSongsFollowTheChosenOrder()         // .recentlyPlayed after loading B then A -> A, B, then the rest by name
```

- [ ] **Step 6: Run them and see them fail**

Run: `scripts/test.sh -only-testing:MetronomeTests/LibraryStoreTests -only-testing:MetronomeTests/SongModelTests`
Expected: build errors for the missing members.

- [ ] **Step 7: Implement**

`LibraryState`: the three properties, decoded with `decodeIfPresent` and the defaults (write `init(from:)`; keep the memberwise initialiser usable by `StoredLegacyState.converted` and the model). `sanitized()` drops last-played entries for songs that are gone.
`MetronomeModel`: load the three values with the state; one private `markPlayed(_ id: UUID)` that sets `lastPlayed[id] = now()`, called where another song becomes the loaded one (`loadSong` inside `isAnotherSong`, `saveAsNewSong`, the loading path of `createSong`), before `persistLibrary()`. Not called where a stored or cloud-combined state is applied. `deleteSong` removes the entry. `currentLibraryState` carries all three. The state applied after a cloud exchange keeps this device's three values.

- [ ] **Step 8: Run the whole suite**

Run: `scripts/test.sh`
Expected: `** TEST SUCCEEDED **`, with the new tests in the count.

- [ ] **Step 9: Tick section 14 and commit**

Tick only the last-played item and the parts of the sorting items that these tests cover, naming the tests. Commit `Metronome/Model/LibraryOrder.swift Metronome/Model/Library.swift Metronome/Model/LibraryStore.swift Metronome/MetronomeModel.swift MetronomeTests docs/specification.md` with subject `Add sort orders and last-played times to the model`.

---

### Task 2: Leave the most recently used setlist's time alone

**Files:**
- Modify: `Metronome/Model/Library.swift:245` (`touchSetlist`)
- Test: `MetronomeTests/LibraryTests.swift`, `MetronomeTests/LibrarySyncTests.swift` or `SyncModelTests.swift` (whichever already has a model wired to `FakeCloudStore`)

**Interfaces:**
- Produces: `Library.touchSetlist(_:now:)` changes the record only when another alive setlist's `lastUsed` is the same or later (spec 9.1). Signature unchanged.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func theMostRecentSetlistKeepsItsTime()
// setlists A (used t1) and B (used t2 > t1): touchSetlist(B, now: t3) leaves the library == before.
@Test func anOlderSetlistGetsTheNewTime()
// touchSetlist(A, now: t3) -> A.lastUsed == t3 and setlistsByRecency.first == A.
@Test func aTieStillSetsTheTime()
// A and B both used at t1: touchSetlist(A, now: t2) -> A.lastUsed == t2.
@Test func theOnlySetlistKeepsItsTime()
@Test func aDeletedSetlistDoesNotCount()
// B used last, then deleted: touchSetlist(A, now: t3) leaves the library unchanged.
@Test func steppingThroughASetlistWritesNothingToICloud()
// model with sync on and a three-song setlist: load song 1 from it, note the fake
// store's write count, then goNext twice: the count is unchanged.
```

- [ ] **Step 2: Run and see `theMostRecentSetlistKeepsItsTime`, `theOnlySetlistKeepsItsTime`, `aDeletedSetlistDoesNotCount` and the iCloud test fail**

Run: `scripts/test.sh -only-testing:MetronomeTests/LibraryTests`

- [ ] **Step 3: Add the guard in `Library.touchSetlist`**

If `FakeCloudStore` has no write counter, add one (`private(set) var setCount`), counting `set(_:forKey:)` calls.

- [ ] **Step 4: Run the whole suite**

Run: `scripts/test.sh`
Expected: `** TEST SUCCEEDED **`. An existing test that expected a touch on the only or latest setlist is updated to the new rule, and the report names each such test.

- [ ] **Step 5: Tick the section 14 item, drop the section 15 entry, commit**

Subject: `Leave the most recently used setlist's time alone`.

---

### Task 3: Menu button, search line with +, and sorting on both tabs

**Files:**
- Create: `Metronome/Views/LibraryControls.swift`
- Modify: `Metronome/Views/LibrarySheet.swift` (`SongListView` header, `controls`, `songs`, `emptyState`; `MoreButtonLabel`; `PillButton.tabHeaderWidth` removed; `SearchField` moves out), `Metronome/Views/SetlistViews.swift` (`SetlistsTab`, `SetlistHeader`), `Metronome/Screenshots/ScreenshotScene.swift` if a Setlists-tab scene is missing
- Test: none new; behaviour is in Task 1's functions. Verified by build and simulator.

**Interfaces:**
- Consumes: `model.songOrder`, `model.setlistOrder`, `model.orderedSongs`, `model.orderedSetlists`, `Setlist.matches(search:)`, `SongOrder.title`, `SetlistOrder.title`.
- Produces (in `LibraryControls.swift`, internal):
  - `struct SearchField: View { @Binding var text: String; let accessibilityName: String }` (moved from `LibrarySheet.swift`; `Search songs` / `Search setlists`)
  - `struct AddButton: View { let accessibilityName: String; let action: () -> Void }`: 36 pt circle, `Theme.amber`, `plus` 16 pt bold in `Theme.ink`, 44 pt touch area
  - `struct ControlsLine<Trailing: View>: View { @Binding var query: String; let searchName: String; @ViewBuilder let trailing: Trailing }`: search field, 10 pt, trailing, then the 12 pt gap and the 1 pt `Theme.line` divider, 20 pt side margins
  - `struct SortMenuSection<Order>`: a `Section("Sort by")` with a `Picker` (or buttons with a checkmark) over the order's cases, bound to the model
  - `struct SongsTabMenu: View { let isEmpty: Bool; let select: () -> Void; let newSong: () -> Void }` and `struct SetlistsTabMenu: View { let isEmpty: Bool; let newSetlist: () -> Void }`: a `Menu` with `MoreButtonLabel()` as its label; VoiceOver `More for songs` / `More for setlists`

What changes on screen (spec 8.1, 8.2, 8.6, 9.1):

- Both tab headers: `LibraryTabs` fills the row (`frame(maxWidth: .infinity)`; the `Spacer` in `SheetHeader` must not take the width, so give `SheetHeader` no spacer when the title fills, or pass the tabs with `maxWidth: .infinity`), then 12 pt, then the 40 pt menu button. The `New song` / `New setlist` pills leave the headers; `PillButton.tabHeaderWidth` and `.hiddenInPlace` uses for them go.
- Songs tab menu: `Select` (symbol `checkmark.circle`), `New song` (`plus`), divider, `Sort by` group. With no songs: `New song` only. `Select` calls a closure that Task 4 fills; until then it is wired to a `@State private var isSelecting` that nothing reads yet.
- Setlists tab menu: `New setlist`, divider, `Sort by`. With no setlists: `New setlist` only.
- Controls line on both tabs, hidden while the tab is empty. The + opens the New song sheet on Songs and calls `newSetlist` on Setlists.
- Songs tab list: `model.orderedSongs` filtered by the query. The order is taken when the list appears and when an order is chosen, not while it is shown: keep the shown ids in `@State`, set in `onAppear` and `onChange(of: model.songOrder)`, and map them to live songs so edits, additions and deletions still show (a new song not in the remembered ids is appended in `orderedSongs` position).
- Setlists tab: `@State private var query = ""`, list is `model.orderedSetlists` filtered with `matches(search:)`, `No matches` as on the Songs tab, `.scrollDismissesKeyboard(.immediately)`. The query empties when the tab is left (the view is rebuilt on a tab switch, which already empties it; confirm that opening a setlist and coming back with the back button keeps it, as the spec says, and if the view is rebuilt there too, hold the query in `LibrarySheet`).
- `SetlistHeader`: `MoreButtonLabel()` at 40 pt (the `size` parameter and its 36 pt case go if nothing else uses them), and `Add song` (`plus`) as the first menu item, calling a new `addSongs: () -> Void` parameter that `SongListView` passes.
- Menus that list setlists (`rowMenu`) keep `setlistsByRecency`.

- [ ] **Step 1: Create `LibraryControls.swift` with the pieces above and move `SearchField` into it**

- [ ] **Step 2: Rework the Songs tab header, controls line and list in `SongListView`**

- [ ] **Step 3: Rework `SetlistsTab` and `SetlistHeader`**

- [ ] **Step 4: Build and run the suite**

Run: `scripts/build.sh` then `scripts/test.sh`
Expected: `** BUILD SUCCEEDED **`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Look at it in the simulator**

Build for the iPhone 16 simulator (UDID `4ADE7DFC-B616-44F2-BAB0-F2D88CCBDFD3`), launch with `-screenshotScene library` and take screenshots of: the Songs tab; its menu open; each sort order chosen; a search with matches and with none; the Setlists tab with its line and menu; a setlist search; a setlist's menu showing Add song first; the empty library (menu holds New song only, no controls line). Compare with the Paper boards named in the spec's introduction. If the scenes cannot reach a state, add a scene to `ScreenshotScene.swift` in the style of the existing ones. Report what was and was not seen.

- [ ] **Step 6: Tick section 14 for what was seen, update section 15, commit**

Subject: `Give the library a menu button, a + and sorting`.

---

### Task 4: Select mode

**Files:**
- Create: `Metronome/Model/SongSelection.swift`, `Metronome/Views/SongSelectMode.swift`
- Modify: `Metronome/MetronomeModel.swift` (two bulk actions beside `deleteSong` / `setSong`), `Metronome/Views/LibrarySheet.swift` (`LibrarySheet`, `SongListView`, `SongRow`), `Metronome/Views/SetlistViews.swift` only if the Add song screen's tick is extracted for reuse
- Test: `MetronomeTests/SongSelectionTests.swift` (new), `MetronomeTests/SongModelTests.swift`

**Interfaces:**
- Consumes: Task 3's `ControlsLine` (with an empty trailing view), `SearchField`, `model.orderedSongs`.
- Produces:
  - `struct SongSelection: Equatable { private(set) var ids: Set<UUID>; mutating func toggle(_ id: UUID); func contains(_ id: UUID) -> Bool; var count: Int; var title: String; mutating func keep(only existing: Set<UUID>); func ordered(in songs: [Song]) -> [UUID] }`. `title` is `Select songs` for none, otherwise `1 selected`, `3 selected`.
  - `enum SongsDeletion { static func title(count: Int) -> String; static func message(setlistCount: Int) -> String? }`: `Delete 3 songs?`; message nil for 0, `They will also be removed from 1 setlist.`, `They will also be removed from 2 setlists.`
  - `Library.setlistCount(containingAnyOf ids: Set<UUID>) -> Int`
  - `MetronomeModel.addSongs(_ ids: [UUID], toSetlist setlistID: UUID)`: appends those not yet in it, in the given order, one persist; does not touch the setlist's last-used time. `MetronomeModel.deleteSongs(_ ids: Set<UUID>)`: as `deleteSong` for each, one persist.
  - `struct SelectHeader: View`, `struct SelectActionBar: View`, `struct SelectionTick: View { let isOn: Bool }` in `SongSelectMode.swift`.

Behaviour (spec 8.7): entered with `Select`; ends with `Done`, after either action, when the sheet closes, and when the library becomes empty; the ticks go with it. Header: title 26 pt heavy as `SheetTitle`, `PillButton(text: "Done")` at the right. Controls line without +. Rows: `SelectionTick` in place of the menu button, drawn as the Add song screen's tick (extract that view if it is inline there so both use one); a tap toggles and loads nothing; no swipe actions; the loaded mark stays. Action bar over the list at the sheet's bottom: `Theme.surface`, 1 pt `Theme.line` on top, two equal 48 pt `Theme.surfaceRaised` capsules 12 pt apart with 20 pt side margins and 12 pt above and below, `Add to setlist` in `Theme.dialWhite` and `Delete` in `Theme.red`, both 16 pt bold, dimmed and disabled with nothing ticked; the list gets bottom content inset so its last row clears the bar. `Add to setlist` is a `Menu` of `setlistsByRecency` without ticks and `New setlist` after a divider; with one song ticked `Delete` shows the row menu's own confirmation. New setlist reuses `LibrarySheet.startCreating`, extended to take the songs. Entering select mode clears `removal` (the Undo bar). VoiceOver per spec section 13: ticked rows read as selected, the title is a heading.

- [ ] **Step 1: Write the failing tests in `SongSelectionTests.swift`**

```swift
@Test func theTitleCountsTheTicks()            // "Select songs", "1 selected", "3 selected"
@Test func togglingTwiceUnticks()
@Test func aSongThatIsGoneLeavesTheSelection() // keep(only:) drops ids not in the set; count follows
@Test func orderedFollowsTheGivenSongs()       // ids ticked in any order come back in the songs' order
@Test func theDeletionTextNamesTheCounts()
// title(count: 3) == "Delete 3 songs?"; message(setlistCount: 0) == nil;
// 1 -> "They will also be removed from 1 setlist."; 2 -> "They will also be removed from 2 setlists."
```

and in `SongModelTests.swift`:

```swift
@Test func addingSeveralSongsAppendsTheNewOnesInOrder()
// setlist [s0]; addSongs([s2, s0, s1], toSetlist:) -> [s0, s2, s1]
@Test func addingSongsDoesNotCountAsUsingTheSetlist()   // lastUsed unchanged, not first by recency
@Test func deletingSeveralSongsRemovesThemEverywhere()  // gone from the library and from every setlist
@Test func deletingSeveralSongsUnloadsTheLoadedOne()    // loadedSong == nil, settings unchanged, as deleteSong
@Test func theSetlistCountCountsEachSetlistOnce()       // two ticked songs in the same setlist -> 1
```

- [ ] **Step 2: Run and see them fail to compile**

Run: `scripts/test.sh -only-testing:MetronomeTests/SongSelectionTests`

- [ ] **Step 3: Write `SongSelection.swift`, `Library.setlistCount(containingAnyOf:)` and the two model actions**

- [ ] **Step 4: Run the whole suite**

Run: `scripts/test.sh`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Build the views and wire them in**

`SongListView` holds `@State private var selection: SongSelection?` (nil when off). `.onChange(of: model.library.songs.map(\.id))` prunes it and ends the mode on an empty library.

- [ ] **Step 6: Build, run the suite, look at it in the simulator**

Add a `librarySelect` screenshot scene (three songs ticked) if the mode cannot be reached by launch arguments otherwise. On the iPhone 16 simulator see: entering from the menu; ticking and unticking; a search that hides a ticked song with the count unchanged; the dimmed bar with nothing ticked; Add to setlist's menu, and the songs at the end of the setlist afterwards; New setlist opening for naming with the songs in it; the delete confirmation with and without the setlist line; Done. Report what was and was not seen.

- [ ] **Step 7: Tick section 14, update section 15, commit**

Subject: `Add a select mode to the Songs tab`.

---

## Self-review notes

- Spec 5 / 8.6 "a time for a song that no longer exists is dropped": Task 1 (`sanitized`, `deleteSong`).
- Spec 8.6 "the order is worked out when the list appears": Task 3, by the remembered ids; no unit test, seen in the simulator by loading with Recently played and reopening.
- Spec 13 labels: Tasks 3 and 4; VoiceOver itself is not run by anyone, and the section 14 notes must say so.
- The row menu's single-song confirmation (`It is not in any setlist.`) is unchanged by this plan.
