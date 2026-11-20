# Snappy Metronome specification

This is the single specification for the app. It describes how version 1.0 is meant to work and is kept up to date as decisions change. Parts that are specified here but not built yet are listed in section 15.

Design source: Paper file "Snappy Metronome", page *v1.0*. Its boards are named *v1.0 · <screen>*, and the screens are drawn at 390 × 844 pt. In rows: the metronome screen (*Metronome — Ready*, *— Playing*, *— Edited* and *— Save menu*); the sheets over it (*Time signature picker*, *Tempo sheet*, *Settings sheet*, and two small boards with the iCloud card switched on, *Settings — iCloud on, up to date* and *Settings — iCloud not signed in*); the library (*Library — Songs, song loaded*, *— Songs, empty*, *— Setlists*, *— Setlist*, *— Add song* and *— Empty setlist*); the song sheet (*Song sheet — New song* and *— Edit song*); and *Beat effects* and *App icon — Downbeat*.

Backing tracks are on the page *Backing tracks (draft)* of the same file. Its boards *Track · Beats — Ready* and *Track · Beats — Playing* draw the metronome screen while a track is in use, stopped and on a beat, in a layout without a dial, tempo controls or time signature row, which the page *Player with mode switch (draft)* supersedes (below); the Playing board draws the number amber, and the app keeps it dial white (section 12). *Track · Beats — Sync* draws the parts of Sync mode (6.13); Sync mode is shown as a sheet, with the sheet's title row, which the board does not draw. *Track · Switch — Track off (today's layout)* shows the Backing tracks switch off over the layout of the *v1.0* boards. That board is a copy of the plain Ready board, so it shows a different tempo and time signature from the others and no setlist footer. The boards *Track · Song sheet — Edit song, with track* and *— Edit song, no track* show the song sheet's Backing track row (10.3), and *Track · Library — Songs, track mark* the library's mark (8.2). Where a board and this document differ in a detail, this document holds. Not drawn: the switch dimmed while playing, the player card of a song not loaded from a setlist with its three buttons, Sync mode stopped, with two rows of tiles or scrolled on a small phone, Sync mode's sheet colours (6.13), and the Backing track row's missing-file state.

The player card's Track content with its Sync pill (6.12) is drawn on the page *Track screen with dial (draft)* of the same file, on the board *Track — dial as gauge, Sync in the card*, and its missing-file state, with the `Choose file` button, on the board *Track — file missing, Choose file* (6.12). The board *Plain — larger digits, no tempo name* on the same page draws the dial's number without a tempo name. These boards draw a 300 pt dial with a larger number, the dial of a song with a track as a locked gauge, and the next-up line in the card; for the dial and the card's size the page *Player with mode switch (draft)* holds (below). The *v1.0* boards draw the dial's number smaller, with a tempo name under it.

The header, its badge and the header menu (6.1, 7.6) are drawn on the page *Header menu (draft)* of the same file, on the boards *Header menu — Song loaded*, *— Edited (badge)*, *— Menu, edited* and *— Menu, nothing loaded*. The *v1.0* and *Backing tracks (draft)* boards draw the header without the menu button; for the header this page and this document hold.

The library's top-level header with its menu button, the controls line with the + button, the Setlists tab's search, the tab menus and select mode (8.1, 8.2, 8.6, 8.7, 9.1) are drawn on the page *Library menus (draft)* of the same file, on the boards *Songs — menu button and +*, *Songs — menu open*, *Setlists — search, + and menu button* and *Songs — select mode*. The *v1.0* boards draw the top-level header with New song and New setlist buttons, and a setlist's menu button at 36 pt; the boards of this page and the *v1.0* library boards draw a ⋯ at the end of every song row outside select mode; for these parts this page and this document hold.

A setlist's controls line with its search and +, and select mode in a setlist (8.3, 8.8), and the Add song screen's search (9.3) are drawn on the page *Setlist controls (draft)* of the same file, on the boards *Setlist — search and +*, *Setlist — searching*, *Setlist — select mode* and *Add song — search*. The *v1.0* boards *Library — Setlist* and *Library — Add song* draw the Add song row after the last song, a 36 pt menu button and no search, and *Library — Setlist* also draws a count line, such as `8 SONGS`, above the list, and a drag handle (≡) at the end of each row; the boards of this page draw a ⋯ at the end of every song row outside select mode; for these parts this page and this document hold. Not drawn: the Undo bar for several songs, and the Add to setlist menu in a setlist's select mode.

Stage mode (9.4) is drawn on the page *Stage mode (draft)* of the same file, on the boards *Stage — ready*, *Stage — playing* and *Stage — stopped, next marked*. The boards draw every song's name on one line and `Done` at 35 % opacity while a tile plays. They also draw a `NEXT` label on the marked tile, the mark moving to the following song when a song stops (*Stage — stopped, next marked*), and the playing tile filled solid amber with ink text. Here the marked tile is the loaded song's, with no label, it stays on a stopped song, and the playing tile keeps the tint and pulses on the beat. Where a board and this document differ, this document holds. Not drawn: the Stage mode items in the header menu and the setlist's menu, a name on two lines with its taller row, the beat dots in 9/8 and 12/8, a playing song whose backing track's file is missing and so with the track mark, the tiles with Backing tracks off and so without track marks, the count-in, a setlist longer than the screen, a narrow phone, the marked tile carrying a track mark, and the beat pulse.

The metronome screen's one layout, with the player card at its bottom (section 6), is drawn on the page *Player with mode switch (draft)* of the same file, on the boards *Header switch — Metronome* (a song with a backing track and Backing tracks off, so the card's Metronome content), *Header switch — Track* (the same song with Backing tracks on, so its Track content) and *Header switch — song without a track*. The board *Header toggles — same logic* draws the Sound button and the Backing tracks switch on and off (6.1). For the layout of the metronome screen, the dial, the tempo controls, the time signature row, the accent tiles and the player card, these boards supersede the metronome screen's boards on the pages *v1.0*, *Backing tracks (draft)*, *Track screen with dial (draft)* and *Header menu (draft)*. For the Sound button and the Backing tracks switch, *Header toggles — same logic* supersedes every other board, the three *Header switch* boards included, which draw the Sound button on a surface fill while the sound is on and the switch off as a muted note without a slash. The boards draw the knob's darker colours as a shade laid over a picture of the knob of the other pages, with the amber indicator drawn again on top, longer and further in than 6.2 says; the tempo controls, the time signature row and the tiles centred in the space below the dial's square rather than below the knob; seven tiles 8 pt apart; and the card 30 pt above the screen's bottom edge rather than at the bottom of the safe area. Not drawn: the playing state, with `Stop` and the time running; Track content with the file missing; the card of a song not loaded from a setlist or with nothing loaded; a time past an hour; two rows of tiles; the Backing tracks switch dimmed while playing; a small phone; and the beat effects. Where a board and this document differ, this document holds.

## 1. Summary

A native iOS metronome with one main screen. The user sets a tempo and a time signature, chooses which beats are accented, and presses Start. Each beat produces a click, a visual effect and a haptic tap on the same instant. Everything can be changed while it plays.

Settings can be saved as named **songs**; a practice setup can be saved as one too. The **library** lists all songs, and **setlists** are named, ordered selections from it. The loaded song's name sits in the header of the metronome screen; tapping it opens the library. On stage a setlist is played in **stage mode**, with its songs as large tiles: a tap starts a song and a second tap stops it.

A song can have a **backing track**: an audio file produced to a click, with its own tempo. Start then plays a count-in of click only, after which the track and the click play together, locked to each other, until the track ends. While a track is in use the player at the bottom of the screen shows the track, and the dial and the other tempo controls set the track's tempo. Sync mode sets the track's tempo and its offset by tapping along, and the mix. A switch in the header turns backing tracks off for the whole app, and every song then plays as a plain metronome at the song's own tempo.

## 2. Scope

Included:

- Tempo from 30 to 300 BPM, set by turning the dial, − / + buttons, tap tempo or typing the number.
- Eight time signatures: 2/4, 3/4, 4/4, 5/4, 6/8, 7/8, 9/8, 12/8.
- Per-beat accents; any combination of beats, including none.
- Start / Stop with click sound, visual beat effects and haptics.
- A Sound button that silences the click while the metronome keeps running.
- The time played and the bars played since Start.
- A song library and setlists.
- Stage mode, for playing a setlist on stage.
- Backing tracks: an audio file attached to a song that plays locked to the click, with its own tempo, a count-in, rewind, fast-forward and a Sync mode that sets the track's tempo and offset by tapping on beat 1 and sets the mix between click and track, and a switch that turns backing tracks off.
- A settings sheet with a choice of seven click sounds and a switch that turns all haptics off.
- Everything remembered between launches.
- Optional iCloud sync that keeps the songs and setlists the same on the user's devices.

Not included:

- Subdivisions, an overall volume control inside the app (the phone's own volume controls set the overall level; see 7.7).
- Playback with the screen locked or the app in the background.
- Search other than by name on the Songs and Setlists tabs, in a setlist and on the Add song screen (8.2, 8.3, 9.1, 9.3), sorting inside a setlist, folders or tags, notes on songs, per-song sounds, importing or exporting songs, and sharing with other people.
- For backing tracks: tempo maps and tempos with decimals, so a track whose tempo wanders is not supported; a waveform view; automatic tempo or beat detection.
- Syncing anything other than songs and setlists: the current settings, the loaded song, the library's sort orders, the songs' last-played times, the click sound and haptics stay separate on each device, and the audio file of a backing track is never synced.
- iPad layout, landscape, light mode, Apple Watch, widgets.

## 3. Platform and identity

- iPhone only, portrait only, dark appearance only.
- SwiftUI. Minimum iOS version: iOS 18.
- Designed at 390 × 844 pt. Smaller phones adapt the layout; see 6.8 and 6.13.
- Typeface: the system font (SF Pro). The Paper boards use Inter and Inter Tight as stand-ins because SF Pro is not available there. Weights and sizes in this document carry over.
- Version: 1.0. Until 1.0 is released, new work stays in 1.0 and goes to TestFlight as a new build number.
- App Store name: "Snappy Metronome". Under the icon on the home screen the app shows as "Metronome", because the full name does not fit there.
- Bundle identifier: `com.metsahalme.metronome`.
- App icon: "Downbeat", one large amber dot followed by three small dial-white dots on ink, as a single 1024 × 1024 image.

## 4. Concepts

- A **song** has a name, a tempo, a time signature and a set of accented beats: the same settings as the metronome screen.
- A song may have one **backing track**: an audio file that plays together with the click. It is meant for a track produced to a click, so its tempo is steady and a whole number of BPM fits it. Besides the file, the track has the file's name as shown to the user, a tempo, an offset, a count-in and a mix:
  - The track's **tempo** is the tempo the click plays at with the track, an integer from 30 to 300 BPM. It is the track's own and is set only in Sync mode (7.11). A track attached to a song starts with the song's tempo at that moment; replacing the file keeps it. A track stored without a tempo, as data written by an earlier build is, takes the song's tempo.
  - The **offset** is the time in the file where beat 1 of the first bar falls, in seconds with two decimals, from 0.00 up to the file's length.
  - The **count-in** is Off, 1 bar or 2 bars; a new track starts with 2 bars.
  - The **mix** is how loud the click is against the track, set between Click and Track; a new track starts at the centre. At the centre the click and the track both play at full level. Towards Click the track is turned down, evenly in decibels along that half, by up to 24 dB at the end. Towards Track the click is turned down the same way, by up to 24 dB at the end. Nothing is ever turned up, and neither end is silent.
- The file is chosen with the system Files picker, from the audio files iOS can play (for example m4a, mp3, wav and aiff). The app copies it into its own storage on the device, so the track keeps working when the original is moved or deleted. There is no size limit.
- **Backing tracks** is one switch for the whole app, on or off (7.12). A **track is in use** while the switch is on and the loaded song has a backing track, whether its file is on this device or not; the player card then shows the track (6.12). With the switch off no track is ever in use, and every song is a plain metronome.
- A song's own tempo, the **song's tempo**, is the plain metronome's tempo. Loading a song sets the **metronome's tempo** to it; while no track is in use the dial, − / +, tap tempo and the tempo sheet change the metronome's tempo, and Save changes in the header menu saves it into the song together with the time signature and the accents (7.6). While a track is in use the same controls change the track's tempo instead (7.1). The song's tempo is what the library, the song sheet and stage mode's tiles show.
- The **tempo in effect** is the tempo the click plays at: the track's tempo while a track is in use, and the metronome's tempo otherwise. Turning Backing tracks on or off, and loading a song, change which of the two is in effect; neither value is changed by it, so an unsaved change of the metronome's tempo is still there when the track stops being in use. The time signature and the accents are the song's and are shared by the plain metronome and the track.
- A song's **last played** time is the moment it last became the loaded song on this device (8.6). A song that has never been loaded here has none. It is kept on the device and not synced, so each device has its own.
- The **library** holds every song. Songs exist only in the library; setlists refer to them.
- A **setlist** has a name and an ordered list of songs. It acts as a filter on the library and defines the order shown while it is selected.
- A song can be in any number of setlists, but only once in each.
- A song is loaded into the metronome either **from a setlist**, which then is its loaded-from setlist and gives it a position and Previous / Next, or **on its own**. Where it is tapped decides: in a setlist's view it is loaded from that setlist, and on the Songs tab on its own (7.6).
- Removing a song from a setlist never deletes the song.
- Deleting a song removes it from the library and from every setlist, and deletes the device's copy of its backing track's file (5.1).
- Changing a song changes it everywhere, since setlists share the same song.
- Names need not be unique, for songs or for setlists.
- Beats per bar is the top number of the time signature (7/8 has seven beats). One beat is one click. BPM counts clicks per minute for every signature, including the /8 ones.

## 5. State

Kept between launches:

| Item | Contents | Default |
|---|---|---|
| Tempo | the metronome's tempo (section 4), integer, 30…300 BPM; a track's tempo is kept with its song | 120 |
| Time signature | one of the eight in section 2 | 4/4 |
| Accents | set of beat numbers, 1…beats per bar | {1} |
| Songs | each with id, name, tempo, time signature, accents and an optional backing track (section 4) | none |
| Setlists | each with id, name, ordered song ids, last-used time | none |
| Song order | the Songs tab's order, Name, Recently added or Recently played, for this device (8.6) | Name |
| Setlist order | the Setlists tab's order, Name or Recently used, for this device (8.6) | Name |
| Last played | for each song loaded on this device, the time it was last loaded (section 4, 8.6); not synced. A time for a song that no longer exists is dropped | none |
| Loaded song | the song in the metronome, if any | none |
| Loaded-from setlist | the setlist the song was loaded from, if any | none |
| Shown setlist | the setlist the library sheet showed last, if any. It only says which setlist a view belongs to; where the sheet opens is decided in section 8 | none |
| Click sound | one of the seven sounds in 11.1 | Digital |
| Haptics | on or off, for the whole app | on |
| Keep screen awake | on or off, for this device | off |
| Backing tracks | on or off, for this device | on |
| iCloud sync | on or off, for this device | off |

Not kept:

| Item | Contents | At launch |
|---|---|---|
| Playing | whether the metronome is running | stopped |
| Muted | whether the click is silenced | sound on |
| Current beat | the beat that is sounding | none |
| Track position | the place in the loaded song's backing track | 0:00, and 0:00 again whenever a song is loaded |
| Elapsed time and bar count | the time and the bars played since the last Start (6.7, 7.13) | `0:00` and `Bar 1` |
| Sync mode | whether Sync mode is shown (6.13) | off |
| Stage mode | whether stage mode is shown, and for which setlist (9.4) | off |
| Search | the text in the search fields of the Songs tab, the Setlists tab, a setlist and the Add song screen (8.2, 8.3, 9.3) | empty |
| Select mode | whether the Songs tab or a setlist is in select mode, and which songs are ticked (8.7, 8.8) | off |

Derived:

- **Edited:** a song is loaded and the metronome's tempo, the time signature or the accents differ from it. While a track is in use only the time signature and the accents count, as the tempo on screen is the track's: an unsaved change of the metronome's tempo is kept, and makes the song edited again once the track stops being in use. On screen this is shown by the badge on the header's menu button (6.1); the word itself is not displayed. Everything set in Sync mode, the track's tempo, offset, count-in and mix and the song's time signature and accents, is saved into the song the moment it is set (7.11), so it never makes the song edited, and so is a change of the track's tempo made with the dial, − / +, tap tempo or the tempo sheet while a track is in use (7.1).
- **Position:** the loaded song's place in the loaded-from setlist, such as 3 of 8.

Reopening the app restores the settings, the loaded song and its setlist, so the position in the setlist is restored too and the user can carry on with Next. The app always launches stopped and with sound on.

Data is stored on the device, together with the copies of backing-track files, which are included in the device's backup. With iCloud sync on, the songs and setlists are also kept in the user's iCloud account (5.1); the files never are.

If the loaded song is deleted, the metronome keeps its current settings and the header shows "nothing loaded". If the song's track was in use and playable (7.10) and was playing, playback stops. If it is removed from the loaded-from setlist, it stays loaded on its own and the header shows the name alone, as for a song loaded from the Songs tab. If the loaded-from setlist is deleted, the same applies. If the setlist the library is showing is deleted, the library shows the Setlists tab. These rules hold whether the change was made on this device or arrived from another one.

### 5.1 iCloud sync

Sync is optional and off by default; the switch and what the user sees are in 6.10 and 7.9. This section says what is synced and how copies are combined.

**What is synced.** Songs and setlists, in both directions, between the user's devices that have sync on. Everything else in the tables above stays on the device, and so do the audio files of backing tracks (see Backing-track files below).

**Storage.** iCloud key-value storage (`NSUbiquitousKeyValueStore`), which uses the iCloud account the phone is signed in to. The app has no account or server of its own. iCloud holds one item per song, one per setlist and one per device. The device always keeps its own complete library, so the app works the same with sync off, signed out or offline.

**What is recorded so copies can be combined.** The device records this at all times, also with sync off, because switching sync off is treated like being offline (7.9).

- A song has four parts, each with the time it last changed: the name; the tempo; the time signature together with the accents, which only make sense as a pair; and the backing track, which is the file's identifier, its name, the track's tempo, the offset, the count-in and the mix together, as they only make sense together. A backing-track part without a tempo, as an earlier build wrote it, gives the track the song's tempo when it is read; the tempo is written into the part the next time the part changes, and filling it in gives the part no new time, so nothing is sent for it. When the song's tempo is changed on this device, the tempo the song had until then is first written into such a part in the same way, with no new time, so the track's tempo stays as it was. A song without a backing track has that part empty. It also has a creation time, which gives the order of creation used in 8.2 and 8.6.
- A setlist has a name with the time it last changed; for every song that is or was in it, whether it is in or out and since when; its order with the time it last changed; and its last-used time, which is set only when the setlist is used while it is not already the most recently used one (9.1).
- A deleted song or setlist leaves a delete marker with the time of deletion.
- Times come from the device's clock. A change always gets a time later than the one it replaces, even when the clock is behind.
- Only a part that really changed gets a new time. Save changes after changing only the tempo leaves the times of the name and the time signature alone. A tempo, offset, count-in or mix set in Sync mode (7.11) gives the backing track a new time and leaves the song's tempo alone; a time signature or accents set there give the time signature a new time and leave the backing track's alone.

**Combining.** Combining two copies gives the same result on every device, in whatever order the changes arrive.

- A song or setlist that exists in only one copy is added to the other.
- For each part, the newer one wins. When two times are equal, a fixed rule picks one, the same on every device.
- A setlist's membership is decided per song: the newer of "in" and "out" wins. So a song added on one device and another removed on a second device are both kept.
- A setlist's order is taken whole from the copy with the newer order. Songs that are in the setlist but not in that order go to the end, in the order they were added. A song that is removed from a setlist and added again goes to the end, like any newly added song.
- The later last-used time wins.
- A delete marker wins only when it is newer than every part of the item. Otherwise the item stays and the marker is dropped, so an edit made after a deletion brings the item back. For a setlist the parts are the name, the membership and the order; the last-used time does not count.
- A deleted song is hidden from its setlists, but its membership is kept, so a song that comes back is in its setlists again.
- An item that is missing from iCloud without a delete marker is never treated as deleted; the device puts its copy back.

Examples: a song renamed on one device and given a new tempo on another ends up with both changes. A song deleted on one device and edited later on another comes back with the edit. A setlist reordered on one device while a song is added on another keeps the new order with the added song at the end.

**Backing-track files.** The audio file itself is never synced; only the song's backing-track part is.

- Each file gets an identifier when it is attached. Replacing the file gives the new one a new identifier.
- On the user's other devices the song arrives with its backing track but without the file, so the track shows as missing (6.12) until the file is picked there, on the player card (6.12) or in the song sheet (10.3).
- A file picked for a missing track is stored under the identifier the part already has. When the picked file's name is the same as the name in the part, the part does not change, so nothing is sent. When it differs, the part takes the picked file's name and syncs; the identifier, the track's tempo, the offset, the count-in and the mix stay as they are. On the other devices only the name changes: a device that has the file keeps it and keeps playing it, and a device where the file is missing still shows it as missing, under the new name.
- Removing or replacing the track changes the part and syncs. A replaced file is then missing on the other devices until it is picked there too.
- A device keeps its copy of a file only while a song on it refers to the file's identifier, and deletes the copy when none does, also when the song is deleted. A backing-track part that names the identifier refers to the file even when the rest of it cannot be read, for example when a later version wrote it. A deleted song that comes back through sync has its track missing until the file is picked again.

**Later versions.** Songs and setlists can get new properties in later versions, and devices on different versions must be able to sync with each other.

- A new property is a new part with its own change time. A part that is missing counts as its default value, never changed, so the first device to set it wins.
- A version that finds a part it does not know keeps it untouched, on the device and in iCloud, and writes it back unchanged. Combining works per part without knowing what the part means, so the newer of two unknown parts still wins. The same goes for items of a kind it does not know: it leaves them alone, except that the clean-up below removes them with everything else.
- The data in iCloud carries a format number, which is 2. A later version raises it only for a change that older versions would misread or miss. A version that finds a lower number raises it.
- Format 1 kept songs under other item names, from when they were called presets. A device that finds a song under such a name combines it in like any other copy, writes it under the current name and then removes the old item, also when iCloud is full, as the move does not add an item. An old item that cannot be read is left alone. Raising the number stops devices still on format 1 from syncing, so they do not keep writing under the old names. A format number that cannot be read counts as higher than the app knows. A version that finds a higher number than it knows stops sending and receiving, keeps its library on the device, and says so in the status line (6.10). It does not take part in the clean-up below.

**Delete markers** are kept for one year and then removed from the device and from iCloud. A device that has been away longer than that can bring a deleted item back.

**Limits.** iCloud key-value storage holds 1 MB and 1,024 items per app, so songs, setlists, delete markers and device entries together have room for about a thousand items. A song's backing-track part is small, and the audio files are not in iCloud, so backing tracks barely count towards the limit. When iCloud reports that it is full, the status line says so (6.10) and the library keeps working on the device. Delete markers count towards the limit, so when the items would go over 1,024 the oldest markers are removed first to make room, even if they are less than a year old.

**Devices and clean-up.** While sync is on, the device keeps an entry in iCloud with a random identifier and the date it last synced, refreshed at most once a day. An entry is live when its date is less than six months old.

- Switching sync off removes the device's entry. If no other live entry is left, the device also removes the songs, setlists, delete markers and stale entries from iCloud. The library on the device stays.
- A device that has had sync on and now has it off checks the device entries each time the app is opened. If no live entry is left and the app still has data in iCloud, it removes that data. This catches two devices switched off close together, and a device that left without switching off.
- The clean-up is best effort and happens without asking. Data stays in iCloud when the app is deleted from every device while sync is on, or when the phone changes iCloud account before sync is switched off. It reaches iCloud when the device is next online.
- If a device that is still syncing finds iCloud emptied, it puts its library back, by the rule that missing is not deleted. The same goes for a syncing device that finds its own entry missing: it puts the entry back together with its library.
- The clean-up only ever runs on the iCloud account the device has synced with.

**iCloud account.**

- Not signed in to iCloud, or iCloud unavailable to the app: sync stays switched on and waits; the status line says so (6.10).
- Signed in to a different iCloud account than the one sync was switched on with: sync switches itself off, so a library is never mixed into another account unasked. The user can switch it on again.

The account is told apart by the identity iOS gives the app for the signed-in iCloud account. When iCloud reports an account change, sync switches off only if the account is now a different one, carries on if it is the same one, and waits if the phone is signed out. If the identity cannot be read in a usable form, the device counts as signed in to an account that never changes, and a change of account is then not noticed. Reading that identity on a signed-in device is still to be confirmed (see section 14).

**Libraries made before sync existed.** Every part of their songs and setlists gets one fixed early change time, the same on every device and earlier than any real change, so that any real edit or deletion wins over an untouched old copy. This matters when two phones hold the same songs because one was set up from the other's backup. Creation times start from that fixed time and keep the current order.

## 6. Metronome screen

One screen with two states, Ready (stopped) and Playing. The layout is identical in both, so nothing moves when Start is pressed. It is the same for every song, with a backing track or without, with Backing tracks on or off, and with nothing loaded; only the content of the player card at the bottom differs: **Metronome content** (6.7) for a song without a backing track, for every song while Backing tracks is off and with nothing loaded, and **Track content** (6.12) while a track is in use (section 4). Sync mode is a sheet over the screen while syncing (6.13). The dial, the tempo controls, the time signature row and the accent tiles look and work the same in both; while a track is in use they show and set the track's tempo (7.1).

From top to bottom, measured from the top of the safe area on the 390 × 844 pt design:

- the header (6.1), 48 pt: 8 pt, then its 40 pt row;
- 4 pt, then the dial (6.2), 264 pt;
- the **controls**: the tempo controls (6.3), 16 pt, the time signature row (6.4), 16 pt, and the accent tiles (6.5), 220 pt with one row of tiles and 250 pt with two. They are centred between the knob's lower edge and the player card, with the same space above and below them. The knob's lower edge is 0.9 dial diameters below the dial's top, so 26 pt above the bottom of the dial's square, which the ticks do not reach at the bottom (6.2);
- the player card (6.7), 188 pt, at the bottom of the safe area.

How the parts are fitted to other screens is in 6.8.

### 6.1 Header

**Song title**, at the left, taking the space left by the buttons. One or two lines; a long name is cut with an ellipsis. Line 1 is 20 pt heavy in dial white, followed by a small ˅. Line 2 is 13 pt in muted. Without a line 2, line 1 is centred vertically in the header.

| State | Line 1 | Line 2 |
|---|---|---|
| Nothing loaded | `Library` | `No song loaded` |
| Loaded on its own, as from the Songs tab | song name | none |
| Loaded from a setlist | song name | setlist name · `3 of 8` |

The title does not change when the loaded song is edited: unsaved changes are shown by the badge on the menu button (below) alone. So the setlist name stays in view while a song is being adjusted, and a title without a second line does not gain one and shift.

The title looks the same stopped and playing. Nothing is added in front of it while playing, so it does not move when Start is pressed; the dial, the tiles and the Stop button show that the metronome is running.

The buttons at the right, 8 pt apart, are the Backing tracks switch, the Sound button and the menu button, in that order. Each is a 40 pt circle that takes touches over 44 pt. The Backing tracks switch and the Sound button are **toggles** and look alike: a 20 pt icon drawn with 1.5 pt lines.

- On: a surface selected fill and the icon in dial white.
- Off: a surface fill, as the menu button's, and the icon in muted, drawn as off.

**Backing tracks switch**, shown only when the loaded song has a backing track, whether its file is on this device or not, between the title and the Sound button. Its icon is a music note: on, the note; off, the note struck through by a slash from its upper left to its lower right, with a gap in the note around the slash. It works only while stopped; while playing it is dimmed to 40 % and does nothing (7.12). A song without a backing track, and the screen with nothing loaded, have no switch, so their header is exactly as it would be without backing tracks. The switch is not in the settings sheet.

**Sound button**, always shown. Its icon is a speaker: on, while the click sounds, the speaker with two sound waves; off, while it is muted (7.5), the speaker with a small × in place of the waves. It works stopped and playing.

Neither toggle is ever amber, so the badge (below) is the only amber thing in the header.

**Menu button**, at the far right, aligned to the right margin: a 40 pt round button on a surface fill with a dial-white ⋯, like the library's menu buttons (8.1). It looks the same whatever the song's state. It is there in every mode, works stopped and playing, and opens the header menu (7.6), a standard iOS menu, with everything that is done to the loaded song as a whole and Settings.

**Badge**, on the menu button while the loaded song is edited (section 5), and so, while a track is in use, for a changed time signature or changed accents only: a 10 pt amber dot with a 2 pt ink ring, sitting on the button's top-right edge. It is the same on every phone. It fades in with the first change. It does not go away the instant the settings equal the saved ones again: it stays until the settings have rested there for half a second, so that turning the dial past the saved tempo does not make it blink out and in. Save changes, Revert, and loading or unloading a song take it away at once, with no fade, so that after Save changes or Revert only the menu's own closing animation is seen. Everything that can be done with unsaved changes is in the header menu; the title never changes what it does.

The header has only these buttons, so the title gets about 230 pt; with the Backing tracks switch shown, about 182 pt. Previous and Next are on the player card (6.7, 6.12).

Sync mode (6.13) is a sheet with its own title row; the header stays under it as it is, out of reach while the sheet is shown.

### 6.2 Tempo dial

The dial is 264 pt across in the design and never larger; on a short screen it shrinks (6.8). Its parts are measured below in a 300 pt square and scale with the dial, so on the 264 pt dial each measure is 88 % of the one given. It looks and works the same in every mode: it shows the tempo in effect (section 4), turns, and sets the tempo (7.1).

- 48 tick marks on a 270° arc that starts at the lower left (the 7:30 position), runs clockwise over the top and ends at the lower right (4:30), leaving a 90° gap at the bottom. Every fourth tick is longer and thicker.
- Ticks from the start of the arc up to the current tempo are amber; the rest are unlit, in the tick colour, which is light enough against the background (3 : 1) that the rest of the range can be seen. Position along the arc is linear: `(bpm − 30) / 270`.
- The ticks run from 146 pt out from the centre in to 134 pt (long ticks) or 138 pt (short ones).
- Inside them sits a **knob**, 120 pt in radius: a dark raised disc lit from the upper left, with a soft dark shadow below it (black at 70 %, 8 pt down with a 24 pt blur on the 264 pt dial) and a 1.5 pt outline in the line colour. Its colours darken from the light towards the lower right: the ridged edge runs from about `#1F1F23` at the upper left to `#0D0D0E` at the lower right, and the face from `#151518` to `#131316`. They are the colours of a disc shaded from `#2C2C31` at the top to `#141416` at the bottom, with a face shaded from `#1D1D21` to `#202024`, under a round shade of black that is 18 % at the point 35 % across and 28 % down the knob and grows evenly to 50 % at the farthest corner of the knob's square. Along its upper edge runs a thin highlight, a 1 pt line of white at 10 %, and inside its lower edge a soft shadow, black at 35 %, 10 pt up from the edge with an 18 pt blur on the 264 pt dial, so the knob keeps its depth. The edge carries 90 ridges, 10 pt long, in dial white at 5 % to 16 % opacity, brighter towards the top, so the grip still shows under the light. The face is 104 pt in radius and covers the rest.
- An amber **pointer**, a 5 pt line with round ends from 102 pt to 112 pt out, on the knob's ridged rim, clear of the number, with a soft amber glow, points at the tempo, where the lit ticks end. It is drawn over the knob's shading at full amber. The knob, its ridges and its pointer turn together as the tempo changes.
- On the face: the BPM number alone, 92 pt on the 264 pt dial, two digits and three alike, heavy, digits set slightly tight, dial white, with no `BPM` label and no tempo name. At that size the widest three-digit number stays clear of the pointer at every tempo.
- Tapping the number opens the tempo sheet (6.11). Turning anywhere on the dial changes the tempo (7.1).

The gap at the bottom of the scale holds nothing; the knob's lower edge shows through it, and it is the lowest part of the dial.

### 6.3 Tempo controls

A 60 pt row of three that spans the screen between the side margins: − (60 pt round), `Tap tempo` (an outlined pill with a hand icon) and + (60 pt round). The pill fills the space between the round buttons, 12 pt from each, so the row lines up with the time signature row and the tiles below it. On a small screen the row can drop to 48 pt, the round buttons with it (6.8). It looks and works the same in every mode; while a track is in use it sets the track's tempo (7.1).

While a tap tempo series is open, from a tap until 2 seconds after the last one, the pill's outline is amber (1.5 pt) and its label reads `Tap again`. The pill keeps its width when the label changes.

### 6.4 Time signature row

A 60 pt row, 16 pt below the tempo controls, with 18 pt corners on a surface fill: the label `Time signature`, the current value in amber (for example `4/4`), and a › chevron. Tapping it opens the picker (6.6). It looks and behaves the same when stopped and when playing, and in every mode. On a small screen it can drop to 48 pt and the gap above it to 10 pt (6.8).

### 6.5 Accents

One tile per beat, 16 pt below the time signature row, with no heading: the tiles are plainly the beats. They sit in a single row with 10 pt gaps, each 68 pt tall with a 20 pt corner radius and a 28 pt number. Each tile shows only its beat number, centred; the fill, border and weight of the number tell an accent apart. On a small screen single-row tiles can drop to 56 pt, with a 22 pt number, and the gap above them to 10 pt (6.8).

| Tile state | Fill | Border | Number |
|---|---|---|---|
| Not accented, idle | surface | none | muted dim, semibold |
| Accented, idle | dark amber tint | 1.5 pt amber | amber, heavy |
| Not accented, sounding | dial white | none | ink, semibold |
| Accented, sounding | amber, with amber glow | none | ink, heavy |

"Sounding" applies only while playing, to the tile of the current beat. A sounding tile follows the beat as it was scheduled, so it always agrees with the click and the haptic.

Up to seven tiles fit in one row. For 9/8 and 12/8 the tiles wrap into two equal rows (5 + 4, and 6 + 6) and the tile height drops to 44 pt, with a smaller number.

### 6.6 Time signature picker

A bottom sheet over a dimmed screen, sized to its content: a grabber, the title `Time signature`, and a 4 × 2 grid of options, each 84 pt tall. Each option shows only the signature (30 pt, bold; heavy when selected), in this order: 2/4, 3/4, 4/4, 5/4, 6/8, 7/8, 9/8, 12/8. VoiceOver still reads a one-word hint with each (March, Waltz, Common, Odd, Compound, Odd, Compound, Compound).

The current signature is filled amber with a glow.

### 6.7 Player card

The **player card** sits at the bottom of the safe area, between the side margins: a surface card with 28 pt corners, 188 pt tall in every mode and on every phone, with 12 pt inner padding at the top, 18 pt at the bottom and 16 pt at the sides. It holds Metronome content, below, or Track content while a track is in use (6.12). Both end in a 68 pt transport row with Start / Stop at its centre and Previous and Next at its ends, so song changes stay under the thumb, next to Start. The card's size and place never change, between Ready and Playing, between the two contents or from song to song, so nothing moves when Start is pressed. The metronome screen has no next-up line in any mode.

**Metronome content**, from top to bottom:

- **Readout**, in the 82 pt above the transport row: the elapsed time at the left and the bar count at the right, each centred vertically in that space and 26 pt in from the card's edges. The elapsed time is 34 pt medium, set slightly tight, with digits of equal width, in dial white: `0:00`, `3:07`, and from an hour on `1:02:07`. The bar count is `Bar` and the bar's number, 15 pt medium in muted, with digits of equal width: `Bar 1`, `Bar 128`. What they count is in 7.13. They are not buttons.
- **Transport row**, 68 pt tall, 8 pt below the readout, across the card's inner width: Previous, the Start / Stop pill and Next, 12 pt apart.
  - **Start / Stop** is a 68 pt fully rounded pill that takes the width left, 198 pt in the design. Stopped: amber fill, an ink play icon (20 pt) and 12 pt after it `Start` (18 pt bold, set slightly tight) in ink, and a soft amber glow (amber at 28 % with a 40 pt blur). Playing: surface fill, a 1.5 pt amber outline, an amber stop icon and `Stop` in amber, and no glow. Everything 7.4 says of Start and Stop applies to it.
  - **Previous** and **Next** are 44 pt buttons with no fill: a dial-white arrow against a bar (20 pt), pointing back and forward, as on Track content (6.12). They are Previous and Next of 7.6 and are shown only when the song was loaded from a setlist. A dimmed one is drawn at 40 % opacity.
  - For a song not loaded from a setlist, and with nothing loaded, Previous and Next are not shown. Their places stay empty, and the pill keeps its width and its place at the centre of the row.

### 6.8 Small screens

The design is drawn for a 390 × 844 pt screen. The layout is the same in every mode, so the dial, the controls and the player card have the same place and size whatever the card holds, on every phone. Heights here are inside the safe area; phones without a home indicator first keep a 16 pt margin below the card.

The fixed parts are the header with the 4 pt below it, 52 pt, and the player card, 188 pt, which never shrinks. The height between them holds the dial down to the knob's lower edge, 0.9 dial diameters (6.2), the controls, 220 pt or 250 pt with two rows of tiles (section 6), and the two equal gaps above and below the controls.

The dial is 264 pt and never larger, so on a taller screen the spare height goes to the two gaps, evenly. On a shorter screen the layout adapts in this order and stops as soon as everything fits:

1. The two gaps shrink, down to 16 pt each.
2. The dial shrinks, down to 200 pt.
3. The controls become compact: the tempo controls and the time signature row drop to 48 pt, the gaps above the row and above the tiles to 10 pt, and single-row accent tiles to 56 pt with a 22 pt number; two rows keep their 44 pt tiles. That makes the controls 172 pt, or 214 pt with two rows. The two gaps can then go down to 10 pt each, and the dial takes the height left, up to 264 pt.
4. The dial shrinks further, as far as it needs to. The screen never scrolls.

The dial's diameter is a whole number of points, rounded down, and the two gaps share what is left.

An iPhone 17 Pro, with 778 pt inside the safe areas, gets the 264 pt dial with gaps of 40 pt, or 25 pt in 9/8 and 12/8. A 390 × 844 pt iPhone, with 763 pt, gets 264 pt with gaps of 32 pt, or 17 pt with two rows. An iPhone SE, with 631 pt once its 16 pt bottom margin is taken, is compact: its dial is 221 pt, or 174 pt in 9/8 and 12/8. An iPhone SE with Display Zoom (320 × 568 pt), with 532 pt, gets 111 pt, or 64 pt in 9/8 and 12/8.

On a small dial the knob, its ridges, its shading and the number scale with the dial like everything else in it.

On screens narrower than 360 pt the side margins drop from 24 pt to 16 pt. The dial is never wider than the space between them.

When accent tiles are narrower than 44 pt (seven beats in a row), each tile's touch area extends into the gaps on either side so that it is at least 44 pt wide. The tile is drawn at its normal size.

### 6.9 Colours

| Token | Value | Use |
|---|---|---|
| ink | `#0B0B0C` | background; text on amber and white, except a swipe button's title, which the system draws white (8.3) |
| surface | `#17171A` | rows, round buttons, the header's toggles when off, idle tiles, sheets, the player card, select mode's action bar, stage mode's unmarked tiles |
| surface raised | `#222226` | picker options, fields, rows and idle tiles inside sheets; the library's header ⋯ buttons and select mode's action pills; Rewind, Fast-forward, the Sync pill and `Choose file` on the player card; Sync mode's stepper pills, count-in options and playback card |
| surface selected | `#3A3A3F` | the selected segment of a switch-like control, and buttons that sit on surface raised: the library's selected tab, the Sound button and the Backing tracks switch when on, the selected count-in option, and in Sync mode the steppers' − and +, Rewind and Fast-forward on the playback card and the unplayed part of its progress line, and the empty selection ring on the Add song screen, for a song not in the setlist, and in select mode, for a song not ticked |
| line | `#2A2A2E` | outlines, dividers, the line of the player card's progress bar and the mix slider |
| tick | `#606066` | unlit ticks on the dial; the centre mark of the mix slider |
| dial white | `#F3EEE6` | primary text; sounding unaccented tile |
| muted | `#8A8780` | labels, secondary text, the bar count, the icons of the header's toggles when off |
| muted dim | `#6B6963` | large text only (18 pt and up, or 14 pt bold and up): idle unaccented tile numbers, position numbers, the numbers on stage mode's unmarked tiles, the placeholders of the tempo sheet and a new setlist's name; the `Syncing…` dot and the › on the Setlists tab's rows |
| amber | `#FFB224` | the single accent colour |
| amber tint | `#1E1A12` | idle accented tile fill, Sync mode's tap pads, stage mode's active and playing tiles |
| red | `#E5484D` | delete actions only |
| green | `#4CC38A` | confirmations only: the sync status dot when up to date |

### 6.10 Settings sheet

A bottom sheet over a dimmed screen, styled like the New song sheet: a grabber, the title `Settings` (26 pt heavy, dial white) and `Done` in amber at the right. It is sized to its content up to the full height of the screen; when the content is taller, as it is on most phones, the cards scroll under the title.

**Click sound** is one surface-raised card with 16 pt corners:

- A header line: `CLICK SOUND` (13 pt, semibold, capitals, wide letter spacing, muted). Tapping a sound plays it, so nothing says so.
- One 44 pt row per sound, in this order: Digital, Soft beep, Woodblock, Mallet, Glass, Tick, Pendulum. Each row shows only the name (16 pt, dial white). Thin line-coloured dividers separate the rows; they are inset 16 pt from both edges of the card.
- The selected sound's name is amber and semibold, with an amber tick at the right. The tick has a fixed slot, so names line up in every row.

Below the card: `Set the click volume with your phone's volume buttons.` (13 pt, muted).

The cards and lines are 10 pt apart, and each line below a card keeps 8 pt below it, so a card that follows a line is 18 pt below it. Only the volume and iCloud have a line below their cards; the switches' names say what they do.

**Haptic feedback** and **Keep screen awake** are two surface-raised cards with 16 pt corners and no header, 10 pt apart, so they read as a pair. Each holds one 44 pt row: the name (16 pt, dial white) and, at the right, a standard iOS switch tinted amber when on.

**iCloud** is a last surface-raised card with 16 pt corners, 18 pt below Keep screen awake, so it stands as its own group:

- The same header line style: `ICLOUD`, with nothing at the right.
- One 44 pt row: `Sync songs and setlists` (16 pt, dial white) and, at the right, a standard iOS switch tinted amber when on.
- While the switch is on, a second 44 pt row inside the card, the **status line**, under a divider inset 16 pt from both edges: an 8 pt dot, the status (15 pt) and, at the right, a detail (13 pt, muted). While the switch is off there is no status line.

| Status | Dot | Text | Detail |
|---|---|---|---|
| Just switched on | muted dim | `Syncing…` in muted | none |
| Working | green | `Up to date` in dial white | `Last synced 14:32`, or a date such as `Last synced 9 Nov` when it was not today; none before the first exchange |
| No iCloud account | amber | `Not signed in to iCloud` in amber | none |
| iCloud full | amber | `iCloud storage is full` in amber | none |
| Newer format in iCloud | amber | `Update the app to keep syncing` in amber | none |

Below the card, one line (13 pt, muted) that depends on the state:

- Off, syncing or up to date: `Keeps your data the same on every device signed in to your iCloud account.`
- Not signed in: `Sign in to iCloud in the Settings app to sync.`
- iCloud full: `Delete songs or setlists you no longer need to make room.`
- Newer format: `Another of your devices has a newer version of the app.`

The status line is the device's own view. iCloud does not tell the app when a change has reached the server, so `Last synced` is the time the device last handed a change to iCloud or received one, and there is no separate status for being offline.

New settings are added as further rows or cards in the same sheet.

### 6.11 Tempo sheet

A bottom sheet over a dimmed screen, sized to its content, opened by tapping the BPM number on the dial (6.2), the tempo value in Sync mode (6.13) or the tempo in the song sheet (section 10). From the dial, Set tempo sets the tempo the dial shows: the metronome's tempo, or while a track is in use the track's (7.1); from Sync mode, the track's tempo; from the song sheet, only the sheet's. Opened from the dial while a track is in use, or from Sync mode, it shows the track's tempo as the current one. From top to bottom:

- A grabber, the title `Tempo` (26 pt heavy, dial white) and, at the right, the range `30 to 300 BPM` (13 pt, muted).
- **The field:** a 92 pt tall surface-raised card with 20 pt corners and a 1.5 pt amber outline. It shows the typed digits (64 pt, heavy, dial white), an amber caret and `BPM` in amber. Before the first key it shows the current tempo in muted dim, as a reminder of where the tempo is now.
- **The keys:** the digits 1 to 9 in three rows of three, then a last row with an empty place, 0 and a delete key. Each key is 54 pt tall with 8 pt gaps; digit keys are surface raised with 16 pt corners and a 26 pt bold digit, and the delete key is an icon with no fill. The sheet has its own keys, not the system keyboard, so they are large, match the app and appear with the sheet.
- **Cancel and Set tempo:** a row of two 56 pt pills, 16 pt below the keys, on the keys' columns. **Cancel** is as wide as one key, under the empty place: `Cancel` (17 pt, bold, dial white) with a 1 pt outline in the line colour and no fill. It is always enabled and closes the sheet without changes. **Set tempo** spans the other two columns, under 0 and the delete key, 8 pt from Cancel: amber with ink text (17 pt, bold) when the digits are a tempo from 30 to 300; otherwise surface raised with muted text, not ready, like the song sheet's save button (section 10), and it does nothing.

### 6.12 Track content

While a track is in use (section 4), Backing tracks on and the loaded song with a backing track, the player card (6.7) holds Track content, for playing along with the track. Everything else on the screen is as for any other song: the header with the Backing tracks switch on, the dial showing and setting the track's tempo, the tempo controls, the time signature row and the accent tiles (7.1 to 7.3). With Backing tracks off the same song has Metronome content, with the switch in its header as the only sign of the track. Like the rest of the screen, Track content is identical stopped and playing. Its rows are 10 pt apart in the card's 188 pt: 12 pt padding, the file-name row, the progress bar, the transport row and 18 pt padding. From top to bottom:

- **File-name row**, 30 pt tall: a 16 pt music-note icon in muted; 8 pt after it the file name (14 pt medium, dial white), which takes the space left and is cut with an ellipsis; and at the row's right end, 8 pt after the name, the **Sync** pill. The pill is fully rounded, on surface raised, 30 pt tall, the row's height, with 14 pt padding at the sides and `Sync` (13 pt semibold, dial white); its touch area is at least 44 pt tall. It opens Sync mode (6.13), stopped or playing, and is the only way there. With the file missing, `Choose file` stands in its place and there is no Sync pill (Missing file, below), so the row always ends in exactly one pill.
- **Progress bar**, 40 pt tall, across the card's full inner width: a 22 pt band holding the line and its knob, and 2 pt below it the times. The line is 4 pt in the line colour, its played part amber, with a 14 pt dial-white knob at the position. Below it are the elapsed time at the left and the file's length at the right (13 pt, muted, digits of equal width), as `m:ss`; the minutes keep counting past 59. Whenever the file is playing, the knob and the elapsed time show its real position. While the count-in's click sounds alone, before the file has started (7.10), the knob is at the start and the elapsed time reads `Count-in` in amber.
- **Transport row**, 68 pt tall, five buttons spread evenly across the inner width, the outer two at its edges: Previous song, Rewind, play / stop, Fast-forward and Next song.
  - **Play / stop** is a 68 pt circle with a symbol and no word. Stopped: amber fill, an ink play symbol (26 pt), set 2 pt right of centre so that the triangle looks centred, and a soft amber glow. Playing: surface fill, a 1.5 pt amber outline, an amber stop symbol (22 pt), centred, and no glow. It is Track content's Start / Stop: everything 7.4 and 7.10 say of Start and Stop applies to it.
  - **Rewind** and **Fast-forward** are 44 pt round buttons on surface raised with a double ‹ and a double › chevron.
  - **Previous song** and **Next song** are 44 pt buttons with no fill: a dial-white arrow against a bar (20 pt), pointing back and forward (SF Symbols `backward.end` and `forward.end`), as Previous and Next are in Metronome content (6.7). They are shown only when the song was loaded from a setlist, and they are Previous and Next of 7.6: every rule there applies to them unchanged.
  - For a song not loaded from a setlist, Previous song and Next song are not shown. Rewind, play / stop and Fast-forward keep their places, so the three stand centred in the row.
  - A dimmed button on the card, whether Previous song, Next song, Rewind or Fast-forward, is drawn at 40 % opacity.

Track content shows no elapsed time or bar count of its own: the progress bar's times are the track's (7.13).

**Missing file.** When the song has a backing track but its file is not on this device (5.1), the card offers the fix in its file-name row. The row holds the music-note icon as usual; then the name of the file the track expects, the name the track carries, in amber, on one line cut with an ellipsis, taking the space left; and at the row's right end, 8 pt after the name, the **Choose file** button in place of the Sync pill, as Sync needs the file. The amber name and the button say that the file is missing, so the card does not show `Track missing`. The button is a fully rounded pill on surface raised, 30 pt tall, the row's height, with 12 pt padding at the sides and `Choose file` (13 pt semibold, dial white); its touch area is at least 44 pt tall. It is the only control the missing state changes on the card, and nothing else on the card moves or changes size.

`Choose file` opens the Files picker for audio files, stopped or playing, as the song sheet's Backing track row does for a missing track (10.3). The picked file is stored at once, with no sheet and no save step, by the rule for a file picked for a missing track (5.1, 10.3): under the identifier the track already has, with the track keeping its tempo, offset, count-in and mix. When the picked file's name is the same as the name the track carries, nothing about the track changes and nothing is sent to other devices. When it differs, the track takes the picked file's name, and the backing track syncs with it. The song does not become edited. While playing, playback stops and the position is 0:00 (7.10). The card then shows its usual state: the picked file's name in dial white and the Sync pill, with the bar, Rewind and Fast-forward working, and the pill opens Sync mode. Closing the picker without choosing changes nothing. A file that cannot be read as audio changes nothing, and an alert says `This file can't be played`, with `OK`. A file that cannot be kept on the device, for example because the phone is full, changes nothing, and an alert says `The track couldn't be saved`, with `OK`.

Until a file is picked, the progress bar, Rewind and Fast-forward are dimmed and do nothing, and the times are not shown. Play / stop, Previous song and Next song work as usual; Start plays the click alone at the track's tempo (7.10), and the dial's number marks its beats. The dial, the tempo controls and the time signature row work as with the file here, on the track's tempo (7.1). The rest of the layout is the same.

### 6.13 Sync mode

Sync mode is for lining the click up with the track while a track is in use. It is shown as a sheet: the Sync pill in the player card's Track content (6.12) slides it up over the metronome screen, stopped or playing, at full height only (the system's large sheet, with no smaller resting height). Like the library and settings sheets it has the grabber at its top and 28 pt corners. Its background is surface, as the library, song, tempo and settings sheets' is, and its parts sit one step lighter, on surface raised, so that they stand out against it. The metronome screen stays under it unchanged. `Done`, or a swipe down on the grabber or the top of the sheet, closes it (7.11). A touch on a pad, a stepper or the mix slider acts on that control; where the middle scrolls (below), a drag there scrolls it. It has the same layout stopped and playing. Its side margins are those of the metronome screen (6.8). From top to bottom:

- **Title row**, 78 pt from the sheet's top edge, 28 pt of it room for the grabber: at the left the title `Sync`, set as the other sheets' titles (26 pt heavy, dial white), and 2 pt below it the file name (13 pt medium, muted, one line, cut with an ellipsis). At the right, 16 pt from the title, `Done` (17 pt semibold, amber), with a touch area of at least 44 × 44 pt.
- **Time signature row**, 16 pt below the header: the metronome screen's full-width `Time signature` row of 6.4, on surface raised as in the song sheet (section 10), opening the same picker (6.6).
- **Accent tiles**, 14 pt below the row, as in 6.5 but 76 pt tall in a single row, working as everywhere (7.3), with the idle unaccented tiles on surface raised as in the song sheet.
- **Tap pads**, 14 pt below the tiles: **Tap tempo** and **Tap on beat 1** side by side, 10 pt apart, sharing the width equally like the steppers below them, so each stands above the stepper it feeds: Tap tempo above Tempo, Tap on beat 1 above Offset. Together they take the height left over by the other parts. Each is an area with 24 pt corners, the amber tint fill and a 1.5 pt amber outline. Centred in each, 8 pt apart: a 26 pt hand icon in amber and the title (20 pt heavy, dial white, one line, scaled down when the pad is too narrow for it), `Tap tempo` and `Tap on beat 1`. While a tap tempo series is open (7.11) Tap tempo's title reads `Tap again`, as the metronome screen's pill does (6.3). A touch anywhere on a pad is a tap on it (7.11). Tap tempo is never dimmed; while Tap on beat 1 does nothing it is drawn at 40 % opacity.
- **Tempo and Offset**, 14 pt below the pads: two steppers side by side, 10 pt apart, sharing the width equally. Each has a label (11 pt semibold, capitals, wide letter spacing, muted), `TEMPO` and `OFFSET`, and 6 pt below it a 48 pt fully rounded surface-raised pill with 4 pt padding holding − (40 pt round, surface selected, an 18 pt symbol), the value centred between them (22 pt heavy, dial white, digits of equal width) and + built like −. Tempo shows the track's tempo, for example `168`, with no unit; tapping the value opens the tempo sheet (6.11). Offset shows seconds with two decimals, for example `0.48`, followed 3 pt after by `s` (12 pt semibold, amber).
- **Count-in**, 14 pt below the steppers: a 40 pt row with the label `COUNT-IN`, in the same style in a 76 pt column, and 12 pt after it the three options `Off`, `1 bar` and `2 bars`, sharing the rest of the row 6 pt apart. Each is 40 pt tall with 14 pt corners on surface raised, showing its name (14 pt semibold, dial white). The selected one is filled surface selected; nothing in the row is amber.
- **Mix**, 10 pt below the count-in: a 32 pt row with the label `MIX` in the same 76 pt column and, 12 pt apart, `Click` (13 pt medium, dial white), the **mix slider**, which takes the width left over, and `Track`. The slider is a 22 pt band holding a 4 pt line in the line colour, which shows against the sheet's surface, a 2 × 12 pt mark at its centre in the tick colour, and a 14 pt dial-white knob. The part of the line between the centre and the knob is amber, so with the knob at the centre nothing is amber. The knob's touch area is at least 44 × 44 pt.
- **Playback card**, pinned to the bottom where the player card is (6.7) and at least 16 pt below the mix row: a surface-raised card with 28 pt corners, 136 pt tall, with 12 pt padding at the top, 14 pt at the bottom and 16 pt at the sides. It holds the progress bar (40 pt), as on the player card except that the unplayed part of its line is surface selected, as the line colour would not show on surface raised, and 14 pt below it the 56 pt transport row: five buttons spread evenly across the inner width, the outer two at its edges.
  - **To the beginning** and **To the end** are 44 pt buttons with no fill, with the dial-white arrow against a bar (20 pt) that Previous song and Next song have on the player card, pointing back and forward.
  - **Rewind** and **Fast-forward** are as on the player card, but on surface selected.
  - **Play / stop** is a 56 pt amber circle with no glow: an ink play symbol when stopped, and an ink stop square (20 pt, 5 pt corners) while playing.
  - A dimmed button is drawn at 40 % opacity.
  - The card has no file-name row, as the file name is in the header, and no Previous song or Next song.

**Small screens.** The sizes below are measured in the sheet's content, from its top edge to the bottom of the screen less the bottom safe area. Without the tap pads, the parts take 590 pt: the title row 78, 16, the time signature row 60, 14, the tiles 76, 14 above and 14 below the pads, the steppers 70, 14, count-in and mix 82, 16 and the playback card 136. Phones without a home indicator get a 16 pt margin below the card. The pads take the rest of the height, down to 72 pt. When it would be less, single-row accent tiles drop to 56 pt tall with a 22 pt number, as in 6.8. If the pads would still be less than 72 pt, they are 72 pt and the part between the title row and the playback card scrolls; the title row and the card stay in place. On pads shorter than 120 pt the hand icon is left out, and the title stays centred.

On an iPhone 17 Pro the sheet's content is 778 pt above the home indicator, which gives the pads 188 pt, or 166 pt in 9/8 and 12/8, with no scrolling. On an iPhone SE the content is 637 pt, 621 pt once its 16 pt bottom margin is taken: 76 pt tiles would leave 31 pt and 56 pt tiles 51 pt, so the tiles are 56 pt, the pads 72 pt, and the area scrolls by 21 pt; in 9/8 and 12/8 the pads would get 9 pt, so they are 72 pt and the area scrolls by 63 pt. With Display Zoom the sheet's height has not been measured; the same rule applies to whatever it is.

## 7. Metronome behaviour

### 7.1 Tempo

All four ways of setting the tempo work when stopped and when playing, and the same in every mode. They set the tempo the dial shows, the tempo in effect (section 4):

- While no track is in use, the metronome's tempo. Save changes saves it into the loaded song and Revert sets it back (7.6).
- While a track is in use, the track's tempo, whether its file is here or not, exactly as Sync mode's − / +, typing and Tap tempo set it (7.11): it stays within 30…300, applies at once, and while playing the click follows the track's grid at the new tempo (7.10). It is saved into the song at once, so it never brings up the badge, and Save changes and Revert leave it as it is (section 5, 7.6). The metronome's tempo is not changed. The track's file always plays at its own speed, so a tempo that does not match the file puts the click out of step with the music until it is set right; Sync mode's Tap tempo and Tap on beat 1 are the way to line them up by ear.

The four ways:

- **Dial.** The dial turns like a real knob: a finger put down anywhere on it, on the number, the knob's edge or the ticks, and moved around the centre turns the knob with it. The tempo changes by the angle the finger travels around the dial centre, 270° for the whole range (1 BPM per degree), rounded to whole BPM. Where the turn begins makes no difference.
  - The tempo never jumps to where the finger lands. A touch that does not move changes nothing, and the turn begins only after the finger has moved 4 pt, so a tap still opens the tempo sheet and a brush against the dial is ignored.
  - The tempo stops at 30 and 300. Turning back from an end takes effect at once.
  - Touches that begin within 0.55 dial diameters of the centre (165 pt on the 300 pt dial) start a turn.
  - **Dead zone:** within 0.1 dial diameters of the centre (30 pt on the 300 pt dial), the finger's angle is ignored, because there a tiny movement swings it a long way. A finger passing through it changes nothing; once it comes out, the turn carries on from there without a jump.
- **Typing.** Tapping the number opens the tempo sheet (6.11).
  - A digit key adds a digit, up to three; a leading zero is ignored. The delete key removes the last digit.
  - `Set tempo` sets the tempo and closes the sheet. It is not ready until the digits are a tempo from 30 to 300 (6.11).
  - When the digits are above 300, the range at the top right turns amber.
  - `Cancel`, swiping the sheet down or tapping outside it closes it without changes. Nothing changes before `Set tempo`.
- **− / +.** One tap changes the tempo by 1 BPM. Holding repeats: after 400 ms, 10 steps per second. The repeat ends the moment the finger lifts, however quickly taps follow each other.
- **Tap tempo.** From the second tap on, the tempo is set to the average of the last four intervals between taps (fewer if fewer exist). A pause longer than 2 seconds starts a new series. While a series is open the pill reads `Tap again` (6.3), so the first tap, which cannot set a tempo yet, is still seen to register. The pill's series is its own, apart from Sync mode's Tap tempo (7.11).
- All inputs clamp to 30…300.
- While playing, a tempo change takes effect from the next beat. The beat that is already scheduled is not moved, and the bar position is kept. With a playable track in use the beats follow the track instead (7.10).

### 7.2 Time signature

- Tapping the row, on the metronome screen in every mode or in Sync mode (6.13), opens the picker. Tapping an option selects it and closes the sheet.
- On the metronome screen choosing another signature is a change to the loaded song like any other, also while a track is in use: it brings up the badge and is saved with Save changes or set back with Revert (7.6), as the accents are. In Sync mode it is saved into the song at once (7.11).
- Swiping the sheet down or tapping outside it closes it without changes.
- Choosing a different signature resets the accents to beat 1 only.
- While playing, the metronome keeps playing: the next beat is beat 1 of a new bar in the new signature. With a playable track in use the bar follows the track instead (7.10).
- Choosing the signature that is already selected changes nothing.

### 7.3 Accents

- Tapping a tile toggles that beat's accent. This works when stopped and when playing.
- Any combination is allowed, including all beats and no beats.
- While playing, a toggle changes the tile's idle appearance at once. The click, effect and haptic for that beat change the next time the beat is scheduled; a beat that is already scheduled is not altered.

### 7.4 Start and stop

- Start begins playback on beat 1, with the first click straight away. With a playable track in use, it starts with the count-in, or from the track's position, as in 7.10.
- Stop silences playback at once, clears the current beat and returns every tile to its idle appearance. A track in use stops with it and keeps its position (7.10).
- Start and Stop are the player card's Start / Stop pill in Metronome content (6.7), its play / stop button in Track content (6.12), and in Sync mode the playback card's play / stop (7.11).
- The screen does not dim or lock while playing, nor while stage mode is shown (9.4). With Keep screen awake on (7.8), it does not dim or lock while stopped either.

### 7.5 Mute

- Tapping the Sound button (6.1) silences the click at once, including clicks that are already scheduled, or brings it back. Off, the click is muted; on, it sounds. It silences only the click, completely, whatever the backing track's mix: the track keeps playing.
- The metronome keeps running: the glow and the number pulse on the dial, the tile lighting, the elapsed time and bar count (7.13) and the haptics carry on.
- Sync mode has no Sound button; the click stays muted or not as it was when Sync mode was entered. Stage mode has none either, and the same holds there (9.4).
- It works when stopped and when playing.
- Mute is separate from the phone's volume and is not remembered between launches.

### 7.6 Songs on the metronome screen

**Loading** a song applies its tempo, time signature and accents to the metronome. It happens from the library and from Previous / Next. While the loaded song's track is in use, the click plays at the track's tempo instead of the song's (section 4).

- Unsaved edits to the previously loaded song are dropped without asking.
- When stopped, the metronome stays stopped.
- When playing, it keeps playing: the next beat is beat 1 of a new bar with the new settings. With Backing tracks on, when the song being left or the song being loaded has a playable backing track, playback stops instead (7.10).
- Loading a song never changes the Backing tracks switch (7.12).
- The loaded song's backing track, if it has one, is at 0:00.
- The song's last-played time is set (8.6).
- The elapsed time and the bar count start again (7.13).
- Where the song is tapped decides its loaded-from setlist. Tapped in a setlist's view, it is loaded from that setlist, so the header shows the setlist and the position, and Previous / Next are shown (8.3). Tapped on the Songs tab, it is loaded on its own, whatever setlist was being stepped through, even one that holds it: the header shows the name alone, and Previous / Next go (8.2). Previous and Next load from their setlist (below).
- Tapping the loaded song's own row in the library is not a load. Nothing on the metronome changes, playing or stopped: playback carries on without a new bar, the track keeps its position, the tempo, time signature and accents stay as they are, and unsaved edits are kept; Revert is how they are dropped. The last-played time stays as it is. Only the loaded-from setlist follows the tap, by the same rule as a load: tapped on the Songs tab, a song loaded from a setlist is then loaded on its own, and tapped in a setlist's view, it is then loaded from that setlist (8.2, 8.3).

**Tapping the title** always opens the library sheet (section 8), edited or not. Unsaved edits are kept while the library is open.

**The header menu** opens from the menu button (6.1), the system menu, stopped or playing, in every mode. Tapping outside it closes it. Its items, from the top, in groups separated by dividers:

- Only while the loaded song is edited: **Save changes** and **Revert**.
- **Edit song** and **Add to setlist** while a song is loaded, with **Save as new song**, always shown, between them.
- Only while a song is loaded: **Unload**.
- Only while the loaded song was loaded from a setlist: **Stage mode**.
- Always: **Settings**.

With nothing loaded the menu is just Save as new song and Settings.

- **Save changes** writes the current settings into the loaded song. The menu closes and the badge goes away at once, with a success haptic (6.1). There is no separate message.
- **Revert**, with the saved song's tempo and time signature on a second, smaller line, for example `120 BPM · 4/4`, so that it is clear what comes back. It sets the metronome back to the song's tempo, time signature and accents, with a selection tick.
  - While playing, the bar carries on when only the tempo or the accents go back, as with any other change of tempo or accents (7.1, 7.3). When the time signature goes back, the next beat is beat 1 of a new bar (7.2).
  - There is no confirmation and no undo.
- **Edit song** opens the Edit song sheet (10.2) for the loaded song.
- **Save as new song** opens the New song sheet (10.1) filled with the current settings, without a backing track, whether a song is loaded or not, edited or not. When the loaded song has a loaded-from setlist, the sheet shows the Add to <setlist> switch for that setlist, on by default (section 10). After saving, the new song is the loaded one, and the song that was loaded is left as it was, its backing track included. With the switch on, the new song is added to the end of that setlist and loaded from it, so the header shows the setlist and the new position, and Previous / Next stay. With the switch off, or with no switch, it is loaded on its own, and Previous / Next go. With Backing tracks on, when the song that was loaded or the new one has a playable backing track (7.10) and the metronome is playing, playback stops, as when another song is loaded.
- **Add to setlist** opens the same second level as in the row menu (8.4), acting on the loaded song: every setlist, with a tick when the song is in it, and New setlist. Taking the song out of a setlist here shows no Undo bar, as there is no library sheet to show it; ticking it again puts it back, at the end. New setlist opens the library sheet inside the new setlist, ready for naming (9.2).
- **Unload** unloads the song, so that nothing is loaded. The tempo, time signature and accents stay as they are, playing or stopped, and the click does not change. The song itself is not changed; unsaved edits stay as plain settings. Previous / Next go and the header shows the "nothing loaded" state. The elapsed time and the bar count start again (7.13). When the song has a backing track, the Backing tracks switch goes away from the header, and with the switch on the player card goes back to Metronome content and the dial to the metronome's tempo. If the track was in use, playable (7.10) and playing, playback stops.
- **Stage mode** opens stage mode (9.4) for the loaded-from setlist. While the metronome is playing it is dimmed and does nothing.
- **Settings** opens the settings sheet (6.10).

While a track is in use the badge is shown for a changed time signature or changed accents only (section 5), but the menu is the same: Save changes writes, and Revert sets back, the metronome's tempo too when it differs. The track's tempo is never part of it, as a change of it is saved at once (7.1).

Saving takes two taps, menu button and menu item, as it is a deliberate choice made between songs, and the menu keeps Revert in plain sight beside it. Everything else that is done to the loaded song as a whole is in the same menu, so the header needs no other button for it.

Edits also go away without Save changes or Revert: loading another song, with Previous / Next, from the library or with a tile in stage mode (9.4), drops them without asking, and Unload keeps them as plain settings.

**Previous and Next** load the previous or next song in the loaded-from setlist's order.

- At the first song Previous is dimmed and does nothing; at the last, Next. They do not wrap around.
- They work when stopped and when playing.
- They are on the player card, in both contents (6.7, 6.12).

### 7.7 Interruptions and volume

- Playback stops when the app leaves the foreground, when the screen is locked, and on audio interruptions such as a phone call. It does not resume by itself. A backing track keeps its position, as with Stop. Stage mode stays shown, with its tile stopped (9.4).
- Playback stops if the audio output goes away, for example when headphones are unplugged. The screen never shows Playing while nothing can sound.
- The click plays even when the ring/silent switch is on silent, as a metronome is the app's whole purpose. Other audio is paused while the metronome plays.
- The click volume is set with the phone's regular volume controls: the side buttons and the Control Center slider. With a backing track the same controls set the overall level of click and track together; the mix (section 4) sets how loud they are against each other. The click is ordinary media audio and the app never overrides the system volume. If "Change with Buttons" is on in the phone's sound settings, the side buttons adjust the ringer while nothing is playing; that is system behaviour.

### 7.8 Settings and click sound

- Settings in the header menu (7.6) opens the settings sheet, when stopped and when playing. `Done`, swiping the sheet down or tapping outside it closes it.
- Tapping a sound selects it at once, with a selection haptic. There is no confirm step; closing the sheet keeps the choice.
- **When stopped**, tapping a sound, including the one already selected, also plays a preview: an accented click and then a normal click, 0.5 s apart. The preview plays even when muted, because the user asked to hear it. A new tap during a preview cuts it short and starts the new one.
- **When playing**, there is no preview; the metronome itself is the preview. The new sound is used from the next beat that is scheduled. A beat that is already scheduled keeps the old sound, as with accent toggles (7.3).
- The choice applies to the whole app and is remembered between launches. Songs do not store a sound.

**Haptics switch:**

- When off, the app plays no haptics at all: no beat taps, no selection ticks and no Start / Stop impact (section 12).
- Turning it on plays one selection tick, so the user feels that haptics are back. Turning it off plays nothing.
- It works when stopped and when playing. While playing, the change applies from the next beat.
- It applies to the whole app and is remembered between launches. Songs do not store it. Mute (7.5) does not affect it.
- If haptics are turned off in the phone's own settings (System Haptics), the app has no haptics whatever the switch says; that is system behaviour.

**Keep screen awake switch:**

- When on, the screen does not dim or auto-lock while the app is open, whether playing or stopped, so between songs the user can start the next one without unlocking the phone.
- When off, the screen stays on only while playing (7.4) and while stage mode is shown (9.4), and otherwise dims and locks as usual while stopped.
- The change applies at once, when stopped and when playing. Like the iCloud switch, it plays no haptic.
- It does not keep the app open: the side button still locks the phone and switching apps still leaves it, and playback stops as in 7.7.
- It is off on a fresh install, is remembered between launches, and stays on this device; songs do not store it and iCloud does not sync it.

### 7.9 iCloud sync

The switch works when stopped and when playing, applies to this device only and is remembered between launches. How copies are combined is in 5.1.

**Switching on:**

- The device's library is combined with what is in iCloud. Nothing is removed on either side except by a delete marker, so a second device gets the first one's songs and setlists next to any of its own.
- The status line shows `Syncing…` until the first exchange with iCloud, or for two seconds when nothing arrives, and then `Up to date`.

**While on:**

- Every change to a song or setlist is handed to iCloud at once.
- Changes from other devices are combined into the library when they arrive while the app is open, and whenever the app is opened or comes back to the foreground.
- iCloud decides when changes travel: usually within a minute, later when a device is offline. The app does not show changes live as they are typed on another device.

**Switching off:**

- The device stops sending and receiving, as if it were offline. Its library stays as it is. Other devices and iCloud are not affected, apart from the clean-up when it was the last device (5.1).
- Switching on again combines everything changed in the meantime, on this device and on the others, by the same rules.

**When changes arrive:**

- The metronome never changes by itself: tempo, time signature and accents stay as they are, playing or stopped.
- If the loaded song's settings changed, the song counts as edited and the badge appears on the menu button, because what is in the metronome now differs from the song. Revert takes the arrived version; Save changes keeps the metronome's and sends it to the other devices.
- If the loaded song's name changed, the header shows the new name at once.
- If the loaded song's backing track changed:
  - A new tempo, offset, count-in or mix of the track applies at once, also while playing, as from Sync mode (7.11), and the dial or Sync mode shows it at once.
  - A backing track attached on another device arrives with its file missing here (5.1). Playback is not affected and carries on. The Backing tracks switch appears in the header at once; with it on, the player card changes to Track content with the file missing (6.12) and the dial to the track's tempo at once.
  - A track that was removed or replaced stops playback only if it was in use, its file was on this device and it was playing with it, and the position then goes to 0:00. Otherwise playback carries on and only the header and the player card change. A replaced file is missing on this device until it is picked here. Sync mode, if it is shown, ends as with `Done` (7.11).
  - A track that only took a new name, from a file picked for it on another device (5.1), keeps its file here and playback carries on; the player card and Sync mode show the new name at once. A track whose file is missing here stays missing, under the new name.
  - The Backing tracks switch itself never changes.
- If the loaded song, the loaded-from setlist or the setlist the library is showing was deleted, the rules in section 5 apply. A deleted loaded song also ends Sync mode.
- An open library sheet, setlist or setlist editor updates in place. In select mode a ticked song deleted elsewhere drops out of the ticks (8.7), and in a setlist's select mode so does a ticked song that leaves the setlist (8.8). A setlist view or editor whose setlist was deleted closes and the library shows the Setlists tab.
- Stage mode, when it is shown, follows its setlist as 9.4 says, and closes when the setlist is deleted or left with no songs.
- Nothing is announced: no alert, banner, sound or haptic.

### 7.10 Playing a song with a backing track

This section applies while a **playable track is in use**: Backing tracks is on (7.12) and the loaded song has a **playable backing track**, a backing track whose file is on this device. With Backing tracks off, none of it applies and every song plays as a plain metronome (7.12). With the switch on and the file missing, the song plays like one without a track, except that the click plays at the track's tempo, as the track is in use: Start begins on beat 1 with the first click straight away, no count-in, and the click alone.

Every rule that stops playback when a song with a backing track is loaded, unloaded, saved as or replaced (sections 5, 7.6, 7.9, 10.1 and 10.2) applies only while Backing tracks is on, and only to a playable backing track. With the switch off, or with the file missing, a song counts as a song without a backing track in all of them, so playback carries on as between two songs without tracks. With the switch on, the player card follows the song, not the file: a song with a backing track always shows Track content (6.12), with its missing-file state when the file is not here. The same happens for one run when the file cannot be opened at Start (section 11).

**The beat grid.** The click's beats are fixed to the file. Beat 1 of bar 1 falls at the offset, and every later beat follows at the track's tempo, so the beat and the bar at any place in the file follow from the offset, the track's tempo and the time signature: at T BPM a beat lasts 60 / T seconds and a bar of b beats 60 × b / T seconds. After any jump the click, the tiles and the haptics land on the right beat of the right bar. No click sounds before the offset, except the count-in.

**Position.** The track's position is shown by Track content's progress bar (6.12). It is 0:00 at launch and whenever a song is loaded. Turning Backing tracks off and on again keeps it (7.12).

**Start** depends on the position:

- **At 0:00** it plays the count-in: the chosen number of bars of click only, on the grid counted back from the offset, with accents, beat effects and haptics as usual. The count-in ends exactly where beat 1 at the offset falls. The file starts offset seconds before that beat, so what is in the file before the offset is heard under the end of the count-in. Start begins whichever of the two comes first.
- **While the count-in's click sounds alone**, from Start until the file starts, the knob is at 0:00 and the elapsed time reads `Count-in` in amber. Once the file starts, also when that is before the offset, the knob and the elapsed time follow the file's real position.
- **When the offset is longer than the count-in**, the file starts at once and `Count-in` is never shown. The count-in's clicks begin later, the count-in's length before the offset.
- **At 0:00 with count-in Off** the file starts at once, `Count-in` is never shown, and the click joins at the offset.
- **Away from 0:00** track and click play from the position at once, with no count-in. The click joins on the next beat of the grid, so its first click is not necessarily straight away.

**Stop** silences track and click at once and keeps the position, so a passage can be tried again. Stopped during the count-in before the file has started, the position stays at 0:00; stopped after the file has started, the position is kept like any other, except that a position within the first second becomes 0:00. Whatever the elapsed time shows as 0:00 therefore starts with the count-in.

**End of the track.** The click runs until the file ends. Then playback stops as with Stop and the position goes back to 0:00. In a setlist the next song is not loaded.

**Rewind and Fast-forward** move the position 15 seconds back or forward, stopped or playing. Rewind within the first 15 seconds goes to 0:00. Within the last 15 seconds Fast-forward is dimmed and does nothing. While playing, playback carries on from the new position without a count-in, also when that is 0:00.

**The progress bar.** Dragging the knob moves the position: the knob and the elapsed time follow the finger, and the position changes when the finger lifts. A drag to within the first second lands on 0:00. While playing, playback carries on from there without a count-in. The knob's touch area is 44 × 44 pt; a tap on the line elsewhere does nothing.

**Changes while playing.** The track's tempo, the time signature and the accents can be changed on the metronome screen while playing (7.1 to 7.3), and the track's tempo, the offset, the time signature and the accents in Sync mode (7.11), as without a track. The track's tempo is the user's to set; it is not detected from the file.

- After a change of the track's tempo, from the metronome screen or Sync mode, the grid is worked out again from the offset at the new tempo, and the click carries on along the new grid from its next beat that is not yet scheduled. A beat that is already scheduled is not moved. Beats never bunch up (section 11): a beat of the new grid less than half a beat interval after the last scheduled one is skipped.
- A change of the offset (7.11) moves the grid in the same way.
- After a time signature change, from the metronome screen or Sync mode, the bar is worked out again from the offset, instead of the next beat being beat 1 of a new bar (7.2). Accents reset to beat 1 as usual. The same holds wherever else a change would start a new bar: Revert (7.6) and Edit song (10.2).
- A change of the metronome's tempo while a track is in use, by Revert or Edit song, does not change the tempo in effect, so the grid stays as it is.
- During the count-in, a change applies to the count-in beats still to come, which stay on the grid counted back from the offset.

**Mute** silences only the click, completely, whatever the mix. The track keeps playing, and the beat effects and haptics carry on.

**Volume.** The mix (section 4) sets the click's level against the track's; the count-in's clicks use the same click level as the rest of the song. The phone's volume controls set the overall level (7.7). A limiter keeps the two together from distorting (section 11).

**Changing songs.**

- Loading a song from the library or with Previous / Next stops playback when the song being left or the song being loaded has a playable backing track, and the loaded song is at 0:00. Between two songs without playable backing tracks 7.6 holds and playback carries on. Tapping the loaded song's own row is not a load (7.6), so playback carries on and the position is kept.
- Unload (7.6) stops playback when the loaded song's track is playable and playing. The settings stay as plain settings, with the metronome's tempo, not the track's, and the player card goes back to Metronome content, with no switch in the header.
- When the loaded song's backing track is attached or replaced with Edit song (10.2), or a file is picked for a missing one there or with `Choose file` on the player card (6.12), playback stops if it is playing and the position is 0:00, as the track can then play: once the sheet is saved, or at once from the card. Removing a playable backing track does the same; removing one whose file is missing does not stop playback.
- With Backing tracks off, none of these stop playback, and attaching, replacing or removing a track changes nothing on the metronome screen but the switch appearing or going away.

**Tempo controls while a track plays.** The dial, − / +, Tap tempo and the tempo sheet work while the track plays, as Sync mode's tempo controls do; each change moves the click to the new grid as above. A turn of the dial is a change for every whole BPM it passes, each applied as it is made, so the click follows the turn; the library is written and sent to iCloud once the changes pause (7.11). Attaching or replacing a track, or picking a file for a missing one, still sets the position to 0:00.

**Interruptions** stop playback as in 7.7, and the position is kept as with Stop, a position within the first second becoming 0:00.

### 7.11 Sync mode

- **Entering and leaving.** The Sync pill in the player card's Track content (6.12) slides up the Sync mode sheet (6.13), stopped or playing, and playback carries on as it is; it is the only way in, as the dial sets the tempo (7.1). With the file missing there is no Sync pill (6.12). `Done`, or a swipe down on the grabber or the top of the sheet, closes it and returns to the metronome screen, leaving playback as it is; both end Sync mode the same way. A touch on a pad, a stepper or the mix slider acts on that control, and where the middle of the sheet scrolls (6.13), a drag there scrolls it. Sync mode also ends, as with `Done`, when the loaded song's track stops being in use or playable while it is shown: when the track is removed or replaced, or the song deleted, on another device (7.9); the sheet then closes by itself. The time signature picker and the tempo sheet open over the Sync mode sheet and return to it. It is not kept between launches. While it is shown, the library, the header menu and the Backing tracks switch cannot be reached, so the loaded song and the switch do not change.
- **Play / stop** is the screen's Start / Stop: everything 7.4 and 7.10 say of Start and Stop applies, so Start at 0:00 plays the count-in. Rewind, Fast-forward and the progress bar work as in the player card's Track content (7.10).
- **To the beginning** sets the position to 0:00, stopped or playing, so the next Start counts in. While playing, playback carries on from 0:00 without a count-in, as after Rewind; during the count-in, before the file has started, it changes nothing.
- **To the end** goes to the end of the file, which does what the end of the track does (7.10): playback stops if it is playing, and the position goes back to 0:00, so the next Start counts in. In a setlist the next song is not loaded. Neither button is ever dimmed.
- **Time signature:** the row opens the picker (6.6), and choosing a signature works as in 7.2; while playing, the bar is worked out again from the offset (7.10). The new time signature, with the accents reset to beat 1, is saved into the song at once.
- **Accents** toggle as in 7.3 and are saved into the song at once.
- Saving the time signature and accents from here writes them as they are, an unsaved time signature or accent change made on the metronome screen included; an unsaved change of the metronome's tempo stays unsaved. When nothing is left that differs from the saved song, the song is no longer edited and the badge goes away at once, as after Save changes.
- **Tempo:** − / + change the track's tempo by 1 BPM, as the metronome screen's tempo controls do while a track is in use (7.1). Holding repeats as in 7.1: after 400 ms, 10 steps per second. Tapping the value opens the tempo sheet (6.11) with the track's tempo; it works as typing does in 7.1, and `Set tempo` sets the track's tempo and closes the sheet, with a selection tick when the tempo changes. Tap tempo sets it too (below). It stays within 30…300. A change applies at once (7.10). The metronome's tempo is not changed.
- **Offset:** − / + move it 0.01 s earlier or later, and holding repeats as for the tempo. It stays between 0.00 and the file's length. A change applies at once: while playing, the click moves as the button is pressed, so the user can nudge it until click and track sound as one.
- **Count-in:** tapping an option selects it at once.
- **Mix:** dragging the knob changes the mix at once, stopped or playing, so it can be set by ear while the track plays. The knob catches at the centre: within 6 pt of the centre it rests exactly on it. A selection tick plays when the knob reaches the centre.
- **Saving.** Everything set in Sync mode, the time signature and accents, the track's tempo, the offset, the count-in and the mix, is saved into the song at once, with no confirm step, and never brings up the badge (section 5). While values keep changing, as when a button is held, taps follow each other or the knob is dragged, the library is written to the device and sent to iCloud once they pause, and at once on `Done` or when the app leaves the foreground.

**Tap tempo and Tap on beat 1.** Two pads set the track's tempo and the offset from taps along with the track, each on its own: Tap tempo only the tempo, Tap on beat 1 only the offset.

- **Tap tempo** sets the track's tempo from taps on the beat, by the rules of tap tempo on the metronome screen (7.1), with a series of its own: from the second tap on, the tempo is the average of the last four intervals between taps (fewer if fewer exist), a pause longer than 2 seconds starts a new series, and the tempo stays within 30…300. While a series is open its title reads `Tap again` (6.13). It works stopped and playing and is never dimmed. A tap counts when the finger touches the pad, and each tap plays a selection tick. The metronome's tempo is not changed.
- **Tap on beat 1** works only while the file is playing: not while stopped, and not during the count-in before the file has started. Otherwise it is dimmed, and a touch does nothing and plays no haptic.
- A tap on it counts when the finger touches the pad and plays a selection tick. Its **tapped time** is the place in the file that was being heard at the touch, so output delay, such as over Bluetooth, is allowed for.
- It sets only the offset, never the tempo: the tapped time t moved back by whole bars, at the track's tempo T and the time signature's b beats per bar, to the earliest place not before 0:00, that is t − L × ⌊t / L⌋ with the bar length L = 60 × b / T seconds, rounded to 0.01 s. A place that lands on a whole bar, or rounds to one, gives 0.00. At 120 BPM in 4/4 a bar is 2 seconds, so a tap at 9.30 s sets the offset to 1.30.
- Every tap sets the offset afresh from its own tapped time, so the latest tap wins; nothing is averaged.
- After a tap on either pad the click follows at once, by the rules for a change of the tempo or the offset while playing (7.10), and the steppers show the new value.

### 7.12 Backing tracks switch

- Tapping the switch in the header (6.1) turns backing tracks on or off for the whole app, with a selection tick. It works only while stopped; while playing it is dimmed and does nothing.
- **Off:** every song, with a backing track or without, is a plain metronome. The player card has Metronome content (6.7), so there is no progress bar and no Sync; Start begins on beat 1 with the first click straight away, with no count-in; the track's file is not opened or played; and playback does not stop at the track's end. 7.10 does not apply. The click plays at the metronome's tempo. The switch is the only sign of the track on the metronome screen, and turning it on is the way to Sync mode.
- **On:** a song with a backing track has Track content (6.12) and plays at the track's tempo as in 7.10, or as in 7.10's missing-file rule when its file is not here; the dial and the tempo controls show and set the track's tempo (7.1). A song without a backing track is plain.
- Turning it off or on changes the player card's content and the dial's tempo at once, and nothing else on the screen moves. It swaps the tempo in effect between the metronome's and the track's (section 4); neither tempo changes. An unsaved change of the metronome's tempo is kept while the switch is on and brings the badge back when it is turned off. The track's position is kept, so turning the switch off and on again finds the track where it was. Loading another song sets the position to 0:00 as always (7.10).
- The switch changes only when it is tapped: never by loading a song, Unload, the song sheet attaching, replacing or removing a track, or changes arriving from other devices.
- It is on on a fresh install, is remembered between launches, and stays on this device; songs do not store it and iCloud does not sync it.

### 7.13 Elapsed time and bar count

The readout in Metronome content (6.7) shows how long the metronome has played since the last Start, and which bar it is in.

- **Start** sets it to `0:00` and `Bar 1`. The time runs from the first counted beat, beat 1 of bar 1, in real time whatever the tempo, and shows whole seconds, rounded down. The bar count shows the bar being played.
- **A count-in is not counted.** While its click sounds alone the readout stays at `0:00` and `Bar 1`, and the first bar after it is bar 1. Only a playable track counts in (7.10), so the count-in is never seen in Metronome content, but such a run is counted the same way, and Metronome content shows its count once Backing tracks is turned off afterwards.
- When Start joins a track's grid away from 0:00 (7.10), the bar in which the first click falls is bar 1, also when the click joins on a later beat of it, and the time runs from that click.
- **Bars count as they are played.** Every beat 1 after the first starts the next bar. A change that starts a new bar (7.2, 7.6, 10.2) starts the next bar at once, so a bar cut short still counts as one. A change of the tempo or the accents changes nothing in the count. Muting does not stop it.
- **Stop**, and playback stopping by itself (7.7, 7.10), leave the readout at the time and the bar it showed when playback stopped, until the next Start.
- **Whenever the loaded song changes**, to another song or to nothing (7.6, 9.4, 10.1, section 5), the readout goes back to `0:00` and `Bar 1`. While playing, it then counts afresh from the next beat, as after Start: the time runs from that beat, and the bar it falls in is bar 1. A song loaded while playing starts with a new bar (7.6), so its first bar is bar 1; after Unload the bar being played carries on as bar 1. Tapping the loaded song's own row is not a load and changes nothing.
- Nothing else changes the count: not the Backing tracks switch, the Sound button, Sync mode, stage mode or changes arriving from other devices. The count runs whichever content the player card shows; Track content shows the track's own times instead (6.12). Stage mode shows no readout, and after `Done` the metronome screen shows the count of the song played there.
- It is not kept between launches: the app launches with `0:00` and `Bar 1` (section 5).

## 8. Library sheet

A tall sheet over the metronome, with a grabber. Swiping it down closes it and changes nothing.

**Structure.** The library has two levels.

- The top level has two tabs: **Songs**, every song, and **Setlists**, the list of setlists (9.1).
- Tapping a setlist on the Setlists tab opens that setlist (8.3), one level down. A ‹ takes the user back up to the Setlists tab.
- Each level slides in like a navigation stack: a deeper one (a setlist, then Add song) comes in from the right over 0.3 s, and going back the level above comes in from the left. Switching tabs does not slide.
- The content starts 36 pt below the top of the sheet, so the grabber has room above the header.
- Every list has 20 pt side margins. The 1 pt dividers between rows, in `line`, run from margin to margin, so they end in line with the header's ⋯, the +'s 40 pt slot and the controls line's divider (8.2).
- A row's own action, loading a song, ticking it, opening a setlist or New song, happens on a tap alone. A swipe, a drag that scrolls or moves a row, or a held drag that ends on a row does nothing more than the swipe or drag does.

**Where it opens.**

- On the Songs tab, so that a song can be picked at once.
- When the loaded song was loaded from a setlist, inside that setlist, where the user is.
- So it opens on the one list that marks the loaded song (8.2, 8.3).
- Either way the list is scrolled only as far as is needed for the marked row (8.2, 8.3) to be in view, when the list has one. This happens once, as the list first appears; a search that hides and brings back the list does not scroll it again.

### 8.1 Header

**On the top level** the header is one row: the tab switch at the left and the menu button at the right. There is no large title; the tabs name what is shown.

- **Tab switch:** a surface-raised pill, 40 pt tall, with `Songs` and `Setlists` (15 pt). It fills the row from the left margin up to 12 pt before the menu button, the two tabs sharing it equally. The selected tab is dial white and bold on surface selected; the other is muted and semibold.
- **Menu button:** the same button as the header menu button on the metronome screen (6.1), without the badge: 40 pt round, surface raised, with a dial-white ⋯. It takes touches over 44 pt. It is there on both tabs at all times, also with an empty library or no setlists, and opens the tab's menu (8.6), a standard iOS menu.

Making a song or a setlist is the + in the controls line (8.2, 9.1), or the large button in the middle of an empty tab; the header has no other button.

In select mode (8.7) the tab switch and the menu button give way to a title and Done. In a setlist's select mode (8.8) the ‹, the name and the menu button give way to them in the same way.

**Inside a setlist** the header has, from the left:

- **‹**, which goes back to the Setlists tab.
- The setlist's name as the title (26 pt heavy). Tapping it does nothing; it is renamed from the menu (9.2).
- **Menu button**, 40 pt round like every other menu button in the library, with **Stage mode**, **Select**, **Add song**, **Rename setlist**, **Duplicate setlist** and **Delete setlist** (8.3), a standard iOS menu. While the name is being typed, **Done** takes its place.

There is no Edit button and no separate edit mode: everything that changes a setlist is done in its own view (8.3).

### 8.2 The Songs tab

- **The controls line**, between the header and the list: the search field, then 14 pt, then the + button. The field ends 12 pt before the +'s 40 pt slot, as the tab switch ends 12 pt before the menu button (8.1), so the two have the same width and their right edges are in line. Below it come 12 pt of space, a 1 pt divider in `line` and then the songs. It stays in place while the songs scroll. It is there whenever the library has songs; an empty library shows only its empty state. The Setlists tab and a setlist have the same line (9.1, 8.3), and the Add song screen has it without the + (9.3). In select mode the search field fills the line alone (8.7, 8.8).
- **The + button:** 36 pt round, filled amber, with an ink + (16 pt, bold). It takes touches over 44 pt. It is centred under the header's menu button: it stands in a 40 pt slot at the right margin, 2 pt in from each side of the slot, so its centre is 20 pt from the margin like the menu button's and it is 14 pt from the search field. It opens the New song sheet (section 10). While a tab has a list, the + is the only amber button on the library's top level; in select mode (8.7) Done takes that place and there is no +, and an empty tab has no + and only its large button is amber.
- **Search**, a field taking the rest of the line. These rules hold for the Setlists tab's search too, which matches the setlist's name (9.1), and for the searches in a setlist and on the Add song screen, which match the song's name (8.3, 9.3).
  - It is 36 pt tall and fully rounded, surface raised with no border, 12 pt padding at the sides: a magnifying glass (15 pt semibold, muted) and, 8 pt after it, the text (15 pt regular, dial white, amber cursor), with the placeholder `Search` in muted.
  - While it has text, a muted ⓧ at its right end empties it. Its touch area is 44 pt.
  - The list shows only the songs whose name contains the text, ignoring case, accents (`a` finds `ä`) and spaces at the ends of the text, in the chosen order (8.6). Empty text, or only spaces, shows every song.
  - When no song matches, the list's place shows `No matches`, centred (17 pt, semibold, dial white), with nothing else.
  - The keyboard does not come up by itself; tapping the field brings it up. It has a Search key, which puts the keyboard away, and scrolling the list puts it away too. There is no autocorrection or automatic capital letter.
  - The text starts empty each time the library opens and is not remembered. Switching tabs empties it too. Opening a setlist from the Setlists tab and coming back with ‹ keeps it, and so do entering and leaving select mode.
  - Rows found by a search work as everywhere else: tapping one loads it, its long-press menu and swipe are the same, and the marked row (below) is still marked.
  - VoiceOver calls the field `Search songs` and the ⓧ `Clear search`.
- Then every song (or every song the search finds), in the order chosen in the tab's menu (8.6), by name A–Z unless another is chosen.
- Each row shows the name (17 pt), and below it the song's tempo and time signature, for example `120 BPM · 4/4`; a backing track's own tempo is not shown. A song with a backing track has a mark, a 13 pt music-note in muted, 5 pt after its time signature on the same line, whether or not the file is on this device; on a marked row `· loaded` follows the mark; the mark is the same in a setlist (8.3) and on the Add song screen (9.3). A row has no buttons: its text has the row's whole width, from margin to margin.
- The loaded song's row is marked, with an amber name and `· loaded` after its details, only when the song was loaded on its own. When it was loaded from a setlist no row here is marked, so it is plain that tapping the song here would load it on its own.
- **Tapping a row** loads the song and closes the sheet; a swipe or a drag on a row loads nothing (8). It does not start the metronome; Start is under the thumb when the sheet has closed. If the metronome is already playing, it keeps playing with the new song, unless Backing tracks is on and either song has a playable backing track (7.10). The loaded song's own row closes the sheet and changes nothing on the metronome, playing or stopped, unsaved edits included; when the song was loaded from a setlist, it is then loaded on its own (7.6).
- A song loaded from this view is loaded on its own: it has no loaded-from setlist, whatever setlist was being stepped through and whether or not the song is in it. The header shows the name alone, and Previous / Next are hidden.
- **Holding a row** opens the row menu (8.4). A row held and let go without the menu loads nothing, and a drag that scrolls the list opens nothing. Not in select mode (8.7).
- **Swiping a row left** reveals **Edit**, in surface selected, and **Delete**, in red at the outer end, as a shortcut to the same items in the row menu. A full swipe does nothing; a button has to be tapped. Not in select mode (8.7).
- Empty library: centred, `No songs yet` (17 pt, semibold, dial white) and a large amber **New song** button (48 pt tall). The controls line is hidden then, and the tab's menu holds New song only (8.6).

There is no button on a row that loads and starts in one tap. Such a button looks like a preview but would replace the loaded song and close the sheet, so it is easy to misread.

### 8.3 A setlist

- **The controls line**, under the header, as on the tabs (8.2): the search field, 14 pt, and the 36 pt amber + button, with the same space and divider below it. It is there whenever the setlist has songs; an empty setlist has no controls line. There is no sorting: the Songs tab's order does not apply here.
- **The + button** opens the Add song screen (9.3). VoiceOver calls it `Add song`.
- Below the controls line: the setlist's songs in the setlist's order, each with its position number at the left. There is no count line; the Setlists tab shows each setlist's count (9.1).
- Rows and tapping work as in 8.2, except that a swipe reveals Edit and Remove (below), a held row lifts to be moved (below) and the loaded song's row is marked only when the song was loaded from this setlist, and its position number is then amber too. A song loaded from this view has this setlist as its loaded-from setlist, so the header shows the position and Previous / Next. Tapping the loaded song's row here while it is loaded on its own or from another setlist changes nothing on the metronome and makes this setlist its loaded-from setlist (7.6).
- **A row has no menu** and no buttons. A held row is dragged to move it, so a menu on the same hold would get in the way of the drag. What is done with a row: a tap loads the song, a swipe gives Edit and Remove, a hold and drag moves it, and select mode (8.8) acts on several. A song is deleted from the library on the Songs tab (8.2, 8.4), not in a setlist. A setlist's songs are added to another setlist with Add to setlist in select mode (8.8).
- **Search** works as on the Songs tab (8.2), on the song's name: the same field, matching, `No matches`, keyboard and ⓧ. VoiceOver calls the field `Search this setlist`. While the field has text:
  - Each song found keeps its position number in the whole setlist, so the seventh song reads `7` also when it is the only one found.
  - The rows cannot be reordered: a held row does not lift.
  - The loaded song's mark, tapping a row to load the song from this setlist, the swipe with Edit and Remove, and the Undo bar (8.5) work as always, and Previous / Next follow the whole setlist's order.
  - The text starts empty each time the setlist is shown: it is emptied when the setlist is left, with ‹ or by closing the library, and when the Add song screen opens, so the songs added there are listed on coming back. Entering and leaving select mode (8.8) keep it.
- **Reordering:** while the search field is empty and outside select mode, a row is moved by holding it until it lifts and dragging it up or down, the standard iOS way for a list. It drops where the finger lets go; the new order is the setlist's order, and the numbers follow. Rows have no drag handles. A row held and let go without moving loads nothing and opens nothing.
- **Removing:** **swiping a row left** reveals **Edit** and **Remove**, laid out as the Songs tab's Edit and Delete (8.2): Edit in surface selected, and Remove at the outer end in amber, so it is not taken for Delete, which alone is red. Remove's title is white, as the system draws a swipe button's title. Edit opens the Edit song sheet for that song, and closing the sheet leaves the setlist with the row closed. Remove takes the song out of this setlist. A full swipe does nothing; a button has to be tapped. The swipe works while the search field has text too, and not in select mode. **Remove** in select mode acts on several songs (8.8). Each has Undo (8.5).
- **Adding:** the + in the controls line, and Add song in the setlist's menu, open 9.3. New songs go to the end.
- **Renaming:** with Rename setlist in the header menu (9.2).
- Empty setlist: centred, `No songs in this setlist` and a large amber **Add song** button (48 pt tall), which opens 9.3. It is the only thing to do there, so it is filled.
- **The setlist's menu** (⋯ in the header) holds what is done to the setlist as a whole, in this order:
  - **Stage mode**, followed by a divider: closes the library sheet and opens stage mode (9.4) for this setlist. In an empty setlist, and while the metronome is playing, it is dimmed and does nothing.
  - **Select:** enters select mode (8.8). Not in an empty setlist.
  - **Add song:** opens 9.3, as the + does.
  - **Rename setlist:** puts the cursor in the name (9.2).
  - **Duplicate setlist:** creates a setlist named `<name> copy` with the same songs in the same order, and shows the copy. The songs are shared, not copied.
  - **Delete setlist**, in red: asks for confirmation, deletes the setlist and goes back to the Setlists tab. The songs stay in the library.

### 8.4 The row menu

A long press on a row on the Songs tab, also while a search narrows the list, opens the row menu: the system context menu, with the row lifted above it as its preview. It holds everything that can be done with that song, in this order:

- **Add to setlist**, which opens a second level:
  - Every setlist, most recently used first whatever the Setlists tab's order (8.6), with a tick when the song is in it. Tapping one adds the song to the end of that setlist, or takes it out (8.5).
  - **New setlist**, after a divider: creates a setlist that starts with this song and opens it for naming (9.2).
- **Edit:** opens the Edit song sheet (10.2), with the name, tempo, time signature and accents. There is no separate Rename, as the sheet holds the name.
- **Delete**, in red: asks for confirmation: `Delete “<song name>”?`, then `It will also be removed from 2 setlists.` (`1 setlist` for one), and `Delete` and `Cancel`. When the song is in no setlist there is no such line, only the title and the buttons.

So a song can be put into a setlist, edited or deleted from the Songs tab without first opening a setlist. A setlist's rows have no menu (8.3), and select mode's rows open none (8.7, 8.8).

### 8.5 Removing a song from a setlist, and Undo

A song is taken out of a setlist by swiping its row in the setlist's view and tapping Remove (8.3); several songs at once with Remove in a setlist's select mode (8.8); by unticking the setlist in Add to setlist in the Songs tab's row menu (8.4); by unticking it in Add to setlist in the header menu on the metronome screen (7.6), for the loaded song; and by unticking it on the Add song screen (9.3). The header menu and the Add song screen show no Undo bar (7.6, 9.3); in every other case:

- It happens at once, without confirmation. The songs stay in the library.
- An **Undo bar** appears at the bottom of the sheet: `Removed <song name>` for one song, or `Removed 3 songs` for several (15 pt, dial white), and `Undo` in amber at the right, on a surface-raised bar with 14 pt corners. It goes away by itself after 6 seconds, and a new removal replaces it.
- **Undo** puts every song of the removal back in the setlist at the place it had. If one of them was the loaded song, loaded from that setlist, its position and Previous / Next come back too.
- If a row of the setlist is dragged to a new place after the removal (8.3), the bar goes away, since the places it would restore do not fit the new order. If the setlist changed in another way meanwhile, Undo puts the songs back at the end, in the order they had. A song deleted from the library meanwhile does not come back.

Only the last removal can be undone, and a removal of several songs is undone as a whole. Deleting a song or a setlist is confirmed beforehand and has no Undo.

### 8.6 The tab menus and sorting

The menu button in the top-level header (8.1) opens the shown tab's menu.

**The Songs tab's menu**, from the top:

- **Select**, which enters select mode (8.7).
- **New song**, which opens the New song sheet, as the + does.
- After a divider, a group headed `Sort by`: **Name**, **Recently added** and **Recently played**, with a tick on the current one.

With an empty library the menu holds New song only.

**The Setlists tab's menu**, from the top:

- **New setlist**, which does what the + does (9.1).
- After a divider, a group headed `Sort by`: **Name** and **Recently used**, listed in the Songs tab's way with Name first, and with a tick on the current one.

With no setlists the menu holds New setlist only.

**Sorting.** Choosing an order re-sorts the list at once and closes the menu. The chosen order is remembered on this device, one for each tab, and is not synced (section 5). A new install starts with Name on both tabs.

- **Name:** A–Z, ignoring case and following the phone's language rules. Songs with the same name keep their order of creation (5.1); setlists with the same name keep the most recently used first.
- **Recently added:** the song created last first, by creation time (5.1).
- **Recently played:** the song with the latest last-played time first. Songs never loaded on this device come after them, by name as above.
- **Recently used:** as in 9.1, the setlist opened or loaded from last first.

A song's last-played time is set whenever it becomes the loaded song: tapped in the library, on the Songs tab or in a setlist; by Previous and Next; by its tile in stage mode (9.4); by Save as new song (7.6); and by naming the current settings (10.1). Tapping the loaded song's own row is not a load and does not set it (7.6), and neither does restoring the loaded song when the app opens. The time is kept on this device and not synced (section 5), so each device has its own Recently played order, and on a new install every song starts as never played. A time for a song that no longer exists is dropped.

Search and sorting go together: the songs or setlists a search finds are listed in the chosen order. A setlist's own view always keeps the setlist's order (8.3), and the Add song screen stays A–Z (9.3), also while searching.

The order is worked out when the list appears and when an order is chosen. Under Recently played a song whose last-played time changes while the list is shown keeps its place until the list next appears. Loading a song from the list closes the sheet, so the list never moves under the finger.

### 8.7 Select mode

Select mode acts on several songs at once. This section is the Songs tab's select mode; a setlist has its own, which works like it (8.8). The Setlists tab has none. **Select** in the tab's menu enters it with nothing ticked. It ends with **Done**, after an action in the action bar, or when the sheet is closed, and every tick goes with it; the library always opens with it off.

- **Header:** in place of the tab switch a title, `Select songs` while nothing is ticked and `3 selected` otherwise (26 pt heavy, as a setlist's title). At the right, **Done** in place of the menu button: the same pill as Done while a setlist is renamed (9.2), 36 pt tall, 14 pt bold, filled amber with ink text. Done also puts the keyboard away.
- **Controls line:** the search field alone, filling the line; there is no +. The search works as in 8.2.
- **Rows** look as in 8.2, the loaded song's mark included, and end in a round tick, drawn as on the Add song screen (9.3): filled amber when ticked, an empty grey ring when not. Tapping a row ticks or unticks it and loads nothing. Rows are not swiped, and holding a row opens no menu and ticks nothing.
- A ticked song stays ticked while a search hides it, and it is counted in the title and acted on. A ticked song deleted on another device drops out of the ticks, and when the library becomes empty select mode ends.
- **Action bar**, at the bottom of the sheet, above the home indicator, over the list: a surface bar with a 1 pt line in `line` along its top. In it two equal pills, 48 pt tall, surface raised, 12 pt apart, with 20 pt side margins and 12 pt above and below them: **Add to setlist** (16 pt bold, dial white) and **Delete** (16 pt bold, red). With nothing ticked both are dimmed and do nothing.
- **Add to setlist** opens a menu, a standard iOS menu, with every setlist, most recently used first, and **New setlist** after a divider, as in the row menu's second level (8.4) but without ticks. With no setlists it holds New setlist only.
  - Choosing a setlist adds the ticked songs that are not in it yet to its end, in the order the Songs tab lists them with the search left aside, and ends select mode. The library stays on the Songs tab. Adding songs does not count as using the setlist (9.1).
  - **New setlist** makes a setlist holding the ticked songs in that order, ends select mode and opens the setlist for naming (9.2).
- **Delete** asks for confirmation once, as Delete in the row menu does (8.4): `Delete 3 songs?`, then `They will also be removed from 2 setlists.`, counting each setlist that holds any of them once, and `Delete` and `Cancel`. When none of them is in a setlist there is no such line, only the title and the buttons. With one song ticked the confirmation is the row menu's. Delete deletes the ticked songs and ends select mode. Deleting the loaded song follows section 5. There is no Undo.
- Neither action shows the Undo bar (8.5), and entering select mode takes away an Undo bar that is shown.

### 8.8 Select mode in a setlist

A setlist's view has a select mode for acting on several of its songs at once. It works as the Songs tab's (8.7) wherever nothing else is said here. **Select** in the setlist's menu (8.3) enters it with nothing ticked; an empty setlist has no Select.

- **Header:** the title, `Select songs` while nothing is ticked and `3 selected` otherwise, and **Done**, in place of the ‹, the setlist's name and the menu button, drawn as in 8.7.
- **Controls line:** the search field alone, filling the line; there is no +. The search works as in 8.3, and the text stays as it was when select mode began.
- **Rows** keep their position numbers in the whole setlist, also while a search narrows the list, and the loaded song's mark, and end in a round tick, drawn as in 8.7. Rows cannot be reordered, a held row does not lift and opens nothing, and rows are not swiped. Tapping a row ticks or unticks it and loads nothing.
- A ticked song stays ticked while a search hides it, and it is counted in the title and acted on. A ticked song that leaves the setlist by other means, such as a change from another device, drops out of the ticks.
- **Action bar**, drawn as in 8.7, with **Add to setlist** and **Remove**, both in dial white. There is no Delete here: a song is deleted from the library on the Songs tab, with its row menu (8.4), its swipe (8.2) or select mode (8.7). With nothing ticked both are dimmed and do nothing.
- **Add to setlist** opens a standard iOS menu with every other setlist, most recently used first, and **New setlist** after a divider, without ticks. With no other setlist it holds New setlist only.
  - Choosing a setlist adds the ticked songs that are not in it yet to its end, in this setlist's order with the search left aside, and ends select mode. The library stays in this setlist. Adding songs does not count as using the setlist (9.1), and shows no Undo bar.
  - **New setlist** makes a setlist holding the ticked songs in this setlist's order, ends select mode and opens the new setlist for naming (9.2).
- **Remove** takes the ticked songs out of this setlist at once, without confirmation, and ends select mode. The songs stay in the library. The Undo bar shows `Removed 3 songs`, or with one song ticked `Removed <song name>`, and Undo puts them all back (8.5). If the loaded song was loaded from this setlist and is among them, it stays loaded on its own (section 5), and Undo brings back its position and Previous / Next.
- It ends with **Done**, after either action, when the library is closed, when the setlist becomes empty, and when the setlist is left because it was deleted on another device, and every tick goes with it. The setlist always opens with it off. Entering it takes away an Undo bar that is shown.

## 9. Setlists

### 9.1 The Setlists tab

- **The controls line**, as on the Songs tab (8.2): the search field, 14 pt, and the + button, with the same space and divider below it. It is there whenever there are setlists.
- **Search** works exactly as on the Songs tab (8.2), on the setlist's name: the same field, matching, `No matches`, keyboard and emptying of the text. Making a setlist here, with the + or New setlist, empties the text too, so the new setlist is listed on coming back. VoiceOver calls the field `Search setlists`. Rows found by a search work as everywhere else, and the amber setlist (below) is still amber.
- **The + button** does what New setlist does: creates a setlist and opens it for naming (9.2).
- Every setlist (or every setlist the search finds) with its song count and a ›, in the order chosen in the tab's menu (8.6), by name A–Z unless another is chosen. A setlist counts as used when it is opened here or a song is loaded from it, Previous, Next and stage mode's tiles (9.4) included. Its last-used time is then set to the moment, but only when it is not already the most recently used setlist on this device, that is, when another setlist's last-used time is the same as its own or later. Otherwise nothing about it changes and nothing is sent to iCloud, so stepping through a setlist with Next writes nothing.
- The setlist the loaded song was loaded from is amber, so the user sees where they are.
- Tapping a setlist opens it (8.3). It loads nothing into the metronome.
- **Swiping a row left** reveals **Delete**, in red, a shortcut to Delete setlist in the setlist's menu. It asks for confirmation in the same way; the songs stay in the library.
- While there are no setlists: centred, `No setlists yet` (17 pt, semibold, dial white) and a large amber **New setlist** button (48 pt tall). The controls line is hidden then, and the tab's menu holds New setlist only (8.6).
- The list scrolls; there is no limit on the number of setlists.

### 9.2 Creating and renaming a setlist

A setlist is changed in its own view (8.3); there is no separate editing screen.

**Renaming:** the name stands in the place and size of a title. **Rename setlist** in the header menu puts the cursor in the name, and **Done** takes the menu button's place. The name takes no taps otherwise, so the title is not edited by surprise. A new setlist starts with the cursor already in its name. Done, Return on the keyboard, or leaving the view ends typing, and only then is the name saved; there is no cancel. An empty name is not accepted: the setlist keeps its previous name, which comes back when typing ends. So a name typed and then erased leaves the setlist as it was.

**Creating**, after the + or New setlist on the Setlists tab (9.1, 8.6), New setlist in a song's row menu (8.4) or New setlist in select mode (8.7, 8.8):

- The setlist is made at once, named `Untitled`, and its own view opens with the name field empty and ready for typing, showing `Untitled` as its placeholder. A setlist made from a row menu already holds that song, and one made in select mode the ticked songs.
- Until it is named, the title stays the grey `Untitled` placeholder, also after Done, so that the setlist does not look named.
- There is no Cancel. Leaving the new setlist, with ‹ or by closing the library, drops it if it still has no name and no songs, since nothing was done with it. Once it has a name or a song it is kept. Only the setlist just made is ever dropped this way: an Untitled setlist opened later is kept.

Duplicating and deleting are in the setlist's menu (8.3).

### 9.3 Adding songs to a setlist

Opened from a setlist's view, with the + in its controls line, with Add song in the setlist's menu or with the button of an empty setlist.

- **Header:** `ADD TO` in small capitals above the setlist's name as the title, and **Done** at the right, which goes back to the setlist.
- **Search**, under the header: the controls line of 8.2 without the +, the search field filling the line, with the same space and divider below it. It is there whenever the library has songs. It works as on the Songs tab (8.2), on the song's name: the same field, matching, keyboard and ⓧ; `No matches` is placed as below. VoiceOver calls the field `Search songs`. The text is empty each time the screen opens, and it is emptied when a song is made with New song here, so the new song is listed.
- Every song in the library (or every song the search finds), A–Z whatever the Songs tab's order (8.6), each with a round tick at the right end: filled amber when it is in the setlist, an empty grey ring when it is not. Ticks work the same while searching.
- Last row: **New song**, in amber, which opens the New song sheet (section 10) with "Add to <setlist>" switched on. It sits at the end of the list, with the + 8 pt from its text, and stays while a search narrows the list. When nothing matches, the list holds the New song row alone, and `No matches` (17 pt, semibold, dial white) stands centred in the space below it.
- Tapping a row adds the song to the end of the setlist, or takes it out. Changes take effect at once. Taking a song out here shows no Undo bar: the user is picking, and ticking it again puts it back (at the end).
- **Empty library:** centred, `No songs in library yet` (17 pt, semibold, dial white), below it `Create one here, and it goes straight into <setlist>.` (15 pt, muted), and a large amber **New song** button that opens the New song sheet with "Add to <setlist>" switched on. Done is grey here (surface raised, dial-white text), so that New song is the one amber button.

### 9.4 Stage mode

Stage mode is for playing a setlist on stage. It shows the setlist's songs as large tiles: a tap on a tile starts that song, a tap on it again stops it, and nothing else can be changed. It covers the whole screen, over the metronome screen, and is drawn at 390 × 844 pt.

**Entering.**

- **Stage mode** in the header menu (7.6), there while the loaded song was loaded from a setlist, opens it for that setlist.
- **Stage mode** in a setlist's menu (8.3) closes the library sheet and opens it for that setlist. In an empty setlist it is dimmed and does nothing.
- Both are dimmed and do nothing while the metronome is playing.
- Entering changes nothing on the metronome: the loaded song and its unsaved edits, the settings, the Backing tracks switch and the Sound button stay as they are.
- On entering, the loaded song's tile is the active tile (below) when the song was loaded from this setlist; otherwise no tile is marked.

**Layout.** The background is ink. From top to bottom:

- **Title row**, 48 pt tall, 6 pt below the top of the safe area, set as Sync mode's (6.13): at the left the setlist's name (20 pt heavy, dial white, one line, cut with an ellipsis) and 2 pt below it `Stage mode` (13 pt medium, muted); at the right, 16 pt from them, `Done` (17 pt semibold, amber), with a touch area of at least 44 × 44 pt. There is no menu button, Sound button, Backing tracks switch, dial or Start button.
- **Tiles**, 20 pt below the title row: two columns 10 pt apart, rows 10 pt apart, in the setlist's order, row by row, between the side margins of the metronome screen (6.8). They scroll under the title row, which stays in place, and the last row scrolls up to 16 pt above the bottom of the safe area.
- **A tile** is a surface card with 24 pt corners, 112 pt tall, with 14 pt padding at the top and bottom and 16 pt at the sides. At its top an 18 pt line: the song's number in the setlist (15 pt heavy, muted dim) at the left and, at the right, for a song with a backing track, whether its file is on this device or not, the music-note mark of the library's rows (8.2), 16 pt, in muted. The mark is shown only while Backing tracks is on (7.12), so it tells whether the song's track will be used; off, no tile has it, active and playing ones included. At its bottom the song's name (20 pt heavy, dial white, set slightly tight) and 8 pt below it the song's tempo and time signature, for example `96 BPM · 4/4` (14 pt medium, muted); a backing track's own tempo is not shown, as in the library. A long name takes up to two lines and is then cut with an ellipsis. A row in which a name takes two lines is 120 pt tall, both of its tiles, so that the rows stay even.
- **The active tile** is the loaded song's when it was loaded from this setlist and is in it; there is none otherwise. Stopped, it has the amber tint fill with a 1.5 pt amber outline and its number in amber; its track mark, if shown, stays in muted. It has no label. While the metronome plays the active song it is the playing tile.
- **The playing tile**, the active tile while the metronome plays, keeps its look: the amber tint fill, the amber outline, the number in amber and the name in dial white, with an amber glow around it (14 pt blur) at 15 % opacity. On every beat, count-in beats included, an amber wash over the fill, under the text, appears at 30 % opacity on an accented beat and 16 % on one that is not and fades to nothing over 0.25 s, easing out; the glow jumps to 50 % with it and fades back to 15 %. In the place of its tempo line is a row of **beat dots**, one per beat of the bar, 5 pt apart, in amber: 12 pt for an accented beat and 8 pt for one that is not, the current beat solid and the others at 28 % opacity. In 9/8 and 12/8 the dots are 8 pt and 5 pt, 3 pt apart, so that twelve fit. Where the tile is narrower than the row needs, as on a narrow phone, the dots and gaps are all scaled down alike until it fits. A dot lights on its beat at once, as the accent tiles do (6.5), count-in beats included. While a playable backing track is in use (7.10), the track's place and the file's length stand at the right of the top line in the place of the mark, for example `0:31 / 3:42` (13 pt semibold, dial white, digits of equal width), `0:00` until the file has started. Otherwise the track mark, if shown, stays in muted.
- While a tile plays, every other tile and `Done` are drawn at 40 % opacity. While the metronome plays a song that has no tile (below), every tile is, and `Done` is not.

**Playing.**

- **Tapping a tile while the metronome is stopped** loads that tile's song from this setlist, exactly as tapping its row in the setlist's view does (7.6, 8.3), and starts it from the top. Loading another song drops the loaded song's unsaved edits without asking (7.6). The loaded song's own tile is not a load: its unsaved edits stay and are played, and it becomes loaded from this setlist. From the top means that the backing track's position goes to 0:00 first, for the loaded song's own tile too, and Start then does what 7.4 and 7.10 say, count-in included; with Backing tracks off or the file missing, what 7.10 and 7.12 say for those. A medium impact plays as on Start (section 12). The tapped tile becomes the playing tile.
- **Tapping the playing tile** stops playback, as Stop does (7.4). It stays the active tile, the last song's too.
- While a tile plays, the other tiles do nothing, and neither does `Done`: the song is stopped first, then stage mode is left.
- While stopped, any tile starts its song, the one just played and songs earlier in the setlist included. Nothing marks a song as played.
- Playback that stops by itself, at the end of a backing track (7.10), on an interruption, when the audio output goes away or when the app leaves the foreground (7.7), leaves the tile stopped and active, as a tap would. Stage mode stays shown. A start that fails (section 11) leaves the tapped tile active, as its song is loaded.
- The end of a backing track does not start the next song (7.10).
- Nothing else can be changed: there is no tempo, time signature or accent control, no reordering, no menu, no swipe, and a hold or a drag on a tile does nothing but scroll. A tile acts on a tap alone, as a library row does (8).
- The Backing tracks switch stays as it was on entering, and a song plays by it (7.12). The track marks show it (Layout).

**Leaving.** `Done` closes stage mode and shows the metronome screen, with the song last loaded still loaded. Loaded from this setlist, as a tile loads it, the header shows the setlist and the position, and Previous and Next are shown (6.1, 6.7). Stage mode is not kept between launches; the loaded song is, and with it the active tile.

**Staying awake.** While stage mode is shown, the screen does not dim or lock, playing or stopped, whatever Keep screen awake says (7.8). It does not keep the app open: the side button still locks the phone, and playback stops as in 7.7.

**Changes from other devices** (7.9) update the tiles at once: songs added, removed or moved, and a changed name, tempo, time signature or backing track. The setlist's new name shows in the title row. The active tile stays on its song wherever it moves; when that song leaves the setlist no tile is marked. A playing song that leaves the setlist or is deleted plays on as section 5 and 7.9 say; no tile is then playing, the tiles still do nothing while the metronome plays, `Done` works, and once it stops no tile is marked, also when it came back to the setlist meanwhile. When the setlist is deleted or left with no songs, stage mode closes as with `Done`, at once while nothing plays, or else as soon as playback stops.

**Other screens.** While stage mode is shown the library, the header menu, the settings sheet and Sync mode cannot be reached.

**Small screens.** The tiles keep their size on every phone and the grid scrolls. The side margins follow 6.8. Stage mode is portrait only, like the rest of the app (section 3), and its text does not scale with Dynamic Type (section 13).

## 10. Song sheet

One sheet for creating a song (10.1) and editing one (10.2). A short sheet with:

- **Name field**, with the placeholder `Name` in muted. Save is disabled while the name is empty. Names are limited to 60 characters; spaces at the ends are removed.
- **Tempo:** the song's tempo, with − and + around the value. One tap changes it by 1 BPM; holding repeats, as on the metronome screen. Tapping the value opens the tempo sheet (6.11) to type a tempo, which sets only the sheet's tempo. A backing track's own tempo is set in Sync mode (7.11), not here.
- **Time signature row:** opens the same picker as the metronome screen. Changing it resets the accents to beat 1.
- **Accent tiles:** one per beat, tap to toggle.
- **Backing track** row, which attaches, replaces or removes the song's backing track (10.3).
- **Add to <setlist>** switch: shown only in New song, when the sheet was opened from 9.3, naming that setlist, or with Save as new song while the loaded song has a loaded-from setlist, naming that one (7.6). It is on by default in both.
- **Cancel and the save button**, in one row at the bottom. **Cancel** is a 60 pt tall, 116 pt wide pill with no fill and a 1 pt outline in the line colour, with `Cancel` (17 pt bold, dial white), as in the tempo sheet (6.11). It is always enabled. 10 pt to its right, **the save button** fills the rest of the row: a 60 pt pill (18 pt heavy), amber with ink text when it can be used. It is surface raised with muted text, readable but plainly not ready, and does nothing while the name is empty, and in Edit song also while nothing differs from the saved song (10.2).

Changing values in the sheet does not affect the metronome, playing or stopped, until the sheet is saved.

**Closing without saving.** Cancel, swiping the sheet down and tapping outside it all close the sheet at once without saving and without asking.

### 10.1 New song

Titled `New song`, with `Save song`. Opened in the library with the + or New song in the Songs tab's menu, with the New song button of an empty library (8.2, 8.6), or with New song on the Add song screen (9.3), or with Save as new song in the header menu (7.6). The name field is ready for typing. All three settings start from the metronome's current values, so the quickest way to make a song is to set the metronome first. The song starts without a backing track. `Save song` is ready once a name is typed; spaces alone do not count.

Saving a new song from the library does not load it, with one exception: **naming the current settings.** When no song is loaded and the song is saved with the same tempo, time signature and accents as the metronome has, the new song becomes the loaded one, so the header shows its name at once and later changes bring up the badge.

- The metronome is not touched: it keeps playing or stays stopped, and no new bar starts. When the new song has a playable backing track and Backing tracks is on (7.10), playback stops if it is playing. The track is at 0:00.
- If the song was added to a setlist (9.3, with "Add to <setlist>" on), it counts as loaded from that setlist, so the header shows its position and Previous / Next appear. Otherwise it is loaded on its own.
- Its last-played time is set, as when any song becomes the loaded one (8.6).
- In every other case the song is only created: when a song is already loaded, or when the values were changed in the sheet.

**Save as new song** in the header menu always makes the new song the loaded one, whatever was loaded before, and stops playback as 7.6 says. With Add to <setlist> on, the song is added to the end of the loaded-from setlist and loaded from it; otherwise it is loaded on its own.

### 10.2 Edit song

Titled `Edit song`, with `Save changes`. Opened with Edit in a song's row menu on the Songs tab (8.4), by swiping its row on the Songs tab or in a setlist (8.2, 8.3), or with Edit song in the header menu for the loaded song (7.6). The name and the three settings start from the song's saved values, also when it is the loaded song with unsaved changes. The keyboard does not come up by itself, as the change is more often to the tempo or the accents; tapping the name brings it up.

`Save changes` is ready when there is a name and the name, leaving aside spaces at its ends, or the tempo, time signature or accents differ from the song's saved values, or the backing track was attached, replaced or removed, or a file was picked for a missing one (10.3). A change undone by hand, such as + then −, counts as none. Closing the sheet without saving keeps the song as it was.

`Save changes` writes only what changed, so that a part left alone does not win over a change made to it on another device (section 5).

- A song that is not loaded is only changed; the metronome is not touched.
- The loaded song with changed settings: the metronome takes them and any unsaved changes are dropped. A changed tempo is the song's, not its track's, so while the track is in use the click stays at the track's tempo. This is not a load, so the rule that loading stops a song with a playable backing track (7.6) does not apply; a song whose playable track is in use keeps playing on the track's grid (7.10). While playing, the bar carries on when only the tempo or the accents changed, and the next beat is beat 1 of a new bar when the time signature changed.
- The loaded song with only a new name: the header shows the new name, and the metronome and any unsaved changes stay as they are.
- The loaded song whose backing track was attached or replaced, or which had a file picked for a missing one, or whose playable backing track was removed: with Backing tracks on, playback stops if it is playing, and the position is 0:00 (7.10). Removing a track whose file is missing does not stop playback. With Backing tracks off, playback carries on and only the switch in the header appears or goes away (7.10, 7.12). The other changes apply as above.

### 10.3 Backing track

The **Backing track** row sits below the accent tiles, above the Add to <setlist> switch when that is shown: a 60 pt surface-raised row with 16 pt corners, like the sheet's other rows, and 16 pt padding at the left. The music-note icon is 18 pt in muted, 10 pt before the text, and the file name or `Add backing track` is 16 pt medium in dial white.

| State | The row shows | Tapping |
|---|---|---|
| No track | the music-note icon and `Add backing track` | the row opens the Files picker |
| Track | the icon, the file name (cut with an ellipsis) and the remove button | the name opens the Files picker to replace the file; × removes the track |
| File missing on this device | the icon, `Track missing` in amber and the remove button | the name opens the Files picker; × removes the track |

The remove button is an 18 pt × in muted in a 44 pt square at the right end of the row. Without a track the row has no button at the right.

- The Files picker offers the audio files iOS can play (section 4). A file that cannot be read as audio is not attached: the row stays as it was and an alert says `This file can't be played`, with `OK`.
- A picked file that cannot be kept on the device when the sheet is saved, for example because the phone is full, saves nothing: no new song, and no change to the name, the settings or the track. The sheet stays open with everything entered, and an alert says `The track couldn't be saved`, with `OK`.
- Like everything else in the sheet, a change takes effect when the sheet is saved. Cancel and the other ways of closing the sheet drop it, a picked file included.
- A newly attached file gets its offset automatically: the first moment the file's level rises above −40 dB relative to full scale, rounded to 0.01 s, or 0.00 when the file starts with sound. Its tempo is the song's tempo as the sheet saves it, its count-in starts at 2 bars and its mix at the centre.
- Replacing the file sets the offset from the new file and keeps the track's tempo, the count-in and the mix.
- Removing the track forgets its tempo, offset, count-in and mix.
- A file picked for a missing track takes the place of the missing one, under the track's identifier, and the row shows the picked file's name. The track keeps its tempo, offset, count-in and mix. When the picked file's name is the same as the name the track carries, nothing about the track changes and nothing is sent to other devices. When it differs, the track takes the picked file's name, saved with `Save changes` as the sheet's other changes are, and the backing track syncs with it (5.1). The song does not become edited.
- The same pick can be made with `Choose file` on the player card (6.12), where the file is stored at once.
- The track's tempo, offset, count-in and mix are set in Sync mode (6.13, 7.11), not here.

## 11. Audio and timing

- Seven click sounds, all generated in code when playback starts, at the output's own sample rate. Each sound has an accented and a normal variant (table below).
- Clicks are scheduled on the audio clock, a little ahead of time. They are never driven by a UI timer.
- A beat is never scheduled in the past. After a large tempo jump the next beat sounds straight away and the following ones space out from it, so beats never bunch up.
- Visual effects and haptics are triggered from the same schedule, so the three stay together.
- Starting playback must not block the screen: the phone's audio is taken over in the background and the first click, or with a backing track the count-in or the track, follows as soon as that is done.
- If starting fails, the app returns to the stopped state and gives the phone's audio back to other apps.
- A backing track is played on the same audio clock as the click, so the relation between them is fixed to the sample: the click does not drift against the track over the file's length, at any tempo.
- The file is read from storage as it plays, not loaded whole into memory, and is converted to the output's sample rate.
- If the file cannot be opened at Start, the song plays as with a missing file for that run (7.10).
- While a playable track in use (7.10) is playing, a limiter on the output keeps the sum of click and track below full scale, so the two together do not distort. It must not delay or soften the click's attack beyond the attack rule in 11.1; its other settings are left to the builder. It is not in the signal path while no playable track is in use, Backing tracks off included, so 11.1 holds there unchanged; with a track, the figures in 11.1 describe the click before the limiter and before the mix (section 4).
- Targets: each click within 2 ms of its ideal time, and no accumulated drift over 10 minutes at any tempo.

### 11.1 Click sounds

"Decay" is the time constant of an exponential fade. Levels in brackets are relative to the sound's first component. "Saturated" means passed through tanh(d · x / peak) / tanh(d) with the drive d given, which fills out the body and adds harmonics. The noise in Woodblock and Tick comes from a fixed seed, so a sound is identical every time.

| Sound | How it is made | Accented | Normal |
|---|---|---|---|
| Digital | A sine burst that starts at its peak, 30 ms decay, 150 ms long. | 1760 Hz | 1175 Hz |
| Soft beep | A sine held flat: 1 ms raised-cosine fade-in, 35 ms hold, then 8 ms decay. 70 ms long. | 1568 Hz | 1047 Hz |
| Woodblock | Sines at f (20 ms decay), 0.5 f (0.6, 25 ms), 2.65 f (0.4, 6 ms) and 4.1 f (0.15, 3 ms) with a 0.5 ms fade-in, plus a noise strike band-passed at 3 f (Q 2) and then faded (1.2 ms decay, 0.5). Saturated, drive 2.5. 80 ms long. | f = 1180 Hz | f = 880 Hz |
| Mallet | Sines at f (45 ms decay), 4 f (0.4, 15 ms) and 10 f (0.1, 4 ms), 0.8 ms fade-in. Saturated, drive 2. 120 ms long. | f = 1047 Hz | f = 784 Hz |
| Glass | An FM bell: carrier f, modulator 3.5 f, modulation index 2.2 with 25 ms decay, amplitude decay 45 ms, 0.6 ms fade-in. 140 ms long. | f = 1760 Hz | f = 1319 Hz |
| Tick | A watch tick. Sines at f (6 ms decay), 1.48 f (0.7, 4 ms) and 2.3 f (0.4, 3 ms) with a 0.3 ms fade-in, 40 ms long, plus a strike (0.5): 6 ms of noise band-passed at 1.8 f (Q 1.5), then faded (0.5 ms decay). Saturated, drive 2. | f = 4000 Hz | f = 3000 Hz |
| Pendulum | A clock's escapement. A ping of sines at 3200 p (4 ms decay), 4750 p (0.6, 3 ms) and 7300 p (0.3, 2 ms), 30 ms long, at 0.7, over a body of sines at 700 p (14 ms decay) and 1350 p (0.6, 9 ms), 70 ms long; both with a 0.3 ms fade-in. Saturated, drive 2. | p = 1.33 | p = 1 |

Rules for every sound:

- **Loudness.** The click must hold its own against music played at the same system volume, since the phone has one media volume for both. Loudness is measured on the scale music is mastered to (ITU-R BS.1770, LUFS, K-weighted, the click on both channels) over the first 100 ms of the sound, about as long as the ear takes to judge a short sound. The accented variant is raised to −2 LUFS and the normal variant to −6 LUFS. To get there without clipping, each sound goes through a soft limiter: samples below half of full scale are untouched, and louder ones bend smoothly (tanh) towards a ceiling of 0.95, so no peak reaches full scale.
- **No crushing.** A sound's peak is never pushed more than 6 dB past the limiter's ceiling (8 dB for Digital, a pure tone that was judged by ear to take it). A dry, short sound that cannot reach its target within that stays quieter instead, and its normal variant then sits 4 dB under its accent. Today that is Woodblock (accent −3.9, normal −7.9 LUFS), Pendulum (−7.6, −11.6) and Tick (−7.8, −11.8); Digital, Soft beep, Mallet and Glass reach the full level.
- **Accent.** Each accented variant is 4 dB louder than its normal variant.
- **Attack.** The click must be heard at its scheduled time: every sound reaches half of its peak within 1 ms of its start.
- **Length.** No sound is longer than 150 ms, so each one ends well before the next beat at 300 BPM (200 ms). The last 3 ms fade to silence.

## 12. Beat effects

Each beat fires all of the following at the moment of its click.

| Effect | Normal beat | Accented beat |
|---|---|---|
| Glow | An amber radial glow behind the BPM number flashes to 30 % opacity and decays over half the beat interval. | Same. |
| Number pulse | The BPM number scales 1.0 → 1.04 and back within half the beat interval. | Same. |
| Tile | The beat's tile switches to its sounding state at once. The previous tile fades back to idle over 150 ms. | Same. |
| Stage mode's playing tile | An amber wash over the tile appears at 16 % and fades out over 0.25 s; the glow around it jumps to 50 % and fades back to 15 %; the beat's dot lights. | The wash appears at 30 %. |
| Haptic | Light impact, intensity 0.5. | Rigid impact, intensity 1.0. |

The glow and the number pulse belong to the dial's number, which is the same in every mode, with Metronome content and with Track content: it marks every beat, accented or not, and stays dial white. Stopped, there is no glow and the number is at its full size. Sync mode has no dial, so there only the tiles and the haptics mark the beat; the dial under the sheet keeps marking it. There are no other beat visuals, except stage mode's playing tile (9.4), whose wash, glow and beat dots stand in for the dial there, as stage mode has none; nothing ripples or moves. The beats of a count-in (7.10) fire all of these like any other beat.

Other haptics: a selection tick for each 1 BPM change from the dial or − / +, Sync mode's included, for each tap-tempo tap, Sync mode's Tap tempo included, for each key in the tempo sheet and for `Set tempo` when it changes the tempo, from Sync mode too, for each accent toggle, for Revert, for each tap on the Sound button and on the Backing tracks switch, and in Sync mode for each 0.01 s step of the offset, each tap on Tap on beat 1 while it works, each change of count-in and each time the mix knob reaches the centre. The dial, − / +, tap tempo and the tempo sheet tick in the same way while a track is in use. `Done` plays none. Beat haptics continue while muted. A medium impact on Start and Stop, the player card's Start / Stop pill and play / stop button, the playback card's play / stop and a tap on a tile in stage mode included; a tile that loads a song plays no selection tick for the load. The system's success notification on Save changes.

The Haptics switch in settings (7.8) turns all of these off.

## 13. Accessibility

- **Reduce Motion:** the number pulse is disabled on the dial, in every mode, and so is the pulse of stage mode's playing tile: no wash, and its glow stays at rest. Tile changes, stage mode's beat dots and the dial's glow remain. The app has no setting that turns beat effects off.
- **VoiceOver:**
  - The dial is an adjustable element ("Tempo, 120 beats per minute") that steps by 1 BPM, in every mode; while a track is in use it reads and steps the track's tempo. It has the action "Type a tempo", which opens the tempo sheet.
  - In the tempo sheet the field reads as "Tempo" with the typed digits, each key as its digit, and the delete key as "Delete". The buttons below read "Cancel" and "Set tempo", Set tempo as dimmed while it is not ready.
  - In the song sheet the tempo value is a button: "Tempo, 120 beats per minute", with the hint "Type a tempo". The accent tiles, which have no visible heading, form a group named "Accents". The buttons at the bottom read "Cancel" and as the save button's text, the save button as dimmed while it is not ready.
  - The header's menu button reads as "More", and as "More, unsaved changes" while the badge is shown. Its menu items read as written, Revert with the saved values. After Save changes, "Saved" is announced, since the badge going away cannot be heard.
  - The tap tempo pill reads as "Tap tempo" also while it shows `Tap again`.
  - The header's two toggles read alike, their name and whether they are on or off: the Backing tracks switch as "Backing tracks, on" or "Backing tracks, off", and as dimmed while playing, and the Sound button as "Click sound, on" or "Click sound, off".
  - In the player card's Metronome content the readout is one element that reads the time and the bar, for example "1 minute 24 seconds, bar 43", and from an hour on "1 hour 2 minutes 7 seconds, bar 1240"; its changes are not announced. The pill reads as "Start" or "Stop", and Previous and Next as "Previous song" and "Next song".
  - In the player card's Track content the file-name row reads as "Backing track, <file name>", or with the file missing as "Track missing, <file name>"; the Sync pill reads as "Sync", a button, and the `Choose file` button as "Choose file". Rewind reads as "Back 15 seconds" and Fast-forward as "Forward 15 seconds". The play / stop button reads as "Start" or "Stop", and Previous song and Next song as "Previous song" and "Next song". The progress bar is an adjustable element that reads the position and the length, for example "1 minute 24 seconds of 3 minutes 42 seconds", or "Count-in" while the count-in's click sounds before the file has started, and steps by 15 seconds. With the file missing, the progress bar, Rewind and Fast-forward are hidden from VoiceOver, as the file-name row already reads "Track missing".
  - In the Sync mode sheet the title reads as "Sync", a heading, followed by the file name, and `Done` as "Done". The time signature row reads as on the metronome screen, "Time signature, 7/8", and the tiles as everywhere. The pads are buttons: Tap tempo reads as "Tap tempo", also while it shows `Tap again`, and Tap on beat 1 as "Tap on beat 1", dimmed while it does nothing. The tempo is an adjustable element, "Tempo, 168 beats per minute", that steps by 1 BPM; it has the action "Type a tempo", which opens the tempo sheet. The offset is an adjustable element too, "Offset, 0.48 seconds", that steps by 0.01 s. The playback card reads as the player card, with play / stop as "Start" or "Stop", and To the beginning and To the end as "To the beginning" and "To the end". Each count-in option reads as, for example, "Count-in, 2 bars", with "selected" for the current one. The mix slider is an adjustable element that reads where it is, rounded to whole decibels: "Mix, centre", "Mix, track turned down 12 decibels" or "Mix, click turned down 6 decibels". It steps by 3 dB, so the centre and both ends are reached exactly.
  - In the song sheet the Backing track row reads as "Backing track, <file name>", "Add backing track" or "Track missing", and its remove button as "Remove backing track".
  - Each tile reads as "Beat 3, accented" or "Beat 2, not accented", with the toggle as its action.
  - A sound row reads as its name, with "selected" for the current one, and says that tapping plays a preview.
  - The haptics switch reads as "Haptic feedback, on" or "Haptic feedback, off".
  - The screen switch reads as "Keep screen awake, on" or "Keep screen awake, off".
  - The sync switch reads as "Sync songs and setlists, on" or "Sync songs and setlists, off". The status line reads as its text and detail, for example "Up to date, last synced 14:32"; the dot is not read.
  - The header title reads the song name and its second line, and says that it opens the library. While the song is edited it says "edited" after the name, for example "Seven Bridges, edited, Friday gig · 3 of 8", because the badge appearing cannot be heard.
  - A song row reads as its name, tempo and time signature, for example "Harbour Lights, 120 beats per minute, 4/4", with "backing track" after it when the song has one, and "loaded" when the row is marked (8.2, 8.3). On the Songs tab the row menu (8.4) is offered among the row's VoiceOver actions, as the system offers a context menu, with its items as written. A setlist's row has no menu; its swipe's Edit and Remove are among its actions as the system offers them.
  - The Undo bar's button reads "Undo"; the back button in a setlist reads "Back to setlists"; the menu button in a setlist reads "More for this setlist", and its items as written. The tabs read "Songs" and "Setlists", with "selected" for the one shown.
  - The top-level header's menu button reads "More for songs" on the Songs tab and "More for setlists" on the Setlists tab; its items read as written, the current order with "selected". The + reads "New song" on the Songs tab and "New setlist" on the Setlists tab. The Setlists tab's search field reads "Search setlists", and its ⓧ "Clear search".
  - In select mode the title is a heading and reads as shown, "Select songs" or "3 selected", and Done reads "Done". A row reads as everywhere else, with "selected" when it is ticked, and tapping it ticks or unticks it. The action bar's buttons read "Add to setlist" and "Delete", as dimmed while nothing is ticked.
  - In a setlist's view, a row is moved with the drag that the system list offers VoiceOver for a row it can reorder, while the search field is empty and outside select mode, and the row's Edit and Remove are offered among its actions, as a swipe's buttons are on every list; the app adds no actions of its own for either. Its search field reads "Search this setlist" and its ⓧ "Clear search", and its + reads "Add song". A row found by a search reads as everywhere else; its position number is not read.
  - In a setlist's select mode the title, Done and the rows read as in the Songs tab's select mode, and the action bar's buttons read "Add to setlist" and "Remove", as dimmed while nothing is ticked.
  - The Add song screen's title reads "Add to <setlist>", and each row says whether the song is in the setlist. Its search field reads "Search songs" and its ⓧ "Clear search".
  - In stage mode the title row reads the setlist's name as a heading, followed by "Stage mode", and `Done` reads "Done", as dimmed while a tile plays. Each tile is one button that reads its number, the song's name, tempo and time signature, for example "3, Seven Bridges, 168 beats per minute, 7/8", with "backing track" after it when the tile shows the track mark, and "loaded" for the active tile while stopped or "playing" for the playing tile, for example "3, Seven Bridges, 168 beats per minute, 7/8, loaded"; a tile that does nothing while another plays reads as dimmed. The beat dots and the track's time are not read. The Stage mode items in the header menu and the setlist's menu read as written, as dimmed when they are.
  - Beat changes during playback are not announced.
- Every tappable control is at least 44 × 44 pt.
- Text does not scale with Dynamic Type; see section 16.

## 14. Acceptance checklist

A ticked line has been verified in the simulator, by unit tests or on a phone. An unticked line carries a note on what is missing.

Metronome:

- [x] Tempo can be set by the dial, − / + and tap tempo, when stopped and when playing, and never leaves 30…300. *(A tap tempo series has not been tapped by hand; its rules are unit tested.)*
- [ ] A turn anywhere on the dial, number included, turns the knob by the angle travelled; the dead zone at the centre changes nothing and leaving it does not jump; a tap on the number still opens the tempo sheet. *(The turning and dead zone rules are unit tested. On the iPhone 17 Pro simulator a quarter turn begun on the number took 187 to 269, a straight drag through the centre changed nothing, and a tap opened the sheet. How it feels under a finger needs a real iPhone.)*
- [ ] The dial is 264 pt with a 92 pt number for two and three digits alike; the knob is darker, lit from the upper left with the colours of 6.2, a thin top highlight and a soft inner shadow at its lower edge, its ridges still visible and its pointer at full amber; the ridges and pointer turn with the tempo, and the number stays clear of the pointer at every tempo. *(Not built yet.)*
- [x] Tapping the number opens the tempo sheet; typing a tempo and Set tempo sets it, and only tempos from 30 to 300 can be set. *(The digit rules are unit tested; typing 174 was tried in the simulator, and with the two-button row, typing 40 and Set tempo set 40.)*
- [x] The tempo sheet shows Cancel under the empty place of the keys and Set tempo under 0 and delete; Set tempo is not ready until the digits are a tempo from 30 to 300, and Cancel closes the sheet without changes whatever is typed. *(Seen in the simulator on an iPhone 17 Pro from the dial: Cancel lined up with the keys' first column and Set tempo with the other two; Set tempo was grey before the first key and at 400, with the range amber, and amber at 140; Cancel at 140 closed the sheet with the tempo still 184. Opened from Edit song by tapping the tempo, Set tempo was not ready before the first key, Cancel was one key wide under the empty place, and Cancel went back to the song sheet with 121 still showing. Swiping down, tapping outside, other screen widths and VoiceOver were not tried.)*
- [ ] The tap tempo pill reads Tap again with an amber outline during a series and goes back two seconds after the last tap. *(The label and outline were seen in the simulator; going back after two seconds was not watched.)*
- [x] Unlit ticks are visible against the background, and nothing in the header moves when Start is pressed. *(Seen in the simulator.)*
- [ ] The dial is never larger than 264 pt: on a tall screen the spare height goes evenly to the gaps above and below the tempo controls, time signature row and tiles, which stay centred between the knob's lower edge and the player card; on a short screen the gaps go down to 16 pt, then the dial to 200 pt, then the controls become compact (48 pt rows, 10 pt gaps, 56 pt single-row tiles, gaps of at least 10 pt) and the dial takes the rest, giving the sizes 6.8 states for an iPhone 17 Pro, a 390 × 844 pt iPhone, an iPhone SE and Display Zoom; the screen never scrolls. *(Not built yet.)*
- [x] The lit arc, pointer and number always agree, and the dial shows the number alone, with no tempo name, on every screen. *(The arc, pointer and number agreeing is verified. In the simulator on an iPhone 17 Pro the number stood alone, with no tempo name, on the plain screen at 75, 88, 120, 255 and 300, and on the track screen at 120, stopped, playing, without a setlist and with the file missing. In the trackOtherTempo scene, where the song is at 120 and its track at 168, the track screen's lit ticks and number showed the track's 168, and with Backing tracks switched off the plain dial showed the song's 120. Other tempos where the two differ were not seen.)*
- [x] All eight time signatures can be selected; the tile count matches the signature.
- [x] Changing the signature resets accents to beat 1 and, while playing, continues with a new bar. Reselecting the current signature, or dismissing the sheet, changes nothing.
- [ ] Accents can be toggled when stopped and when playing; accented beats sound, look and feel different from normal beats. *(Toggling and the look are verified. Sound and haptics need a listener and a real iPhone.)*
- [x] Start always begins on beat 1. Stop is immediate.
- [x] The Sound button silences the click at once and brings it back, while the visuals and haptics continue.
- [ ] Click, visual and haptic stay together at 30, 120 and 300 BPM. *(Needs a real iPhone.)*
- [ ] No audible drift against a reference metronome over 10 minutes. *(The timing maths is unit tested to the sample; the listening check needs a real iPhone.)*
- [ ] The phone's volume buttons and the Control Center slider change the click volume. *(Needs a real iPhone.)*
- [x] Tempo, time signature and accents survive quitting and reopening the app.
- [ ] Reduce Motion and VoiceOver behave as in section 13. *(Not yet tried with the settings switched on.)*
- [ ] Every song has the same layout, stopped and playing, with Backing tracks on or off and with nothing loaded: the header, the dial, the tempo controls, the time signature row, the tiles and the 188 pt player card, with only the card's content differing; nothing moves when Start is pressed, when Backing tracks is switched, or between songs. *(Not built yet.)*
- [ ] The tempo controls, the time signature row and the tiles are 60, 16, 60, 16 and 68 pt (98 pt for two rows of tiles), with 28 pt numbers on single-row tiles. *(Not built yet.)*
- [ ] The header's Sound button and Backing tracks switch look as in 6.1: on, surface selected with a dial-white icon; off, surface with a muted icon drawn as off, the speaker with a × and the note with a slash; the menu button stays surface with a dial-white ⋯; nothing in the header but the badge is amber. *(Not built yet.)*
- [ ] VoiceOver reads the Sound button as "Click sound, on" or "Click sound, off" and the Backing tracks switch as "Backing tracks, on" or "Backing tracks, off". *(Not built yet.)*
- [ ] Metronome content shows the elapsed time at the left and the bar count at the right above Previous, the Start / Stop pill and Next; Start and Stop look as in 6.7; outside a setlist and with nothing loaded Previous and Next are not shown and the pill keeps its width and place. *(Not built yet.)*
- [ ] Start sets the readout to `0:00` and `Bar 1`; the time runs in whole seconds from the first counted beat, as `m:ss` and from an hour on as `h:mm:ss`; every beat 1 after the first counts a bar, a change that starts a new bar counts one at once, and a tempo or accent change counts none; a count-in is not counted; Stop and playback stopping by itself keep the readout until the next Start; a change of the loaded song, Unload included, sets it back to `0:00` and `Bar 1` and, while playing, counts afresh from the next beat; the Backing tracks switch, mute, Sync mode and stage mode change nothing; the readout is not kept between launches; VoiceOver reads it as one element. *(Not built yet.)*
- [ ] The metronome screen has no next-up line in any mode. *(Not built yet.)*

Songs and setlists:

- [x] A song can be created, loaded, edited and deleted; sorted by Name, the library is A–Z.
- [x] Unload in the header menu unloads the loaded song and keeps the settings and playback; it is in the menu only while a song is loaded. *(Unloading is unit tested, and the menu's items in nothingLoadedOffersOnlySaveAsNewSongAndSettings and aLoadedSongOffersEverythingButSaving. In the simulator on an iPhone 17 Pro, Unload from the menu showed Library / No song loaded with the tempo still 172, and the menu then held only Save as new song and Settings. Unload while playing was not seen on screen.)*
- [x] Search on the Songs tab narrows the list by name, ignoring case, accents and the spaces at the ends, and shows `No matches` when nothing matches. *(Matching is unit tested, accents included. In the simulator, with a song loaded (on an iPhone 17 Pro, with no Unload) and with nothing loaded, the field did not take focus when the library opened, filtered the list as text was typed (the loaded song staying amber), showed `No matches`, and ⓧ emptied it; a song tapped in a filtered list was the one loaded. The simulator had a hardware keyboard, so the on-screen keyboard, its Search key and scrolling it away were not seen, and nor was VoiceOver. With `li` typed, a long press on Northern Line opened its row menu, on an iPhone 16 on iOS 18 and an iPhone 17 Pro on iOS 26.)*
- [x] Tapping a row loads without starting, and keeps playing when the metronome is running. *(Unit tested.)*
- [x] Song rows have no buttons, on the Songs tab and in a setlist; a long press on a Songs tab row opens the row menu, the system context menu with the row lifted above it, holding Add to setlist, Edit and Delete in that order; Add to setlist's second level ticks the song's setlists, and tapping a ticked one takes the song out with the Undo bar; Edit opens Edit song and Delete asks for confirmation; a plain tap loads, the swipe gives the shortcuts of 8.2, and a drag that scrolls the list opens nothing and loads nothing. *(Seen in the simulator on an iPhone 16 on iOS 18 and an iPhone 17 Pro on iOS 26 on Harbour Lights: the menu after a hold of about half a second, with the lifted row a dark card with its own text, and on the loaded Seven Bridges the amber name and `· loaded`; Friday gig ticked in the second level, and tapping it gave `Removed Harbour Lights` with Undo, and tapping it again ticked it; Edit opened Edit song; Delete gave `Delete “Harbour Lights”?` and `It will also be removed from 1 setlist.`; the swipe showed Edit and Delete; New setlist in the second level opened `Untitled` with the cursor in its name, holding Harbour Lights alone; unticking Friday gig and tapping Undo at once ticked it again; a slow drag up and back and a quick flick down on the rows scrolled the list, opened no menu and loaded nothing. A long press made while a closing Edit song sheet was still sliding away opened nothing and loaded nothing, 5 of 5 times on each phone.)*
- [x] A setlist's rows have no menu: a hold without moving opens nothing and loads nothing, on both phones. *(Seen in the simulator on an iPhone 16 on iOS 18 and an iPhone 17 Pro on iOS 26 in Friday gig, with a hold of about a second on Copper Sky.)*
- [x] Edit song changes a song's name, tempo, time signature and accents as 10.2 says. *(The rules for the loaded and the unloaded song are unit tested. Changing a tempo by typing it and saving was tried in the simulator.)*
- [x] Tapping the tempo in the song sheet opens the tempo sheet, and Set tempo sets only the sheet's tempo. *(Tried in the simulator from Edit song; New song uses the same sheet and was not tried separately.)*
- [x] In Edit song, `Save changes` is not ready until the name or a setting differs from the saved song; spaces at the ends of the name and a change undone by hand do not count. *(Unit tested. In the simulator on an iPhone 17 Pro it was grey on opening and turned amber after one tap on +.)*
- [x] The song sheet has Cancel at the left of the save button, in one row at the bottom, in New song and Edit song. *(Seen in the simulator on an iPhone 17 Pro in both.)*
- [ ] Cancel, swiping the song sheet down and tapping outside it each close it at once without saving and without asking, with or without changes. *(In the simulator on an iPhone 17 Pro: in New song with a typed name, Cancel closed the sheet and made no song; in Edit song, after one tap on + (120 to 121) had turned `Save changes` amber, Cancel closed the sheet and the song still showed 120 BPM in the library; in Edit song with the tempo changed by +, swiping down closed it with no question and the song unchanged. Swiping New song down and tapping outside were not tried; an earlier tap outside made with the simulator tool did not close the sheet, so tapping outside has not been seen working. VoiceOver was not tried.)*
- [x] The song sheet shows the accent tiles below the time signature row with no heading. *(Seen in the simulator on an iPhone 17 Pro, in Edit song and New song. The "Accents" group with VoiceOver was not tried.)*
- [x] Row dividers in the library's lists end at the 20 pt margin, in line with the header's ⋯ and the controls line's divider. *(Seen on simulator screenshots on an iPhone 16 on iOS 18 and an iPhone 17 Pro on iOS 26, in a setlist, on the Songs tab, on the Setlists tab and, on the iPhone 17 Pro, on the Add song screen.)*
- [x] Taking a song out of a setlist shows the Undo bar, and Undo puts it back in its place. *(Unit tested, including the loaded song's position, and tried in the simulator.)*
- [x] The library opens on the Songs tab, or inside the loaded song's setlist when it came from one, and scrolls to the marked row. *(Choosing the setlist is unit tested, and both ways of opening were seen in the simulator. In the simulator the list stayed at its top on an iPhone 17 Pro, where the loaded row fits, and scrolled just far enough to show it on an iPhone SE, where it does not. A library of several screens has not been tried.)*
- [x] The Songs tab marks the loaded song only when it was loaded on its own; a setlist marks it only when it was loaded from that setlist. *(Unit tested: theSongsTabMarksTheSongOnlyWhenLoadedOnItsOwn, aSongLoadedOnItsOwnIsMarkedOnlyInAllSongs, aSongLoadedFromAnotherSetlistIsNotMarkedInThisOne and aSongTappedOnTheSongsTabIsNotMarkedInTheSetlistBeingSteppedThrough. In the simulator on an iPhone 17 Pro, with Seven Bridges loaded on its own it was marked on the Songs tab and unmarked in Friday gig, and loaded from Friday gig it was marked there with its number amber. The Songs tab with no row marked, for a song loaded from a setlist, has not been seen. VoiceOver was not tried.)*
- [x] A song tapped on the Songs tab is loaded on its own, also when it is in the setlist being stepped through: the header shows the name alone, and Previous / Next go. *(Unit tested: aSongTappedOnTheSongsTabIsLoadedOnItsOwn and loadedFromSetlistFollowsTheLoadedSong. Not seen in the simulator.)*
- [x] The header shows the right title and second line in every state of 6.1.
- [ ] Changing a loaded song's settings shows the badge on the menu button and leaves the title as it is; the badge fades in, lingers for half a second and goes at once on Save changes, Revert, loading and unloading, as 6.1 says; Save changes, Revert and Save as new song in the header menu do what 7.6 says, and the title opens the library also while edited. *(Save and Revert, with the bar carrying on or starting over, are unit tested, and so are the half second and going at once on Save changes, Revert, loading and unloading: saveStaysOfferedWhileTheTempoPassesTheSavedValue, saveStopsBeingOfferedOnceTheSettingsRestOnTheSavedValues, movingOnBeforeTheWaitIsOverKeepsSaveOffered, savingWhileRestingOnTheSavedValuesTakesTheButtonAwayAtOnce and revertingAndLoadingTakeTheSaveOfferAwayAtOnce, which ends by unloading. Save as new song is unit tested in saveAsNewSongLoadsTheNewOne. In the simulator on an iPhone 17 Pro an edited song showed the badge on the menu button, and after Save changes from the menu the badge was gone. The badge fading in, lingering and going without a fade were not watched, as screenshots cannot show them; Revert from the menu and the title opening the library while edited were not tried on screen.)*
- [ ] The header has title, the Backing tracks switch when shown, the Sound button and the menu button, in every mode; the header menu shows the items of 7.6 for nothing loaded, a loaded song and an edited one, stopped and playing; Edit song opens Edit song for the loaded song, Add to setlist acts on the loaded song, Save as new song loads the new song in every state, with the Add to <setlist> switch, on by default, only while the loaded song has a loaded-from setlist: on, the new song goes to the end of that setlist and keeps the position and Previous / Next; off, it is loaded on its own; and Settings opens the settings sheet; VoiceOver reads the button as in section 13. *(The menu's items are unit tested: nothingLoadedOffersOnlySaveAsNewSongAndSettings, aLoadedSongOffersEverythingButSaving, anEditedSongPutsSaveChangesAndRevertFirst and editedWithoutASongIsTreatedAsNothingLoaded, and the button's VoiceOver label in theButtonSaysWhenThereAreUnsavedChanges. Save as new song is unit tested in saveAsNewSongLoadsTheNewOne, saveAsNewSongIntoTheLoadedSetlistKeepsThePlace, saveAsNewSongWithNoSetlistIgnoresTheSwitch and saveAsNewSongAfterTheSetlistWasDeletedLoadsItOnItsOwn, and the loaded-from setlist in loadedFromSetlistFollowsTheLoadedSong and takingTheLoadedSongOutOfItsSetlistKeepsItLoaded. In the simulator on an iPhone 17 Pro, stopped: the header was title, mute and menu button with nothing loaded, and title, Backing tracks switch, mute and menu button on the track screen; with nothing loaded the menu held Save as new song and Settings only; for an edited song it held all seven items in the order of 7.6, with the saved tempo and time signature under Revert, and after Save changes it held neither Save changes nor Revert; Edit song opened Edit song for the loaded song; Add to setlist ticked the loaded song's setlist, and New setlist opened the library inside a new setlist holding the song, with the cursor in its name; Save as new song from an edited song loaded from a setlist showed the Add to <setlist> switch on, and saved with it on the header showed the setlist and 9 of 9 with Previous / Next, and with it off the name alone without them; and Settings opened the settings sheet. The menu while playing was not tried, and VoiceOver was not switched on.)*
- [x] Quick taps on − / + each count once and never leave the tempo running on by itself. *(Four quick taps on + were tried in the simulator after two quick taps had left the repeat running up to 250.)*
- [x] Naming the current settings while nothing is loaded loads the new song, from the setlist it was added to; in other cases a new song from the library is not loaded. *(Unit tested.)*
- [x] Opening the library keeps unsaved edits; loading another song drops them.
- [x] Tapping the loaded song's own row changes nothing on the metronome, playing or stopped: no new bar and no stop, the track keeps its position, and the settings and unsaved edits are kept; only the loaded-from setlist follows the tap: in a setlist's view the song is then loaded from that setlist, and on the Songs tab on its own. *(Unit tested: selectingTheLoadedSongKeepsUnsavedEdits, selectingTheLoadedSongWhilePlayingStartsNoNewBar, selectingTheLoadedSongInASetlistLoadsItFromThatSetlist, selectingTheLoadedSongOnTheSongsTabLoadsItOnItsOwn, selectingTheLoadedSongKeepsTheTrackPlaying, selectingTheLoadedSongWhileStoppedKeepsThePosition and detachingTheLoadedSongOnTheSongsTabKeepsTheTrackPlaying.)*
- [x] A setlist can be created, renamed, duplicated and deleted; deleting it leaves its songs in the library.
- [x] Songs can be added to a setlist, removed from it and reordered; the order is kept.
- [x] A new song can be created from inside a setlist and lands in that setlist.
- [x] Previous and Next step through the loaded-from setlist, stopped and playing, and stop at the ends. *(Next was tried in the simulator; Previous and the ends are unit tested.)*
- [x] Loading a song while playing keeps the metronome running and starts a new bar.
- [ ] The Setlists tab shows all setlists with counts, a setlist opens from it with a way back, and the tab explains setlists while there are none and stays usable with 20 setlists. *(The tab, opening a setlist and going back were tried in the simulator, and the explanations on an empty Setlists tab, an empty Songs tab and an empty setlist were seen. 20 setlists have not been seen.)*
- [x] A setlist's menu has Duplicate and Delete. *(Tried in the simulator: Duplicate showed the copy, Delete went back to the Setlists tab.)*
- [x] A setlist is changed in its own view, with no edit mode: Rename setlist in the menu renames it in place. *(Tried in the simulator on an iPhone 17 Pro: renaming with Done.)*
- [x] Outside a search and select mode a setlist's rows have no drag handles and no buttons; holding a row until it lifts and dragging it moves it, and the numbers follow when it drops; a row held and let go without moving loads nothing and opens nothing, a plain tap loads the song, and the swipe gives Edit and Remove. *(Seen in the simulator on an iPhone 16 on iOS 18 and an iPhone 17 Pro on iOS 26 in Friday gig: no handles; a row held between half a second and a second and dragged lifted and dropped where the finger let go, with the numbers following on the drop, five times out of five on each phone with different rows, up and down, and no row left lifted; a one-second hold let go in place loaded nothing and opened nothing; a tap on Waltz for June loaded it as 4 of 8; the swipe showed Edit and the amber Remove. On the iPhone 16 the lifted row is drawn see-through over the row under it. On a phone the lift delay and how the drag feels were not tried.)*
- [x] Swiping a setlist's row left reveals Edit in surface selected and Remove in amber at the outer end, where the Songs tab has Edit and Delete, and loads nothing; Edit opens Edit song for that song, and closing it leaves the setlist with the row closed; tapping Remove takes the song out with `Removed <song name>` and Undo puts it back in its place; both work with a search typed; the Songs tab's swipe reveals Edit and Delete in red. *(Seen in the simulator on an iPhone 16 on iOS 18 and an iPhone 17 Pro on iOS 26: Copper Sky's swipe showed grey Edit and amber Remove side by side, square blocks filling the row's height on the iPhone 16 and separate rounded buttons on the iPhone 17 Pro, Remove's title white on amber on both; Edit opened Edit song for Copper Sky, and Cancel left Friday gig with the row closed; Remove gave `Removed Copper Sky` with Undo. With `li` typed, Northern Line's swipe showed both, Edit opened Edit song for Northern Line and Remove gave `Removed Northern Line`. The Songs tab showed Edit and red Delete. On the iPhone 16, Undo put Copper Sky back at 2, a full swipe across it left both buttons showing and the song in place, and a tap on the row's content then closed them and loaded nothing; these three were not tried on the iPhone 17 Pro with this swipe.)*
- [x] A setlist with songs has the controls line under its header, the search field, 14 pt and the 36 pt amber +, then the list, with no count line and no Add song row after the last song; the + opens the Add song screen; an empty setlist has no controls line and keeps its large Add song button. *(Seen in the simulator on an iPhone 16: the line under the header with the list straight below its divider and no count line or Add song row, the + opening Add song, and a new empty setlist with No songs in this setlist, the large Add song button and no line. Measured at 3 px per pt: the field from 60 to 962 px, the + from 1005 to 1112 px, 42 px after the field, centred at 1058.5 px like the header's ⋯.)*
- [x] Search in a setlist narrows its list by name by the rules of 8.2 and shows `No matches`; found rows keep their numbers in the whole setlist, and rows cannot be reordered; tapping a found row loads it from the setlist, its swipe's Remove with Undo works, and Previous / Next follow the whole setlist. *(The numbering and matching are unit tested in SetlistSearchTests. Seen in the simulator on an iPhone 16 on iOS 18 and an iPhone 17 Pro on iOS 26: with `li` typed, Northern Line's swipe and Remove gave `Removed Northern Line`, and Undo within a few seconds brought back its 7. Seen on the iPhone 16: `li` showed 1 Harbour Lights and 7 Northern Line, `zz` showed No matches, tapping Northern Line loaded it with `Friday gig · 7 of 8` and Next up Last Orders, Next went to 8 of 8 and Previous twice to Slow Burn, 6 of 8. With `li` typed, on the iPhone 16 and on an iPhone 17 Pro on iOS 26, Harbour Lights held a second and dragged down did not lift: the sheet followed the finger, and on letting go nothing moved and nothing loaded.)*
- [x] A setlist's search text is emptied when the setlist is left with ‹, when the library closes and when the Add song screen opens, so songs added there are listed on coming back. *(Seen in the simulator on an iPhone 16: with `li` typed, the + and Done came back to an empty field with the added song at the end; with `zz` typed, ‹ and reopening the setlist showed an empty field and every song; with `li` typed, closing the library with a swipe and reopening it showed an empty field.)*
- [x] Entering and leaving select mode keep a setlist's search text. *(Seen in the simulator on an iPhone 16: with `north` typed and three songs ticked, Done left the field holding `north` with Northern Line alone, and Select in the menu then opened select mode with `north` still in the field.)*
- [ ] VoiceOver reads a setlist's search field "Search this setlist" and its + "Add song". *(VoiceOver is not run by anyone.)*
- [ ] VoiceOver can move a setlist's row with the system list's drag and offers Edit and Remove among the row's actions, as in section 13. *(VoiceOver is not run by anyone, so neither was heard.)*
- [ ] VoiceOver offers a Songs tab row's menu (8.4) among the row's actions, with its items as written, and a setlist row's Edit and Remove, as in section 13. *(VoiceOver is not run by anyone: none of the row actions were heard, on the Songs tab or in a setlist.)*
- [x] Select in a setlist's menu enters its select mode: the title reads `Select songs`, then the count, Done takes the place of ‹, the name and the menu button, the search fills the controls line, rows keep their numbers and end in a tick ring, a tap ticks or unticks and loads nothing, and a hold ticks nothing and opens nothing. *(A hold on two unticked rows in select mode changed no tick and opened nothing, on an iPhone 16 on iOS 18 and an iPhone 17 Pro on iOS 26. The title is unit tested in theTitleCountsTheTicks. Seen in the simulator on an iPhone 16 in Friday gig: Select gave `Select songs` and the amber Done with no ‹, name or menu button, the search alone in the line with no count line, rows numbered 1 to 8 each ending in a grey ring; ticking gave `1 selected` to `4 selected`, a second tap unticked, and tapping the loaded Seven Bridges ticked it with its amber 3, name and `· loaded` kept and the sheet left open. With `north` typed only 7 Northern Line showed and the title stayed `3 selected`.)*
- [x] In a setlist's select mode a swiped row reveals nothing and a held row does not lift or move, and neither ticks the row. *(Seen in the simulator on an iPhone 16 on iOS 18 and an iPhone 17 Pro on iOS 26: a left swipe on Midnight Ferry showed no button, a right swipe on Harbour Lights and Harbour Lights held a second and dragged down left it in place, and the title stayed `3 selected`; a tap on Midnight Ferry then ticked it and a second tap unticked it.)*
- [x] In every library list a row acts on a tap alone: a swipe either way, a drag that scrolls the list or a held drag ending on a row does not load, tick or open it, and the swipe buttons stay. *(Seen in the simulator on an iPhone 16 on iOS 18 and an iPhone 17 Pro on iOS 26. In a setlist: a right swipe on Midnight Ferry loaded nothing and a tap loaded it; a left swipe showed the swipe's buttons; a row held and dragged reordered; a hold let go in place loaded nothing. With `li` typed: a right swipe on Northern Line loaded nothing and a tap loaded it. On the Songs tab: a left swipe showed Edit and Delete, a right swipe on Last Orders, a drag from Slow Burn that scrolled the list and a quick flick starting on a row loaded nothing, and a tap on Northern Line loaded it; in its select mode swipes both ways and a held drag ticked nothing and taps ticked and unticked. On the Setlists tab: a right swipe on Friday gig opened nothing, a left swipe showed Delete and a tap opened it. On the Add song screen: swipes both ways on Odd-time drill ticked nothing, taps ticked and unticked it, a drag scrolled the list, and a right swipe on New song opened nothing while a tap opened the New song sheet. VoiceOver was not run, so activating a row with it was not heard.)*
- [x] In a setlist's select mode the action bar shows Add to setlist and Remove in dial white, dimmed and doing nothing while nothing is ticked; Add to setlist lists the other setlists and New setlist, or New setlist alone when there is no other setlist; a setlist gets the ticked songs not yet in it at its end in this setlist's order, and the library stays in this setlist; New setlist makes a setlist of the ticked songs in this setlist's order and opens it for naming; both end select mode without an Undo bar. *(Unit tested: addingFromASetlistKeepsThatSetlistsOrder, addingSongsThatAreAllThereChangesNothing and addingSongsDoesNotCountAsUsingTheSetlist. Seen in the simulator on an iPhone 16: both pills dimmed with nothing ticked and tapping them opened nothing; in Friday gig as the only setlist the menu held New setlist alone, which opened an Untitled setlist for naming holding Copper Sky, Waltz for June and Slow Burn in Friday gig's order; with that setlist named Encore, Friday gig's menu held Encore and New setlist and Encore's menu Friday gig and New setlist, neither listing the setlist shown; adding Northern Line, then Last Orders and Harbour Lights ticked in that order, gave Encore Northern Line, Harbour Lights, Last Orders; adding Encore's three songs to Friday gig, which held them all, left it at 8; each add ended select mode in the setlist shown with no Undo bar. VoiceOver is not run by anyone, so the pills being read as dimmed was not heard.)*
- [ ] Add to setlist in a setlist's select mode lists several other setlists most recently used first, and adds the ticked songs in this setlist's order also while a search hides some of them. *(The order of the setlists is the row menu's setlistsByRecency, and the songs' order is taken from the whole setlist, as addingFromASetlistKeepsThatSetlistsOrder pins in the model. Neither was seen on screen: there was only one other setlist, and no add was made with a search typed.)*
- [x] Remove in a setlist's select mode takes the ticked songs out at once and ends select mode; the Undo bar reads `Removed 3 songs`, or `Removed <song name>` for one; Undo puts them all back in their places, or at the end in their order when the setlist changed meanwhile, and a row dragged to a new place afterwards takes the bar away; the loaded song loaded from the setlist and removed with them stays loaded on its own, and Undo brings back its position and Previous / Next. *(Removing several songs and their Undo are unit tested in removingSeveralSongsCanBeUndoneInPlace, removingSongsNotInTheSetlistGivesNothingToUndo, removingSeveralKeepsTheLoadedSongLoadedOnItsOwn, undoingSeveralBringsBackTheLoadedSongsPlace, removingSeveralWithoutTheLoadedSongLeavesItsSetlist, undoingSeveralAfterTheSetlistChangedPutsThemAtTheEnd, undoingSeveralSkipsASongDeletedMeanwhile and undoingWhenEverySongIsGoneDoesNothing. Seen in the simulator on an iPhone 16: Northern Line alone gave `Removed Northern Line`, and Undo put it back at 7; three songs removed three times, Copper Sky, Waltz for June and Slow Burn, then Midnight Ferry, Waltz for June and Slow Burn, then Harbour Lights, Northern Line and Last Orders, each gave `Removed 3 songs`; Copper Sky, Seven Bridges, Waltz for June and Slow Burn gave `Removed 4 songs`, and Undo put all four back at 2, 3, 5 and 6; with the loaded Seven Bridges removed, alone or among four, the metronome's header showed its name alone, and after Undo it showed `Friday gig · 3 of 8` with Next up Midnight Ferry. Also seen on the iPhone 16 and on an iPhone 17 Pro on iOS 26: Remove of Copper Sky, Waltz for June and Slow Burn took them out at once with `Removed 3 songs` and select mode ended, and Undo put them back at 2, 5 and 6; on both, a row dragged to a new place under five seconds after a swipe's Remove took the bar away as the row dropped. Undo after the setlist changed in another way was not tried on screen.)*
- [x] A setlist's select mode ends with Done, after an action and when the library is closed; entering it takes an Undo bar away; the setlist opens with it off. *(Seen in the simulator on an iPhone 16: Done, Add to setlist, New setlist and Remove each ended it, Remove of every song in Encore leaving `No songs in this setlist` with the large Add song button; closing the library with three songs ticked and opening it again showed Friday gig with its ‹, name and no ticks; Select chosen while `Removed Last Orders` was shown took the bar away.)*
- [ ] A setlist's select mode ends when the setlist becomes empty by other means, and a ticked song that leaves the setlist through sync drops out of the ticks and the title's count. *(The ticks following the setlist's members are unit tested against an in-memory stand-in for iCloud in aTickedSongTakenOutElsewhereLeavesTheSelection, which applies the same keep(only:) the view applies to the setlist's songs. A change from another device cannot be made on one simulator, so neither was seen on screen.)*
- [x] The Add song screen has a search field under its header, filling the line with no +, while the library has songs; it narrows the A–Z list by name by the rules of 8.2, with the New song row always at the end, and when nothing matches the New song row alone with `No matches` centred in the space below it; ticks work while searching; the text is empty each time the screen opens and is emptied when a song is made with New song there. *(The matching is unit tested with the Songs tab's. Seen in the simulator on an iPhone 16, from Friday gig's +: the field filling the line under the header, with the divider below it; `s` leaving Copper Sky, Harbour Lights, Last Orders, Scales in thirds, Seven Bridges and Slow Burn with New song last; Scales in thirds ticked and Copper Sky unticked while searching, and after Done the setlist without Copper Sky and with Scales in thirds at its end; ⓧ emptying the field; `zz` showing the New song row alone, in the place of the first row, with `No matches` centred below it; Cancel in New song leaving `zz`; with `zz` typed, Zed saved from New song with Add to Friday gig switched off, and the field empty with Zed listed and not ticked, then Zoe saved with it on, and the field empty with Zoe listed and ticked; `s` typed, Done and the + again showing an empty field; and an empty library's Add song screen, from a new setlist's Add song button, with its message and no field. The simulator had a hardware keyboard, so the on-screen keyboard, its Search key and scrolling it away were not seen.)*
- [ ] VoiceOver reads the Add song screen's search field "Search songs" and its ⓧ "Clear search". *(VoiceOver is not run by anyone.)*
- [x] New setlist makes an Untitled setlist and opens its view with the name ready for typing; leaving it with no name and no songs drops it, and a name typed and then erased counts as no name. *(Tried in the simulator: Done without typing kept the grey placeholder, and ‹ then dropped the setlist. The dropping rule and refusing an empty name are unit tested. Closing the library from a new setlist was not tried on screen.)*
- [x] Swiping a setlist left on the Setlists tab offers Delete, with confirmation. *(Tried in the simulator.)*
- [x] The Add song screen ticks songs at the right end and explains an empty library with a New song button. *(Both seen in the simulator.)*
- [x] Songs, setlists, the loaded song, and its position in the setlist survive quitting and reopening the app.
- [ ] The library's top-level header is the tab switch and a 40 pt menu button on both tabs, there also with an empty library and with no setlists, and has no New song or New setlist button; VoiceOver reads the button as in section 13. *(In the simulator on an iPhone 16 both tabs showed the tab switch filling the row and the round 40 pt ⋯ button, with no New song or New setlist button, also with an empty library and no setlists. VoiceOver was not switched on.)*
- [x] On both tabs the controls line is the search field, 14 pt and the 36 pt amber +; the + opens New song on the Songs tab and makes a setlist for naming on the Setlists tab; the line is hidden on an empty tab, where the large button in the middle stays. *(Seen in the simulator on an iPhone 16: the line on both tabs, the + opening New song on the Songs tab and a new setlist with the cursor in its name on the Setlists tab, and no line on the empty Songs and Setlists tabs, which showed No songs yet and No setlists yet with the large button.)*
- [x] On both tabs the + is centred under the header's menu button, 20 pt in from the right margin, with 14 pt between the search field and the +; the search field and the tab switch above it have the same width, their left and right edges in line. *(Measured on simulator screenshots on an iPhone 16 at 3 px per pt: on both tabs the header's ⋯ and the + spanned pixels 999–1118 and 1005–1112, centred at 1058.5 px, 40 pt from the screen's right edge. On both tabs the tab switch and the search field each spanned 60–962 px, and the + began at 1005 px. The +'s touch area was not tested at its edges.)*
- [x] The Songs tab's menu holds Select, New song and, after a divider, Sort by with Name, Recently added and Recently played, the current one ticked; with an empty library New song only. The Setlists tab's menu holds New setlist and, after a divider, Sort by with Name and Recently used; with no setlists New setlist only. *(Seen in the simulator on an iPhone 16, each menu opened with the library full and empty. The order of the Setlists tab's options is unit tested in theOrdersHaveTheirTitles, and the full Setlists tab's menu was seen on the iPhone 16 with Name above Recently used and the tick on Name, in the library scene, whose state carries no chosen order.)*
- [x] Each sort order lists as in 8.6: Name A–Z with equal names in order of creation, or for setlists the most recently used first; Recently added newest first; Recently played the latest loaded first and never-loaded songs after them by name; Recently used as in 9.1. A search lists what it finds in the chosen order, a setlist's view keeps its own order and the Add song screen stays A–Z. *(The orders themselves are unit tested in LibraryOrderTests, equal names and equal times included, and the model's lists in orderedSongsFollowTheChosenOrder and orderedSetlistsFollowTheChosenOrder. In the simulator on an iPhone 16 the Songs tab listed by Name, newest first under Recently added, and under Recently played the song just loaded first and the rest by name; a search under Recently played listed its finds in that order; the Setlists tab listed the setlist just made first under Recently used and A–Z under Name; a setlist kept its own order and the Add song screen was A–Z.)*
- [x] The chosen orders are kept per tab on the device, survive quitting and reopening the app, are not synced, and a fresh install starts with Name on both tabs. *(Keeping them is unit tested: theChosenOrdersAreRemembered, which also pins Name as both tabs' starting order, theNewValuesSurviveSavingAndLoading, which keeps a stored Recently used, aStateSavedWithoutTheNewValuesStillLoads, which gives a state stored without an order Name for both, and lastPlayedTimesAndOrdersStayOnTheDevice; orderedSetlistsFollowTheChosenOrder pins that a new model lists setlists A–Z and that using one does not move it. In the simulator on an iPhone 16 the Setlists tab's menu opened with Name ticked in the library scene, whose state carries no chosen order; a fresh install with several setlists listed A–Z was not seen. The Songs tab kept Recently played after closing and reopening the library and after switching tabs.)*
- [ ] A song's last-played time is set when it is tapped in the library, by Previous and Next, by Save as new song and by naming the current settings, and not by tapping the loaded song's own row or by restoring the loaded song at launch; it is kept on the device, survives quitting and reopening the app, is not synced, and is dropped with its song; under Recently played the list keeps its order while it is shown. *(Unit tested, in loadingASongSetsItsLastPlayedTime, previousAndNextSetTheLastPlayedTime, saveAsNewSongAndNamingTheSettingsSetTheTime, tappingTheLoadedSongAgainKeepsItsTime, restoringTheLoadedSongAtLaunchSetsNoTime, deletingASongDropsItsLastPlayedTime, aLastPlayedTimeForAMissingSongIsDropped and lastPlayedTimesAndOrdersStayOnTheDevice. The order taken from the list is unit tested only in the helper the list uses, in aSongPlayedWhileTheListIsShownKeepsItsPlace, theKeptOrderShowsEditsAndDropsDeletedSongs and aSongNotInTheKeptOrderGoesInAtItsLivePlace. In the simulator on an iPhone 16 the list took its order when it appeared and when an order was chosen: choosing Recently played after loading Northern Line put it first at once, after loading Midnight Ferry the reopened library listed Midnight Ferry then Northern Line, and choosing Name went back to A–Z at once. A song's time changing while the list is shown was not seen, as loading from the list closes the sheet; that the list keeps its place then is not verified on screen.)*
- [ ] Search on the Setlists tab narrows the list by name by the rules of 8.2, shows `No matches`, is emptied when the library opens, when the tab is switched and when a setlist is made there, and reads "Search setlists" with VoiceOver. *(The matching is unit tested in aSetlistMatchesLikeASong. In the simulator on an iPhone 16 `fri` left Friday gig, `zz` showed No matches, the text stayed after opening the setlist and coming back with ‹, and switching to Songs and back emptied it. With `fri` typed, the + made a setlist, named Zed, and ‹ came back to an empty field listing Zed and Friday gig; New setlist in the tab's menu, which does the same, was not tried. Emptying when the library opens was not watched, and VoiceOver was not switched on.)*
- [x] Select in the Songs tab's menu enters select mode: the title reads `Select songs`, then the count, Done takes the menu button's place, the search fills the controls line, every row ends in a tick ring, and a hold on a row opens no menu and ticks nothing. *(The title is unit tested in theTitleCountsTheTicks. A hold on a ticked row and on an unticked one opened no menu and changed no tick, on an iPhone 16 on iOS 18 and an iPhone 17 Pro on iOS 26. Seen in the simulator on an iPhone 16: Select in the menu gave `Select songs`, the amber Done, the search alone in the line and a grey ring on every row, and ticking gave `1 selected`, `3 selected` and `4 selected`.)*
- [ ] In select mode a tap ticks or unticks a row and loads nothing, rows are not swiped, the loaded song keeps its usual mark, and a ticked song hidden by a search stays ticked and counted. *(Ticking, unticking and a song that is gone leaving the ticks are unit tested in togglingTwiceUnticks and aSongThatIsGoneLeavesTheSelection. Seen in the simulator on an iPhone 16: taps on a row and on its ring ticked it, a second tap unticked it, tapping the loaded song ticked it with its amber name and `· loaded` kept and the sheet left open, a left swipe showed no Edit or Delete, and `odd` showed only Odd-time drill with the title still `3 selected`. VoiceOver was not switched on, so "selected" on a ticked row was not heard, and a ticked song deleted on another device was not tried on screen.)*
- [ ] The action bar shows Add to setlist and Delete, dimmed and doing nothing while nothing is ticked. *(Seen in the simulator on an iPhone 16: both pills dimmed with nothing ticked, and tapping them opened nothing. VoiceOver was not switched on, so their being read as dimmed was not heard.)*
- [x] On the Songs tab, Add to setlist in select mode lists the setlists most recently used first and New setlist; a setlist gets the ticked songs not yet in it at its end, in the Songs tab's order; New setlist makes a setlist of the ticked songs and opens it for naming; both end select mode without an Undo bar. *(Unit tested: addingSeveralSongsAppendsTheNewOnesInOrder, addingSongsDoesNotCountAsUsingTheSetlist and orderedFollowsTheGivenSongs. Seen in the simulator on an iPhone 16: the menu held the setlists without ticks, the one made last first, then New setlist after a divider; with a search showing only one of the three ticked songs, Friday gig got the two it lacked at its end in A–Z order and the third was not repeated; New setlist opened an Untitled setlist for naming holding the three ticked songs in order; each ended select mode on the Songs tab with no Undo bar.)*
- [x] Delete in select mode asks once, naming the count and the setlists, deletes the ticked songs, follows section 5 for the loaded song, and ends select mode with no Undo. *(Unit tested: theDeletionTextNamesTheCounts, theSetlistCountCountsEachSetlistOnce, deletingSeveralSongsRemovesThemEverywhere and deletingSeveralSongsUnloadsTheLoadedOne. Seen in the simulator on an iPhone 16: `Delete 3 songs?` with no message for songs in no setlist, `Delete 4 songs?` with `They will also be removed from 2 setlists.`, the row menu's own confirmation with one song ticked, and after each Delete the songs gone, select mode ended and no Undo bar; the loaded song deleted alone and, separately, among four ticked songs each left the metronome at its settings with `No song loaded`. While the confirmation for four faded out it still read `Delete 4 songs?` and its setlist line.)*
- [ ] Select mode ends with Done, which puts the keyboard away, after an action and when the sheet is closed, taking every tick away, and the library opens with it off. *(Seen in the simulator on an iPhone 16: Done, Add to setlist, New setlist and Delete each ended it, Done with the on-screen keyboard up for the search put it away, and a sheet closed with a song ticked opened again with the tab switch and no ticks. The mode ending when the library becomes empty was not tried on screen.)*
- [x] Opening a setlist or loading a song from it, Previous and Next included, sets its last-used time only when another setlist's time is the same or later; when it is already the most recently used one nothing changes and nothing is sent to iCloud. *(Unit tested: theMostRecentSetlistKeepsItsTime, anOlderSetlistGetsTheNewTime, aTieStillSetsTheTime, theOnlySetlistKeepsItsTime and aDeletedSetlistDoesNotCount, and against an in-memory stand-in for iCloud steppingThroughASetlistWritesNothingToICloud, which loads a song from the setlist, steps with Next, Next and Previous and opens the setlist without a write.)*
- [x] A setlist's menu button is 40 pt, and in its menu Add song, which opens the Add song screen, comes before Rename setlist, Duplicate setlist and Delete setlist, in that order. *(Seen in the simulator on an iPhone 16: the header's ⋯ 40 pt, the menu in that order, and Add song opening the Add song screen.)*
- [x] A setlist's menu starts with Select, before Add song, in a setlist with songs; an empty setlist's menu has no Select. *(Seen in the simulator on an iPhone 16: Friday gig's menu read Select, Add song, Rename setlist, Duplicate setlist and Delete setlist, and Encore's menu, with its songs removed, started with Add song.)*

Settings and click sounds:

- [ ] Settings in the header menu opens the settings sheet when stopped and when playing; Done, swiping down and tapping outside close it. *(Done was tried in the simulator; swiping and tapping outside are the system's sheet behaviour and were not tried. On an iPhone 17 Pro, stopped, Settings in the header menu opened the settings sheet; opening it while playing was not tried.)*
- [x] Each of the seven sounds can be selected; the choice survives quitting and reopening the app, and a fresh install starts with Digital. *(Unit tested, and selecting while stopped and while playing was tried in the simulator.)*
- [ ] When stopped, tapping a sound plays an accented and a normal click; when playing, the new sound starts with the next scheduled beat. *(The model's rules are unit tested and playing carries on when the sound changes; hearing the preview and the switch needs a listener.)*
- [x] Every sound meets the loudness, attack and length rules in 11.1. *(Unit tested on the generated buffers at 48 and 44.1 kHz.)*
- [ ] In Metronome content, Previous and Next sit at the ends of the transport row only for a song loaded from a setlist, as 44 pt arrows against a bar, and Next is dimmed at the last song. *(Not built yet.)*
- [ ] The Haptics switch turns every haptic off and back on, stopped and playing; it survives quitting and reopening the app, and a fresh install starts with it on. *(The rules are unit tested and the switch was tried in the simulator; feeling the haptics stop needs a real iPhone.)*
- [ ] With Keep screen awake on, the screen does not dim or lock while the app is open and stopped; with it off, it does so only while playing. The switch survives quitting and reopening the app, and a fresh install starts with it off. *(The rules are unit tested. In the simulator the switch was tried on and off, stopped and playing, and across a relaunch, reading the app's idle-timer flag each time. The simulator never auto-locks, so the screen actually staying on needs a real iPhone.)*
- [ ] All seven sounds are equally loud by ear, and accented beats are clearly different from normal ones, on the phone's speaker and on headphones. *(Needs a listener and a real iPhone.)*

iCloud sync:

- [ ] The iCloud card looks as in 6.10 in every state, and the settings sheet scrolls when it is taller than the screen. *(The off state and Not signed in to iCloud were tried in the simulator, and the sheet scrolls under the fixed title on an iPhone 17 Pro and an iPhone SE. The simulator is not signed in to iCloud, so Syncing…, Up to date, iCloud storage is full and Update the app to keep syncing were not seen on screen.)*
- [x] Sync is off on a fresh install, and the switch survives quitting and reopening the app. *(Unit tested.)*
- [ ] Switching sync on for a second device brings the first device's songs and setlists next to its own, and later changes on either device reach the other. *(Needs two devices on one iCloud account. Only a stand-in for iCloud has been used.)*
- [x] Copies are combined as in 5.1: per part of a song, per song in a setlist, order, an edit after a deletion, and an item missing from iCloud. *(Unit tested against an in-memory stand-in for iCloud.)*
- [ ] When changes arrive, the metronome keeps its settings, a changed loaded song counts as edited, and open lists update in place. *(The metronome keeping its settings, the song counting as edited, a deleted loaded song, setlist or filter being cleared, and no haptic are unit tested. Open lists updating in place, and the setlist editor closing when its setlist is deleted elsewhere, need a change arriving from a second device.)*
- [x] Switching sync off leaves the library on the device and the other devices untouched; switching it on again combines what changed meanwhile. *(Unit tested against an in-memory stand-in for iCloud.)*
- [ ] The last device to switch sync off empties iCloud, and a syncing device that finds iCloud emptied puts its library back. *(Unit tested against an in-memory stand-in for iCloud. The clean-up reaching real iCloud has not been seen.)*
- [ ] The status line shows not signed in, iCloud full and newer format as in 6.10. *(Every status text and the line below the card are unit tested, and Not signed in to iCloud was seen in the simulator. iCloud storage is full and Update the app to keep syncing were not seen on screen.)*
- [x] A part or item the app does not know survives combining and being written back, and a higher format number stops syncing without changing iCloud. *(Unit tested.)*
- [x] A library made before sync existed is kept in full when the app is updated. *(Unit tested.)*
- [ ] The app can tell a signed-in device from a signed-out one, and one iCloud account from another. *(Needs a device signed in to iCloud.)*

Backing tracks:

- [ ] The song sheet's Backing track row attaches an audio file from the Files picker, replaces it and removes it, and the change is kept only when the sheet is saved; a file that cannot be played shows `This file can't be played` and is not attached; a file that cannot be kept on the device saves nothing, leaves the sheet open and shows `The track couldn't be saved`. *(Attaching, replacing, removing, keeping the change until the sheet is saved and refusing a file that cannot be read are unit tested, and so is saving nothing when the file cannot be stored, in New song, Save as new song and Edit song. That alert and the sheet staying open were not seen, as a full phone cannot be made in the simulator. In the simulator on an iPhone 17 Pro, Edit song for a song with a track showed the icon, the file name and × at the right, as in 10.3; × turned the row into `Add backing track` and made `Save changes` ready, and Cancel kept the track. A song without a track showed `Add backing track` with no ×. The Files picker and the `This file can't be played` alert need the picker driven by hand.)*
- [x] A newly attached file gets its offset where its level first rises above −40 dBFS, and a count-in of 2 bars; replacing the file sets a new offset and keeps the count-in. *(Unit tested on generated files at 44.1 and 48 kHz, a quiet lead-in below the threshold included.)*
- [ ] The attached file keeps playing after the original is moved or deleted, and it is restored with a device backup. *(Copying the picked file into the app's own storage is unit tested. Moving or deleting the original after picking it needs the Files picker driven by hand, and the backup restore a real iPhone.)*
- [ ] With Backing tracks on, a loaded song with a backing track shows Track content in the player card (6.12), the same stopped and playing: the file-name row with the Sync pill, the progress bar and the transport row, 10 pt apart in the 188 pt card, with no next-up line; the rest of the screen is as for any song; other songs, every song with Backing tracks off, and nothing loaded show Metronome content. *(Not built yet.)*
- [ ] While a track is in use the dial turns, and the dial, − / +, Tap tempo and the tempo sheet set the track's tempo, stopped and playing, with the click following the grid at once; the change is saved into the song at once, never brings up the badge, is left alone by Save changes and Revert, and leaves the metronome's tempo as it is; the tempo sheet opened from the dial shows the track's tempo; with the file missing they set the track's tempo too. *(Not built yet.)*
- [ ] While a track is in use the time signature row opens the picker, and another signature brings up the badge like an accent change, is saved with Save changes and set back with Revert, and while playing has its bar worked out from the offset. *(Not built yet.)*
- [ ] Only the Sync pill opens Sync mode, stopped and playing; a tap on the dial opens the tempo sheet in every mode. *(Not built yet.)*
- [ ] While playing, the dial's number marks every beat, accented or not, count-in included, the same in every mode: the round amber glow flashes behind the number and the number pulses to 1.04, both settling within half the beat interval, and the number stays dial white throughout; with Reduce Motion on the glow stays and the pulse is left out; stopped, there is no glow and the number is at its full size. *(Not built yet.)*
- [ ] The Backing tracks switch is in the header only for a song with a backing track, file present or missing, between the title and the Sound button; it looks as in 6.1 on and off, is dimmed and does nothing while playing, and leaves the header of a song without a track as it is. *(Not built yet for the look of 6.1. Being there only for a song with a backing track, dimmed while playing where a tap changed nothing, and gone for a song without a track were seen in the simulator on an iPhone 17 Pro; doing nothing while playing is unit tested.)*
- [ ] Backing tracks is on on a fresh install, survives quitting and reopening the app, is not synced, and changes only when tapped: not by loading a song, Unload, the song sheet or changes from other devices. *(On at first launch, kept across a relaunch, unchanged by loading a song, by Unload, and by a track attached or replaced on another device arriving are unit tested. Not being synced and the song sheet leaving it as it is have no test of their own.)*
- [ ] With Backing tracks off, a song with a backing track is a plain metronome: Metronome content, no count-in, no stop at the track's end, the file not opened, no Sync; loading, unloading or editing a song with a track never stops playback. *(Start with the file not opened and without the track, and, while playing, loading a song with a track, Unload, Save as new song from a song whose file is here, naming the settings with a picked file, and replacing the loaded song's file are unit tested; the plain layout without Sync was seen in the simulator. No stop at the track's end follows from the file not being played but has no test of its own.)*
- [x] Turning Backing tracks off and on again keeps the track's position until another song is loaded. *(Unit tested. In the simulator on an iPhone 17 Pro, stopped at 0:18, off and on again showed 0:18.)*
- [ ] Track content shows the file-name row with the icon, the file name and the Sync pill at its right end, the progress bar across its width and the transport row, as in 6.12; play / stop looks and works as Start / Stop; Previous song and Next song follow 7.6; outside a setlist the three remaining buttons stand centred; with the file missing the file-name row shows the expected file name in amber and `Choose file` in the Sync pill's place, with no Sync pill, no `Track missing` and nothing else on the card moving or changing size, and the bar, Rewind and Fast-forward are dimmed, while the dial and the tempo controls keep working. *(Not built yet for the 188 pt card without the next-up line, and for the dial with the file missing. Seen in the simulator on an iPhone 17 Pro and an iPhone SE in a 192 pt card: the file-name row with the icon and the name, the bar and the transport row. On an iPhone 17 Pro, stopped: in the trackScreen scene the Sync pill at the row's right end; in the trackMissing scene the name in amber with `Choose file` in the pill's place, no Sync pill and no `Track missing`, and the bar, Rewind and Fast-forward dimmed; with a long file name, the name was cut with an ellipsis and both pills kept their places. That nothing else on the card moves or changes size with the file missing was not measured. Play / stop working as Start / Stop was seen only with beats from a timer in place of the audio engine; the three buttons centred outside a setlist and Previous song and Next song on this card were not looked at on screen.)*
- [ ] With the file missing, `Choose file` on the player card opens the Files picker, stopped and playing; the picked file is stored at once under the track's identifier, the track keeping its tempo, offset, count-in and mix; a file with the name the track carries changes nothing else and sends nothing, and one with another name gives the track its name, which syncs with the backing track; the song is not edited; while playing, playback stops and the position is 0:00; the card then shows the picked file's name in dial white and the Sync pill, the bar, Rewind and Fast-forward working, and the pill and the dial opening Sync mode; closing the picker changes nothing, and a file that cannot be played or kept shows the song sheet's alert and changes nothing; VoiceOver reads the row as "Track missing, <file name>" and the button as "Choose file". *(Unit tested: choosingAFileFromTheCardStoresItAtOnce, with the name the track carries, leaving the library as it was and the song not edited; choosingAFileWithAnotherNameFromTheCardRenamesTheTrack, keeping the identifier, tempo, offset, count-in and mix; choosingAFileWhilePlayingStopsPlayback, at 0:00; choosingAFileThatCannotBeStoredChangesNothing; choosingAFileWhenTheTrackIsNotMissingDoesNothing; and choosingAFileForAnotherTrackDoesNothing, for a pick made for a track that is no longer loaded. The renamed track part being stamped to sync is unit tested through the song sheet in pickingAFileWithAnotherNameRenamesTheTrackAndKeepsTheRest. In the simulator on an iPhone 17 Pro, stopped, in the trackMissing scene: `Choose file`, and a tap 8 pt above it, opened the Files picker; closing it with × left the card as it was, with no alert; picking everlong, a file with another name, made the card show `everlong.wav` in dial white, the Sync pill, the bar at 0:00 / 4:51 and Rewind and Fast-forward undimmed. Not tried on screen: `Choose file` while playing, the pill and the dial opening Sync mode after a pick, the two alerts, the pill dimmed and doing nothing while a file is read, changing song while a file is read, and VoiceOver.)*
- [ ] Start at 0:00 plays the chosen count-in of click only, and the track's beat 1 at the offset lands on the beat after it; with count-in Off the track starts at once and the click joins at the offset. *(Where the file and the clicks start, with 1 bar, 2 bars and Off, is unit tested, and the beat times to within a sample over ten minutes. In the simulator Start at 0:00 showed `Count-in` with the tiles lighting, then the bar moving. Hearing the track's beat 1 at the offset land on the beat after the count-in needs a listener.)*
- [x] While the count-in's click sounds before the file has started, the knob is at 0:00 and the elapsed time reads `Count-in`; once the file starts, the bar shows its real position; with an offset longer than the count-in, `Count-in` is never shown. Stop before the file has started leaves 0:00, and after it keeps the position, except that within the first second it goes to 0:00 and the next Start counts in. *(Unit tested, an offset longer than the count-in and Stop at 0.4 and 1.2 seconds included; the place heard just behind 0:00 after a start or a jump without a count-in in countInOffNeverShowsTheCountIn, anOffsetLongerThanTheCountInShowsNoCountIn, startingFromAKeptPositionShowsNoCountIn, toTheBeginningWhilePlayingShowsNoCountIn and rewindingToZeroWhilePlayingShowsNoCountIn, and with one in theCountInShowsUntilTheFileIsHeard and startingAgainAtZeroShowsTheCountInAgain. In the simulator on an iPhone 17 Pro the elapsed time read `Count-in` in amber with the knob at the start, then the bar and the time followed the file; Stop at 0:11 kept 0:11. Stop during the count-in was not tried on screen.)*
- [x] Start away from 0:00 plays at once without a count-in, and the click joins on the right beat of the right bar. *(Unit tested. In the simulator Start at 0:15 and a drag to 0:02 while playing went on at once with no `Count-in`; the click joining on the right beat was not checked by ear.)*
- [x] Stop keeps the position; the end of the track stops playback and goes back to 0:00, and in a setlist the next song is not loaded. *(Unit tested. In the simulator on an iPhone 17 Pro, with the song loaded from a setlist, Stop kept the position, and at the end of the 30-second file, played from 0:00 with the count-in, playback stopped, the bar went back to 0:00 and the same song stayed loaded.)*
- [x] Rewind and Fast-forward move 15 seconds, stopped and playing; Rewind near the start goes to 0:00, and Fast-forward is dimmed in the last 15 seconds. *(Unit tested, playing included. In the simulator, stopped, Fast-forward took 0:11 to 0:26 and was then dimmed, Rewind took it back to 0:11 and then to 0:00. Skipping while playing was not tried on screen.)*
- [ ] Dragging the knob moves the position when the finger lifts, and playback carries on from there without a count-in; a drag to within the first second lands on 0:00. *(In the simulator a drag while stopped moved the position to 0:17, and a drag while playing to 0:02 carried on from there without `Count-in`. The model's seek landing on 0:00 below one second is unit tested. There is no unit test of the drag itself, whether the position changes only when the finger lifts was not watched, and a drag carrying on across Start or Stop was not tried on screen.)*
- [x] Changing the tempo of the grid while playing keeps the click on the track's grid, with no beats bunched up; changing the time signature works the bar out from the offset. *(Unit tested on the beat schedule; not checked by ear.)*
- [ ] Mute silences only the click; the track, beat effects and haptics carry on. *(The engine muting the click while the track plays on is unit tested. Hearing it needs a listener, and feeling the haptics a real iPhone.)*
- [x] With Backing tracks on, loading a song while playing stops playback when either song has a playable backing track, and keeps playing between two songs without one; a song whose file is missing counts as one without a track. Unload stops a playing song with a playable track. With Backing tracks off, neither stops playback. *(Unit tested: with Backing tracks on, loading a song with a track and leaving one, two songs without tracks, a missing file counting as none, and Unload stopping only a playing track; with it off, loading a song with a track and Unload while playing.)*
- [ ] A backing track attached on another device arrives for the loaded song with its file missing with Backing tracks on, and only the switch with it off, and playback carries on; a track removed or replaced elsewhere stops playback only when it was in use, its file was here and it was playing. *(A track attached elsewhere, a playing track removed or replaced elsewhere, and the loaded song deleted elsewhere while its track plays are unit tested against an in-memory stand-in for iCloud, none of them with a haptic, and with Backing tracks off a track attached or replaced elsewhere arriving while playing is unit tested to leave playback and the switch as they are, with no haptic, the attached one giving the song a track and so the switch. A track removed elsewhere whose file was not here is not tested, and none of it has been seen between two devices on one iCloud account.)*
- [ ] In Edit song for the loaded song, with Backing tracks on, attaching, replacing or picking a file for a missing track stops playback and sets 0:00, and so does removing a playable track; removing a track whose file is missing does not stop playback. With Backing tracks off none of them stop playback. *(Replacing the file, removing a playable track and removing one whose file is missing are unit tested with Backing tracks on, and replacing the file while playing with it off. Attaching a file to a loaded song that had none, and picking one for a missing track, while playing, are not, and need the Files picker driven by hand. Attaching, picking and removing with Backing tracks off are not tested.)*
- [ ] An interruption stops playback and keeps the position, a position within the first second becoming 0:00. *(The model's side is unit tested against a stand-in for the audio engine: playback stops, the position is kept, and below one second it becomes 0:00. The audio engine noticing a real interruption, such as a call, and keeping the position when the system stops it before the interruption is reported, need a real iPhone.)*
- [ ] The Sync pill on the player card slides up Sync mode as a full-height sheet over the metronome screen, stopped and playing, and playback carries on; `Done` and a swipe down on the top of the sheet close it, back to the metronome screen, leaving playback as it is; the time signature picker and the tempo sheet open over it and return to it; Sync mode is not kept between launches. *(Unit tested: enteringAndLeavingLeavesPlaybackAsItIs and syncModeIsOffAtLaunch. In the simulator on an iPhone 17 Pro, stopped (ts-sync-pro.png, ts-picker-over-sync.png, ts-tempo-over-sync.png): the sheet with its grabber over the track screen; a swipe down from the title row closed it; the time signature picker and the tempo sheet opened over it and closed back to it; `Done` closed it. Stopped, a tap on the Sync pill opened it, and after `Done` the pill opened it again. Opening it while playing was not tried; the sheet was seen playing only in a scene that opens in Sync mode.)*
- [ ] A drag that starts on a pad, a stepper or the mix slider does not move or close the Sync mode sheet. *(On an iPhone 17 Pro in the simulator a drag 150 pt down from Tap tempo counted one tap and one from the + of Offset stepped the offset once, and the sheet was in place afterwards. The sheet during the drag, and the mix slider, were not seen. Needs a phone.)*
- [ ] When Sync mode ends by itself, its sheet closes, and a tempo sheet or time signature picker open over it closes with it without changes. *(Sync mode ending is unit tested: syncModeEndsWhenTheTrackIsRemovedElsewhere, syncModeEndsWhenTheTrackIsReplacedElsewhere and syncModeEndsWhenTheSongIsDeletedElsewhere; the sheet is shown from that state. The sheet closing, with or without a sheet over it, was not seen, as it needs a change from another device.)*
- [ ] Sync mode looks as in 6.13: a sheet on surface with the grabber, its title row with `Sync`, the file name and `Done`; the time signature row and the idle tiles on surface raised as in the song sheet, the Tap tempo and Tap on beat 1 pads side by side above the Tempo and Offset steppers, whose pills are surface raised with − and + in surface selected, the count-in on surface raised with the selected option in surface selected, the mix row, and the surface-raised playback card, with Rewind, Fast-forward and the unplayed part of the progress line in surface selected, no file-name row, no Previous song or Next song and no next-up line. *(The colours were seen in the simulator on an iPhone 17 Pro, stopped and playing: the sheet on surface, as the library sheet; the time signature row, idle tiles, stepper pills, count-in options and playback card one step lighter; and − and +, the selected count-in option, Rewind, Fast-forward and the unplayed part of the line lighter again. The layout was seen in the simulator stopped on an iPhone 17 Pro in 4/4 and on an iPhone SE in 4/4 and 9/8, where the mix row, and in 9/8 the count-in too, were below the visible part of the scrolling area. Seen playing only on an iPhone 17 Pro, with beats and file time from a timer in place of the audio engine, during `Count-in` and after it, with the stop square on the playback card. Not seen: an iPhone SE playing, and anything with the real audio engine, which aborts on Start in this simulator.)*
- [ ] Sync mode fits on an iPhone 17 Pro without scrolling, with 188 pt pads, or 166 pt in 9/8 and 12/8; on an iPhone SE the tiles drop to 56 pt, the pads are 72 pt and the area between the title row and the playback card scrolls by 21 pt, or 63 pt in 9/8 and 12/8; pads shorter than 120 pt leave out the hand icon and keep the title centred. *(The sheet's content heights, 778 pt on an iPhone 17 Pro and 637 pt on an iPhone SE, were measured in the simulator, and the sizes for them are unit tested: syncModeOnAnIPhone17Pro and syncModeOnAnIPhoneSE, with the tiles shrinking only below 72 pt pads (tallTilesStayWhileThePadHas72), the hand icon below 120 pt (theHandIconNeeds120) and the parts filling the height or scrolling by the rest (syncModeFitsOrScrollsByTheRest). Seen in the simulator: on an iPhone 17 Pro in 4/4 without scrolling and with the hand icon; on an iPhone SE in 4/4 and 9/8 with short pads, titles centred, no hand icon and the area cut at the playback card. The area scrolling was not dragged, 12/8 was not on screen, and with Display Zoom the sheet's height was not measured.)*
- [x] In Sync mode play / stop works as Start / Stop, counting in at 0:00; To the beginning goes to 0:00, playing on without a count-in while playing; To the end stops playback and goes back to 0:00 without loading the next song. *(Unit tested: playInSyncModeCountsInAtZero, toTheBeginningWhileStoppedGoesToZero, toTheBeginningWhilePlayingCarriesOnWithoutCountIn, toTheBeginningDuringTheCountInChangesNothing and toTheEndStopsAndGoesToZero, which keeps the loaded song. In the simulator on an iPhone 17 Pro, with a timer in place of the audio engine, Start at 0:00 showed `Count-in` with Tap on beat 1 dimmed; To the beginning while playing went to 0:00 and played on without `Count-in`; To the end while playing stopped at 0:00 with the song still loaded; stopped, both went from 0:15 to 0:00.)*
- [x] A time signature or accents set in Sync mode are saved into the song at once and shared with the plain metronome, without making the song edited, and an unsaved metronome tempo stays unsaved. *(Unit tested: aTimeSignatureInSyncModeIsSavedAtOnce, anAccentInSyncModeIsSavedAtOnce and syncModeSavesAnEarlierAccentAndLeavesTheMetronomeTempo.)*
- [x] Tempo − / + in Sync mode step the track's tempo by 1 BPM and repeat when held, and offset − / + step 0.01 s, the click following at once while playing; the metronome's tempo does not change. *(Unit tested: theTrackTempoStepsByOne, aTrackTempoStepReachesThePlayingEngine and aNudgedOffsetMovesLaterBeats. In the simulator on an iPhone 17 Pro, with a timer in place of the audio engine, holding − on Tempo for 1.5 s took 108 to 95 and holding + on Offset took 0.72 to 0.84, and after `Done` the header showed no unsaved changes. The click following was not checked by ear.)*
- [x] The track's tempo, offset, count-in and mix set in Sync mode are saved into the song at once, written once the changes pause and on `Done` or when the app leaves the foreground, and never make the song edited. *(Unit tested: severalTrackTempoStepsSaveOnce, severalSyncModeChangesSaveOnce, nudgingTheOffsetSavesWithoutEdited, countInAndMixAreSaved, doneSavesAWaitingChangeAtOnce and leavingTheForegroundKeepsSyncModeAndSaves.)*
- [ ] The mix slider turns the track down by up to 24 dB towards Click and the click by up to 24 dB towards Track, evenly in decibels, with both at full level at the centre and neither end silent; the count-in's clicks follow the same level, and Mute still silences the click completely. *(The gains at the centre, at both ends and in between, and the count-in starting at the same click level, are unit tested, and Mute goes to the engine apart from the mix. Hearing the levels, and Mute silencing the click completely, needs a listener.)*
- [ ] The mix knob catches at the centre with a selection tick, applies at once while playing, is saved into the song without making it edited, and syncs to other devices with the backing track; a new track starts at the centre, and replacing the file or picking one for a missing track keeps the mix. *(The tick on arriving at the centre, the new gains going to the engine, saving without making the song edited, a new track at the centre, keeping the mix on replacing or picking a file, and a mix arriving by sync reaching a playing engine are unit tested; a mix set by the knob was unit tested only while stopped. In the simulator on an iPhone 17 Pro, stopped, the knob dragged towards Track drew the amber part from the centre to the knob, and let go 4 pt right of the centre it rested on the centre with no amber. Hearing the mix change at once while playing needs a listener, feeling the tick a real iPhone, and syncing between two devices on one iCloud account was not tried.)*
- [ ] Click and a full-level track together do not distort, by ear, on the speaker and on headphones. *(Needs a listener and a real iPhone.)*
- [ ] Tap on beat 1 sets only the offset: the tapped place moved back by whole bars at the track's tempo and the time signature to the earliest place not before 0:00, rounded to 0.01 s, a place on or rounding to a whole bar giving 0.00; every tap sets it afresh and the latest wins; the tempo never changes; output delay such as Bluetooth is allowed for; while stopped or counting in it is dimmed and a touch does nothing and plays no haptic. *(Unit tested: tapOnBeat1SetsTheOffsetFromTheHeardPlace, tapOnBeat1NeverChangesTheTempo, theLatestTapOnBeat1Wins, aTapOnBeat1AtTheSameOffsetMovesNothing, tapOnBeat1DoesNothingWhileStoppedOrCountingIn and tapOnBeat1NeedsATrackInUse, and the fold in theFoldGoesBackWholeBars, anExactBarFoldsToZero, aFoldThatRoundsToAWholeBarGivesZero, theFoldWithABarLongerThanTheTap and theFoldAtTheSlowestTempo. In the simulator on an iPhone 17 Pro, with beats and file time from a timer in place of the audio engine, the pad was dimmed while stopped and during `Count-in` and not once the file played; taps while playing took the offset from 0.50 to 1.38 and then 1.28 with the tempo staying 120. Allowing for Bluetooth delay needs a real iPhone with Bluetooth headphones.)*
- [x] Tap tempo sets the track's tempo by the rules of 7.1, the average of the last four intervals, a new series after a 2 second pause and within 30…300, with a selection tick per tap, stopped and playing; it is never dimmed, its title reads `Tap again` while a series is open and `Tap tempo` again after it, and the metronome's tempo does not change. *(Unit tested: tapTempoSetsTheTracksTempo, tapTempoAveragesTheLastFourIntervals, aPauseStartsANewTapTempoSeries, tapTempoStaysInRange, tapTempoReachesThePlayingEngine, tapTempoTicksForEveryTapWhilePlaying, tapTempoHasASeriesOfItsOwn and tapTempoNeedsATrackInUse. Seen in the simulator on an iPhone 17 Pro, with beats and file time from a timer in place of the audio engine: at full strength stopped (tt-sync-stopped.png); reading `Tap again` at full strength during `Count-in` after a tap (tp-pad-tap-again-count-in.png); reading `Tap tempo` at full strength while playing a few seconds later (tp-pad-back-playing.png); and stopped, quick taps took the stepper from 120 to 300 (tt-tap-tempo.png).)*
- [x] Tapping the tempo value in Sync mode opens the tempo sheet with the track's tempo; `Set tempo` sets the track's tempo within 30…300, with a selection tick only when it changes, and Cancel closes the sheet without changes; the metronome's tempo does not change. *(Unit tested: theTypedTempoSetsTheTracksTempo, theTypedTempoTicksOnlyWhenItChanges, theTypedTempoIsClamped, theTypedTempoReachesThePlayingEngine and theTypedTempoNeedsATrackInUse. Seen in the simulator on an iPhone 17 Pro: the sheet opened from the value with the track's tempo, 120, dimmed (ts-tempo-over-sync.png), 140 typed (tt-typed-sheet.png), and `Set tempo` showing 140 in the stepper (tt-typed-set.png); with the track at 120, 99 typed (tp-cancel-1-typed.png) and Cancel left 120 (tp-cancel-2-after.png).)*
- [ ] A tempo set by Tap tempo or the tempo sheet, and an offset set by Tap on beat 1, are saved into the song at once without making it edited and written once the taps pause, and the click follows at once. *(Unit tested: severalTapTempoTapsSaveOnce, severalTapsOnBeat1SaveOnce, tapTempoSetsTheTracksTempo, theTypedTempoSetsTheTracksTempo, tapOnBeat1SetsTheOffsetFromTheHeardPlace, tapTempoReachesThePlayingEngine and theTypedTempoReachesThePlayingEngine. Hearing the click follow needs a listener, and feeling the ticks a real iPhone.)*
- [ ] Click and track stay together to the sample over a whole file at 30, 120 and 300 BPM, on the speaker and over Bluetooth. *(The beat times are unit tested to within a sample over ten minutes at 44.1 and 48 kHz. Hearing it needs a listener and a real iPhone, on the speaker and over Bluetooth.)*
- [ ] On a second device the song arrives with its track missing; Start plays the click alone; picking a file there with the name the track carries sends nothing, and one with another name gives the track that name, which syncs and changes only the name on the other devices; removing the track syncs; a device deletes a file no song refers to. *(The track arriving missing, the click alone, removing the track syncing and a device deleting a file no song refers to are unit tested against an in-memory stand-in for iCloud. Picking a file is unit tested on one device: with the name the track carries, pickingAFileWithTheSameNameForAMissingTrackChangesNoPart and choosingAFileFromTheCardStoresItAtOnce leave the library as it was, so nothing is sent; with another name, pickingAFileWithAnotherNameRenamesTheTrackAndKeepsTheRest gives the track that name and stamps its track part, leaving the name, tempo and meter parts, and choosingAFileWithAnotherNameFromTheCardRenamesTheTrack does the same from the card; the song sheet shows the picked name in aFilePickedForAMissingTrackShowsThePickedName. None of it has been seen between two devices, and a rename reaching another device has not been tried.)*
- [ ] Songs with a backing track show the music-note mark in every song list, also with the file missing. *(Seen in the simulator on the Songs tab, in a setlist, loaded and not, and on the Add song screen. A song whose file is missing was not seen.)*
- [ ] A song's backing track has its own tempo: with the track in use the click plays at it and the dial shows it, and with Backing tracks off, or Unload, the song plays at the metronome's tempo; the switch swaps the tempo in effect without changing either value. *(Unit tested: theClickPlaysAtTheTracksTempo, switchedOffTheClickPlaysAtTheMetronomesTempo, unloadPlaysAtTheMetronomesTempo and theSwitchSwapsTheTempoWithoutChangingEither. In the simulator the track screen's number showed the track's tempo after it was stepped in Sync mode; in the trackOtherTempo scene, with the song at 120 and its track at 168, the track screen's dial showed 168, and switching Backing tracks off with the header's button brought the plain dial at 120. The click at that tempo was not checked by ear.)*
- [x] While a track is in use an unsaved change of the metronome's tempo alone does not make the song edited; it is kept and the song is edited again when the track stops being in use; an accent toggled while a track is in use makes it edited as without one. *(Unit tested: anUnsavedMetronomeTempoIsNotEditedWhileTheTrackIsInUse and anAccentOnTheTrackScreenShowsSave.)*
- [x] Attaching a track gives it the song's tempo as saved with the sheet; replacing the file and picking one for a missing track keep the track's tempo; a track stored without a tempo takes the song's tempo, and filling it in sends nothing; the track's tempo syncs with the rest of the backing-track part. *(Unit tested: attachingATrackGivesItTheSongsTempoAsSaved, replacingTheFileKeepsTheTracksTempo, pickingAFileForAMissingTrackKeepsItsTempo, aTrackStoredWithoutATempoTakesTheSongsTempo, fillingInTheTempoStampsNothing, aTrackFromAnEarlierBuildIsReadWithoutBeingWritten and aTrackTempoArrivingFromAnotherDeviceReachesThePlayingEngine, the last against an in-memory stand-in for iCloud; not seen between two devices.)*
- [x] Sync mode ends by itself when the track is removed or replaced, or the song deleted, on another device. *(Unit tested against an in-memory stand-in for iCloud: syncModeEndsWhenTheTrackIsRemovedElsewhere, syncModeEndsWhenTheTrackIsReplacedElsewhere and syncModeEndsWhenTheSongIsDeletedElsewhere; not seen between two devices.)*
- [ ] VoiceOver reads the Backing tracks switch, the dial while a track is in use, Track content with its Sync pill, Sync mode and the Backing track row as in section 13, and every new control has a 44 × 44 pt touch area. *(The mix's spoken values and the spoken times are unit tested. VoiceOver was not switched on. The touch areas were not measured; in the simulator a tap 8 pt above the Sync pill and one 8 pt above `Choose file` each worked.)*

Stage mode:

- [x] Stage mode is in the header menu only while the loaded song was loaded from a setlist, and first in a setlist's menu, followed by a divider; from the setlist's menu the library sheet closes and stage mode covers the screen. *(Where the header menu puts it is unit tested: aSetlistSongOffersStageModeBeforeSettings, anEditedSetlistSongKeepsSaveFirst and nothingLoadedNeverOffersStageMode. In the simulator on an iPhone 17 Pro the header menu of a song loaded from a setlist showed Stage mode after Unload, and that of a song on its own showed none; the setlist's menu showed Stage mode first, then a divider, then Select and the rest. From the setlist's menu the library sheet closed and stage mode covered the screen in each of 13 tries, and from the header menu it covered the metronome screen.)*
- [x] The header menu's Stage mode is dimmed while playing, and the setlist's is dimmed in an empty setlist. *(Seen in the simulator on an iPhone 17 Pro: in the header menu after Start, and in the menu of an empty setlist. That stage mode cannot be entered while playing or for an empty setlist is unit tested in onlyAStoppedSetlistWithSongsCanBeEntered and stageModeCannotBeEnteredWhilePlayingOrEmpty.)*
- [ ] The setlist's Stage mode is dimmed while playing, and a dimmed Stage mode item does nothing. *(The rule both items follow, that stage mode is not entered while playing or for an empty setlist, is unit tested in onlyAStoppedSetlistWithSongsCanBeEntered and stageModeCannotBeEnteredWhilePlayingOrEmpty. The setlist's menu was not opened while playing, and a dimmed item was not tapped.)*
- [x] On entering, the loaded song's tile is the active tile when it was loaded from that setlist, and no tile is marked when it came on its own or from another setlist or nothing is loaded; entering leaves the loaded song and its unsaved edits as they are and does not start playback. *(Unit tested: theLoadedSongIsActiveWhenItCameFromThisSetlist, noSongIsActiveWhenTheLoadedSongCameFromElsewhere, enteringFromTheLoadedSetlistMarksTheLoadedSong, enteringWithASongFromElsewhereMarksNothing, enteringWithASongFromAnotherSetlistMarksNothing, enteringWithNothingLoadedMarksNothing and enteringChangesNothingOnTheMetronome. In the simulator on an iPhone 17 Pro, with Seven Bridges loaded from the setlist, its tile was the only one marked on entering. Entering with no active tile was not seen on screen.)*
- [ ] Entering leaves the settings, the Backing tracks switch and mute as they are. *(Not tested, and not looked at on screen.)*
- [x] Stage mode looks as in 9.4: the title row with the setlist's name, `Stage mode` and `Done`; two columns of 112 pt surface tiles 10 pt apart with number, name, tempo and time signature and the track mark; a two-line name making its row 120 pt; the other tiles and `Done` at 40 % while a tile plays. *(Seen in the simulator on an iPhone 17 Pro and on an iPhone SE (3rd generation) with iOS 18, stopped and playing, with beats and file time from a timer in place of the audio engine. Measured on screenshots: on the iPhone 17 Pro the grid 20 pt below the title row, tiles 172 pt wide with 24 pt margins and 10 pt between the columns, single-line rows 112 pt tall and 10 pt apart, and the row in which Harbour Lights took two lines 120 pt tall in both columns; on the iPhone SE tiles 158.5 pt wide with 24 pt margins, and every row 120 pt, as each had a two-line name. The 40 % was judged by eye only. Nothing was tried on a real iPhone.)*
- [x] Stopped, the active tile is in amber tint with a 1.5 pt amber outline and an amber number, with no label, and keeps its track mark in muted. *(Unit tested: stoppedTheActiveTileIsMarked and noActiveSongMarksNothing. Seen in the simulator on an iPhone 17 Pro: Seven Bridges' tile on entering, and Copper Sky's after it was stopped, with its track mark in muted. The outline's width was judged by eye only.)*
- [x] With Backing tracks on, a song with a backing track shows the track mark, whether or not its file is here; with it off, no tile shows it, idle, active or playing, and no tile reads "backing track". *(Unit tested: aTileWithATrackShowsTheMarkOnlyWithBackingTracksOn, withBackingTracksOffATileDoesNotReadBackingTrack, theTrackMarksFollowTheBackingTracksSwitch and aTrackWhoseFileIsMissingStillShowsTheMark. In the simulator on an iPhone 17 Pro Copper Sky's active tile showed the mark with Backing tracks on; after Done, the switch off and stage mode again from the header menu, its tile showed none stopped or playing. A missing file, an idle tile with a track and VoiceOver were not seen on screen.)*
- [x] Playing, the tile keeps the tint, the amber outline, the amber number and the name in dial white, with an amber glow; the beat dots are amber, the current one solid and the others faint; the track's time is in dial white; an amber wash shows over the tile shortly after a beat and is gone between beats. *(Seen in the simulator on an iPhone 17 Pro with beats and file time from a timer in place of the audio engine: of four screenshots of Copper Sky playing, two caught the wash at different strengths, one after the plain beat 2 and one after the accented beat 1, and two the tile at rest with only the faint glow; the dots and `0:00 / 0:30` were as described. The time was at 0:00 in every screenshot.)*
- [ ] The wash peaks at 30 % on an accented beat and 16 % on a plain one and fades over 0.25 s, easing out, and the glow goes from 50 % to 15 % with it. *(Not measured: still screenshots cannot catch the peak or time the fade, and the two strengths were not compared.)*
- [ ] With Reduce Motion on, the playing tile shows no wash and its glow stays at rest, while the beat dots still light. *(Not tried: Reduce Motion was not switched on.)*
- [x] A hold on a tile does nothing, stopped or playing. *(Seen in the simulator on an iPhone 17 Pro: holds of 0.6, 0.7 and 1 second on stopped tiles started nothing, and a hold of 0.7 second on the playing tile left it playing; a short tap then started a tile, and another on it stopped it. Nothing was tried on a real iPhone.)*
- [x] A vertical drag starting on a tile starts nothing. *(Seen in the simulator on an iPhone SE (3rd generation) with iOS 18: a drag upwards from Midnight Ferry's stopped tile pulled the grid up, it sprang back, and no tile started.)*
- [ ] The grid scrolls under the title row, which stays in place, and its last row scrolls up to 16 pt above the bottom of the safe area; a drag starting on a tile scrolls a grid longer than the screen; a name longer than two lines is cut with an ellipsis; the playing tile of a song whose track's file is missing shows the track mark in muted; with Display Zoom the side margins are 16 pt. *(Not seen: the sample setlist's eight songs fit the screen on the iPhone 17 Pro and on the iPhone SE, so the grid was not seen to scroll. No sample name takes more than two lines, a playing song whose track's file is missing was not set up, and Display Zoom was not tried.)*
- [x] The beat dots show one dot per beat, accented beats larger, and the small sizes in 9/8 and 12/8, so that twelve fit. *(Unit tested: dotsAreLargerOnAccentedBeats, nineDotsUseTheSmallSizes, twelveDotsUseTheSmallSizes, twelveAccentedDotsFitANarrowTile, which scales twelve accented dots down alike to fit a narrow tile, dotsAreNotScaledUp, and noWidthOrNoBeatsGiveNoNegativeOrNaNSizes. In the simulator, playing, four dots in 4/4 with beats 1 and 3 larger and seven in 7/8 with beats 1, 3 and 5 larger on an iPhone 17 Pro, and twelve dots on one line in 12/8 on an iPhone SE. The dot sizes were judged by eye only. 12/8 with every beat accented, and the dots scaled down with Display Zoom, were not seen.)*
- [ ] The current beat's dot is solid and the others faint, each lighting on its beat at once, count-in beats included. *(Not unit tested. Which dot was solid was not checked on screen, and the count-in was not seen.)*
- [x] A tap on a tile while stopped loads its song from the setlist as a tap in the setlist's view does, dropping another song's unsaved edits and keeping the loaded song's own, and starts it from the top: beat 1, or the count-in at 0:00 with a playable track, also for the song just played. *(Unit tested: aTapWhileStoppedStartsThatSong, aTapLoadsFromTheSetlistAndStarts, aTapDropsAnotherSongsUnsavedEdits, theLoadedSongsOwnTileKeepsItsEdits, aTileWithATrackCountsIn, theSameTileAgainStartsFromTheTop and aMissingFilePlaysTheClickAlone, the last three against a stand-in for the audio engine. In the simulator on an iPhone 17 Pro, with a timer in place of the audio engine, a tap on Seven Bridges' stopped tile started it in 7/8. The count-in was not seen on screen.)*
- [x] A tap on the playing tile stops it and it stays the active tile, the last song's too; while a tile plays the other tiles and `Done` do nothing. *(Unit tested: aTapOnThePlayingTileStops, tappingThePlayingTileStopsAndKeepsItMarked and stoppingTheLastSongKeepsItMarked, and otherTilesDoNothingWhileOnePlays and doneDoesNothingWhileATilePlays, each for the rules and for the model. In the simulator on an iPhone 17 Pro a tap on Copper Sky playing stopped it and its tile stayed the only one marked; another tap started it again. Stopping the last song, and taps on other tiles and `Done` while a tile plays, were not seen on screen.)*
- [x] When the audio engine reports that playback stopped, at the end of a backing track, on an interruption or when the audio output goes away, and when the app leaves the foreground, the playing tile stops and stays the active tile, and stage mode stays shown; a start that fails leaves the tapped tile active. *(Unit tested against a stand-in for the audio engine: theEndOfTheTrackKeepsItsSongMarked, anInterruptionKeepsThePlayedSongMarked, which stands for an interruption and the audio output going away, as the engine reports both alike, leavingTheForegroundKeepsThePlayedSongMarked and aFailedStartMarksTheTappedTile. None of it was seen on screen.)*
- [ ] A real interruption, such as a call, and the audio output going away stop the playing tile in stage mode. *(Needs a real iPhone.)*
- [x] `Done` returns to the metronome screen with the last loaded song loaded from the setlist. *(Unit tested: doneDoesNothingWhileATilePlays, which leaves the song a tile played loaded, and aTapLoadsFromTheSetlistAndStarts, which loads it from the setlist. In the simulator on an iPhone 17 Pro, `Done` while stopped returned to the metronome screen with Seven Bridges loaded from Friday gig, 3 of 8, after its tile had played it, and also when no tile had been tapped.)*
- [ ] Stage mode is not kept between launches. *(Not tested, and the app was not relaunched with stage mode shown.)*
- [x] While stage mode is shown the app keeps the screen on, playing or stopped, with Keep screen awake off. *(Unit tested: theScreenStaysAwakeWhileStageModeIsShown, stopped with Keep screen awake off, and screenStaysAwakeOnlyWhilePlayingWhenTheSwitchIsOff for playing. In the simulator on an iPhone 17 Pro the app's idle-timer flag read on while stage mode was shown and stopped, and off after `Done`; it was not read while a tile played.)*
- [ ] The screen does not dim or lock while stage mode is shown. *(The simulator never auto-locks, so the screen actually staying on needs a real iPhone.)*
- [x] A tap on a tile asks for the Start / Stop impact and no selection tick. *(Unit tested, counting the haptics asked for: aTapLoadsFromTheSetlistAndStarts, tappingThePlayingTileStopsAndKeepsItMarked and otherTilesDoNothingWhileOnePlays.)*
- [ ] A tap on a tile is felt as the Start / Stop impact. *(Needs a real iPhone.)*
- [x] Changes from another device reorder and remove tiles; the active tile follows its song, and goes when its song leaves the setlist; a playing song that leaves the setlist plays on with no tile playing, the tiles doing nothing and `Done` working; stopping a song that plays with no tile leaves no tile marked; stage mode closes when its setlist is deleted or emptied, at once while stopped and once playback stops while playing. *(Unit tested with two models against an in-memory stand-in for iCloud: stageModeFollowsAReorderFromAnotherDevice, theActiveMarkGoesWhenItsSongLeavesTheSetlist, thePlayingSongLeavingTheSetlistLeavesDoneWorking, stoppingASongWithNoTileMarksNothing, stoppingASongThatCameBackWithNoTileMarksNothing, which stops a song that left the setlist and came back to it while playing, stageModeClosesWhenItsSetlistIsDeletedElsewhere, stageModeClosesWhenItsSetlistIsEmptiedElsewhere, and stageModeClosesOnceStoppedWhenItsSetlistGoesWhilePlaying and stageModeClosesOnceStoppedWhenItsSetlistIsEmptiedWhilePlaying, the last two for a deleted and an emptied setlist. Not seen between two devices.)*
- [ ] Songs added on another device, and a changed name, tempo, time signature or backing track, update the tiles, and a renamed setlist's name shows in the title row. *(Not tested, and not seen between two devices.)*
- [ ] VoiceOver reads stage mode's title, `Done` and each tile as in section 13, dimmed tiles and `Done` as dimmed. *(The tiles' labels, with the number, name, tempo, time signature, backing track and loaded or playing, are unit tested in aTileReadsNumberNameTempoAndState. VoiceOver was not switched on.)*

## 15. Not built yet

A part that is specified before it is built is listed here until it is.

- **The metronome screen's one layout** (section 6): the same layout for every song, with the player card's Metronome content and Track content (6.7, 6.12); the 264 pt dial with its darker knob and 92 pt number (6.2); the controls centred between the knob and the card, and the small-screen steps (6.8); the header's Sound button and Backing tracks switch as toggles (6.1, 6.9); the dial, the tempo controls and the time signature row setting the track's tempo and the time signature while a track is in use, with the Sync pill as the only way into Sync mode (7.1, 7.2, 7.11); the elapsed time and bar count (7.13); no next-up line; and their beat effects, haptics and VoiceOver labels (sections 12 and 13).

## 16. Ideas for later

Not part of version 1.0.

- **Dynamic Type in rows and sheets.** Labels and text in rows and sheets scale with the phone's text size, up to the first accessibility size. The large BPM number stays fixed.
- **Making room when iCloud is full.** When iCloud reports that it is full, the oldest delete markers are removed to make room, not only when the item count is over the limit (5.1).
- **Play while locked.** Playback continues when the user locks the screen.
- **Waveform for the offset.** A waveform of the backing track with a marker for the offset that can be dragged.
- **Tempos with decimals.** For backing tracks that are not at a whole BPM.
- **Syncing backing-track files.** The audio file travels to the user's other devices with the song.
- **Backing tracks per setlist.** Each setlist carries Backing tracks on or off. A song loaded from a setlist plays by that setlist's setting, on the metronome screen and in stage mode; a song loaded on its own plays by the app's switch. The header's Backing tracks switch shows the setting in effect, and tapping it while a song from a setlist is loaded changes that setlist's setting. The setting would sync with the setlist.
- **Locking tempo and time signature with a track.** The dial, − / +, Tap tempo, the tempo sheet and the Time signature row work while a track is in use, on the track's tempo and the song's time signature (6.12, 7.1, 7.2, 7.10). If a change from the metronome screen proves troublesome, for example a tempo changed by accident putting the click out of step with the recording, they could instead be dimmed in Track content, leaving the tempo to Sync mode (7.11), or ask before a change.
