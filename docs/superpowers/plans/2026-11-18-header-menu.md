# Header Menu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the header's Save button and Settings gear with one menu button that carries an amber badge for unsaved changes and holds Save changes, Revert, Edit song, Save as new song, Add to setlist, Unload and Settings.

**Architecture:** The model already has every action except adding a new song to the loaded-from setlist, so the model gains one parameter and one accessor. A new pure value, `HeaderMenuItems`, decides which items show, so that is unit tested; `HeaderMenuButton` draws the button, badge and menu from it. The library loses its Unload pill and learns to open inside a setlist it has just made.

**Tech Stack:** Swift, SwiftUI, Swift Testing. Xcode project `Metronome.xcodeproj`, scheme `Metronome`.

**Spec:** `docs/specification.md` on this branch: 6.1 (header, menu button, badge), 7.6 (the header menu), 8.2 (controls line), 10 and 10.1 (Add to setlist switch, New song), 13 (VoiceOver), 14 and 15 (checklist). Design boards: Paper file "Snappy Metronome", page *Header menu (draft)*.

## Global Constraints

- Work only in the worktree `/Users/arime/metronome/.claude/worktrees/screen-menu` on branch `screen-menu`. Never switch the main checkout.
- Build with `scripts/build.sh`, test with `scripts/test.sh`. Both print a summary; the full log is in `build/`. A task is not done until `scripts/test.sh` ends with `** TEST SUCCEEDED **` and no `warning:` line from files this plan touches.
- Colours only from `Theme` (`Metronome/Views/Theme.swift`). Amber is `Theme.amber`, ink `Theme.ink`, the button fill `Theme.surface`.
- UI copy, exactly: `Save changes`, `Revert`, `Edit song`, `Save as new song`, `Add to setlist`, `New setlist`, `Unload`, `Settings`. No explanatory footnotes or hints anywhere.
- VoiceOver, exactly: the menu button is `More`, and `More, unsaved changes` while the badge shows. `Saved` is announced after Save changes.
- Sizes from spec 6.1: menu button 40 pt round, touch area at least 44 pt; badge a 10 pt amber dot with a 2 pt ink ring (14 pt overall) on the button's top-right edge.
- Shell: single quotes, no `cd` before git, no `git -C`, no command substitution, no backticks in commit messages.
- Commits: imperative subject, capitalised, no trailing period, at most 72 characters, no Conventional Commits prefix, no Claude attribution. Write the message to a scratch file and commit with `git commit -F <file>`.
- Spec section 14: tick a line only when every claim in it is covered by a named unit test or was seen in the simulator; otherwise leave it unticked with a note saying which part is covered. Remove an entry from section 15 only when it is built.

## Review Focus

1. **The loaded-from setlist is deleted (here or by iCloud) while the New song sheet from Save as new song is open.** Saving must still create and load the song, on its own. Pinned in Task 1.
2. **Save as new song with nothing loaded and the switch flag passed as true.** There is no setlist, so the song is loaded on its own and nothing crashes. Pinned in Task 1.
3. **Unload from the menu while a playable track is playing.** Playback stops (7.6, 7.10). Already covered by `TrackSongModelTests`; Task 4 must call the same `unloadSong()` and nothing else.
4. **The menu opened during the badge's half-second linger, when the settings already equal the saved song.** The badge shows but Save changes and Revert must not, as there is nothing to save. Pinned in Task 3.
5. **Add to setlist in the header menu removes the loaded song from its loaded-from setlist.** The song stays loaded, the header shows the name alone and Previous / Next go, with no crash and no Undo bar. Pinned in Task 1.

---

### Task 1: Model: save as new song into the loaded-from setlist

**Files:**
- Modify: `Metronome/MetronomeModel.swift` (`saveAsNewSong`, about line 819; a new accessor beside `loadedSong`, about line 641)
- Test: `MetronomeTests/SongModelTests.swift`

**Interfaces:**
- Produces:
  - `var loadedFromSetlist: Setlist? { get }` on `MetronomeModel`: the setlist with `loadedFromSetlistID`, nil when there is none or it no longer exists.
  - `func saveAsNewSong(name: String, settings: MetronomeSettings, track: PickedTrack? = nil, addingToLoadedSetlist: Bool = false) -> Song?`. The existing three-argument calls keep compiling and behaving as before.

- [ ] **Step 1: Write the failing tests** in `SongModelTests`, after `saveAsNewSongLoadsTheNewOne`. They use the file's `modelWithSetlist()` (three songs, Slow 60, Mid 100, Fast 180, in one setlist).

```swift
@Test func saveAsNewSongIntoTheLoadedSetlistKeepsThePlace() throws {
    let (model, songs, setlist) = modelWithSetlist()
    model.loadSong(songs[0].id, from: setlist)
    model.setBPM(66)
    let made = try #require(model.saveAsNewSong(name: "Slow, faster", settings: model.settings, addingToLoadedSetlist: true))
    #expect(model.loadedSong?.id == made.id)
    #expect(model.loadedFromSetlistID == setlist)
    #expect(model.library.setlist(id: setlist)?.songIDs == songs.map(\.id) + [made.id])
    #expect(model.position?.index == 3)
    #expect(model.position?.count == 4)
    #expect(model.canGoPrevious)
    #expect(model.canGoNext == false)
    #expect(model.isEdited == false)
    #expect(model.library.song(id: songs[0].id)?.settings.bpm == 60)
}

@Test func saveAsNewSongWithNoSetlistIgnoresTheSwitch() throws {
    let model = makeModel()
    model.setBPM(132)
    let made = try #require(model.saveAsNewSong(name: "Song", settings: model.settings, addingToLoadedSetlist: true))
    #expect(model.loadedSong?.id == made.id)
    #expect(model.loadedFromSetlistID == nil)
    #expect(model.position == nil)
}

@Test func saveAsNewSongAfterTheSetlistWasDeletedLoadsItOnItsOwn() throws {
    let (model, songs, setlist) = modelWithSetlist()
    model.loadSong(songs[0].id, from: setlist)
    model.deleteSetlist(setlist)
    let made = try #require(model.saveAsNewSong(name: "Copy", settings: model.settings, addingToLoadedSetlist: true))
    #expect(model.loadedSong?.id == made.id)
    #expect(model.loadedFromSetlistID == nil)
}

@Test func loadedFromSetlistFollowsTheLoadedSong() {
    let (model, songs, setlist) = modelWithSetlist()
    #expect(model.loadedFromSetlist == nil)
    model.loadSong(songs[1].id, from: setlist)
    #expect(model.loadedFromSetlist?.id == setlist)
    model.loadSong(songs[1].id, from: nil)
    #expect(model.loadedFromSetlist?.id == setlist)
    model.unloadSong()
    #expect(model.loadedFromSetlist == nil)
}

@Test func takingTheLoadedSongOutOfItsSetlistKeepsItLoaded() {
    let (model, songs, setlist) = modelWithSetlist()
    model.loadSong(songs[1].id, from: setlist)
    model.setSong(songs[1].id, inSetlist: setlist, included: false)
    #expect(model.loadedSong?.id == songs[1].id)
    #expect(model.loadedFromSetlistID == nil)
    #expect(model.position == nil)
    model.setSong(songs[1].id, inSetlist: setlist, included: true)
    #expect(model.library.setlist(id: setlist)?.songIDs.last == songs[1].id)
}
```

The third assertion of `loadedFromSetlistFollowsTheLoadedSong` (loading from the Songs tab keeps the setlist being stepped through) states the existing rule of spec 8.2. If the last test already passes, keep it: it pins Review Focus 5.

- [ ] **Step 2: Run the tests and see them fail**

Run: `scripts/test.sh -only-testing:MetronomeTests/SongModelTests`
Expected: build errors for `addingToLoadedSetlist` and `loadedFromSetlist`.

- [ ] **Step 3: Implement**

`loadedFromSetlist` is `loadedFromSetlistID.flatMap(library.setlist(id:))`.

In `saveAsNewSong`, read the target setlist before anything changes: `addingToLoadedSetlist ? loadedFromSetlist?.id : nil`. After `library.addSong`, when there is a target, add the song with `library.add(_:toSetlist:now:)` and `library.touchSetlist(_:now:)` using one `now()` value for all three calls, as `createSong` does, and set `loadedFromSetlistID` to the target; otherwise nil as today. Everything else in the function stays in its order. Update the doc comment: the song is in no setlist unless it was added to the loaded-from one.

- [ ] **Step 4: Run the tests and see them pass**

Run: `scripts/test.sh`
Expected: `** TEST SUCCEEDED **`, including the existing `saveAsNewSongLoadsTheNewOne` and the `saveAsNewSong` tests in `TrackSongModelTests` and `TrackSwitchModelTests`.

- [ ] **Step 5: Commit**

Subject: `Save a new song into the loaded-from setlist`

---

### Task 2: Library: no Unload pill, and opening inside a new setlist

**Files:**
- Modify: `Metronome/Views/LibrarySheet.swift` (`LibrarySheet` init and `.onAppear`, about lines 5 to 83; `controls`, about lines 521 to 544; delete `UnloadSongButton`, about lines 814 to 826)

**Interfaces:**
- Produces: `LibrarySheet(newSetlistWith: UUID? = nil)`. With a song ID, the sheet makes a setlist holding that song and opens inside it, ready for naming, exactly as New setlist in a row menu does (`startCreating(with:)`), but with no slide, as the sheet is only just appearing. `LibrarySheet()` behaves as before.

- [ ] **Step 1: Remove the Unload pill.** `controls` becomes the `SearchField` alone in the line, with the same paddings and divider. Delete `UnloadSongButton`. Update the doc comment on `controls`. `close` stays, as loading a song still uses it.

- [ ] **Step 2: Add `let newSetlistWith: UUID?` with a default of nil.** In `.onAppear`, before the existing loaded-from check: when it is set, do what `startCreating(with:)` does (create the setlist, add the song, set `namingID` and `creatingID`) and set `mode = .setlist` directly, without `go(to:)`. Guard it with a `@State` flag so it runs once, as `.onAppear` can fire again when a sheet above the library closes.

- [ ] **Step 3: Build**

Run: `scripts/build.sh`
Expected: `** BUILD SUCCEEDED **`, no warnings from `LibrarySheet.swift`.

- [ ] **Step 4: Run the tests**

Run: `scripts/test.sh`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

Subject: `Take Unload out of the library and open it in a new setlist`

---

### Task 3: The header menu's items, and the switch in the song sheet

**Files:**
- Create: `Metronome/Views/HeaderMenuItems.swift`
- Create: `MetronomeTests/HeaderMenuItemsTests.swift`
- Modify: `Metronome/Views/SongSheet.swift` (`Purpose.saveAsNew` comment, `setlist`, `save()`)

Add both new files to the Xcode project's targets the way the existing files in those folders are (check whether the project uses file-system synchronised groups; if it does, creating the files is enough).

**Interfaces:**
- Consumes: `MetronomeModel.loadedFromSetlist`, `saveAsNewSong(name:settings:track:addingToLoadedSetlist:)` from Task 1.
- Produces:

```swift
/// Which items the header menu shows, top to bottom, in groups separated by dividers (spec 7.6).
struct HeaderMenuItems: Equatable {
    enum Item: Equatable { case saveChanges, revert, editSong, saveAsNewSong, addToSetlist, unload, settings }
    let groups: [[Item]]
    init(hasSong: Bool, isEdited: Bool)
    /// "More", or "More, unsaved changes" while the badge shows.
    static func accessibilityLabel(hasBadge: Bool) -> String
}
```

- [ ] **Step 1: Write the failing tests** in `HeaderMenuItemsTests` (a `struct` with `@Test` functions, `import Testing`, `@testable import Metronome`):

```swift
@Test func nothingLoadedOffersOnlySaveAsNewSongAndSettings() {
    #expect(HeaderMenuItems(hasSong: false, isEdited: false).groups == [[.saveAsNewSong], [.settings]])
}

@Test func aLoadedSongOffersEverythingButSaving() {
    #expect(HeaderMenuItems(hasSong: true, isEdited: false).groups
        == [[.editSong, .saveAsNewSong, .addToSetlist], [.unload], [.settings]])
}

@Test func anEditedSongPutsSaveChangesAndRevertFirst() {
    #expect(HeaderMenuItems(hasSong: true, isEdited: true).groups
        == [[.saveChanges, .revert], [.editSong, .saveAsNewSong, .addToSetlist], [.unload], [.settings]])
}

@Test func editedWithoutASongIsTreatedAsNothingLoaded() {
    #expect(HeaderMenuItems(hasSong: false, isEdited: true).groups == [[.saveAsNewSong], [.settings]])
}

@Test func theButtonSaysWhenThereAreUnsavedChanges() {
    #expect(HeaderMenuItems.accessibilityLabel(hasBadge: false) == "More")
    #expect(HeaderMenuItems.accessibilityLabel(hasBadge: true) == "More, unsaved changes")
}
```

- [ ] **Step 2: Run and see them fail**

Run: `scripts/test.sh -only-testing:MetronomeTests/HeaderMenuItemsTests`
Expected: build error, `HeaderMenuItems` not found.

- [ ] **Step 3: Implement `HeaderMenuItems`** in its own file, with no SwiftUI import needed.

- [ ] **Step 4: Song sheet.** In `SongSheet`:
  - `setlist` also returns `model.loadedFromSetlist` for `.saveAsNew`, so the existing `Add to <setlist>` toggle shows, on by default (`addToSetlist` already starts true).
  - `save()` passes `addingToLoadedSetlist: addToSetlist` for `.saveAsNew`.
  - The `Purpose.saveAsNew` comment says: from the header menu; the song is created and becomes the loaded one, added to the loaded-from setlist when the switch is on.

- [ ] **Step 5: Run the tests**

Run: `scripts/test.sh`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

Subject: `Decide the header menu's items and offer the setlist on Save as`

---

### Task 4: The menu button, its badge and the header

**Files:**
- Create: `Metronome/Views/HeaderMenuButton.swift`
- Modify: `Metronome/Views/MetronomeScreen.swift` (`header`, the sheets, about lines 6 to 36 and 90 to 109)
- Modify: `Metronome/Views/SongTitle.swift` (delete `SaveButton` and `SettingsButton`; fix the `SongTitle` doc comment)
- Modify: `Metronome/Screenshots/ScreenshotScene.swift` (one new scene)

**Interfaces:**
- Consumes: `HeaderMenuItems` (Task 3), `LibrarySheet(newSetlistWith:)` (Task 2), and from the model: `isEdited`, `isSaveOffered`, `loadedSong`, `saveChanges()`, `discardChanges()`, `revertDescription`, `unloadSong()`, `setSong(_:inSetlist:included:)`, `library.setlistsByRecency`.
- Produces: `HeaderMenuButton(openSettings: () -> Void, newSetlist: (UUID) -> Void)`, a view that reads `MetronomeModel` from the environment and presents the Save as new song and Edit song sheets itself.

- [ ] **Step 1: Build `HeaderMenuButton`.**
  - A SwiftUI `Menu` whose content is built from `HeaderMenuItems(hasSong: model.loadedSong != nil, isEdited: model.isEdited).groups`: one `Section` (or the items followed by `Divider()`) per group, in order.
  - Items, with their SF Symbols: Save changes `square.and.arrow.down`; Revert `arrow.uturn.backward`, built as the old `SaveButton` built it (title, then `model.revertDescription` as a second `Text`, then the image) so the saved values sit on a second line; Edit song `pencil`; Save as new song `plus.square.on.square`; Add to setlist `text.badge.plus`; Unload `eject`; Settings `gearshape`.
  - Save changes calls `model.saveChanges()` and posts `AccessibilityNotification.Announcement("Saved")`.
  - Edit song sets a `@State var editingSong: Song?` to `model.loadedSong`; the view presents `SongSheet(purpose: .edit(song))` with `.sheet(item:)`.
  - Save as new song presents `SongSheet(purpose: .saveAsNew)`.
  - Add to setlist is a nested `Menu`, the same shape as `rowMenu(for:)` in `LibrarySheet.swift`: every setlist in `model.library.setlistsByRecency` with a checkmark when it holds the loaded song, each calling `model.setSong(song.id, inSetlist: candidate.id, included: !isIncluded)`; then `Divider()` and New setlist (`plus`), which calls `newSetlist(song.id)`. No Undo bar here (spec 7.6).
  - Unload calls `model.unloadSong()` and nothing else.
  - Settings calls `openSettings()`.
  - Label: `Image(systemName: "ellipsis")`, 15 pt bold, `Theme.dialWhite`, in a 40 pt frame on `Theme.surface` in a `Circle`, `contentShape(Circle().inset(by: -2))`. Do not reuse `MoreButtonLabel`: its fill is surface raised, for use inside sheets.
  - Badge: while `model.isSaveOffered`, an overlay aligned `.topTrailing`, offset 1 pt right and 1 pt up: a 10 pt `Theme.amber` circle inside a 14 pt `Theme.ink` circle. It uses `.transition(.asymmetric(insertion: .opacity, removal: .identity))`, and the overlay is animated with `.animation(.easeOut(duration: 0.15), value: model.isSaveOffered)`, so it fades in and leaves at once, as the Save button did.
  - `.accessibilityLabel(HeaderMenuItems.accessibilityLabel(hasBadge: model.isSaveOffered))`, no hint.

- [ ] **Step 2: Wire the header.** In `MetronomeScreen`:
  - `header` becomes `SongTitle`, `TrackSwitchButton` when `model.loadedTrack != nil`, `MuteButton`, `HeaderMenuButton`. Remove the `SaveButton` branch and the header-level `.animation` on `isSaveOffered`. Update the doc comment.
  - Add `@State private var newSetlistSongID: UUID?`. `HeaderMenuButton`'s `newSetlist` sets it and then `isLibraryShown = true`; the library sheet is `LibrarySheet(newSetlistWith: newSetlistSongID)`, and the ID is cleared when the sheet is dismissed (`.sheet(isPresented:onDismiss:)`).
  - `openSettings` sets `isSettingsShown = true`.

- [ ] **Step 3: Delete `SaveButton` and `SettingsButton`** from `SongTitle.swift`, and change `SongTitle`'s comment to say unsaved changes belong to the header menu. Search the project for any other use of either name and remove it.

- [ ] **Step 4: Add a screenshot scene `edited`** to `ScreenshotScene`: the default metronome scene (a song loaded from the setlist, stopped) with the tempo nudged by 4 BPM after the model is made, so the badge and the full menu can be seen. Document it like its neighbours ("Not an App Store screenshot; for checking the header in the simulator").

- [ ] **Step 5: Build and test**

Run: `scripts/test.sh`
Expected: `** TEST SUCCEEDED **`, no warnings from the touched files.

- [ ] **Step 6: See it in the simulator** on an iPhone 17 Pro. Launch with `xcrun simctl launch booted com.metsahalme.metronome -screenshotScene edited` and with no scene. Save a screenshot of each to the scratchpad and compare with spec 6.1 and 7.6 and the Paper boards on *Header menu (draft)*:
  1. Nothing loaded: header is title, mute, menu button; the menu holds Save as new song and Settings only.
  2. Scene `edited`: the badge on the button; the menu holds all seven items in the order of 7.6, Revert with `BPM · signature` on its second line.
  3. Save changes: the badge goes at once; the menu no longer holds Save changes or Revert.
  4. Save as new song from the edited scene: the sheet shows `Add to Friday gig`, on. Saved with it on, the header shows `Friday gig · 9 of 9` and Previous / Next stay. Repeat with it off: the header shows the name alone and Previous / Next go.
  5. Add to setlist: the loaded song's setlists are ticked; New setlist opens the library inside a new setlist with the cursor in its name and the song in it.
  6. Unload: the header shows `Library` / `No song loaded`, the tempo stays.
  7. Settings opens the settings sheet.
  8. Scene `trackScreen`: the header is title, Backing tracks switch, mute, menu button.
  9. The library's Songs tab with a song loaded: the search field fills the line; no Unload pill.

  Fix any difference before going on. Note what could not be tried (VoiceOver, haptics need a device).

- [ ] **Step 7: Commit**

Subject: `Put the header's actions in a menu with a badge for changes`

---

### Task 5: Specification checklist

**Files:**
- Modify: `docs/specification.md` (sections 14 and 15 only)

- [ ] **Step 1:** For each line in section 14 that this plan touched (Unload, Search filling the line, the badge and header menu, the header layout and menu contents, Settings opening), tick it only if every claim was covered by a named unit test or seen in Task 4's Step 6, and rewrite its note to say which tests and what was seen, in the style of the neighbouring notes. Leave unticked, with a note, anything not tried (VoiceOver, haptics on a device).

- [ ] **Step 2:** Remove the **Header menu** entry from section 15, or cut it down to what is still not built.

- [ ] **Step 3:** In the intro's design-source paragraph, replace the sentence saying the header on every board differs from 6.1 with a pointer to the page *Header menu (draft)* for the header, its badge and its menu, and say that the v1.0 and Backing tracks boards still draw the earlier header.

- [ ] **Step 4: Commit**

Subject: `Tick what is verified for the header menu`
