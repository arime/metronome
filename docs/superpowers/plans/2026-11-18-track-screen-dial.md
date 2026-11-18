# Track Screen Dial Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the track screen look like the plain screen with the dial locked: the same dial as a gauge that opens Sync mode, a `Sync backing track` row in the time signature row's place, a larger number with no tempo name on both screens, and the Sync sheet in the other sheets' colours.

**Architecture:** The dial's number becomes one shared view sized by one pure function, used by the plain dial and a new track dial. `DialRing` gains a gauge style. `TrackScreenLayout` is rewritten to size the track screen by the plain screen's rules (dial takes the spare height, gaps and tiles give way in the same order), which stays pure and unit tested. The Sync sheet's colour change is passed down through small fill parameters on the shared views it reuses.

**Tech Stack:** Swift, SwiftUI, Swift Testing. Xcode project `Metronome.xcodeproj`, scheme `Metronome`. The project uses file-system synchronised groups, so new files need no project edit.

**Spec:** `docs/specification.md` on this branch: 6.2 (dial number), 6.8 (small screens), 6.9 (colours, surface selected), 6.12 (track screen), 6.13 (Sync mode), 7.1, 7.2, 7.11, 12 (beat effects), 13 (VoiceOver), 14 and 15 (checklist). Design boards: Paper file "Snappy Metronome", page *Track screen with dial (draft)*.

## Global Constraints

- Work only in the worktree `/Users/arime/metronome/.claude/worktrees/screen-menu` on branch `screen-menu`. Never switch the main checkout.
- Build with `scripts/build.sh`, test with `scripts/test.sh`. A task is not done until `scripts/test.sh` ends with `** TEST SUCCEEDED **` and no `warning:` line from files this plan touches.
- Colours only from `Theme`. No colour literals outside `Theme.swift` and the dial's own knob gradients.
- Sizes, in the 300 pt dial design (spec 6.2, 6.12): number 114 pt heavy, three-digit tempos at 88 % of that; gauge disc radius 120 pt, surface fill, 1.5 pt outline in the line colour; ticks unchanged.
- Track screen stack (spec 6.12): header 48 pt, 12 pt, dial, 26 pt, Sync row 60 pt, 22 pt, tiles (76 pt, or 98 pt for two rows), at least 16 pt, player card 192 pt (222 pt with the next-up line). Compact step: both gaps 16 pt and single-row tiles 56 pt. Dial grows to 340 pt, shrinks to 240 pt before the compact step, and the next-up line is left out when it would push the dial below 200 pt.
- UI copy, exactly: `Sync backing track`. No explanatory text.
- VoiceOver, exactly (spec 13): plain dial: label `Tempo`, value `<n> beats per minute`. Track dial: a button, label `Tempo`, value `<n> beats per minute`, hint `Opens Sync mode`. Sync row: `Sync backing track`.
- The track screen's dial never changes the tempo: no drag, no adjustable action, no tempo sheet.
- Shell: single quotes, no `cd` before git, no `git -C`, no command substitution, no backticks in commit messages.
- Commits: imperative subject, capitalised, no trailing period, at most 72 characters, no Conventional Commits prefix, no Claude attribution. Write the message to a scratch file and commit with `git commit -F <file>`.
- Spec section 14: tick a line only when every claim in it is covered by a named unit test or was seen in the simulator; otherwise leave it unticked with a note saying which part is covered. Remove an entry from section 15 only when it is built.

## Review Focus

1. **A three-digit number beside the pointer.** At 255 BPM the pointer sits at 3 o'clock, level with the digits. The 100 pt number must not touch it. Seen in the simulator in Task 1.
2. **A drag across the track screen's dial.** It must change nothing: not the track's tempo, not the metronome's. Pinned by construction (no drag gesture) and tried in the simulator in Task 2.
3. **The file is missing.** A tap on the dial and on the Sync row does nothing, and the row is dimmed. Tried in the simulator in Task 2 with the `trackMissing` scene.
4. **The smallest phone in 9/8.** The layout must return a dial that fits (74 pt on a 320 × 548 pt screen), never a negative size and never a screen that overflows. Pinned in Task 2's tests.
5. **A song with a track whose tempo differs from the metronome's.** The track dial's ticks and number show the track's tempo (`tempoInEffect`), not `settings.bpm`. Pinned in Task 2's simulator check with a scene whose two tempos differ, and by using `tempoInEffect` in one place.

---

### Task 1: A larger number and no tempo name on the dial

**Files:**
- Modify: `Metronome/Model/Tempo.swift` (`DialGeometry`; remove `Tempo.name(for:)`)
- Modify: `Metronome/Views/TempoDial.swift` (`TempoDial.readout`, `numberSize`, accessibility value; `DialRing.numberSize`)
- Modify: `Metronome/MetronomeModel.swift` (remove `tempoName`)
- Modify: `Metronome/Views/TrackScreen.swift` (only where it reads `DialRing.numberSize`, so it still builds)
- Test: `MetronomeTests/TempoTests.swift`, `MetronomeTests/MetronomeModelTests.swift`

**Interfaces:**
- Produces:
  - `DialGeometry.numberSize(bpm: Int, dialDiameter: Double) -> Double`: the BPM number's font size.
  - `DialGeometry.fullNumberSize: Double` = 114, replacing `DialRing.numberSize`.
  - `struct DialNumber: View` in `TempoDial.swift`: `DialNumber(bpm: Int, diameter: CGFloat)`. Draws the number with the tight kerning and the beat pulse, at `DialGeometry.numberSize`, in a line `fullNumberSize * diameter / 300` tall. Reads `MetronomeModel` from the environment for `lastBeat`.

- [ ] **Step 1: Write the failing tests** in `TempoTests`, replacing `tempoNameIsHiddenOnASmallDial`:

```swift
@Test func theDialNumberIs114AndSmallerForThreeDigits() {
    #expect(DialGeometry.numberSize(bpm: 99, dialDiameter: 300) == 114)
    #expect(abs(DialGeometry.numberSize(bpm: 100, dialDiameter: 300) - 100.32) < 0.001)
    #expect(abs(DialGeometry.numberSize(bpm: 300, dialDiameter: 300) - 100.32) < 0.001)
}

@Test func theDialNumberScalesWithTheDial() {
    #expect(DialGeometry.numberSize(bpm: 60, dialDiameter: 150) == 57)
    #expect(abs(DialGeometry.numberSize(bpm: 120, dialDiameter: 340) - 113.696) < 0.001)
}
```

Delete the tests of `Tempo.name(for:)` and of `model.tempoName` (for example `MetronomeModelTests` near line 98, and any in `TempoTests`); delete only the assertions about the name where a test also checks something else.

- [ ] **Step 2: Run and see them fail**

Run: `scripts/test.sh -only-testing:MetronomeTests/TempoTests`
Expected: build error, `numberSize(bpm:dialDiameter:)` not found.

- [ ] **Step 3: Implement.**
  - `DialGeometry`: add `fullNumberSize` and `numberSize(bpm:dialDiameter:)` (`fullNumberSize * dialDiameter / 300`, times 0.88 for `bpm >= 100`). Remove `tempoNameMinimumDiameter` and `showsTempoName`.
  - Remove `Tempo.name(for:)` and `MetronomeModel.tempoName`, and any other use of them.
  - Extract `DialNumber` from `TempoDial.readout`: the `numberText` kerning, `.monospacedDigit()`, `.fixedSize()`, the line-height frame and `NumberPulse`. `TempoDial.readout` becomes `DialNumber(bpm: model.settings.bpm, diameter: diameter)` with its tap opening the tempo sheet; no tempo name under it.
  - `TempoDial` accessibility value: `"\(model.settings.bpm) beats per minute"`.
  - Remove `DialRing.numberSize`; `TrackScreen.swift`'s glow sizing reads `DialGeometry.fullNumberSize` for now (Task 2 rewrites that file).
  - Fix doc comments that mention the tempo name.

- [ ] **Step 4: Run the tests**

Run: `scripts/test.sh`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: See it in the simulator** on an iPhone 17 Pro, plain screen, no scene. Save screenshots to the scratchpad at 88, 120, 255 and 300 BPM (type them with the tempo sheet). Check: no tempo name; at 255 the number does not touch the pointer; at 300 the number is inside the face. If the number touches the pointer at 255, stop and report DONE_WITH_CONCERNS with the screenshot; do not change the sizes yourself.

- [ ] **Step 6: Commit**

Subject: `Enlarge the dial's number and drop the tempo name`

---

### Task 2: The track screen with the dial as a gauge and a Sync row

**Files:**
- Modify: `Metronome/Views/TempoDial.swift` (`DialRing`)
- Modify: `Metronome/Views/TrackLayouts.swift` (`TrackScreenLayout`)
- Modify: `Metronome/Views/TrackScreen.swift` (`TrackScreenContent`; replace `TempoReading` and `SyncButton`)
- Modify: `Metronome/Views/MetronomeScreen.swift` (only if `TrackScreenContent`'s use needs it)
- Test: `MetronomeTests/TrackLayoutTests.swift`

**Interfaces:**
- Consumes: `DialNumber(bpm:diameter:)`, `DialGeometry.fullNumberSize` (Task 1).
- Produces:
  - `DialRing(fraction: Double, style: DialRing.Style = .knob)` with `enum Style { case knob, gauge }`. `.gauge` draws the same ticks, then a flat disc of the knob's radius in `Theme.surface` with a 1.5 pt `Theme.line` outline, and nothing else: no shadow, ridges, face or pointer.
  - `TrackScreenLayout` with: `sideMargin`, `bottomPadding`, `dialDiameter`, `rowTopGap`, `rowBottomGap`, `tileHeight`, `cardHeight`, `tilesHeight`, `showsNextLine`. It no longer has `readingRoom` or `numberFontSize`.
  - `struct TrackDial: View`: `TrackDial(diameter: CGFloat)`.
  - `struct SyncRow: View`: `SyncRow()`.

- [ ] **Step 1: Write the failing tests.** In `TrackLayoutTests`, replace the track screen tests (`theTrackScreenOnAnIPhone17Pro`, `theTrackScreenOnAnIPhoneSE`, `theTrackScreenWithDisplayZoom`, `theNextUpLineNeeds280OfRoom`, `theNumberScalesBelow152OfRoom`, `anImpossiblyShortScreenKeepsTheSmallestNumber`, `theTrackScreenFillsTheHeight`) with these, using the file's `trackScreen(...)` helper. Leave the Sync mode tests alone.

```swift
@Test func theTrackScreenOnAnIPhone17Pro() {
    let layout = trackScreen(width: 402, height: 778, hasBottomInset: true, hasSetlist: true)
    #expect(layout.dialDiameter == 296)
    #expect(layout.showsNextLine)
    #expect(layout.cardHeight == 222)
    #expect(layout.rowTopGap == 26)
    #expect(layout.rowBottomGap == 22)
    #expect(layout.tileHeight == 76)
    #expect(trackScreen(width: 402, height: 778, hasBottomInset: true, beats: 9, hasSetlist: true).dialDiameter == 274)
    #expect(trackScreen(width: 402, height: 778, hasBottomInset: true).dialDiameter == 326)
    #expect(trackScreen(width: 402, height: 778, hasBottomInset: true, beats: 12).dialDiameter == 304)
}

@Test func theTrackScreenOnAnIPhoneSE() {
    let layout = trackScreen(height: 647, hasSetlist: true)
    #expect(layout.showsNextLine == false)
    #expect(layout.cardHeight == 192)
    #expect(layout.dialDiameter == 215)
    #expect(layout.rowTopGap == 16)
    #expect(layout.rowBottomGap == 16)
    #expect(layout.tileHeight == 56)
    #expect(trackScreen(height: 647, beats: 9, hasSetlist: true).dialDiameter == 173)
}

@Test func theTrackScreenWithDisplayZoom() {
    #expect(trackScreen(width: 320, height: 548, hasSetlist: true).dialDiameter == 116)
    #expect(trackScreen(width: 320, height: 548, hasSetlist: true).showsNextLine == false)
    #expect(trackScreen(width: 320, height: 548, beats: 9, hasSetlist: true).dialDiameter == 74)
}

@Test func theDialGrowsTo340AndNoWiderThanTheMargins() {
    #expect(trackScreen(width: 402, height: 900, hasBottomInset: true).dialDiameter == 340)
    #expect(trackScreen(width: 375, height: 900, hasBottomInset: true).dialDiameter == 327)
}

@Test func theNextUpLineIsLeftOutBelowA200Dial() {
    // With the line and the compact step the fixed parts are 168 + 56 + 222 = 446.
    #expect(trackScreen(height: 446 + 200, hasBottomInset: true, hasSetlist: true).showsNextLine)
    #expect(trackScreen(height: 446 + 199, hasBottomInset: true, hasSetlist: true).showsNextLine == false)
}

@Test func theDialShrinksTo240BeforeTheGapsGiveWay() {
    // Without the line the fixed parts are 184 + 76 + 192 = 452 with the full gaps.
    let roomy = trackScreen(height: 452 + 240, hasBottomInset: true)
    #expect(roomy.dialDiameter == 240)
    #expect(roomy.tileHeight == 76)
    let compact = trackScreen(height: 452 + 239, hasBottomInset: true)
    #expect(compact.tileHeight == 56)
    #expect(compact.rowTopGap == 16)
}

@Test func anImpossiblyShortScreenKeepsTheSmallestDial() {
    #expect(trackScreen(height: 200).dialDiameter == TrackScreenLayout.minimumDial)
}

@Test func theTrackScreenFillsTheHeightOrLeavesSpareAboveTheCard() {
    for height in stride(from: CGFloat(560), through: 900, by: 17) {
        for beats in [4, 7, 9, 12] {
            let layout = trackScreen(height: height, hasBottomInset: true, beats: beats, hasSetlist: true)
            let used = TrackScreenLayout.headerHeight + TrackScreenLayout.dialTopGap + layout.dialDiameter
                + layout.rowTopGap + TrackScreenLayout.rowHeight + layout.rowBottomGap + layout.tilesHeight
                + TrackScreenLayout.cardTopGap + layout.cardHeight
            #expect(used <= height)
        }
    }
}
```

`tilesHeight` is the tiles' height at `layout.tileHeight` (`AccentTiles.height(forBeats:singleRowTileHeight:)`).

- [ ] **Step 2: Run and see them fail**

Run: `scripts/test.sh -only-testing:MetronomeTests/TrackLayoutTests`
Expected: build errors for `dialDiameter` and the other new members.

- [ ] **Step 3: Rewrite `TrackScreenLayout`** by the plain screen's rule (`ScreenLayout` in `MetronomeScreen.swift` is the model to follow):
  - Constants: `headerHeight` 48, `dialTopGap` 12, `rowHeight` 60, `cardTopGap` 16, `playerCardHeight` 192, `playerNextLineHeight` 30, `nextLineMinimumDial` 200, `minimumDial` 60 (a safety floor; the smallest supported case is 74). Reuse `ScreenLayout.fullDial`, `maximumDial`, `roomyMinimumDial`.
  - The largest dial is `min(340, max(300, width - 2 * sideMargin))`.
  - `fit(nextLine:)`: with the roomy values (gaps 26 and 22, tiles 76), if the height left for the dial is at least 240, the dial is that height capped at the largest dial; otherwise use the compact values (gaps 16 and 16, tiles 56) and the dial is the height left, capped at the largest dial and floored at `minimumDial`.
  - With a setlist, use the fit with the next-up line when its dial is at least 200; otherwise the fit without it.
  - Remove the members and constants that only the tempo reading used.

- [ ] **Step 4: `DialRing` gauge style.** Add `style` as specified under Produces. Keep `.knob` drawing exactly as it is. The ticks are shared code, not copied.

- [ ] **Step 5: `TrackDial`, `SyncRow` and the screen.**
  - `TrackDial(diameter:)`: a `Button` whose action is `model.enterSyncMode()` and whose label is a `ZStack` of `DialRing(fraction: Tempo.arcFraction(for: model.tempoInEffect), style: .gauge)`, `BeatGlow(lastBeat: model.lastBeat, bpm: model.tempoInEffect, diameter: diameter)` at opacity 1 only while `model.isPlaying` (stopped, there is no glow, even mid-fade), and `DialNumber(bpm: model.tempoInEffect, diameter: diameter)`, framed `diameter` square with a circular content shape. `.buttonStyle(.plain)`, `.disabled(model.isTrackMissing)`. It has no drag gesture, no adjustable action and no sheet. Accessibility: one element, a button, label `Tempo`, value `"\(model.tempoInEffect) beats per minute"`, hint `Opens Sync mode`.
  - `SyncRow()`: built like the row in `TimeSignatureRow.swift` (60 pt tall, `Theme.surface`, 18 pt continuous corners, 20 pt leading and 18 pt trailing padding): the label `Sync backing track` (16 pt medium, `Theme.dialWhite`) taking the width, and `chevron.right` (13 pt bold, `Theme.muted`) in a 16 pt slot. Its action is `model.enterSyncMode()`. With `model.isTrackMissing` it is at 40 % opacity and disabled. Accessibility label `Sync backing track`.
  - `TrackScreenContent`: from the top, `TrackDial(diameter: layout.dialDiameter)` with 12 pt above it, `SyncRow()` with `layout.rowTopGap` above it, `AccentTiles(singleRowTileHeight: layout.tileHeight)` with `layout.rowBottomGap` above it, `Spacer(minLength: TrackScreenLayout.cardTopGap)`, `PlayerCard(showsNextLine: layout.showsNextLine)`.
  - Delete `TempoReading` and `SyncButton`. Search the project for other uses of either, and of `readingRoom`, `numberFontSize`, `syncButtonHeight`.

- [ ] **Step 6: Run the tests**

Run: `scripts/test.sh`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 7: See it in the simulator** on an iPhone 17 Pro, and on an iPhone SE if a simulator of it exists. Launch with `-screenshotScene` set to `trackScreen`, `trackPlaying`, `trackSolo` and `trackMissing`, save a screenshot of each to the scratchpad, and compare with spec 6.12 and the Paper board *Track — dial as gauge, Sync row*:
  1. The dial is the plain screen's size and place, with a flat dark disc, no ridges and no pointer; the ticks are lit to the track's tempo; the number matches the plain screen's.
  2. No time signature and no Sync pill; the `Sync backing track` row sits where the plain screen has the time signature row.
  3. A tap on the dial opens Sync mode; so does a tap on the row.
  4. A drag around the dial changes nothing.
  5. `trackPlaying`: the number pulses and glows on the beat.
  6. `trackMissing`: the row is dimmed, and neither tap does anything.
  7. Compare the plain screen (Backing tracks switched off for the same song) with the track screen: the dial's top edge is at the same height on both.

  Fix any difference before going on, and note what could not be tried.

- [ ] **Step 8: Commit**

Subject: `Show the dial as a gauge on the track screen, with a Sync row`

---

### Task 3: Sync mode in the other sheets' colours, and one selected grey

**Files:**
- Modify: `Metronome/Views/Theme.swift`
- Modify: `Metronome/Views/SyncMode.swift`, `Metronome/Views/SyncModeControls.swift`
- Modify: `Metronome/Views/TimeSignatureRow.swift`, `Metronome/Views/AccentTiles.swift`, `Metronome/Views/TrackControls.swift` (new fill parameters with today's values as defaults)
- Modify: `Metronome/Views/LibrarySheet.swift`, `Metronome/Views/TrackSwitchButton.swift` (the token)

**Interfaces:**
- Produces:
  - `Theme.surfaceSelected` = `#3A3A3F`, replacing `Theme.tileDot` and every literal `0x3A3A3F` and `0x3A3A40` in `Metronome/Views`.
  - `TimeSignatureRow(sideMargin:, fill: Color = Theme.surface)`.
  - `AccentTiles(singleRowTileHeight:, idleFill: Color = Theme.surface)`, passed to `BeatTile.idleFill`.
  - `TrackSkipButton` gains `fill: Color = Theme.surfaceRaised`.
  - `TrackProgressBar(unplayed: Color = Theme.line)`.

- [ ] **Step 1: The token.** Rename `Theme.tileDot` to `surfaceSelected` with the doc comment "The selected segment of a switch-like control, and buttons that sit on surface raised." Use it for the library's selected tab and its swipe Edit tint (`LibrarySheet.swift`), the Backing tracks switch when on (`TrackSwitchButton.swift`) and the selected count-in option (`SyncModeControls.swift`), deleting their private colour constants.

- [ ] **Step 2: The parameters.** Add the four parameters under Produces, each defaulting to what the view draws today, so no other screen changes.

- [ ] **Step 3: Sync mode (spec 6.13).**
  - The sheet's background and its content's background are `Theme.surface`.
  - `TimeSignatureRow(..., fill: Theme.surfaceRaised)` and `AccentTiles(..., idleFill: Theme.surfaceRaised)`.
  - Stepper pills on `Theme.surfaceRaised`; their − and + buttons on `Theme.surfaceSelected`.
  - Count-in options on `Theme.surfaceRaised`; the selected one on `Theme.surfaceSelected`.
  - Playback card on `Theme.surfaceRaised`; its Rewind and Fast-forward with `fill: Theme.surfaceSelected`; its progress bar with `unplayed: Theme.surfaceSelected`.
  - The mix slider, the tap pads, all text colours, sizes and layout stay as they are.
  - Update doc comments that describe the old colours.

- [ ] **Step 4: Build and test**

Run: `scripts/test.sh`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: See it in the simulator** on an iPhone 17 Pro with `-screenshotScene trackSync` and `trackSyncTimer` (press play in the latter). Save screenshots and compare with spec 6.13: the sheet is on surface like the library sheet; the row, idle tiles, steppers, count-in options and playback card are one step lighter; the − and +, the selected count-in option, Rewind and Fast-forward are lighter again; the unplayed part of the card's progress line is visible; nothing is amber except the tap pads, accented tiles, the offset's `s`, the played part of the line and the play button. Also look at the player card on the track screen and the library's tab switch to confirm they did not change.

- [ ] **Step 6: Commit**

Subject: `Give Sync mode the other sheets' colours and one selected grey`

---

### Task 4: Specification checklist

**Files:**
- Modify: `docs/specification.md` (sections 14 and 15 only)

- [ ] **Step 1:** For each line in section 14 about the dial's number and tempo name, the track screen's layout, taps, beat marking and fit, the player card's missing-file state, entering Sync mode, Sync mode's look and the VoiceOver readings this plan changed: tick it only if every claim was covered by a named unit test or seen in a simulator step of Tasks 1 to 3, and rewrite its note to say which tests and what was seen, in the style of the neighbouring notes. Leave unticked, with a note, anything not tried (VoiceOver, an iPhone SE if none was available, the real audio engine).

- [ ] **Step 2:** Remove from section 15 the entries this plan built: the dial's number, the track screen's dial and Sync row, Sync mode's sheet colours, surface selected.

- [ ] **Step 3: Commit**

Subject: `Tick what is verified for the track screen's dial`
