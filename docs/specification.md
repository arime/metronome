# Snappy Metronome 1.0 specification

Status: design locked 2026-11-10. This is version 1.0, the first version to be implemented and released through TestFlight. Where this document says "v1", it means version 1.0.

Design source: Paper file "Snappy Metronome", page *v1.0*, boards *v1.0 · Metronome — Ready*, *v1.0 · Metronome — Playing*, *v1.0 · Metronome — Time signature picker*, *v1.0 · Motion — Beat cycle* and *v1.0 · App icon — Downbeat (1024, chosen)*. The same page holds the icon alternatives that were not chosen.

Version: this first release is version 1.0 everywhere: in the Paper design, in the Xcode project and on the App Store.

App icon: "Downbeat", one large amber dot followed by three small dial-white dots on ink. It is in the app as a single 1024 × 1024 image, in use for now.

Points the design did not settle were decided on 2026-11-10 and are recorded in section 11. Ideas for later versions are in section 12.

## 1. Summary

A single-screen native iOS metronome. The user sets a tempo and a time signature, chooses which beats are accented, and presses Start. Each beat produces a click, a visual effect and a haptic tap on the same instant. Everything except the time signature can be changed while it plays.

## 2. Scope

In v1:

- Tempo from 30 to 250 BPM, set by ring drag, − / + buttons or tap tempo.
- Eight time signatures: 2/4, 3/4, 4/4, 5/4, 6/8, 7/8, 9/8, 12/8.
- Per-beat accents; any combination of beats, including none.
- Start / Stop with click sound, visual beat effects and haptics.
- Settings remembered between launches.

Not in v1:

- Bar counter, subdivisions, sound selection, a volume control inside the app (the phone's own volume controls set the click volume; see 6.5), presets, set lists.
- Playback with the screen locked or the app in the background (see 6.5 and section 12).
- iPad layout, landscape, light mode, Apple Watch, widgets.
- A settings screen, and the header settings button that would open it (see 5.1).

## 3. Platform

- iPhone only, portrait only, dark appearance only.
- SwiftUI. Minimum iOS version: iOS 18.
- Designed at 390 × 844 pt. Smaller phones adapt the layout; see 5.8.
- Typeface: the system font (SF Pro). The Paper boards use Inter and Inter Tight only as stand-ins because SF Pro is not available there. Weights and sizes in section 5 carry over.

## 4. State

| State | Type | Default | Persisted |
|---|---|---|---|
| `bpm` | integer, 30…250 | 120 | yes |
| `timeSignature` | one of the eight in section 2 | 4/4 | yes |
| `accents` | set of beat numbers, 1…beats per bar | {1} | yes |
| `isPlaying` | boolean | false | no |
| `currentBeat` | integer, 1…beats per bar; none when stopped | none | no |

Beats per bar is the top number of the time signature (7/8 has seven beats). One beat is one click. BPM counts clicks per minute for every signature, including the /8 ones.

The app always launches stopped.

## 5. Screen

There is one screen with two states, Ready (stopped) and Playing. The layout is identical in both, so nothing moves when Start is pressed. From top to bottom:

### 5.1 Header

- Left label: `TEMPO` when stopped. When playing: an amber dot followed by `PLAYING` in dial white.
- Right: the design shows a 40 pt round settings button. It is left out of the v1 build, because v1 has no settings screen. The header keeps its height.

### 5.2 Tempo dial

- 300 pt gauge. 48 tick marks on a 270° arc that starts at the lower left (the 7:30 position), runs clockwise over the top and ends at the lower right (4:30), leaving a 90° gap at the bottom. Every fourth tick is longer and thicker.
- Ticks from the start of the arc up to the current tempo are amber; the rest are unlit. Position along the arc is linear: `(bpm − 30) / 220`.
- A 28 pt amber knob with a dark 5 pt border and an amber glow sits at the end of the lit arc.
- Centre: the BPM number (112 pt, heavy, tight tracking, dial white). Below it: `BPM` in amber, a dot, and the tempo name in muted italic.

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

### 5.3 Tempo controls

A row of three: − (56 pt round), `Tap tempo` (outlined pill with a hand icon), + (56 pt round).

### 5.4 Time signature row

A 60 pt row: the label `Time signature`, the current value in amber (for example `4/4`), and a › chevron. Tapping it opens the picker (5.6). It looks and behaves the same when stopped and when playing.

### 5.5 Accents

The label `ACCENTS`, then one tile per beat in a single row with 10 pt gaps, each 76 pt tall with a 20 pt corner radius. Each tile shows a small mark above its beat number.

| Tile state | Fill | Border | Number and mark |
|---|---|---|---|
| Not accented, idle | surface | none | muted number, small dot |
| Accented, idle | dark amber tint | 1.5 pt amber | amber number, ^ mark |
| Not accented, sounding | dial white | none | ink number, ink dot |
| Accented, sounding | amber, with amber glow | none | ink number, ink ^ mark |

"Sounding" applies only while playing, to the tile of `currentBeat`.

Up to seven tiles fit in one row. For 9/8 and 12/8 the tiles wrap into two equal rows (5 + 4, and 6 + 6) and the tile height drops to 44 pt, with the mark omitted. This case is not drawn in the design.

### 5.6 Time signature picker

A bottom sheet over a dimmed screen: a grabber, the title `Time signature`, and a 4 × 2 grid of options. Each option shows the signature and a one-word hint:

| 2/4 | 3/4 | 4/4 | 5/4 | 6/8 | 7/8 | 9/8 | 12/8 |
|---|---|---|---|---|---|---|---|
| March | Waltz | Common | Odd | Compound | Odd | Compound | Compound |

The current signature is filled amber with a glow. Use the standard sheet presentation, sized to its content.

### 5.7 Start / Stop button

A 68 pt pill pinned to the bottom with 24 pt side margins.

- Stopped: amber fill, ink play icon and `Start`, soft amber glow.
- Playing: surface fill, 1.5 pt amber outline, amber stop icon and `Stop`, no glow.

### 5.8 Small screens

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

### 5.9 Colours

| Token | Value | Use |
|---|---|---|
| ink | `#0B0B0C` | background; text on amber and white |
| surface | `#17171A` | rows, round buttons, idle tiles, sheet |
| surface raised | `#222226` | picker options |
| line | `#2A2A2E` | unlit ticks, outlines |
| dial white | `#F3EEE6` | primary text; sounding unaccented tile |
| muted | `#8A8780` | labels, secondary text |
| muted dim | `#6B6963` | idle unaccented tile numbers |
| amber | `#FFB224` | the single accent colour |
| amber tint | `#1E1A12` | idle accented tile fill |

## 6. Behaviour

### 6.1 Tempo

All three tempo controls work when stopped and when playing.

- **Ring.** Dragging the knob or swiping on the ring sets the tempo. The knob follows the angle of the finger around the dial centre, mapped linearly over the 270° arc, rounded to whole BPM. Angles in the gap at the bottom clamp to the nearer end. Only touches that begin between 105 pt and 165 pt from the dial centre start a drag, so a touch on the number does nothing.
- **− / +.** One tap changes the tempo by 1 BPM. Holding repeats: after 400 ms, 10 steps per second.
- **Tap tempo.** From the second tap on, the tempo is set to the average of the last four intervals between taps (fewer if fewer exist). A pause longer than 2 seconds starts a new series.
- All inputs clamp to 30…250.
- While playing, a tempo change takes effect from the next beat. The beat that is already scheduled is not moved, and the bar position is kept.

### 6.2 Time signature

- Tapping the row opens the picker. Tapping an option selects it and closes the sheet.
- Swiping the sheet down or tapping outside it closes it without changes.
- When the selection is different from the current signature:
  - playback stops, if it was running;
  - accents reset to beat 1 only.
- Choosing the signature that is already selected changes nothing and does not stop playback.

### 6.3 Accents

- Tapping a tile toggles that beat's accent. This works when stopped and when playing.
- Any combination is allowed, including all beats and no beats.
- While playing, a toggle changes the tile's idle appearance at once. The click, effect and haptic for that beat change the next time the beat is scheduled; a beat that is already sounding is not altered.

### 6.4 Start and stop

- Start begins playback on beat 1, with the first click immediately.
- Stop silences playback at once, clears `currentBeat` and returns every tile to its idle appearance.
- The screen does not dim or lock while playing.

### 6.5 Interruptions

- Playback stops when the app leaves the foreground, when the screen is locked, and on audio interruptions such as a phone call. It does not resume by itself.
- The click plays even when the ring/silent switch is on silent, as a metronome is the app's whole purpose. It mixes with nothing: other audio is paused while the metronome plays.
- The click volume is set with the phone's regular volume controls: the side buttons and the Control Center slider. The click is ordinary media audio and the app never overrides the system volume. (Requirement added 2026-11-10. If "Change with Buttons" is on in the phone's sound settings, the side buttons adjust the ringer while nothing is playing; that is system behaviour.)

## 7. Audio and timing

- Two short click sounds: an accent click (higher pitch, louder) and a normal click.
- The first TestFlight release uses the generated clicks (decided 2026-11-10): a 30 ms sine burst with a fast decay, 1760 Hz at full level for accented beats and 1175 Hz at 0.6 for the others. Designed or recorded sounds can replace them in a later version.
- Clicks are scheduled on the audio clock (for example `AVAudioEngine` with sample-time scheduling), a little ahead of time. They must not be driven by a UI timer.
- Visual effects and haptics are triggered from the same schedule, so the three stay together.
- Targets: each click within 2 ms of its ideal time, and no accumulated drift over 10 minutes at any tempo.

## 8. Beat effects

Each beat fires all of the following at the moment of its click.

| Effect | Normal beat | Accented beat |
|---|---|---|
| Glow | An amber radial glow behind the BPM number flashes to 30 % opacity and decays over half the beat interval. | Same. |
| Number pulse | The BPM number scales 1.0 → 1.04 and back within half the beat interval. | Same. |
| Tile | The beat's tile switches to its sounding state at once. The previous tile fades back to idle over 150 ms. | Same. |
| Haptic | Light impact, intensity 0.5. | Rigid impact, intensity 1.0. |

An earlier draft of the design also drew rings rippling out from the dial on every beat. That effect was removed on 2026-11-10 after trying the app on a phone: it was too intrusive.

Other haptics: a selection tick for each 1 BPM change from the ring or − / +, for each tap-tempo tap, and for each accent toggle. A medium impact on Start and Stop.

## 9. Accessibility

- **Reduce Motion:** the number pulse is disabled. Tile changes and the glow remain.
- **VoiceOver:** the dial is an adjustable element ("Tempo, 120 beats per minute, Allegro") that steps by 1 BPM. Each tile reads as "Beat 3, accented" or "Beat 2, not accented", with the toggle as its action. Beat changes during playback are not announced.
- Every tappable control is at least 44 × 44 pt.
- The large BPM number does not scale with Dynamic Type. Row labels and picker text do, up to the largest size that still fits.

## 10. Acceptance checklist for the first TestFlight build

Status on 2026-11-10, after the first implementation. Ticked lines were checked in the iPhone simulator, by unit tests, or both. Unticked lines carry a note on what is still missing.

- [x] Tempo can be set by ring, − / + and tap tempo, when stopped and when playing, and never leaves 30…250. *(Ring, + and holding − used in the simulator; limits, tap tempo and stepping covered by unit tests. A tap tempo series was not tapped by hand.)*
- [x] The lit arc, knob, number and tempo name always agree.
- [x] All eight time signatures can be selected; the tile count matches the signature. *(4/4 and 12/8 seen in the simulator; the rest by unit tests.)*
- [x] Changing the signature while playing stops playback and resets accents to beat 1. Reselecting the current signature, or dismissing the sheet, does neither.
- [ ] Accents can be toggled when stopped and when playing; accented beats sound, look and feel different from normal beats. *(Toggling and the look are verified. Sound and haptics need a listener and a real iPhone.)*
- [x] Start always begins on beat 1. Stop is immediate.
- [x] The accent and normal click sounds are in place. *(The generated clicks, accepted for the first TestFlight release.)*
- [ ] Click, visual and haptic stay together at 30, 120 and 250 BPM. *(Needs a real iPhone.)*
- [ ] No audible drift against a reference metronome over 10 minutes. *(The timing maths is unit tested to the sample; the listening check needs a real iPhone.)*
- [x] BPM, time signature and accents survive quitting and reopening the app.
- [ ] Reduce Motion and VoiceOver behave as in section 9. *(Implemented; not yet tried with the settings switched on.)*
- [ ] The phone's volume buttons and the Control Center slider change the click volume. *(Expected from how the audio is set up; needs a real iPhone to confirm.)*

## 11. Decisions

Confirmed on 2026-11-10:

| # | Question | Decision |
|---|---|---|
| 1 | The header settings button has no screen behind it. | Left out of the v1 build; it returns when there are settings to show. |
| 2 | How are 9 and 12 beat tiles laid out? | Two rows of shorter tiles, as in 5.5. |
| 3 | Minimum iOS version. | iOS 18. |
| 4 | Should it keep playing with the screen locked or the app in the background? | Not in v1; playback stops (6.5). Planned for later (section 12). |
| 5 | Should the click ignore the silent switch? | Yes. |

Still open before the first TestFlight release:

| # | Item | Status |
|---|---|---|
| 1 | Adding testers in TestFlight. | The App Store Connect record exists and version 1.0 (build 1) was uploaded on 2026-11-10. |

Settled since:

| Item | Decision |
|---|---|
| App name | "Snappy Metronome" on the App Store, decided on 2026-11-10. Under the icon on the home screen the app shows as "Metronome", because the full name is too long to fit there. |
| Bundle identifier | `com.metsahalme.metronome`, set on 2026-11-10. |
| Click sounds | The generated clicks are used for the first TestFlight release (section 7), decided on 2026-11-10. |
| App icon | "Downbeat", in use for now. |

## 12. Later versions

Stored for further development. None of these are part of v1.

- **Mute button.** A quick button that silences the click while the metronome keeps running, so the visual effects and haptics continue.
- **Keep screen awake setting.** A setting that lets the user choose whether the app keeps the screen awake. In v1 the screen always stays awake while playing (6.4). This brings back the settings screen and the header settings button.
- **Play while locked.** Playback continues when the user locks the screen. In v1 it stops (6.5).
