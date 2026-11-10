# Snappy Metronome specification

This is the single specification for the app. It describes how version 1.0 is meant to work and is kept up to date as decisions change. Parts that are specified here but not built yet are listed in section 15.

Design source: Paper file "Snappy Metronome". The page *v1.0* holds the metronome screen, the time signature picker, the beat effects and the app icon. The page *v1.0 — Presets & setlists (draft)* holds the library and setlist boards. The page *v1.0 — Settings & click sounds (draft)* holds the metronome screen with the settings button and Previous / Next beside Start, and the settings sheet; its other boards are alternatives that were not chosen.

## 1. Summary

A native iOS metronome with one main screen. The user sets a tempo and a time signature, chooses which beats are accented, and presses Start. Each beat produces a click, a visual effect and a haptic tap on the same instant. Everything can be changed while it plays.

Settings can be saved as named **presets**, usually one per song or practice setup. The **library** lists all presets, and **setlists** are named, ordered selections from it. The loaded preset's name sits in the header of the metronome screen; tapping it opens the library.

## 2. Scope

Included:

- Tempo from 30 to 250 BPM, set by ring drag, − / + buttons or tap tempo.
- Eight time signatures: 2/4, 3/4, 4/4, 5/4, 6/8, 7/8, 9/8, 12/8.
- Per-beat accents; any combination of beats, including none.
- Start / Stop with click sound, visual beat effects and haptics.
- A mute button that silences the click while the metronome keeps running.
- A preset library and setlists.
- A settings sheet with a choice of seven click sounds.
- Everything remembered between launches.

Not included:

- Bar counter, subdivisions, a volume control inside the app (the phone's own volume controls set the click volume; see 7.7).
- Playback with the screen locked or the app in the background.
- Search, folders or tags, notes on presets, per-preset sounds, sync between devices, import, export and sharing.
- iPad layout, landscape, light mode, Apple Watch, widgets.

## 3. Platform and identity

- iPhone only, portrait only, dark appearance only.
- SwiftUI. Minimum iOS version: iOS 18.
- Designed at 390 × 844 pt. Smaller phones adapt the layout; see 6.8.
- Typeface: the system font (SF Pro). The Paper boards use Inter and Inter Tight as stand-ins because SF Pro is not available there. Weights and sizes in this document carry over.
- Version: 1.0. Until 1.0 is released, new work stays in 1.0 and goes to TestFlight as a new build number.
- App Store name: "Snappy Metronome". Under the icon on the home screen the app shows as "Metronome", because the full name does not fit there.
- Bundle identifier: `com.metsahalme.metronome`.
- App icon: "Downbeat", one large amber dot followed by three small dial-white dots on ink, as a single 1024 × 1024 image.

## 4. Concepts

- A **preset** has a name, a tempo, a time signature and a set of accented beats: the same settings as the metronome screen.
- The **library** holds every preset. Presets exist only in the library; setlists refer to them.
- A **setlist** has a name and an ordered list of presets. It acts as a filter on the library and defines the order shown while it is selected.
- A preset can be in any number of setlists, but only once in each.
- Removing a preset from a setlist never deletes the preset.
- Deleting a preset removes it from the library and from every setlist.
- Changing a preset changes it everywhere, since setlists share the same preset.
- Names need not be unique, for presets or for setlists.
- Beats per bar is the top number of the time signature (7/8 has seven beats). One beat is one click. BPM counts clicks per minute for every signature, including the /8 ones.

## 5. State

Kept between launches:

| Item | Contents | Default |
|---|---|---|
| Tempo | integer, 30…250 BPM | 120 |
| Time signature | one of the eight in section 2 | 4/4 |
| Accents | set of beat numbers, 1…beats per bar | {1} |
| Presets | each with id, name, tempo, time signature, accents | none |
| Setlists | each with id, name, ordered preset ids, last-used time | none |
| Loaded preset | the preset in the metronome, if any | none |
| Loaded-from setlist | the setlist the preset was loaded from, if any | none |
| Selected filter | what the library sheet shows: All presets or a setlist | All presets |
| Click sound | one of the seven sounds in 11.1 | Digital |

Not kept:

| Item | Contents | At launch |
|---|---|---|
| Playing | whether the metronome is running | stopped |
| Muted | whether the click is silenced | sound on |
| Current beat | the beat that is sounding | none |

Derived:

- **Edited:** a preset is loaded and the current tempo, time signature or accents differ from it.
- **Position:** the loaded preset's place in the loaded-from setlist, such as 3 of 8.

Reopening the app restores the settings, the loaded preset and its setlist, so the position in the setlist is restored too and the user can carry on with Next. The app always launches stopped and with sound on.

Data is stored on the device only.

If the loaded preset is deleted, the metronome keeps its current settings and the header shows "nothing loaded". If it is removed from the loaded-from setlist, it stays loaded and the header shows the name alone, as for a preset loaded from All presets.

## 6. Metronome screen

One screen with two states, Ready (stopped) and Playing. The layout is identical in both, so nothing moves when Start is pressed. From top to bottom:

### 6.1 Header

**Preset title**, at the left, taking the space left by the buttons. One or two lines; a long name is cut with an ellipsis. Line 1 is 20 pt heavy in dial white, followed by a small ˅. Line 2 is 13 pt in muted. Without a line 2, line 1 is centred vertically in the header.

| State | Line 1 | Line 2 |
|---|---|---|
| Nothing loaded | `Library` | `No preset loaded` |
| Loaded from All presets | preset name | none |
| Loaded from a setlist | preset name | setlist name · `3 of 8` |
| Edited | preset name | `Edited` in amber, followed by · `3 of 8` when from a setlist |

While playing, an amber dot sits before line 1.

**Mute button**, 40 pt round:

- Sound on: a dial-white speaker with sound waves on a surface fill.
- Muted: an amber crossed-out speaker on the amber tint fill with a 1.5 pt amber outline.

**Settings button**, at the far right: a 20 pt dial-white gear with no fill, in a 32 pt wide slot aligned to the right margin. It is lighter than the round buttons because it is used far less often. Its touch area is 44 × 44 pt. It opens the settings sheet (6.10).

The header has only these two buttons, so the title always gets about 240 pt. Previous and Next sit beside the Start / Stop button (6.7).

### 6.2 Tempo dial

- 300 pt gauge. 48 tick marks on a 270° arc that starts at the lower left (the 7:30 position), runs clockwise over the top and ends at the lower right (4:30), leaving a 90° gap at the bottom. Every fourth tick is longer and thicker.
- Ticks from the start of the arc up to the current tempo are amber; the rest are unlit. Position along the arc is linear: `(bpm − 30) / 220`.
- A 28 pt amber knob with a dark 5 pt border and an amber glow sits at the end of the lit arc.
- Centre: the BPM number (112 pt, heavy, digits set slightly tight, dial white). Three-digit tempos are drawn at 88 % of that size so they stay clear of the knob. Below the number: `BPM` in amber, a dot, and the tempo name in muted italic.

Tempo names:

| BPM | Name |
|---|---|
| 30–39 | Grave |
| 40–59 | Largo |
| 60–65 | Larghetto |
| 66–75 | Adagio |
| 76–107 | Andante |
| 108–119 | Moderato |
| 120–155 | Allegro |
| 156–175 | Vivace |
| 176–199 | Presto |
| 200–250 | Prestissimo |

### 6.3 Tempo controls

A row of three: − (56 pt round), `Tap tempo` (outlined pill with a hand icon), + (56 pt round).

### 6.4 Time signature row

A 60 pt row: the label `Time signature`, the current value in amber (for example `4/4`), and a › chevron. Tapping it opens the picker (6.6). It looks and behaves the same when stopped and when playing.

### 6.5 Accents

The label `ACCENTS`, then one tile per beat in a single row with 10 pt gaps, each 76 pt tall with a 20 pt corner radius. Each tile shows a small mark above its beat number.

| Tile state | Fill | Border | Number and mark |
|---|---|---|---|
| Not accented, idle | surface | none | muted number, small dot |
| Accented, idle | dark amber tint | 1.5 pt amber | amber number, ^ mark |
| Not accented, sounding | dial white | none | ink number, ink dot |
| Accented, sounding | amber, with amber glow | none | ink number, ink ^ mark |

"Sounding" applies only while playing, to the tile of the current beat. A sounding tile follows the beat as it was scheduled, so it always agrees with the click and the haptic.

Up to seven tiles fit in one row. For 9/8 and 12/8 the tiles wrap into two equal rows (5 + 4, and 6 + 6) and the tile height drops to 44 pt, with the mark omitted.

### 6.6 Time signature picker

A bottom sheet over a dimmed screen, sized to its content: a grabber, the title `Time signature`, and a 4 × 2 grid of options. Each option shows the signature and a one-word hint:

| 2/4 | 3/4 | 4/4 | 5/4 | 6/8 | 7/8 | 9/8 | 12/8 |
|---|---|---|---|---|---|---|---|
| March | Waltz | Common | Odd | Compound | Odd | Compound | Compound |

The current signature is filled amber with a glow.

### 6.7 Start / Stop button

A 68 pt pill pinned to the bottom with 24 pt side margins.

- Stopped: amber fill, ink play icon and `Start`, soft amber glow.
- Playing: surface fill, 1.5 pt amber outline, amber stop icon and `Stop`, no glow.

**Previous and Next** are shown only when the preset was loaded from a setlist (see 7.6). They are 56 pt round buttons on a surface fill with a dial-white ‹ and › (20 pt), one on each side of the pill, 12 pt from it and centred on it. The pill takes the width that is left, about 206 pt. Putting them here keeps song changes under the thumb, next to Start.

The footer changes only when the loaded preset's setlist changes, never between Ready and Playing, so nothing moves when Start is pressed.

### 6.8 Small screens

The design is drawn for a 390 × 844 pt screen. On shorter screens the layout adapts in this order and stops as soon as everything fits:

1. The dial shrinks, down to 240 pt.
2. The gaps above and below the time signature row drop to 16 pt, and single-row accent tiles drop to 56 pt tall with a smaller number.
3. The dial shrinks further, as far as it needs to. The screen never scrolls.

In practice only an iPhone SE with Display Zoom (320 × 568 pt) goes below 200 pt: its dial is about 150 pt, or about 108 pt in 9/8 and 12/8. An iPhone SE without Display Zoom gets about 249 pt, or 207 pt in 9/8 and 12/8.

A small dial is simplified so that it stays legible:

- Below 180 pt the tempo name is hidden; the centre shows the number and `BPM` only.
- The knob scales with the dial, from 28 pt on the full-size dial down to about 17 pt at the smallest.

At least 16 pt is always kept between the accent tiles and the Start / Stop button. Phones without a home indicator get a 16 pt margin below the button.

On screens narrower than 360 pt the side margins drop from 24 pt to 16 pt.

When accent tiles are narrower than 44 pt (seven beats in a row), each tile's touch area extends into the gaps on either side so that it is at least 44 pt wide. The tile is drawn at its normal size.

### 6.9 Colours

| Token | Value | Use |
|---|---|---|
| ink | `#0B0B0C` | background; text on amber and white |
| surface | `#17171A` | rows, round buttons, idle tiles, sheets |
| surface raised | `#222226` | picker options, fields and rows inside sheets |
| line | `#2A2A2E` | unlit ticks, outlines |
| dial white | `#F3EEE6` | primary text; sounding unaccented tile |
| muted | `#8A8780` | labels, secondary text |
| muted dim | `#6B6963` | idle unaccented tile numbers, position numbers |
| amber | `#FFB224` | the single accent colour |
| amber tint | `#1E1A12` | idle accented tile fill, muted button fill |
| red | `#E5484D` | remove and delete actions only |

### 6.10 Settings sheet

A bottom sheet over a dimmed screen, sized to its content, styled like the New preset sheet: a grabber, the title `Settings` (26 pt heavy, dial white) and `Done` in amber at the right.

**Click sound** is one surface-raised card with 16 pt corners:

- A header line: `CLICK SOUND` (13 pt, semibold, capitals, wide letter spacing, muted) and, at the right, `Tap to hear it` (13 pt, muted dim).
- One 44 pt row per sound, in this order: Digital, Soft beep, Woodblock, Mallet, Glass, Tick, Classic. Each row shows only the name (16 pt, dial white). Thin line-coloured dividers separate the rows and start at the text edge.
- The selected sound's name is amber and semibold, with an amber tick at the right. The tick has a fixed slot, so names line up in every row.

Below the card: `Use your phone's volume buttons to set how loud the click is.` (13 pt, muted).

New settings are added as further rows or cards in the same sheet.

## 7. Metronome behaviour

### 7.1 Tempo

All three tempo controls work when stopped and when playing.

- **Ring.** Dragging the knob or swiping on the ring sets the tempo. The knob follows the angle of the finger around the dial centre, mapped linearly over the 270° arc, rounded to whole BPM. Angles in the gap at the bottom clamp to the nearer end. Only touches that begin on the ring, between 0.35 and 0.55 dial diameters from the centre (105 pt and 165 pt on the full-size dial), start a drag, so a touch on the number does nothing.
- **− / +.** One tap changes the tempo by 1 BPM. Holding repeats: after 400 ms, 10 steps per second.
- **Tap tempo.** From the second tap on, the tempo is set to the average of the last four intervals between taps (fewer if fewer exist). A pause longer than 2 seconds starts a new series.
- All inputs clamp to 30…250.
- While playing, a tempo change takes effect from the next beat. The beat that is already scheduled is not moved, and the bar position is kept.

### 7.2 Time signature

- Tapping the row opens the picker. Tapping an option selects it and closes the sheet.
- Swiping the sheet down or tapping outside it closes it without changes.
- Choosing a different signature resets the accents to beat 1 only.
- While playing, the metronome keeps playing: the next beat is beat 1 of a new bar in the new signature.
- Choosing the signature that is already selected changes nothing.

### 7.3 Accents

- Tapping a tile toggles that beat's accent. This works when stopped and when playing.
- Any combination is allowed, including all beats and no beats.
- While playing, a toggle changes the tile's idle appearance at once. The click, effect and haptic for that beat change the next time the beat is scheduled; a beat that is already scheduled is not altered.

### 7.4 Start and stop

- Start begins playback on beat 1, with the first click straight away.
- Stop silences playback at once, clears the current beat and returns every tile to its idle appearance.
- The screen does not dim or lock while playing.

### 7.5 Mute

- Tapping the mute button silences the click at once, including clicks that are already scheduled, or brings it back.
- The metronome keeps running: the glow, the number pulse, the tile lighting and the haptics carry on.
- It works when stopped and when playing.
- Mute is separate from the phone's volume and is not remembered between launches.

### 7.6 Presets on the metronome screen

**Loading** a preset applies its tempo, time signature and accents to the metronome. It happens from the library, from Previous / Next, and from Discard changes.

- Unsaved edits to the previously loaded preset are dropped without asking.
- When stopped, the metronome stays stopped.
- When playing, it keeps playing: the next beat is beat 1 of a new bar with the new settings.

**Tapping the title:**

- Not edited: opens the library sheet (section 8).
- Edited: opens a menu with, in this order:
  - **Save changes:** writes the current settings into the loaded preset.
  - **Save as new preset:** opens the New preset sheet (section 10) filled with the current settings. After saving, the new preset is the loaded one.
  - **Discard changes:** sets the metronome back to the preset's settings.
  - **Open library:** opens the library sheet. The edits are kept.

**Previous and Next** load the previous or next preset in the loaded-from setlist's order.

- At the first preset Previous is dimmed and does nothing; at the last, Next. They do not wrap around.
- They work when stopped and when playing.

### 7.7 Interruptions and volume

- Playback stops when the app leaves the foreground, when the screen is locked, and on audio interruptions such as a phone call. It does not resume by itself.
- Playback stops if the audio output goes away, for example when headphones are unplugged. The screen never shows Playing while nothing can sound.
- The click plays even when the ring/silent switch is on silent, as a metronome is the app's whole purpose. Other audio is paused while the metronome plays.
- The click volume is set with the phone's regular volume controls: the side buttons and the Control Center slider. The click is ordinary media audio and the app never overrides the system volume. If "Change with Buttons" is on in the phone's sound settings, the side buttons adjust the ringer while nothing is playing; that is system behaviour.

### 7.8 Settings and click sound

- The settings button opens the settings sheet, when stopped and when playing. `Done`, swiping the sheet down or tapping outside it closes it.
- Tapping a sound selects it at once, with a selection haptic. There is no confirm step; closing the sheet keeps the choice.
- **When stopped**, tapping a sound, including the one already selected, also plays a preview: an accented click and then a normal click, 0.5 s apart. The preview plays even when muted, because the user asked to hear it. A new tap during a preview cuts it short and starts the new one.
- **When playing**, there is no preview; the metronome itself is the preview. The new sound is used from the next beat that is scheduled. A beat that is already scheduled keeps the old sound, as with accent toggles (7.3).
- The choice applies to the whole app and is remembered between launches. Presets do not store a sound.

## 8. Library sheet

A tall sheet over the metronome, with a grabber. Swiping it down closes it and changes nothing.

### 8.1 Header

- **Title = filter selector.** It names what is shown, `All presets` or the setlist's name, with a ˅. Tapping it opens the filter list (9.1).
- One button at the right, depending on what is shown:
  - All presets: **New preset**, which opens the New preset sheet (section 10).
  - A setlist: **Edit**, with a pencil, which opens editing (9.2). Adding presets to the setlist happens there; only an empty setlist has a shortcut for it (8.3).

### 8.2 All presets

- Every preset, sorted by name A–Z, ignoring case and following the phone's language rules. Presets with the same name keep their order of creation.
- Each row shows the name (17 pt), and below it tempo and time signature, for example `120 BPM · 4/4`. At the right is a 40 pt round play button.
- The loaded preset's row has an amber name, `· loaded` after its details, and an amber play button.
- **Tapping a row** loads the preset and closes the sheet. It does not start the metronome.
- **Tapping the play button** loads the preset, closes the sheet and starts the metronome. If it is already playing, it keeps playing with the new preset.
- A preset loaded from this view has no loaded-from setlist, so Previous / Next are hidden.
- **Swiping a row left** reveals **Rename** and **Delete**.
  - Rename asks for the new name in a small dialog.
  - Delete asks for confirmation and says how many setlists the preset is in.
- Empty library: only the text `No presets in the library yet`, centred. New presets are made with the button in the header.

### 8.3 A setlist

- Only the setlist's presets, in the setlist's order, each with its position number at the left.
- Above the list: the count, such as `8 PRESETS`.
- Rows, tapping and the play button work as in 8.2. A preset loaded from this view has this setlist as its loaded-from setlist, so the header shows the position and Previous / Next.
- Rows cannot be swiped here; removing and reordering happen in Edit.
- Empty setlist: the text `No presets in this setlist`, centred, with an outlined **Add preset** button under it. The button opens 9.3 directly, as a shortcut for filling a new setlist without going through Edit.

## 9. Setlists

### 9.1 Filter list

Opened from the library sheet's title. A list titled `Show`:

- `All presets` first, with the number of presets.
- Then every setlist with its preset count, most recently used first. A setlist counts as used when it is selected here or a preset is loaded from it.
- The current filter is amber with a tick.
- Tapping an entry selects it, closes the list and shows that view. It loads nothing into the metronome.
- **New setlist** button at the top right: creates an empty setlist, selects it and opens it in Edit with the name field ready for typing.
- The list scrolls; there is no limit on the number of setlists.

### 9.2 Editing a setlist

Opened with Edit in a setlist view's header.

- **Name field** at the top. An empty name is not accepted; the previous name is kept.
- **Done** closes editing. Every change below takes effect at once; there is no cancel.
- Each row has a red remove button at the left and a drag handle at the right.
  - Remove takes the preset out of this setlist immediately, without confirmation. The preset stays in the library.
  - Dragging the handle moves the row; the new order is the setlist's order.
- **Add preset** row after the last preset: opens 9.3.
- **Duplicate setlist:** creates a setlist named `<name> copy` with the same presets in the same order, selects it and stays in Edit on the copy. The presets are shared, not copied.
- **Delete setlist:** asks for confirmation, deletes the setlist and shows All presets. The presets stay in the library.

### 9.3 Adding presets to a setlist

Opened with Add preset, in Edit or in an empty setlist. A list titled `Add to <setlist>`, with Done, which goes back to where the list was opened from.

- First row: **New preset**, which opens the New preset sheet (section 10) with "Add to <setlist>" switched on.
- Then every preset in the library, A–Z, with a tick when it is in the setlist.
- Tapping a row adds the preset to the end of the setlist, or removes it. Changes take effect at once.

## 10. New preset sheet

A short sheet with:

- **Name field**, ready for typing. Save is disabled while the name is empty. Names are limited to 60 characters; spaces at the ends are removed.
- **Tempo:** − and + around the value. One tap changes it by 1 BPM; holding repeats, as on the metronome screen.
- **Time signature row:** opens the same picker as the metronome screen. Changing it resets the accents to beat 1.
- **Accent tiles:** one per beat, tap to toggle.
- **Add to <setlist>** switch: shown only when the sheet was opened from 9.3, and on by default there.
- **Save preset.**

All three settings start from the metronome's current values, so the quickest way to make a preset is to set the metronome first.

Changing values in the sheet does not affect the metronome, playing or stopped. Saving a new preset from the library does not load it; only **Save as new preset** from the title menu (7.6) makes the new preset the loaded one.

## 11. Audio and timing

- Seven click sounds, all generated in code when playback starts, at the output's own sample rate. Each sound has an accented and a normal variant (table below).
- Clicks are scheduled on the audio clock, a little ahead of time. They are never driven by a UI timer.
- A beat is never scheduled in the past. After a large tempo jump the next beat sounds straight away and the following ones space out from it, so beats never bunch up.
- Visual effects and haptics are triggered from the same schedule, so the three stay together.
- Starting playback must not block the screen: the phone's audio is taken over in the background and the first click follows as soon as that is done.
- If starting fails, the app returns to the stopped state and gives the phone's audio back to other apps.
- Targets: each click within 2 ms of its ideal time, and no accumulated drift over 10 minutes at any tempo.

### 11.1 Click sounds

"Decay" is the time constant of an exponential fade. Levels in brackets are relative to the sound's first component. The noise in Woodblock, Tick and Classic comes from a fixed seed, so a sound is identical every time.

| Sound | How it is made | Accented | Normal |
|---|---|---|---|
| Digital | A sine burst that starts at its peak, 5 ms decay, 30 ms long. | 1760 Hz | 1175 Hz |
| Soft beep | A sine with a 1 ms fade-in. | 1568 Hz, 22 ms decay, 90 ms long | 1047 Hz, 18 ms decay, 80 ms long |
| Woodblock | Sines at f (14 ms decay), 2.65 f (0.45, 6 ms) and 4.1 f (0.15, 3 ms), plus a noise strike (0.8 ms decay) band-passed at 3 f (0.6). 70 ms long. | f = 1180 Hz | f = 880 Hz |
| Mallet | Sines at f (45 ms decay), 4 f (0.30, 12 ms) and 9.9 f (0.06, 4 ms), 0.7 ms fade-in. 140 ms long. | f = 1047 Hz | f = 784 Hz |
| Glass | An FM bell: carrier f, modulator 3.5 f, modulation index 2.2 with 12 ms decay, amplitude decay 38 ms, 0.6 ms fade-in. 140 ms long. | f = 1760 Hz | f = 1319 Hz |
| Tick | Noise, high-passed at 6 kHz, plus the same noise through a band-pass (Q 4, 0.8). 60 ms long. | 8 ms decay, band-pass at 5.2 kHz | 5 ms decay, band-pass at 7.5 kHz |
| Classic | A noise burst (2.5 ms decay, 50 ms long) through band-passes at 2.4 kHz (Q 6) and 950 Hz (Q 8, 0.7), plus a high-passed layer at 4 kHz (0.25). | Both band-passes 1.2 × higher | As described |

Rules for every sound:

- **Loudness.** The normal variants of all seven sounds are equally loud, measured as RMS over their first 20 ms. Each accented variant is 4 dB louder than its normal variant. The loudest peak of any sound stays below full scale.
- **Attack.** The click must be heard at its scheduled time: every sound reaches half of its peak within 1 ms of its start.
- **Length.** No sound is longer than 150 ms, so each one ends well before the next beat at 250 BPM (240 ms). The last 3 ms fade to silence.

## 12. Beat effects

Each beat fires all of the following at the moment of its click.

| Effect | Normal beat | Accented beat |
|---|---|---|
| Glow | An amber radial glow behind the BPM number flashes to 30 % opacity and decays over half the beat interval. | Same. |
| Number pulse | The BPM number scales 1.0 → 1.04 and back within half the beat interval. | Same. |
| Tile | The beat's tile switches to its sounding state at once. The previous tile fades back to idle over 150 ms. | Same. |
| Haptic | Light impact, intensity 0.5. | Rigid impact, intensity 1.0. |

There are no other beat visuals; in particular nothing ripples or moves outside the dial.

Other haptics: a selection tick for each 1 BPM change from the ring or − / +, for each tap-tempo tap, for each accent toggle, and for each tap on the mute button. Beat haptics continue while muted. A medium impact on Start and Stop.

## 13. Accessibility

- **Reduce Motion:** the number pulse is disabled. Tile changes and the glow remain.
- **VoiceOver:**
  - The dial is an adjustable element ("Tempo, 120 beats per minute, Allegro") that steps by 1 BPM.
  - Each tile reads as "Beat 3, accented" or "Beat 2, not accented", with the toggle as its action.
  - The mute button reads as "Click sound, on" or "Click sound, muted".
  - The settings button reads as "Settings".
  - A sound row reads as its name, with "selected" for the current one, and says that tapping plays a preview.
  - The header title reads the preset name and its second line, and says that it opens the library.
  - A preset row reads as its name, tempo and time signature, for example "Harbour Lights, 120 beats per minute, 4/4", with "loaded" when it is. Its play button reads "Load and start".
  - In setlist editing, rows can be moved up and down with VoiceOver actions as well as by dragging.
  - Beat changes during playback are not announced.
- Every tappable control is at least 44 × 44 pt.
- The large BPM number does not scale with Dynamic Type. Labels and text in rows and sheets do, up to the first accessibility size.

## 14. Acceptance checklist

A ticked line has been verified in the simulator, by unit tests or on a phone. An unticked line carries a note on what is missing.

Metronome:

- [x] Tempo can be set by ring, − / + and tap tempo, when stopped and when playing, and never leaves 30…250. *(A tap tempo series has not been tapped by hand; its rules are unit tested.)*
- [x] The lit arc, knob, number and tempo name always agree.
- [x] All eight time signatures can be selected; the tile count matches the signature.
- [x] Changing the signature resets accents to beat 1 and, while playing, continues with a new bar. Reselecting the current signature, or dismissing the sheet, changes nothing.
- [ ] Accents can be toggled when stopped and when playing; accented beats sound, look and feel different from normal beats. *(Toggling and the look are verified. Sound and haptics need a listener and a real iPhone.)*
- [x] Start always begins on beat 1. Stop is immediate.
- [x] The mute button silences the click at once and brings it back, while the visuals and haptics continue.
- [ ] Click, visual and haptic stay together at 30, 120 and 250 BPM. *(Needs a real iPhone.)*
- [ ] No audible drift against a reference metronome over 10 minutes. *(The timing maths is unit tested to the sample; the listening check needs a real iPhone.)*
- [ ] The phone's volume buttons and the Control Center slider change the click volume. *(Needs a real iPhone.)*
- [x] Tempo, time signature and accents survive quitting and reopening the app.
- [ ] Reduce Motion and VoiceOver behave as in section 13. *(Not yet tried with the settings switched on.)*

Presets and setlists:

- [x] A preset can be created, loaded, renamed and deleted; the library is sorted A–Z.
- [x] Tapping a row loads without starting; the play button loads and starts.
- [x] The header shows the right title and second line in every state of 6.1.
- [x] Changing a loaded preset's settings shows Edited; Save changes, Save as new preset and Discard changes do what 7.6 says. *(Save changes is unit tested; the other two were also tried in the simulator.)*
- [x] Opening the library keeps unsaved edits; loading another preset drops them.
- [x] A setlist can be created, renamed, duplicated and deleted; deleting it leaves its presets in the library.
- [x] Presets can be added to a setlist, removed from it and reordered; the order is kept.
- [x] A new preset can be created from inside a setlist and lands in that setlist.
- [x] Previous and Next step through the loaded-from setlist, stopped and playing, and stop at the ends. *(Next was tried in the simulator; Previous and the ends are unit tested.)*
- [x] Loading a preset while playing keeps the metronome running and starts a new bar.
- [ ] The filter list shows all setlists with counts and stays usable with 20 setlists. *(Counts and order are verified; it has not been tried with 20 setlists.)*
- [x] Presets, setlists, the loaded preset, its position in the setlist and the selected filter survive quitting and reopening the app.

Settings and click sounds:

- [ ] The settings button opens the settings sheet when stopped and when playing; Done, swiping down and tapping outside close it. *(Not built.)*
- [ ] Each of the seven sounds can be selected; the choice survives quitting and reopening the app, and a fresh install starts with Digital. *(Not built.)*
- [ ] When stopped, tapping a sound plays an accented and a normal click; when playing, the new sound starts with the next scheduled beat. *(Not built.)*
- [ ] Every sound meets the loudness, attack and length rules in 11.1. *(Not built. These can be unit tested on the generated buffers.)*
- [ ] All seven sounds are equally loud by ear, and accented beats are clearly different from normal ones, on the phone's speaker and on headphones. *(Needs a listener and a real iPhone.)*

## 15. Not built yet

A part that is specified before it is built is listed here until it is.

- The settings button in the header (6.1).
- Previous and Next beside the Start / Stop button instead of in the header (6.7).
- The settings sheet and the click sound choice (6.10, 7.8).
- The six click sounds other than Digital, and the loudness rule for all seven (11.1). Today the app plays only the Digital sound, at the levels it had before the loudness rule.

## 16. Ideas for later

Not part of version 1.0.

- **Keep screen awake setting.** Let the user choose whether the app keeps the screen awake; today it always does while playing. It would be a row in the settings sheet (6.10).
- **Play while locked.** Playback continues when the user locks the screen.
