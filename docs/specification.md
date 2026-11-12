# Snappy Metronome specification

This is the single specification for the app. It describes how version 1.0 is meant to work and is kept up to date as decisions change. Parts that are specified here but not built yet are listed in section 15.

Design source: Paper file "Snappy Metronome". The page *v1.0* holds the metronome screen, the time signature picker, the beat effects and the app icon. The page *v1.0 — Presets & setlists (draft)* holds the library and setlist boards. The page *v1.0 — Settings & click sounds (draft)* holds the metronome screen with the settings button and Previous / Next beside Start, and the settings sheet; its three boards named *iCloud sync · A / B / C* show the settings sheet with the iCloud card in its states, and its other boards are alternatives that were not chosen. The page *Main view UX review (draft)* holds the tempo sheet (board A), the split Save button in the header and its menu (boards D and E; board B is the earlier one-part button they replaced), now used only on small dials, the next-up line (board C), and the save controls in the dial's gap (board V4; the other boards in its row are alternatives that were not chosen).

## 1. Summary

A native iOS metronome with one main screen. The user sets a tempo and a time signature, chooses which beats are accented, and presses Start. Each beat produces a click, a visual effect and a haptic tap on the same instant. Everything can be changed while it plays.

Settings can be saved as named **presets**, usually one per song or practice setup. The **library** lists all presets, and **setlists** are named, ordered selections from it. The loaded preset's name sits in the header of the metronome screen; tapping it opens the library.

## 2. Scope

Included:

- Tempo from 30 to 300 BPM, set by ring drag, − / + buttons, tap tempo or typing the number.
- Eight time signatures: 2/4, 3/4, 4/4, 5/4, 6/8, 7/8, 9/8, 12/8.
- Per-beat accents; any combination of beats, including none.
- Start / Stop with click sound, visual beat effects and haptics.
- A mute button that silences the click while the metronome keeps running.
- A preset library and setlists.
- A settings sheet with a choice of seven click sounds and a switch that turns all haptics off.
- Everything remembered between launches.
- Optional iCloud sync that keeps the presets and setlists the same on the user's devices.

Not included:

- Bar counter, subdivisions, a volume control inside the app (the phone's own volume controls set the click volume; see 7.7).
- Playback with the screen locked or the app in the background.
- Search, folders or tags, notes on presets, per-preset sounds, import, export and sharing with other people.
- Syncing anything other than presets and setlists: the current settings, the loaded preset, the click sound and haptics stay separate on each device.
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
| Tempo | integer, 30…300 BPM | 120 |
| Time signature | one of the eight in section 2 | 4/4 |
| Accents | set of beat numbers, 1…beats per bar | {1} |
| Presets | each with id, name, tempo, time signature, accents | none |
| Setlists | each with id, name, ordered preset ids, last-used time | none |
| Loaded preset | the preset in the metronome, if any | none |
| Loaded-from setlist | the setlist the preset was loaded from, if any | none |
| Shown setlist | the setlist the library sheet showed last, if any. It only says which setlist a view belongs to; where the sheet opens is decided in section 8 | none |
| Click sound | one of the seven sounds in 11.1 | Digital |
| Haptics | on or off, for the whole app | on |
| Keep screen awake | on or off, for this device | off |
| iCloud sync | on or off, for this device | off |

Not kept:

| Item | Contents | At launch |
|---|---|---|
| Playing | whether the metronome is running | stopped |
| Muted | whether the click is silenced | sound on |
| Current beat | the beat that is sounding | none |

Derived:

- **Edited:** a preset is loaded and the current tempo, time signature or accents differ from it. On screen this is shown by the save controls in the dial (6.2), or on a small dial by the Save button in the header (6.1); the word itself is not displayed.
- **Position:** the loaded preset's place in the loaded-from setlist, such as 3 of 8.

Reopening the app restores the settings, the loaded preset and its setlist, so the position in the setlist is restored too and the user can carry on with Next. The app always launches stopped and with sound on.

Data is stored on the device. With iCloud sync on, the presets and setlists are also kept in the user's iCloud account (5.1).

If the loaded preset is deleted, the metronome keeps its current settings and the header shows "nothing loaded". If it is removed from the loaded-from setlist, it stays loaded and the header shows the name alone, as for a preset loaded from the Presets tab. If the loaded-from setlist is deleted, the same applies. If the setlist the library is showing is deleted, the library shows the Setlists tab. These rules hold whether the change was made on this device or arrived from another one.

### 5.1 iCloud sync

Sync is optional and off by default; the switch and what the user sees are in 6.10 and 7.9. This section says what is synced and how copies are combined.

**What is synced.** Presets and setlists, in both directions, between the user's devices that have sync on. Everything else in the tables above stays on the device.

**Storage.** iCloud key-value storage (`NSUbiquitousKeyValueStore`), which uses the iCloud account the phone is signed in to. The app has no account or server of its own. iCloud holds one item per preset, one per setlist and one per device. The device always keeps its own complete library, so the app works the same with sync off, signed out or offline.

**What is recorded so copies can be combined.** The device records this at all times, also with sync off, because switching sync off is treated like being offline (7.9).

- A preset has three parts, each with the time it last changed: the name; the tempo; and the time signature together with the accents, which only make sense as a pair. It also has a creation time, which gives the order of creation used in 8.2.
- A setlist has a name with the time it last changed; for every preset that is or was in it, whether it is in or out and since when; its order with the time it last changed; and its last-used time.
- A deleted preset or setlist leaves a delete marker with the time of deletion.
- Times come from the device's clock. A change always gets a time later than the one it replaces, even when the clock is behind.
- Only a part that really changed gets a new time. Save changes after changing only the tempo leaves the times of the name and the time signature alone.

**Combining.** Combining two copies gives the same result on every device, in whatever order the changes arrive.

- A preset or setlist that exists in only one copy is added to the other.
- For each part, the newer one wins. When two times are equal, a fixed rule picks one, the same on every device.
- A setlist's membership is decided per preset: the newer of "in" and "out" wins. So a preset added on one device and another removed on a second device are both kept.
- A setlist's order is taken whole from the copy with the newer order. Presets that are in the setlist but not in that order go to the end, in the order they were added. A preset that is removed from a setlist and added again goes to the end, like any newly added preset.
- The later last-used time wins.
- A delete marker wins only when it is newer than every part of the item. Otherwise the item stays and the marker is dropped, so an edit made after a deletion brings the item back. For a setlist the parts are the name, the membership and the order; the last-used time does not count.
- A deleted preset is hidden from its setlists, but its membership is kept, so a preset that comes back is in its setlists again.
- An item that is missing from iCloud without a delete marker is never treated as deleted; the device puts its copy back.

Examples: a preset renamed on one device and given a new tempo on another ends up with both changes. A preset deleted on one device and edited later on another comes back with the edit. A setlist reordered on one device while a preset is added on another keeps the new order with the added preset at the end.

**Later versions.** Presets and setlists can get new properties in later versions, and devices on different versions must be able to sync with each other.

- A new property is a new part with its own change time. A part that is missing counts as its default value, never changed, so the first device to set it wins.
- A version that finds a part it does not know keeps it untouched, on the device and in iCloud, and writes it back unchanged. Combining works per part without knowing what the part means, so the newer of two unknown parts still wins. The same goes for items of a kind it does not know: it leaves them alone, except that the clean-up below removes them with everything else.
- The data in iCloud carries a format number, starting at 1. A later version raises it only for a change that older versions would misread. A format number that cannot be read counts as higher than the app knows. A version that finds a higher number than it knows stops sending and receiving, keeps its library on the device, and says so in the status line (6.10). It does not take part in the clean-up below.

**Delete markers** are kept for one year and then removed from the device and from iCloud. A device that has been away longer than that can bring a deleted item back.

**Limits.** iCloud key-value storage holds 1 MB and 1,024 items per app, so presets, setlists, delete markers and device entries together have room for about a thousand items. When iCloud reports that it is full, the status line says so (6.10) and the library keeps working on the device. Delete markers count towards the limit, so when the items would go over 1,024 the oldest markers are removed first to make room, even if they are less than a year old.

**Devices and clean-up.** While sync is on, the device keeps an entry in iCloud with a random identifier and the date it last synced, refreshed at most once a day. An entry is live when its date is less than six months old.

- Switching sync off removes the device's entry. If no other live entry is left, the device also removes the presets, setlists, delete markers and stale entries from iCloud. The library on the device stays.
- A device that has had sync on and now has it off checks the device entries each time the app is opened. If no live entry is left and the app still has data in iCloud, it removes that data. This catches two devices switched off close together, and a device that left without switching off.
- The clean-up is best effort and happens without asking. Data stays in iCloud when the app is deleted from every device while sync is on, or when the phone changes iCloud account before sync is switched off. It reaches iCloud when the device is next online.
- If a device that is still syncing finds iCloud emptied, it puts its library back, by the rule that missing is not deleted. The same goes for a syncing device that finds its own entry missing: it puts the entry back together with its library.
- The clean-up only ever runs on the iCloud account the device has synced with.

**iCloud account.**

- Not signed in to iCloud, or iCloud unavailable to the app: sync stays switched on and waits; the status line says so (6.10).
- Signed in to a different iCloud account than the one sync was switched on with: sync switches itself off, so a library is never mixed into another account unasked. The user can switch it on again.

The account is told apart by the identity iOS gives the app for the signed-in iCloud account. When iCloud reports an account change, sync switches off only if the account is now a different one, carries on if it is the same one, and waits if the phone is signed out. If the identity cannot be read in a usable form, the device counts as signed in to an account that never changes, and a change of account is then not noticed. Reading that identity on a signed-in device is still to be confirmed (see section 14).

**Libraries made before sync existed.** Every part of their presets and setlists gets one fixed early change time, the same on every device and earlier than any real change, so that any real edit or deletion wins over an untouched old copy. This matters when two phones hold the same presets because one was set up from the other's backup. Creation times start from that fixed time and keep the current order.

## 6. Metronome screen

One screen with two states, Ready (stopped) and Playing. The layout is identical in both, so nothing moves when Start is pressed. From top to bottom:

### 6.1 Header

**Preset title**, at the left, taking the space left by the buttons. One or two lines; a long name is cut with an ellipsis. Line 1 is 20 pt heavy in dial white, followed by a small ˅, which is left out while the Save button is showing in the header (on a small dial only), so that the name gets its place. Line 2 is 13 pt in muted. Without a line 2, line 1 is centred vertically in the header.

| State | Line 1 | Line 2 |
|---|---|---|
| Nothing loaded | `Library` | `No preset loaded` |
| Loaded from the Presets tab | preset name | none |
| Loaded from a setlist | preset name | setlist name · `3 of 8` |

The title does not change when the loaded preset is edited: unsaved changes are shown by the save controls (6.2) alone. So the setlist name stays in view while a song is being adjusted, and a title without a second line does not gain one and shift.

The title looks the same stopped and playing. Nothing is added in front of it while playing, so it does not move when Start is pressed; the dial, the tiles and the Stop button show that the metronome is running.

**Save button**, only on a dial too small for the save controls in its gap (6.2), as on iPhone SE. It takes their place: shown only while the loaded preset is edited, between the title and the mute button, a 40 pt tall amber pill in two parts, about 109 pt wide.

- The left part reads `Save` (15 pt, bold, ink), with 16 pt of padding before it and 12 pt after. One tap saves the changes (7.6).
- A 1 pt, 22 pt tall divider in ink at 28 % separates the parts.
- The right part is 44 pt wide with an ink ˅ (14 pt). It opens the Save menu (7.6). It is a full-size target of its own, because a miss to the left would save.
- Both parts take touches over a height of 44 pt.

The button comes and goes like the save controls (6.2), and the title gives up its width to it. After Save it confirms the save the same way: for one second the pill keeps its size and place and reads `Saved ✓` (15 pt, bold) in place of its two parts, green on the green tint, and cannot be tapped; then it fades away. The word starts where `Save` did, so it only gains a letter, and the tick stands where the ˅ was, so nothing jumps; there is no divider. Everything that can be done with unsaved changes is in this one control, which is there only while there are changes; the title never changes what it does.

**Mute button**, 40 pt round:

- Sound on: a dial-white speaker with sound waves on a surface fill.
- Muted: an amber crossed-out speaker on the amber tint fill with a 1.5 pt amber outline.

**Settings button**, at the far right: a 20 pt dial-white gear with no fill, in a 32 pt wide slot aligned to the right margin. It is lighter than the round buttons because it is used far less often. Its touch area is 44 × 44 pt. It opens the settings sheet (6.10).

The header has only these buttons, so the title gets about 240 pt, also while the preset is edited. Only on a small dial, while the Save button is shown there, it gets about 142 pt, with the title's ˅ left out: room for about 13 characters of the name, which comes back in full once the changes are saved or reverted. Previous and Next sit beside the Start / Stop button (6.7).

### 6.2 Tempo dial

- 300 pt gauge in the design; on a tall screen it grows, up to 340 pt (6.8), and everything in it scales with it. 48 tick marks on a 270° arc that starts at the lower left (the 7:30 position), runs clockwise over the top and ends at the lower right (4:30), leaving a 90° gap at the bottom. Every fourth tick is longer and thicker.
- Ticks from the start of the arc up to the current tempo are amber; the rest are unlit, in the tick colour, which is light enough against the background (3 : 1) that the rest of the range can be seen. Position along the arc is linear: `(bpm − 30) / 270`.
- A 28 pt amber knob with a dark 5 pt border and an amber glow sits at the end of the lit arc.
- Centre: the BPM number (112 pt, heavy, digits set slightly tight, dial white). Three-digit tempos are drawn at 88 % of that size so they stay clear of the knob. Below the number: `BPM` in amber, a dot, and the tempo name in muted italic.
- Tapping the number or the line below it opens the tempo sheet (6.11).

**Save controls**, in the gap at the bottom of the ring, shown only while the loaded preset is edited. Three pieces side by side, 176 pt wide in all, centred under the number, with their bottom edge 6 pt above the bottom of the dial, so about 10 pt above `Tap tempo`. They do not scale with the dial.

- Left: **Revert**, a 38 pt round button with a dial-white ↺ on a surface fill and a 1 pt outline in the line colour.
- Middle: **Save**, an amber pill, 84 × 38 pt, reading `Save` (15 pt, bold, ink). It is the only coloured piece, so it reads as the thing to tap.
- Right: **Save as new preset**, a 38 pt round button like Revert, with two overlapping squares and a +.
- 8 pt between the pieces. Each takes touches over 44 pt, which leaves 2 pt between the touch areas. A touch on a control never turns the dial. Revert and Save as new preset are on opposite sides of Save, so the two less-used actions are never mistaken for each other.

The controls fade in with the first change. They do not go away the instant the settings equal the saved ones again: they stay until the settings have rested there for half a second, so that turning the dial past the saved tempo does not make them blink out and in. Reverting, and loading or unloading a preset, take them away at once. After Save they confirm the save first: the two round buttons fade out, and for one second the pill keeps its size and place and reads `Saved ✓` (15 pt, bold, centred), in green on a see-through green tint (green at 16 %) rather than solid amber, so that it reads as a status and not as a button. It cannot be tapped then. Then it fades away. A change to the settings during that second brings the controls straight back.

The controls fit in the gap only while a round button stays at least 4 pt clear of the knob with the knob at either end of the arc, which takes a dial of about 290 pt or more. On a smaller dial, as on iPhone SE, they are left out and the Save button in the header (6.1) is shown instead.

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
| 200–300 | Prestissimo |

### 6.3 Tempo controls

A row of three: − (56 pt round), `Tap tempo` (outlined pill with a hand icon), + (56 pt round).

While a tap tempo series is open, from a tap until 2 seconds after the last one, the pill's outline is amber (1.5 pt) and its label reads `Tap again`. The pill keeps its width when the label changes.

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

**Next-up line**, shown with Previous and Next, centred 14 pt above the row and 18 pt tall. It says what Next leads to: `NEXT` (11 pt, semibold, capitals, wide letter spacing, muted), the next preset's name (14 pt, semibold, dial white) and its tempo and time signature, for example `168 BPM · 7/8` (14 pt, muted). A long name is cut with an ellipsis; the tempo and time signature are always shown in full. At the last preset of the setlist it reads `Last preset in the setlist` (14 pt, muted) and keeps its height, so the footer does not move from song to song. It is not a button. On short screens it can be left out (6.8).

The footer changes only when the loaded preset's setlist changes, never between Ready and Playing, so nothing moves when Start is pressed.

### 6.8 Small screens

The design is drawn for a 390 × 844 pt screen.

On taller screens the dial takes the spare height: it grows from 300 pt up to 340 pt, and never wider than the space between the side margins. An iPhone 17 Pro gets 340 pt, or 328 pt with the next-up line. Height that is still left over stays between the accent tiles and the footer.

On shorter screens the layout adapts in this order and stops as soon as everything fits:

1. The dial shrinks, down to 240 pt.
2. The gaps above and below the time signature row drop to 16 pt, and single-row accent tiles drop to 56 pt tall with a smaller number.
3. The dial shrinks further, as far as it needs to. The screen never scrolls.

The next-up line (6.7) takes 32 pt with its gap. It is fitted by the same steps, and is left out when it would push the dial below 200 pt. Previous and Next stay.

In practice only an iPhone SE with Display Zoom (320 × 568 pt) goes below 200 pt: its dial is about 150 pt, or about 108 pt in 9/8 and 12/8. An iPhone SE without Display Zoom gets about 249 pt, or 207 pt in 9/8 and 12/8; with the next-up line it gets about 217 pt, and in 9/8 and 12/8 the line is left out.

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
| line | `#2A2A2E` | outlines, dividers |
| tick | `#606066` | unlit ticks on the dial |
| dial white | `#F3EEE6` | primary text; sounding unaccented tile |
| muted | `#8A8780` | labels, secondary text |
| muted dim | `#6B6963` | idle unaccented tile numbers, position numbers |
| amber | `#FFB224` | the single accent colour |
| amber tint | `#1E1A12` | idle accented tile fill, muted button fill |
| red | `#E5484D` | remove and delete actions only |
| green | `#4CC38A` | confirmations only: the sync status dot when up to date, and the Save pill while it reads Saved |

### 6.10 Settings sheet

A bottom sheet over a dimmed screen, styled like the New preset sheet: a grabber, the title `Settings` (26 pt heavy, dial white) and `Done` in amber at the right. It is sized to its content up to the full height of the screen; when the content is taller, as it is on most phones, the cards scroll under the title.

**Click sound** is one surface-raised card with 16 pt corners:

- A header line: `CLICK SOUND` (13 pt, semibold, capitals, wide letter spacing, muted) and, at the right, `Tap to hear it` (13 pt, muted dim).
- One 44 pt row per sound, in this order: Digital, Soft beep, Woodblock, Mallet, Glass, Tick, Classic. Each row shows only the name (16 pt, dial white). Thin line-coloured dividers separate the rows and start at the text edge.
- The selected sound's name is amber and semibold, with an amber tick at the right. The tick has a fixed slot, so names line up in every row.

Below the card: `Use your phone's volume buttons to set how loud the click is.` (13 pt, muted).

**Haptics** is a second surface-raised card with 16 pt corners, below that line:

- The same header line style: `HAPTICS`, with nothing at the right.
- One 44 pt row: `Haptic feedback` (16 pt, dial white) and, at the right, a standard iOS switch tinted amber when on.

Below the card: `A tap on every beat, and a tick when you change a setting.` (13 pt, muted).

**Screen** is a third surface-raised card with 16 pt corners, below that line:

- The same header line style: `SCREEN`, with nothing at the right.
- One 44 pt row: `Keep screen awake` (16 pt, dial white) and, at the right, a standard iOS switch tinted amber when on.

Below the card: `Keeps the screen on while the app is open, even when stopped. The screen always stays on while playing.` (13 pt, muted).

**iCloud** is a fourth surface-raised card with 16 pt corners, below that line:

- The same header line style: `ICLOUD`, with nothing at the right.
- One 44 pt row: `Sync presets and setlists` (16 pt, dial white) and, at the right, a standard iOS switch tinted amber when on.
- While the switch is on, a second 44 pt row, the **status line**: an 8 pt dot, the status (15 pt) and, at the right, a detail (13 pt, muted dim). While the switch is off there is no status line.

| Status | Dot | Text | Detail |
|---|---|---|---|
| Just switched on | muted dim | `Syncing…` in muted | none |
| Working | green | `Up to date` in dial white | `Last synced 14:32`, or a date such as `Last synced 9 Nov` when it was not today; none before the first exchange |
| No iCloud account | amber | `Not signed in to iCloud` in amber | none |
| iCloud full | amber | `iCloud storage is full` in amber | none |
| Newer format in iCloud | amber | `Update the app to keep syncing` in amber | none |

Below the card, one line (13 pt, muted) that depends on the state:

- Off, syncing or up to date: `Keeps your presets and setlists the same on every device signed in to your iCloud account. Your settings stay separate on each device.`
- Not signed in: `Sign in to iCloud in the Settings app to sync. Until then your presets and setlists stay on this iPhone.`
- iCloud full: `Delete presets or setlists you no longer need to make room. Until then some changes stay on this iPhone.`
- Newer format: `Another of your devices has a newer version of the app. Until this one is updated, your presets and setlists stay on this iPhone.`

The status line is the device's own view. iCloud does not tell the app when a change has reached the server, so `Last synced` is the time the device last handed a change to iCloud or received one, and there is no separate status for being offline.

New settings are added as further rows or cards in the same sheet.

### 6.11 Tempo sheet

A bottom sheet over a dimmed screen, sized to its content, opened by tapping the BPM number on the dial (6.2) or in the preset sheet (section 10). From the dial, Set tempo sets the metronome's tempo; from the preset sheet, only the sheet's. From top to bottom:

- A grabber, the title `Tempo` (26 pt heavy, dial white) and, at the right, the range `30 to 300 BPM` (13 pt, muted).
- **The field:** a 92 pt tall surface-raised card with 20 pt corners and a 1.5 pt amber outline. It shows the typed digits (64 pt, heavy, dial white), an amber caret and `BPM` in amber. Before the first key it shows the current tempo in muted dim, as a reminder of where the tempo is now.
- **The keys:** the digits 1 to 9 in three rows of three, then a last row with an empty place, 0 and a delete key. Each key is 54 pt tall with 8 pt gaps; digit keys are surface raised with 16 pt corners and a 26 pt bold digit, and the delete key is an icon with no fill. The sheet has its own keys, not the system keyboard, so they are large, match the app and appear with the sheet.
- **Cancel / Set tempo:** a 56 pt pill. Until the digits are a tempo from 30 to 300, it reads `Cancel` (17 pt, bold, dial white) with a 1 pt outline in the line colour and no fill, and closes the sheet without changes. Once they are, it becomes the amber `Set tempo` (ink text). Deleting digits until they are no longer a valid tempo turns it back into Cancel.

## 7. Metronome behaviour

### 7.1 Tempo

All four ways of setting the tempo work when stopped and when playing.

- **Ring.** Dragging on the ring turns the dial: the tempo changes by the angle the finger travels around the dial centre, 270° for the whole range, rounded to whole BPM. It makes no difference where on the ring the drag begins, so the knob can be grabbed and moved, and a drag anywhere else on the ring turns it by the same amount.
  - The tempo never jumps to where the finger lands. A touch that does not move changes nothing, and the drag begins only after the finger has moved 4 pt, so a tap or a brush against the ring is ignored.
  - The tempo stops at 30 and 300. Turning back from an end takes effect at once.
  - Only touches that begin on the ring, between 0.35 and 0.55 dial diameters from the centre (105 pt and 165 pt on the 300 pt dial), start a drag.
- **Typing.** Tapping the number opens the tempo sheet (6.11).
  - A digit key adds a digit, up to three; a leading zero is ignored. The delete key removes the last digit.
  - `Set tempo` sets the tempo and closes the sheet. Until the digits are a tempo from 30 to 300, the button is `Cancel` instead (6.11), so there is always a visible way back.
  - When the digits are above 300, the range at the top right turns amber.
  - `Cancel`, swiping the sheet down or tapping outside it closes it without changes. Nothing changes before `Set tempo`.
- **− / +.** One tap changes the tempo by 1 BPM. Holding repeats: after 400 ms, 10 steps per second. The repeat ends the moment the finger lifts, however quickly taps follow each other.
- **Tap tempo.** From the second tap on, the tempo is set to the average of the last four intervals between taps (fewer if fewer exist). A pause longer than 2 seconds starts a new series. While a series is open the pill reads `Tap again` (6.3), so the first tap, which cannot set a tempo yet, is still seen to register.
- All inputs clamp to 30…300.
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
- The screen does not dim or lock while playing. With Keep screen awake on (7.8), it does not dim or lock while stopped either.

### 7.5 Mute

- Tapping the mute button silences the click at once, including clicks that are already scheduled, or brings it back.
- The metronome keeps running: the glow, the number pulse, the tile lighting and the haptics carry on.
- It works when stopped and when playing.
- Mute is separate from the phone's volume and is not remembered between launches.

### 7.6 Presets on the metronome screen

**Loading** a preset applies its tempo, time signature and accents to the metronome. It happens from the library and from Previous / Next.

- Unsaved edits to the previously loaded preset are dropped without asking.
- When stopped, the metronome stays stopped.
- When playing, it keeps playing: the next beat is beat 1 of a new bar with the new settings.

**Tapping the title** always opens the library sheet (section 8), edited or not. Unsaved edits are kept while the library is open.

**Unsaved changes** are handled with the save controls in the dial's gap (6.2), which are shown while the preset is edited; on a small dial, with the Save button in the header and its menu (6.1). There are three things to do with them:

- **Save:** tapping `Save` writes the current settings into the loaded preset. The pill confirms it by reading `Saved ✓` for a second, with a success haptic, and then goes away (6.2). There is no separate message.
- **Save as new preset:** the round button right of Save (in the header, the Save menu). It opens the New preset sheet (section 10) filled with the current settings. After saving, the new preset is the loaded one, and the preset that was edited is left as it was.
- **Revert:** the round ↺ button left of Save (in the header, the Save menu, as `Revert` with the saved preset's tempo and time signature on a second, smaller line, for example `120 BPM · 4/4`, so that it is clear what comes back). It sets the metronome back to the preset's tempo, time signature and accents, with a selection tick.
  - While playing, the bar carries on when only the tempo or the accents go back, as with any other change of tempo or accents (7.1, 7.3). When the time signature goes back, the next beat is beat 1 of a new bar (7.2).
  - There is no confirmation and no undo.

The Save menu, on a small dial only, is the system menu, opened by the ˅ part of the header button, with Save as new preset and Revert in this order. Tapping outside it closes it.

Edits also go away without the controls: loading another preset, with Previous / Next or from the library, drops them without asking, and **No preset** in the library (8.2) keeps them as plain settings.

**Previous and Next** load the previous or next preset in the loaded-from setlist's order.

- At the first preset Previous is dimmed and does nothing; at the last, Next. They do not wrap around.
- They work when stopped and when playing.
- The next-up line (6.7) names the preset that Next would load, and updates with every change to the setlist or to that preset.

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

**Haptics switch:**

- When off, the app plays no haptics at all: no beat taps, no selection ticks and no Start / Stop impact (section 12).
- Turning it on plays one selection tick, so the user feels that haptics are back. Turning it off plays nothing.
- It works when stopped and when playing. While playing, the change applies from the next beat.
- It applies to the whole app and is remembered between launches. Presets do not store it. Mute (7.5) does not affect it.
- If haptics are turned off in the phone's own settings (System Haptics), the app has no haptics whatever the switch says; that is system behaviour.

**Keep screen awake switch:**

- When on, the screen does not dim or auto-lock while the app is open, whether playing or stopped, so between songs the user can start the next one without unlocking the phone.
- When off, the screen stays on only while playing (7.4), and dims and locks as usual while stopped.
- The change applies at once, when stopped and when playing. Like the iCloud switch, it plays no haptic.
- It does not keep the app open: the side button still locks the phone and switching apps still leaves it, and playback stops as in 7.7.
- It is off on a fresh install, is remembered between launches, and stays on this device; presets do not store it and iCloud does not sync it.

### 7.9 iCloud sync

The switch works when stopped and when playing, applies to this device only and is remembered between launches. How copies are combined is in 5.1.

**Switching on:**

- The device's library is combined with what is in iCloud. Nothing is removed on either side except by a delete marker, so a second device gets the first one's presets and setlists next to any of its own.
- The status line shows `Syncing…` until the first exchange with iCloud, or for two seconds when nothing arrives, and then `Up to date`.

**While on:**

- Every change to a preset or setlist is handed to iCloud at once.
- Changes from other devices are combined into the library when they arrive while the app is open, and whenever the app is opened or comes back to the foreground.
- iCloud decides when changes travel: usually within a minute, later when a device is offline. The app does not show changes live as they are typed on another device.

**Switching off:**

- The device stops sending and receiving, as if it were offline. Its library stays as it is. Other devices and iCloud are not affected, apart from the clean-up when it was the last device (5.1).
- Switching on again combines everything changed in the meantime, on this device and on the others, by the same rules.

**When changes arrive:**

- The metronome never changes by itself: tempo, time signature and accents stay as they are, playing or stopped.
- If the loaded preset's settings changed, the preset counts as edited and the save controls appear, because what is in the metronome now differs from the preset. Revert takes the arrived version; Save keeps the metronome's and sends it to the other devices.
- If the loaded preset's name changed, the header shows the new name at once.
- If the loaded preset, the loaded-from setlist or the setlist the library is showing was deleted, the rules in section 5 apply.
- An open library sheet, setlist or setlist editor updates in place. A setlist view or editor whose setlist was deleted closes and the library shows the Setlists tab.
- Nothing is announced: no alert, banner, sound or haptic.

## 8. Library sheet

A tall sheet over the metronome, with a grabber. Swiping it down closes it and changes nothing.

**Structure.** The library has two levels.

- The top level has two tabs: **Presets**, every preset, and **Setlists**, the list of setlists (9.1).
- Tapping a setlist on the Setlists tab opens that setlist (8.3), one level down. A ‹ takes the user back up to the Setlists tab.

**Where it opens.**

- On the Presets tab, so that a preset can be picked at once.
- When the loaded preset was loaded from a setlist, inside that setlist, where the user is.
- Either way the list is scrolled only as far as is needed for the loaded preset's row to be in view, when the list has it.

### 8.1 Header

**On the top level** the header is one row: the tab switch at the left and one button at the right. There is no large title; the tabs name what is shown.

- **Tab switch:** a surface-raised pill, 40 pt tall, with `Presets` and `Setlists` (15 pt). The selected tab is dial white and bold on a lighter fill (`#3A3A3F`); the other is muted and semibold.
- **Presets tab:** **New preset**, which opens the New preset sheet (section 10).
- **Setlists tab:** **New setlist** (9.1).

**Inside a setlist** the header has, from the left:

- **‹**, which goes back to the Setlists tab.
- The setlist's name as the title (26 pt heavy). It is not a button.
- **Menu button** (⋯, 36 pt round), with **Duplicate setlist** and **Delete setlist** (8.3).
- **Edit**, with a pencil, which opens editing (9.2). Reordering happens there; only an empty setlist has a shortcut for adding presets (8.3).

### 8.2 The Presets tab

- **No preset**, the first row, shown only while a preset is loaded. It is how the user goes back to having no preset loaded.
  - Below the name it says what it does and what is kept, for example `Unload current preset, keep 120 BPM · 4/4`. While the preset has unsaved edits, these are the edited values. On a narrow screen the end of the line is cut.
  - It has no menu button, so it is not taken for a preset.
  - Tapping it unloads the preset and closes the sheet. The tempo, time signature and accents stay as they are, playing or stopped, and the click does not change. The preset itself is not changed; unsaved edits stay as plain settings. Previous / Next disappear and the header shows the "nothing loaded" state.
  - It is not shown while nothing is loaded, since there is nothing to unload, and not in a setlist.
- Then every preset, sorted by name A–Z, ignoring case and following the phone's language rules. Presets with the same name keep their order of creation.
- Each row shows the name (17 pt), and below it tempo and time signature, for example `120 BPM · 4/4`. At the right is the **menu button**: a 40 pt round surface-raised button with a dial-white ⋯ (8.4).
- The loaded preset's row has an amber name and `· loaded` after its details.
- **Tapping a row** loads the preset and closes the sheet. It does not start the metronome; Start is under the thumb when the sheet has closed. If the metronome is already playing, it keeps playing with the new preset.
- A preset loaded from this view keeps the setlist that was being stepped through when it is in that setlist, so the header still shows its position and Previous / Next stay. A preset that is not in that setlist, or one loaded while no setlist was being stepped through, has no loaded-from setlist, and Previous / Next are hidden.
- **Swiping a row left** reveals **Edit** and **Delete**, as a shortcut to the same items in the row's menu.
- Empty library: centred, `No presets yet` (17 pt, semibold, dial white) and below it `A preset is a tempo, time signature and accents saved under a name, usually one per song. Make one with New preset.` (15 pt, muted). New presets are made with the button in the header.

There is no button on a row that loads and starts in one tap. A button that looked like a preview but replaced the loaded preset and closed the sheet was easy to misread, and its place is better used for the menu.

### 8.3 A setlist

- Only the setlist's presets, in the setlist's order, each with its position number at the left.
- Above the list: the count, such as `8 PRESETS`. An empty setlist shows no count.
- Rows, tapping and the menu button work as in 8.2. A preset loaded from this view has this setlist as its loaded-from setlist, so the header shows the position and Previous / Next.
- **Swiping a row left** reveals **Remove**, which takes the preset out of this setlist (8.5). Reordering happens in Edit.
- Empty setlist: centred, `No presets in this setlist`, below it `Add the presets you want to play, in the order you want them.`, and an outlined **Add preset** button. The button opens 9.3 directly, as a shortcut for filling a new setlist without going through Edit.
- **The setlist's menu** (⋯ in the header) holds what is done to the setlist as a whole:
  - **Duplicate setlist:** creates a setlist named `<name> copy` with the same presets in the same order, and shows the copy. The presets are shared, not copied.
  - **Delete setlist**, in red: asks for confirmation, deletes the setlist and goes back to the Setlists tab. The presets stay in the library.

### 8.4 The row menu

The ⋯ button at the end of every preset row, on the Presets tab and in a setlist, opens the system menu with everything that can be done with that preset, in this order:

- **Add to setlist**, which opens a second level:
  - Every setlist, most recently used first, with a tick when the preset is in it. Tapping one adds the preset to the end of that setlist, or takes it out (8.5).
  - **New setlist**, after a divider: creates a setlist that starts with this preset and opens it for naming (9.2).
- **Edit:** opens the Edit preset sheet (10.2), with the name, tempo, time signature and accents. There is no separate Rename, as the sheet holds the name.
- **Remove from setlist:** only in a setlist view. Takes the preset out of the setlist shown (8.5).
- **Delete**, in red: asks for confirmation and says how many setlists the preset is in.

So a preset can be put into a setlist, edited or deleted from wherever it is listed, without first changing what the library shows.

### 8.5 Removing a preset from a setlist, and Undo

A preset can be taken out of a setlist from the row menu, by swiping in a setlist view, with the remove button in Edit (9.2) and by unticking it in 9.3. In every case:

- It happens at once, without confirmation. The preset stays in the library.
- An **Undo bar** appears at the bottom of the sheet: `Removed <preset name>` (15 pt, dial white) and `Undo` in amber at the right, on a surface-raised bar with 14 pt corners. It goes away by itself after 6 seconds, and a new removal replaces it.
- **Undo** puts the preset back in the setlist at the place it had. If it was the loaded preset, loaded from that setlist, its position and Previous / Next come back too.
- If the setlist's order was changed in Edit after the removal, the bar goes away, since the old place no longer means anything. If the setlist changed in another way meanwhile, Undo puts the preset back at the end.

Only the last removal can be undone. Deleting a preset or a setlist is confirmed beforehand and has no Undo.

## 9. Setlists

### 9.1 The Setlists tab

- Every setlist with its preset count and a ›, most recently used first. A setlist counts as used when it is opened here or a preset is loaded from it.
- The setlist the loaded preset was loaded from is amber, so the user sees where they are.
- Tapping a setlist opens it (8.3). It loads nothing into the metronome.
- **New setlist** button at the top right: creates a setlist and opens it for naming (9.2).
- While there are no setlists: centred, `No setlists yet` (17 pt, semibold, dial white) and below it `A setlist is an ordered selection of presets, for a gig or a practice routine. Make one with New setlist.` (15 pt, muted).
- The list scrolls; there is no limit on the number of setlists.

### 9.2 Creating and editing a setlist

One screen with two uses. It holds the setlist's name and its presets, with **Add preset** after the last one (9.3). Each preset row has a red remove button at the left and a drag handle at the right:

- Remove takes the preset out of this setlist, with Undo (8.5).
- Dragging the handle moves the row; the new order is the setlist's order.

Duplicating and deleting are not here; they are in the setlist's own menu (8.3).

**Creating**, after New setlist on the Setlists tab or in a preset's row menu (8.4):

- The name field is empty and ready for typing, showing `New setlist` as its placeholder.
- At the right are **Cancel** (15 pt, semibold, dial white) and **Done**. There is nothing else in the header.
- **Done** keeps the setlist and shows it (8.3). A setlist that still has its default name and no presets is not kept, as with Cancel.
- **Cancel** drops the setlist, whatever name and presets it was given, and goes back to the screen New setlist was chosen on. Swiping the library away counts as Cancel.

**Editing**, with Edit in a setlist's header:

- The name stands in the place and size of a title, with a muted **pen** right after it. Tapping the name or the pen puts the cursor in the name; the pen hides while the name is being typed. An empty name is not accepted; the previous name is kept.
- At the right is **Done** only. It goes back to the setlist. Every change takes effect at once; there is no cancel.

### 9.3 Adding presets to a setlist

Opened with Add preset, in Edit or in an empty setlist. A list titled `Add to <setlist>`, with Done, which goes back to where the list was opened from.

- First row: **New preset**, which opens the New preset sheet (section 10) with "Add to <setlist>" switched on.
- Then every preset in the library, A–Z, with a tick when it is in the setlist.
- Tapping a row adds the preset to the end of the setlist, or takes it out, with Undo (8.5). Changes take effect at once.

## 10. Preset sheet

One sheet for creating a preset (10.1) and editing one (10.2). A short sheet with:

- **Name field.** Save is disabled while the name is empty. Names are limited to 60 characters; spaces at the ends are removed.
- **Tempo:** − and + around the value. One tap changes it by 1 BPM; holding repeats, as on the metronome screen. Tapping the value opens the tempo sheet (6.11) to type a tempo, which sets only the sheet's tempo.
- **Time signature row:** opens the same picker as the metronome screen. Changing it resets the accents to beat 1.
- **Accent tiles:** one per beat, tap to toggle.
- **Add to <setlist>** switch: shown only when the sheet was opened from 9.3, and on by default there.
- **The save button**, a 60 pt amber pill.

Changing values in the sheet does not affect the metronome, playing or stopped, until the sheet is saved.

### 10.1 New preset

Titled `New preset`, with `Save preset`. Opened with New preset in the library (8.1, 9.3) or with Save as new preset (7.6). The name field is ready for typing. All three settings start from the metronome's current values, so the quickest way to make a preset is to set the metronome first.

Saving a new preset from the library does not load it, with one exception: **naming the current settings.** When no preset is loaded and the preset is saved with the same tempo, time signature and accents as the metronome has, the new preset becomes the loaded one, so the header shows its name at once and later changes bring up the save controls.

- The metronome is not touched: it keeps playing or stays stopped, and no new bar starts.
- If the preset was added to a setlist (9.3, with "Add to <setlist>" on), it counts as loaded from that setlist, so the header shows its position and Previous / Next appear. Otherwise it is loaded on its own.
- In every other case the preset is only created: when a preset is already loaded, or when the values were changed in the sheet.

**Save as new preset** for unsaved changes (7.6) always makes the new preset the loaded one.

### 10.2 Edit preset

Titled `Edit preset`, with `Save changes`. Opened with Edit in a preset's row menu, or by swiping its row on the Presets tab (8.2, 8.4). The name and the three settings start from the preset's saved values, also when it is the loaded preset with unsaved changes. The keyboard does not come up by itself, as the change is more often to the tempo or the accents; tapping the name brings it up. Swiping the sheet away keeps the preset as it was.

`Save changes` writes only what changed, so that a part left alone does not win over a change made to it on another device (section 5).

- A preset that is not loaded is only changed; the metronome is not touched.
- The loaded preset with changed settings: the metronome takes them, as if the preset were loaded again, and any unsaved changes are dropped. While playing, the bar carries on when only the tempo or the accents changed, and the next beat is beat 1 of a new bar when the time signature changed.
- The loaded preset with only a new name: the header shows the new name, and the metronome and any unsaved changes stay as they are.

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
- **Length.** No sound is longer than 150 ms, so each one ends well before the next beat at 300 BPM (200 ms). The last 3 ms fade to silence.

## 12. Beat effects

Each beat fires all of the following at the moment of its click.

| Effect | Normal beat | Accented beat |
|---|---|---|
| Glow | An amber radial glow behind the BPM number flashes to 30 % opacity and decays over half the beat interval. | Same. |
| Number pulse | The BPM number scales 1.0 → 1.04 and back within half the beat interval. | Same. |
| Tile | The beat's tile switches to its sounding state at once. The previous tile fades back to idle over 150 ms. | Same. |
| Haptic | Light impact, intensity 0.5. | Rigid impact, intensity 1.0. |

There are no other beat visuals; in particular nothing ripples or moves outside the dial.

Other haptics: a selection tick for each 1 BPM change from the ring or − / +, for each tap-tempo tap, for each key in the tempo sheet and for `Set tempo` when it changes the tempo, for each accent toggle, for Revert, and for each tap on the mute button. Beat haptics continue while muted. A medium impact on Start and Stop. The system's success notification on Save.

The Haptics switch in settings (7.8) turns all of these off.

## 13. Accessibility

- **Reduce Motion:** the number pulse is disabled. Tile changes and the glow remain.
- **VoiceOver:**
  - The dial is an adjustable element ("Tempo, 120 beats per minute, Allegro") that steps by 1 BPM. It has the action "Type a tempo", which opens the tempo sheet.
  - In the tempo sheet the field reads as "Tempo" with the typed digits, each key as its digit, and the delete key as "Delete".
  - In the preset sheet the tempo value is a button: "Tempo, 120 beats per minute", with the hint "Type a tempo".
  - The save controls in the dial read as "Revert", with a hint that says what comes back (for example "Goes back to 120 BPM · 4/4"), "Save changes" and "Save as new preset". They are separate from the dial's own element. The header Save button on a small dial reads as "Save changes" and "More save options". After Save, "Saved" is announced, and the pill reads "Saved" while it shows that.
  - The tap tempo pill reads as "Tap tempo" also while it shows `Tap again`.
  - The next-up line reads as one element, for example "Next: Seven Bridges, 168 beats per minute, 7/8", or "Last preset in the setlist".
  - Each tile reads as "Beat 3, accented" or "Beat 2, not accented", with the toggle as its action.
  - The mute button reads as "Click sound, on" or "Click sound, muted".
  - The settings button reads as "Settings".
  - A sound row reads as its name, with "selected" for the current one, and says that tapping plays a preview.
  - The haptics switch reads as "Haptic feedback, on" or "Haptic feedback, off".
  - The screen switch reads as "Keep screen awake, on" or "Keep screen awake, off".
  - The sync switch reads as "Sync presets and setlists, on" or "Sync presets and setlists, off". The status line reads as its text and detail, for example "Up to date, last synced 14:32"; the dot is not read.
  - The header title reads the preset name and its second line, and says that it opens the library. While the preset is edited it says "edited" after the name, for example "Seven Bridges, edited, Friday gig · 3 of 8", because the save controls appearing cannot be heard.
  - A preset row reads as its name, tempo and time signature, for example "Harbour Lights, 120 beats per minute, 4/4", with "loaded" when it is. Its menu button reads "More for Harbour Lights".
  - The Undo bar's button reads "Undo"; the back button in a setlist reads "Back to setlists"; the menu button in a setlist reads "More for this setlist"; the pen in setlist editing reads "Rename setlist". The tabs read "Presets" and "Setlists", with "selected" for the one shown.
  - In setlist editing, rows can be moved up and down with VoiceOver actions as well as by dragging.
  - Beat changes during playback are not announced.
- Every tappable control is at least 44 × 44 pt.
- Text does not scale with Dynamic Type; see section 16.

## 14. Acceptance checklist

A ticked line has been verified in the simulator, by unit tests or on a phone. An unticked line carries a note on what is missing.

Metronome:

- [x] Tempo can be set by ring, − / + and tap tempo, when stopped and when playing, and never leaves 30…300. *(A tap tempo series has not been tapped by hand; its rules are unit tested.)*
- [ ] A drag on the ring turns the dial by the angle travelled, wherever it begins; a tap or a brush against the ring changes nothing. *(The turning rules are unit tested, and a drag and a tap on the ring were tried in the simulator. How it feels under a finger needs a real iPhone.)*
- [x] Tapping the number opens the tempo sheet; typing a tempo and Set tempo sets it, and only tempos from 30 to 300 can be set. *(The digit rules are unit tested; typing 174 was tried in the simulator.)*
- [ ] The tap tempo pill reads Tap again with an amber outline during a series and goes back two seconds after the last tap. *(The label and outline were seen in the simulator; going back after two seconds was not watched.)*
- [x] Unlit ticks are visible against the background, and nothing in the header moves when Start is pressed. *(Seen in the simulator.)*
- [x] On a tall screen the dial grows up to 340 pt and never wider than the space between the margins. *(Unit tested, and seen on an iPhone 17 Pro.)*
- [x] The lit arc, knob, number and tempo name always agree.
- [x] All eight time signatures can be selected; the tile count matches the signature.
- [x] Changing the signature resets accents to beat 1 and, while playing, continues with a new bar. Reselecting the current signature, or dismissing the sheet, changes nothing.
- [ ] Accents can be toggled when stopped and when playing; accented beats sound, look and feel different from normal beats. *(Toggling and the look are verified. Sound and haptics need a listener and a real iPhone.)*
- [x] Start always begins on beat 1. Stop is immediate.
- [x] The mute button silences the click at once and brings it back, while the visuals and haptics continue.
- [ ] Click, visual and haptic stay together at 30, 120 and 300 BPM. *(Needs a real iPhone.)*
- [ ] No audible drift against a reference metronome over 10 minutes. *(The timing maths is unit tested to the sample; the listening check needs a real iPhone.)*
- [ ] The phone's volume buttons and the Control Center slider change the click volume. *(Needs a real iPhone.)*
- [x] Tempo, time signature and accents survive quitting and reopening the app.
- [ ] Reduce Motion and VoiceOver behave as in section 13. *(Not yet tried with the settings switched on.)*

Presets and setlists:

- [x] A preset can be created, loaded, edited and deleted; the library is sorted A–Z.
- [x] No preset unloads the loaded preset and keeps the settings and playback; it is only on the Presets tab, and only while a preset is loaded. *(Unit tested; the row and its new text were seen in the simulator.)*
- [x] Tapping a row loads without starting, and keeps playing when the metronome is running. *(Unit tested.)*
- [x] The row menu offers Add to setlist, Edit, Remove from setlist and Delete in every list, and the swipe gives the shortcuts of 8.2 and 8.3. *(Adding to a setlist, New setlist, Delete and Remove were tried in the simulator before Edit replaced Rename. Edit from the menu on the Presets tab was tried after it; the Edit swipe and Edit in a setlist view were not.)*
- [x] Edit preset changes a preset's name, tempo, time signature and accents as 10.2 says. *(The rules for the loaded and the unloaded preset are unit tested. Changing a tempo by typing it and saving was tried in the simulator.)*
- [x] Tapping the tempo in the preset sheet opens the tempo sheet, and Set tempo sets only the sheet's tempo. *(Tried in the simulator from Edit preset; New preset uses the same sheet and was not tried separately.)*
- [x] Taking a preset out of a setlist shows the Undo bar, and Undo puts it back in its place. *(Unit tested, including the loaded preset's position, and tried in the simulator.)*
- [x] The library opens on the Presets tab, or inside the loaded preset's setlist when it came from one, and scrolls to its row. *(Choosing the setlist is unit tested, and both ways of opening were seen in the simulator. In the simulator the list stayed at its top on an iPhone 17 Pro, where the loaded row fits, and scrolled just far enough to show it on an iPhone SE, where it does not. A library of several screens has not been tried.)*
- [x] A preset loaded from the Presets tab keeps the setlist being stepped through when it is in it. *(Unit tested.)*
- [x] The header shows the right title and second line in every state of 6.1.
- [x] Changing a loaded preset's settings shows the save controls in the dial's gap and leaves the title as it is; Save, Save as new preset and Revert do what 7.6 says, and the title opens the library also while edited. *(Save and Revert, with the bar carrying on or starting over, are unit tested, and so is the dial size the controls need. On the iPhone 17 Pro simulator Revert, Save with its Saved confirmation, and Save as new preset opening its sheet were tried. On the iPhone SE simulator the header Save button was seen to take their place.)*
- [x] Quick taps on − / + each count once and never leave the tempo running on by itself. *(Four quick taps on + were tried in the simulator after two quick taps had left the repeat running up to 250.)*
- [x] Naming the current settings while nothing is loaded loads the new preset, from the setlist it was added to; in other cases a new preset from the library is not loaded. *(Unit tested.)*
- [ ] The next-up line names the preset Next would load, says so at the last preset, and is left out when it would push the dial below 200 pt. *(The preset and the layout rule are unit tested, and the line was seen in the simulator. The last preset and a small phone were not seen on screen.)*
- [x] Opening the library keeps unsaved edits; loading another preset drops them.
- [x] A setlist can be created, renamed, duplicated and deleted; deleting it leaves its presets in the library.
- [x] Presets can be added to a setlist, removed from it and reordered; the order is kept.
- [x] A new preset can be created from inside a setlist and lands in that setlist.
- [x] Previous and Next step through the loaded-from setlist, stopped and playing, and stop at the ends. *(Next was tried in the simulator; Previous and the ends are unit tested.)*
- [x] Loading a preset while playing keeps the metronome running and starts a new bar.
- [ ] The Setlists tab shows all setlists with counts, a setlist opens from it with a way back, and the tab explains setlists while there are none and stays usable with 20 setlists. *(The tab, opening a setlist and going back were tried in the simulator, and the explanations on an empty Setlists tab, an empty Presets tab and an empty setlist were seen. 20 setlists have not been seen.)*
- [x] A setlist's menu has Duplicate and Delete. Creating a setlist offers Cancel and Done, and Cancel or swiping the library away drops it; editing shows a pen beside the name and Done only. *(All tried in the simulator: Duplicate showed the copy, Delete went back to the Setlists tab, Done kept a named new setlist and dropped an unnamed one, Cancel and swiping away dropped a named one, and the pen put the cursor in the name without moving the rows.)*
- [x] Presets, setlists, the loaded preset, and its position in the setlist survive quitting and reopening the app.

Settings and click sounds:

- [x] The settings button opens the settings sheet when stopped and when playing; Done, swiping down and tapping outside close it. *(Done was tried in the simulator; swiping and tapping outside are the system's sheet behaviour and were not tried.)*
- [x] Each of the seven sounds can be selected; the choice survives quitting and reopening the app, and a fresh install starts with Digital. *(Unit tested, and selecting while stopped and while playing was tried in the simulator.)*
- [ ] When stopped, tapping a sound plays an accented and a normal click; when playing, the new sound starts with the next scheduled beat. *(The model's rules are unit tested and playing carries on when the sound changes; hearing the preview and the switch needs a listener.)*
- [x] Every sound meets the loudness, attack and length rules in 11.1. *(Unit tested on the generated buffers at 48 and 44.1 kHz.)*
- [x] Previous and Next sit beside Start / Stop only for a preset loaded from a setlist, and Next is dimmed at the last preset. *(Tried in the simulator.)*
- [ ] The Haptics switch turns every haptic off and back on, stopped and playing; it survives quitting and reopening the app, and a fresh install starts with it on. *(The rules are unit tested and the switch was tried in the simulator; feeling the haptics stop needs a real iPhone.)*
- [ ] With Keep screen awake on, the screen does not dim or lock while the app is open and stopped; with it off, it does so only while playing. The switch survives quitting and reopening the app, and a fresh install starts with it off. *(The rules are unit tested. In the simulator the switch was tried on and off, stopped and playing, and across a relaunch, reading the app's idle-timer flag each time. The simulator never auto-locks, so the screen actually staying on needs a real iPhone.)*
- [ ] All seven sounds are equally loud by ear, and accented beats are clearly different from normal ones, on the phone's speaker and on headphones. *(Needs a listener and a real iPhone.)*

iCloud sync:

- [ ] The iCloud card looks as in 6.10 in every state, and the settings sheet scrolls when it is taller than the screen. *(The off state and Not signed in to iCloud were tried in the simulator, and the sheet scrolls under the fixed title on an iPhone 17 Pro and an iPhone SE. The simulator is not signed in to iCloud, so Syncing…, Up to date, iCloud storage is full and Update the app to keep syncing were not seen on screen.)*
- [x] Sync is off on a fresh install, and the switch survives quitting and reopening the app. *(Unit tested.)*
- [ ] Switching sync on for a second device brings the first device's presets and setlists next to its own, and later changes on either device reach the other. *(Needs two devices on one iCloud account. Only a stand-in for iCloud has been used.)*
- [x] Copies are combined as in 5.1: per part of a preset, per preset in a setlist, order, an edit after a deletion, and an item missing from iCloud. *(Unit tested against an in-memory stand-in for iCloud.)*
- [ ] When changes arrive, the metronome keeps its settings, a changed loaded preset counts as edited, and open lists update in place. *(The metronome keeping its settings, the preset counting as edited, a deleted loaded preset, setlist or filter being cleared, and no haptic are unit tested. Open lists updating in place, and the setlist editor closing when its setlist is deleted elsewhere, need a change arriving from a second device.)*
- [x] Switching sync off leaves the library on the device and the other devices untouched; switching it on again combines what changed meanwhile. *(Unit tested against an in-memory stand-in for iCloud.)*
- [ ] The last device to switch sync off empties iCloud, and a syncing device that finds iCloud emptied puts its library back. *(Unit tested against an in-memory stand-in for iCloud. The clean-up reaching real iCloud has not been seen.)*
- [ ] The status line shows not signed in, iCloud full and newer format as in 6.10. *(Every status text and the line below the card are unit tested, and Not signed in to iCloud was seen in the simulator. iCloud storage is full and Update the app to keep syncing were not seen on screen.)*
- [x] A part or item the app does not know survives combining and being written back, and a higher format number stops syncing without changing iCloud. *(Unit tested.)*
- [x] A library made before sync existed is kept in full when the app is updated. *(Unit tested.)*
- [ ] The app can tell a signed-in device from a signed-out one, and one iCloud account from another. *(Needs a device signed in to iCloud.)*

## 15. Not built yet

Everything in this document is built. A part that is specified before it is built is listed here until it is.

## 16. Ideas for later

Not part of version 1.0.

- **Dynamic Type in rows and sheets.** Labels and text in rows and sheets scale with the phone's text size, up to the first accessibility size. The large BPM number stays fixed.
- **Making room when iCloud is full.** When iCloud reports that it is full, the oldest delete markers are removed to make room, not only when the item count is over the limit (5.1).
- **Play while locked.** Playback continues when the user locks the screen.
