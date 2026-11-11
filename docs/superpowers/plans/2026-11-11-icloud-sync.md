# iCloud Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user switch on iCloud sync so that presets and setlists are the same on all their devices, combined part by part as the specification says.

**Architecture:** Every preset and setlist becomes a record whose parts each carry a change time, and combining two records is a pure function. `Library` keeps its present reading API but is built on those records, on the device at all times. A `LibrarySync` object exchanges records with iCloud key-value storage through a small `CloudStore` protocol, so everything except the thin `NSUbiquitousKeyValueStore` wrapper is unit tested with an in-memory fake. `MetronomeModel` owns the switch and applies arrived changes without touching the metronome.

**Tech Stack:** Swift 6 language mode, SwiftUI, Observation, Foundation (`NSUbiquitousKeyValueStore`, `UserDefaults`), Swift Testing. No third-party dependencies. The Xcode project uses file-system-synchronized groups, so new files need no project edits.

**Spec:** `docs/specification.md`: sections 5 and 5.1, 6.9 (green), 6.10 (iCloud card, scrolling), 7.9, the sync lines in 13 and 14, and section 15. Design: Paper file "Snappy Metronome", page "v1.0 — Settings & click sounds (draft)", boards "iCloud sync · A / B / C".

## Global Constraints

- Sync is off by default and applies to this device only.
- Only presets and setlists sync. Current settings, loaded preset, loaded-from setlist, selected filter, click sound and haptics stay on the device.
- The device always keeps its complete library; the app works the same with sync off, signed out or offline.
- Storage is iCloud key-value storage: 1 MB and 1,024 items per app. The app uses at most `1000` items.
- Change times are recorded at all times, also with sync off.
- A change always gets a time later than the one it replaces.
- An item missing from iCloud without a delete marker is never treated as deleted.
- Delete markers live for `365` days. A device entry is live for `180` days and is refreshed at most once per `24` hours.
- Format number in iCloud: `1`.
- Fixed early time for libraries made before sync: `2026-01-01T00:00:00Z`, `Date(timeIntervalSince1970: 1_767_225_600)`.
- The metronome's tempo, time signature and accents never change because of sync.
- No alert, banner, sound or haptic when changes arrive.
- iOS 18.0 minimum. System font. Colours from spec 6.9; green `#4CC38A` is used for the status dot only.
- Copy is exact, as in spec 6.10: `ICLOUD`, `Sync presets and setlists`, `Syncing…`, `Up to date`, `Last synced 14:32`, `Not signed in to iCloud`, `iCloud storage is full`, `Update the app to keep syncing`, and the four lines below the card.
- Work on a new branch `icloud-sync`, cut from `presets-setlists`. Commit with the `commit-commands:commit` skill; subjects are imperative, capitalized, no prefix, no attribution lines, no backticks.
- Run tests with `scripts/test.sh`. One suite: `scripts/test.sh -only-testing:MetronomeTests/<SuiteName>`. A passing run prints `** TEST SUCCEEDED **`.
- Never read `.env.*` or `.appsettings.*` files.

## Review Focus

1. **A device whose clock is wrong.** An edit made on this device after a change arrived from a device with a clock far ahead must still win. Pinned in Task 2.
2. **Two phones holding the same presets from a backup, updated at different times.** An edit or deletion on the phone that updated first must survive combining with the other phone's untouched copy. Pinned in Task 3.
3. **Unreadable data in iCloud** (garbage bytes, a record of the wrong shape, a key the app does not know). The app must not crash, must not delete it unless it owns a good copy of the same item, and must keep syncing the rest. Pinned in Task 4.
4. **The switch flipped quickly, or switched off while a change is on its way.** A change that arrives after switching off must not alter the library, and on-off-on must not empty iCloud while this device is about to sync again. Pinned in Task 5.
5. **The loaded preset deleted or changed on another device while playing.** Playback continues with the same settings; the header shows "nothing loaded" or `Edited`. Pinned in Task 6.

## File Structure

```
Metronome/
  Metronome.entitlements          new; iCloud key-value storage
  Model/SyncRecords.swift         new; JSONValue, Part, SyncClock, PresetRecord, SetlistRecord and their combining
  Model/Library.swift             rebuilt on records; same reading API; combining, markers, limits
  Model/LibraryStore.swift        new storage key; converts a library made before sync
  Model/CloudStore.swift          new; the protocol LibrarySync talks to, and CloudChange
  Model/LibrarySync.swift         new; exchange with iCloud, format number, devices, clean-up, status
  Model/SettingsStore.swift       unchanged
  Engine/UbiquitousCloudStore.swift  new; NSUbiquitousKeyValueStore behind CloudStore
  MetronomeModel.swift            the switch, the status, applying arrived changes, an injected clock
  MetronomeApp.swift              wires the real store; tells the model when the app becomes active
  Views/Theme.swift               adds green
  Views/SettingsSheet.swift       iCloud card; title pinned, cards scroll
  Views/SetlistViews.swift        the editor closes when its setlist is deleted elsewhere
MetronomeTests/
  SyncRecordsTests.swift          new
  LibraryMergeTests.swift         new
  LibraryTests.swift              call sites gain now:
  LibraryStoreTests.swift         new
  FakeCloudStore.swift            new; in-memory CloudStore shared by two "devices"
  LibrarySyncTests.swift          new
  SyncModelTests.swift            new
docs/specification.md             checklist ticks and section 15 at the end
```

---

### Task 1: Records and combining

**Files:**
- Create: `Metronome/Model/SyncRecords.swift`
- Test: `MetronomeTests/SyncRecordsTests.swift`

**Interfaces:**
- Consumes: `Preset`, `MetronomeSettings`, `TimeSignature` as they are.
- Produces:

```swift
/// Any JSON value, so parts the app does not know survive unchanged.
enum JSONValue: Codable, Equatable, Sendable {
    case null, bool(Bool), number(Double), string(String), array([JSONValue]), object([String: JSONValue])
    init<T: Encodable>(encoding value: T) throws
    func decoded<T: Decodable>(_ type: T.Type) -> T?
}

struct Part: Codable, Equatable, Sendable {
    var time: Date
    var value: JSONValue
    /// Newer time wins. Equal times: the value whose sorted-keys JSON is greater, byte by byte.
    func merged(with other: Part) -> Part
}

enum SyncClock {
    static let legacy = Date(timeIntervalSince1970: 1_767_225_600)
    /// max(now, previous + 1 ms); now when previous is nil.
    static func stamp(_ now: Date, after previous: Date?) -> Date
}

struct PresetRecord: Codable, Equatable, Sendable, Identifiable {
    static let nameKey = "name", tempoKey = "tempo", meterKey = "meter"
    let id: UUID
    var created: Date
    var parts: [String: Part]
    var deleted: Date?
    init(id: UUID, name: String, settings: MetronomeSettings, created: Date, now: Date)
    /// nil when deleted, or when a known part is missing or unreadable.
    var preset: Preset? { get }
    /// The latest part time; `created` when there are no parts.
    var lastChange: Date { get }
    mutating func setName(_ name: String, now: Date)
    /// Stamps tempo and meter separately, each only when its value differs.
    mutating func setSettings(_ settings: MetronomeSettings, now: Date)
    /// Leaves only id, created and the marker.
    mutating func delete(now: Date)
    func merged(with other: PresetRecord) -> PresetRecord
}

struct Membership: Codable, Equatable, Sendable {
    var time: Date
    var isIn: Bool
    var added: Date
}

struct SetlistRecord: Codable, Equatable, Sendable, Identifiable {
    static let nameKey = "name", orderKey = "order"
    let id: UUID
    var parts: [String: Part]
    /// Keyed by the preset id's uuidString.
    var members: [String: Membership]
    var lastUsed: Date
    var deleted: Date?
    init(id: UUID, name: String, presetIDs: [UUID], now: Date)
    var name: String? { get }
    /// The order part first, then members not in it by `added`, then uuidString; only members that are in and alive.
    func presetIDs(alive: Set<UUID>) -> [UUID]
    /// The latest of the name, the order and every membership time. lastUsed does not count.
    var lastChange: Date { get }
    mutating func setName(_ name: String, now: Date)
    /// Does not touch the order part.
    mutating func add(_ presetID: UUID, now: Date)
    mutating func remove(_ presetID: UUID, now: Date)
    mutating func reorder(to order: [UUID], now: Date)
    /// lastUsed becomes the later of itself and now.
    mutating func touch(now: Date)
    mutating func delete(now: Date)
    func merged(with other: SetlistRecord) -> SetlistRecord
}
```

Decisions the signatures do not show:

- `meter` holds the time signature and the accents together: `{"signature": <TimeSignature as it encodes>, "accents": [Int] sorted}`. `tempo` is a number. `name` is a string.
- Every mutator stamps with `SyncClock.stamp(now, after:)` against the time it replaces; `delete` against `lastChange`.
- `merged` on either record: parts by key with `Part.merged`, keeping keys only one side has; `created` is the earlier; the marker is the later of the two; then the marker is dropped when it is not later than `lastChange`, and when it stays, parts and members are emptied. Membership per key: newer `time` wins, equal times prefer `isIn == true`. `lastUsed` is the later.
- `merged` must be commutative, associative and idempotent.

- [ ] **Step 1: Write the failing tests** in `SyncRecordsTests` (a `struct`, `import Testing`, `@testable import Metronome`). Use `let t0 = Date(timeIntervalSince1970: 2_000_000_000)` and `t(n) = t0 + n`.

```swift
@Test func stampIsAlwaysLaterThanWhatItReplaces() {
    #expect(SyncClock.stamp(t(5), after: t(1)) == t(5))
    #expect(SyncClock.stamp(t(1), after: t(5)) == t(5).addingTimeInterval(0.001))
    #expect(SyncClock.stamp(t(1), after: nil) == t(1))
}

@Test func renameOnOneDeviceAndTempoOnAnotherAreBothKept() {
    let base = PresetRecord(id: UUID(), name: "Song", settings: settings(100), created: t(0), now: t(0))
    var a = base; a.setName("Renamed", now: t(10))
    var b = base; b.setSettings(settings(140), now: t(20))
    let merged = a.merged(with: b)
    #expect(merged.preset?.name == "Renamed")
    #expect(merged.preset?.settings.bpm == 140)
    #expect(merged == b.merged(with: a))
}

@Test func savingOnlyATempoChangeLeavesTheOtherTimesAlone() {
    var record = PresetRecord(id: UUID(), name: "Song", settings: settings(100), created: t(0), now: t(0))
    record.setSettings(settings(120), now: t(9))
    #expect(record.parts[PresetRecord.tempoKey]?.time == t(9))
    #expect(record.parts[PresetRecord.meterKey]?.time == t(0))
    #expect(record.parts[PresetRecord.nameKey]?.time == t(0))
}

@Test func signatureAndAccentsTravelTogether() {
    let base = PresetRecord(id: UUID(), name: "Song", settings: settings(100), created: t(0), now: t(0))
    var a = base; a.setSettings(MetronomeSettings(bpm: 100, timeSignature: .threeFour, accents: [1]), now: t(10))
    var b = base; b.setSettings(MetronomeSettings(bpm: 100, timeSignature: .fourFour, accents: [1, 3]), now: t(20))
    #expect(a.merged(with: b).preset?.settings == b.preset?.settings)
}

@Test func anEditAfterADeletionBringsThePresetBack() {
    let base = PresetRecord(id: UUID(), name: "Song", settings: settings(100), created: t(0), now: t(0))
    var a = base; a.delete(now: t(10))
    var b = base; b.setSettings(settings(150), now: t(20))
    let merged = a.merged(with: b)
    #expect(merged.deleted == nil)
    #expect(merged.preset?.settings.bpm == 150)
    #expect(merged.preset?.name == "Song")
}

@Test func aDeletionAfterAnEditStays() {
    let base = PresetRecord(id: UUID(), name: "Song", settings: settings(100), created: t(0), now: t(0))
    var a = base; a.setSettings(settings(150), now: t(10))
    var b = base; b.delete(now: t(20))
    #expect(a.merged(with: b).preset == nil)
    #expect(a.merged(with: b).deleted == t(20))
}

@Test func anUnknownPartSurvivesCombiningAndEncoding() throws {
    var a = PresetRecord(id: UUID(), name: "Song", settings: settings(100), created: t(0), now: t(0))
    a.parts["note"] = Part(time: t(5), value: .string("capo 2"))
    var b = a; b.setName("Other", now: t(9))
    let merged = b.merged(with: a)
    let again = try JSONDecoder().decode(PresetRecord.self, from: JSONEncoder().encode(merged))
    #expect(again.parts["note"]?.value == .string("capo 2"))
    #expect(again.preset?.name == "Other")
}

@Test func addingOnOneDeviceAndReorderingOnAnotherKeepsBoth() {
    let p = [UUID(), UUID(), UUID()]; let new = UUID()
    let base = SetlistRecord(id: UUID(), name: "Gig", presetIDs: p, now: t(0))
    var a = base; a.reorder(to: [p[2], p[0], p[1]], now: t(10))
    var b = base; b.add(new, now: t(20))
    let merged = a.merged(with: b)
    #expect(merged.presetIDs(alive: Set(p + [new])) == [p[2], p[0], p[1], new])
}

@Test func membershipIsDecidedPerPresetAndHiddenForMissingPresets() {
    let p = [UUID(), UUID()]
    let base = SetlistRecord(id: UUID(), name: "Gig", presetIDs: p, now: t(0))
    var a = base; a.remove(p[0], now: t(10))
    var b = base; b.setName("Tour", now: t(5))
    let merged = a.merged(with: b)
    #expect(merged.name == "Tour")
    #expect(merged.presetIDs(alive: Set(p)) == [p[1]])
    #expect(base.presetIDs(alive: [p[0]]) == [p[0]])
}

@Test func lastUsedDoesNotBringADeletedSetlistBack() {
    let base = SetlistRecord(id: UUID(), name: "Gig", presetIDs: [], now: t(0))
    var a = base; a.delete(now: t(10))
    var b = base; b.touch(now: t(20))
    #expect(a.merged(with: b).deleted == t(10))
}

@Test func combiningGivesTheSameResultInAnyOrder() {
    let base = PresetRecord(id: UUID(), name: "Song", settings: settings(100), created: t(0), now: t(0))
    var a = base; a.setName("A", now: t(7))
    var b = base; b.setName("B", now: t(7))
    var c = base; c.delete(now: t(3))
    let one = a.merged(with: b).merged(with: c)
    let two = c.merged(with: a.merged(with: b)).merged(with: b)
    #expect(one == two)
    #expect(one.merged(with: one) == one)
}
```

`settings(_ bpm:)` is the helper from `LibraryTests`.

- [ ] **Step 2: Run** `scripts/test.sh -only-testing:MetronomeTests/SyncRecordsTests`. Expected: the build fails, `cannot find 'PresetRecord' in scope`.
- [ ] **Step 3: Implement `SyncRecords.swift`** to the interface and decisions above.
- [ ] **Step 4: Run** the same command. Expected: `** TEST SUCCEEDED **`.
- [ ] **Step 5: Commit** with subject `Add records that combine part by part`.

---

### Task 2: Library built on records

**Files:**
- Modify: `Metronome/Model/Library.swift` (all of it)
- Modify: `Metronome/MetronomeModel.swift` (call sites only; pass `Date()` for now)
- Modify: `MetronomeTests/LibraryTests.swift` (call sites gain `now:`)
- Test: `MetronomeTests/LibraryMergeTests.swift`

**Interfaces:**
- Consumes: Task 1.
- Produces: `Preset` and `Setlist` unchanged. `Library` keeps `presets`, `setlists`, `preset(id:)`, `setlist(id:)`, `sortedPresets`, `presets(inSetlist:)`, `setlistCount(containing:)`, `setlistsByRecency`, `cleanName`, `maxNameLength`, `defaultSetlistName`, `sanitized()`. Changed and new:

```swift
struct Library: Codable, Equatable, Sendable {
    private(set) var presetRecords: [UUID: PresetRecord]
    private(set) var setlistRecords: [UUID: SetlistRecord]

    /// Alive presets by `created`, then uuidString.
    var presets: [Preset] { get }
    /// Alive setlists by uuidString, each with the visible presetIDs.
    var setlists: [Setlist] { get }

    mutating func addPreset(name: String, settings: MetronomeSettings, now: Date) -> Preset?
    mutating func renamePreset(_ id: UUID, to name: String, now: Date)
    mutating func updatePreset(_ id: UUID, settings: MetronomeSettings, now: Date)
    mutating func deletePreset(_ id: UUID, now: Date)
    mutating func addSetlist(name: String, now: Date) -> Setlist
    mutating func renameSetlist(_ id: UUID, to name: String, now: Date)
    mutating func deleteSetlist(_ id: UUID, now: Date)
    mutating func duplicateSetlist(_ id: UUID, now: Date) -> Setlist?
    mutating func add(_ presetID: UUID, toSetlist id: UUID, now: Date)
    mutating func remove(_ presetID: UUID, fromSetlist id: UUID, now: Date)
    mutating func reorder(setlist id: UUID, to order: [UUID], now: Date)
    mutating func touchSetlist(_ id: UUID, now: Date)

    /// Records from elsewhere combined into this library.
    mutating func merge(presets: [PresetRecord], setlists: [SetlistRecord])
    /// Presets, setlists and markers together.
    var itemCount: Int { get }
    /// Removes markers older than the cutoff; returns the ids removed.
    mutating func purgeMarkers(before cutoff: Date) -> [UUID]
    /// Removes the oldest markers, at most `count`; returns the ids removed.
    mutating func dropOldestMarkers(_ count: Int) -> [UUID]
    /// A library made before sync: every part at SyncClock.legacy, creation times and
    /// membership `added` times at legacy + index seconds, in the given order.
    init(legacyPresets: [Preset], legacySetlists: [Setlist])
}
```

Decisions:

- A new preset's `created` is `SyncClock.stamp(now, after: <latest created in the library>)`, so creation order survives equal clock readings.
- `deletePreset` no longer edits setlists; a deleted preset is hidden by `presetIDs(alive:)` and returns to its setlists if it comes back.
- `reorder` still accepts only a rearrangement of the visible presets, and stores that full order.
- `duplicateSetlist` makes a new record whose members and order are the original's visible presets.
- Codable form: `{"presets": [PresetRecord], "setlists": [SetlistRecord]}`, each sorted by uuidString, encoded with `.sortedKeys`.

- [ ] **Step 1: Write the failing tests** in `LibraryMergeTests`:

```swift
@Test func aDeletedPresetLeavesAMarkerAndComesBackIntoItsSetlist() {
    var a = Library()
    let preset = a.addPreset(name: "Song", settings: settings(100), now: t(0))!
    let setlist = a.addSetlist(name: "Gig", now: t(0))
    a.add(preset.id, toSetlist: setlist.id, now: t(1))
    var b = a
    a.deletePreset(preset.id, now: t(10))
    #expect(a.presets.isEmpty)
    #expect(a.setlist(id: setlist.id)?.presetIDs.isEmpty == true)
    #expect(a.itemCount == 2)
    b.updatePreset(preset.id, settings: settings(160), now: t(20))
    a.merge(presets: Array(b.presetRecords.values), setlists: Array(b.setlistRecords.values))
    #expect(a.preset(id: preset.id)?.settings.bpm == 160)
    #expect(a.setlist(id: setlist.id)?.presetIDs == [preset.id])
}

@Test func twoLibrariesAreCombinedNotReplaced() {
    var a = Library(); var b = Library()
    let one = a.addPreset(name: "One", settings: settings(90), now: t(0))!
    let two = b.addPreset(name: "Two", settings: settings(110), now: t(0))!
    a.merge(presets: Array(b.presetRecords.values), setlists: [])
    #expect(Set(a.presets.map(\.id)) == [one.id, two.id])
}

// Review Focus 1
@Test func aLocalEditWinsOverAnArrivedChangeFromAClockFarAhead() {
    var a = Library()
    let preset = a.addPreset(name: "Song", settings: settings(100), now: t(0))!
    var b = a
    b.updatePreset(preset.id, settings: settings(200), now: t(86_400))
    a.merge(presets: Array(b.presetRecords.values), setlists: [])
    a.updatePreset(preset.id, settings: settings(130), now: t(60))
    b.merge(presets: Array(a.presetRecords.values), setlists: [])
    #expect(a.preset(id: preset.id)?.settings.bpm == 130)
    #expect(b.preset(id: preset.id)?.settings.bpm == 130)
}

@Test func presetsCreatedAtTheSameInstantKeepTheirOrder() {
    var library = Library()
    let ids = (0..<5).map { library.addPreset(name: "Same", settings: settings(100), now: t(0))!.id }
    #expect(library.presets.map(\.id) == ids)
}

@Test func markersCanBePurgedByAgeAndOldestFirst() {
    var library = Library()
    let ids = (0..<3).map { library.addPreset(name: "P\($0)", settings: settings(100), now: t(0))!.id }
    library.deletePreset(ids[0], now: t(10)); library.deletePreset(ids[1], now: t(20)); library.deletePreset(ids[2], now: t(30))
    #expect(library.dropOldestMarkers(1) == [ids[0]])
    #expect(library.purgeMarkers(before: t(25)) == [ids[1]])
    #expect(library.itemCount == 1)
}

@Test func aLibraryMadeBeforeSyncKeepsItsOrderAndLosesToAnyRealChange() {
    let old = [Preset(id: UUID(), name: "b", settings: settings(90)), Preset(id: UUID(), name: "a", settings: settings(80))]
    let gig = Setlist(id: UUID(), name: "Gig", presetIDs: [old[1].id, old[0].id], lastUsed: t(0))
    let first = Library(legacyPresets: old, legacySetlists: [gig])
    #expect(first.presets.map(\.id) == old.map(\.id))
    #expect(first.setlist(id: gig.id)?.presetIDs == [old[1].id, old[0].id])
    #expect(first == Library(legacyPresets: old, legacySetlists: [gig]))
}
```

- [ ] **Step 2: Run** `scripts/test.sh -only-testing:MetronomeTests/LibraryMergeTests`. Expected: build failure on the new signatures.
- [ ] **Step 3: Rebuild `Library`** on the records, update `MetronomeModel`'s calls to pass `Date()`, and add `now:` to the calls in `LibraryTests` (use the suite's `now`, or `now + n` where a test relies on order).
- [ ] **Step 4: Run** `scripts/test.sh`. Expected: `** TEST SUCCEEDED **` for the whole suite, including the unchanged `PresetModelTests`.
- [ ] **Step 5: Commit** with subject `Build the library on combinable records`.

---

### Task 3: Storing the library and converting an old one

**Files:**
- Modify: `Metronome/Model/LibraryStore.swift`
- Test: `MetronomeTests/LibraryStoreTests.swift`

**Interfaces:**
- Consumes: `Library(legacyPresets:legacySetlists:)`.
- Produces: `LibraryStore.load() -> LibraryState` and `save(_:)` with unchanged signatures. `LibraryState` unchanged in shape.

Decisions:

- New key `metronome.library.v2`. `load()` reads v2; when absent it reads `metronome.library.v1` in its old shape (`library.presets: [Preset]`, `library.setlists: [Setlist]`, plus the three ids), converts with the legacy initialiser, and returns it sanitized. The v1 value is left in place.
- `save` writes v2 only, with `.sortedKeys`.

- [ ] **Step 1: Write the failing tests**:

```swift
@Test func anOldLibraryIsConvertedInFull() throws {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let p = UUID(); let s = UUID()
    let old = """
    {"library":{"presets":[{"id":"\(p)","name":"Song","settings":{"bpm":96,"timeSignature":\(signatureJSON),"accents":[1]}}],
    "setlists":[{"id":"\(s)","name":"Gig","presetIDs":["\(p)"],"lastUsed":0}]},
    "loadedPresetID":"\(p)","loadedFromSetlistID":"\(s)","selectedSetlistID":"\(s)"}
    """
    defaults.set(Data(old.utf8), forKey: "metronome.library.v1")
    let state = LibraryStore(defaults: defaults).load()
    #expect(state.library.preset(id: p)?.settings.bpm == 96)
    #expect(state.library.setlist(id: s)?.presetIDs == [p])
    #expect(state.loadedPresetID == p)
    #expect(state.loadedFromSetlistID == s)
    #expect(state.selectedSetlistID == s)
    #expect(state.library.presetRecords[p]?.parts[PresetRecord.tempoKey]?.time == SyncClock.legacy)
}

// Review Focus 2
@Test func anEditOnThePhoneThatUpdatedFirstSurvivesTheOtherPhonesOldCopy() {
    let old = [Preset(id: UUID(), name: "Song", settings: MetronomeSettings(bpm: 100, timeSignature: .fourFour, accents: [1]))]
    var first = Library(legacyPresets: old, legacySetlists: [])
    first.updatePreset(old[0].id, settings: MetronomeSettings(bpm: 150, timeSignature: .fourFour, accents: [1]), now: t(100))
    var deleted = Library(legacyPresets: old, legacySetlists: [])
    deleted.deletePreset(old[0].id, now: t(100))
    let late = Library(legacyPresets: old, legacySetlists: [])
    first.merge(presets: Array(late.presetRecords.values), setlists: [])
    deleted.merge(presets: Array(late.presetRecords.values), setlists: [])
    #expect(first.preset(id: old[0].id)?.settings.bpm == 150)
    #expect(deleted.presets.isEmpty)
}

@Test func theNewFormatRoundTripsAndWinsOverTheOldKey() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    defaults.set(Data("not json".utf8), forKey: "metronome.library.v1")
    var library = Library()
    let preset = library.addPreset(name: "New", settings: MetronomeSettings(), now: t(0))!
    let state = LibraryState(library: library, loadedPresetID: preset.id)
    LibraryStore(defaults: defaults).save(state)
    #expect(LibraryStore(defaults: defaults).load() == state)
}
```

`signatureJSON` is `TimeSignature.fourFour` encoded with `JSONEncoder`, so the test follows however the type encodes.

- [ ] **Step 2: Run** `scripts/test.sh -only-testing:MetronomeTests/LibraryStoreTests`. Expected: FAIL, the old library loads empty.
- [ ] **Step 3: Implement** the v2 key and the conversion.
- [ ] **Step 4: Run** `scripts/test.sh`. Expected: `** TEST SUCCEEDED **`.
- [ ] **Step 5: Commit** with subject `Keep an existing library when records arrive`.

---

### Task 4: Exchanging records with iCloud

**Files:**
- Create: `Metronome/Model/CloudStore.swift`, `Metronome/Model/LibrarySync.swift`
- Create: `MetronomeTests/FakeCloudStore.swift`
- Test: `MetronomeTests/LibrarySyncTests.swift`

**Interfaces:**
- Consumes: Tasks 1 and 2.
- Produces:

```swift
enum CloudChange: Sendable { case changed, quotaExceeded, accountChanged }

@MainActor
protocol CloudStore: AnyObject {
    var keys: [String] { get }
    func data(forKey key: String) -> Data?
    func set(_ data: Data, forKey key: String)
    func remove(_ key: String)
    /// Identifies the signed-in iCloud account; nil when not signed in.
    var account: Data? { get }
    var onChange: (@MainActor (CloudChange) -> Void)? { get set }
    /// Starts listening and asks iCloud for the latest data.
    func start()
}

enum SyncStatus: Equatable, Sendable {
    case syncing, upToDate(lastSynced: Date?), notSignedIn, full, needsUpdate
}

@MainActor
final class LibrarySync {
    static let format = 1, maxItems = 1000
    static let markerLifetime: TimeInterval = 365 * 86_400
    init(cloud: CloudStore, defaults: UserDefaults = .standard)
    private(set) var isOn: Bool
    /// nil while off.
    private(set) var status: SyncStatus?
    /// Combines the library with iCloud and writes back what iCloud lacks or has older.
    /// Returns the input unchanged while off, not signed in, or when iCloud has a newer format.
    func exchange(_ library: Library, now: Date) -> Library
}
```

`FakeCloudStore` is an in-memory `[String: Data]` with a settable `account` (default `Data([1])`), a `send(_ change: CloudChange)` that calls `onChange`, and a `writes` counter. Two `LibrarySync` objects on one `FakeCloudStore`, each with its own `UserDefaults` suite, stand for two devices. This task also adds `func turnOn(now: Date)` in its smallest form: it sets `isOn` and remembers it under the defaults key `metronome.sync.on`. Task 5 extends it.

Decisions:

- Keys in iCloud: `format` (the number as UTF-8 text), `p.<uuidString>` and `s.<uuidString>` (one record each, JSON with `.sortedKeys`), `d.<uuidString>` (Task 5). Any other key is left alone.
- `exchange` in order: stop if `format` is greater than `1` (status `.needsUpdate`); stop if `cloud.account` is nil (status `.notSignedIn`); decode every `p.` and `s.` value, skipping ones that do not decode; `library.merge`; `purgeMarkers(before: now - markerLifetime)` and remove those keys; if `itemCount + device entries + 1 > maxItems`, `dropOldestMarkers` by the excess and remove those keys; write each record whose encoding differs from what iCloud holds, which includes records iCloud lacks and undecodable values for ids the library owns; write `format` when absent.
- When the library still does not fit after dropping markers, status is `.full` and only records that already have a key are written. A `.quotaExceeded` change also sets `.full`. `.full` clears on the next exchange in which the library fits and is smaller, by `itemCount` or encoded bytes, than when the notice arrived.
- `lastSynced` (defaults key `metronome.sync.lastSynced`) is set to `now` whenever an exchange wrote a key or merged a difference.
- An exchange that changes nothing writes nothing.

- [ ] **Step 1: Write the failing tests**:

```swift
@Test func aSecondDeviceGetsTheFirstOnesLibraryNextToItsOwn()   // A exchanges, B exchanges: B has both; A exchanges: A has both
@Test func aLaterChangeOnEitherDeviceReachesTheOther()
@Test func anExchangeWithNothingNewWritesNothing()              // cloud.writes unchanged on a second exchange
@Test func anItemMissingFromICloudIsPutBack()                   // remove every key, exchange: p./s. keys return, library unchanged
@Test func aMarkerOlderThanAYearIsRemovedFromDeviceAndICloud()  // delete at t(0), exchange at t(0) + 366 days: no key, itemCount 0
@Test func theOldestMarkersGoFirstWhenTheLibraryDoesNotFit()    // 990 presets + 20 markers: 11 oldest markers dropped, status not .full
@Test func aLibraryThatCannotFitIsFullAndKeepsWorking()         // 1005 presets: status == .full, library returned whole
@Test func aQuotaNoticeSetsFull()
@Test func aNewerFormatStopsSyncWithoutChangingICloud()         // format "2": status == .needsUpdate, keys and values untouched
@Test func notSignedInWaitsWithoutTouchingICloud()              // account nil: status == .notSignedIn, writes == 0

// Review Focus 3
@Test func unreadableDataIsSkippedKeptOrRepaired() {
    // "p.<owned id>" = garbage: overwritten with the device's record.
    // "p.<unknown id>" = garbage: left exactly as it was.
    // "x.future" = anything: left exactly as it was.
    // A valid record next to them still arrives in the library.
}
```

Each body builds libraries with the Task 2 API and asserts on `library.presets`, `cloud.keys`, `cloud.data(forKey:)` and `sync.status`.

- [ ] **Step 2: Run** `scripts/test.sh -only-testing:MetronomeTests/LibrarySyncTests`. Expected: build failure, `cannot find 'LibrarySync' in scope`.
- [ ] **Step 3: Implement** `CloudStore.swift`, `FakeCloudStore.swift` and `LibrarySync.exchange`.
- [ ] **Step 4: Run** the same command. Expected: `** TEST SUCCEEDED **`.
- [ ] **Step 5: Commit** with subject `Exchange library records with iCloud`.

---

### Task 5: The switch, devices and clean-up

**Files:**
- Modify: `Metronome/Model/LibrarySync.swift`
- Test: `MetronomeTests/LibrarySyncTests.swift` (new tests in the same suite)

**Interfaces:**
- Consumes: Task 4.
- Produces, added to `LibrarySync`:

```swift
static let deviceLifetime: TimeInterval = 180 * 86_400
static let deviceRefresh: TimeInterval = 86_400
/// Called on the main actor when iCloud reports a change while sync is on.
var onCloudChange: (() -> Void)?
/// Called whenever `status` or `isOn` changes.
var onStatusChange: (() -> Void)?
/// Remembers the switch, registers this device, shows .syncing.
func turnOn(now: Date)
/// Leaves .syncing for the status the last exchange found; called after two seconds or on the first cloud change.
func finishSyncing()
/// Removes this device's entry; empties iCloud when no other live entry is left.
func turnOff(now: Date)
/// Call when the app becomes active: refreshes the device entry when on, runs the clean-up check when off.
func appOpened(now: Date)
```

Decisions:

- Defaults keys: `metronome.sync.on` (Bool), `metronome.sync.deviceID` (uuidString, made once), `metronome.sync.everOn` (Bool), `metronome.sync.account` (Data), `metronome.sync.deviceRefreshed` (Date).
- Device entry: key `d.<deviceID>`, value the date as seconds since 1970 in UTF-8 text. Written by `turnOn`, and by `appOpened` when on and the last refresh is older than `deviceRefresh`. Live when younger than `deviceLifetime`.
- `turnOff`: remove the own entry; if no other live entry exists, remove every key in the store, known or not. Skipped when iCloud's format is newer or the account differs from the remembered one.
- `appOpened` while off with `everOn`: same account, format not newer, no live entry, and keys present: remove every key.
- The account is remembered at `turnOn`, or at the first exchange that sees one. When an exchange or `appOpened` sees a different non-nil account, or a `.accountChanged` change arrives, sync turns itself off without touching iCloud.
- A cloud change that arrives while off is ignored. While on, `.changed` calls `finishSyncing()` and then `onCloudChange`.
- `turnOn` starts the two-second wait itself with `Task.sleep`; tests call `finishSyncing()` directly.

- [ ] **Step 1: Write the failing tests**:

```swift
@Test func syncIsOffAtFirstAndTheSwitchIsRemembered()          // new sync: isOn false, status nil; turnOn; a new LibrarySync on the same defaults: isOn true
@Test func switchingOnShowsSyncingThenUpToDate()               // .syncing; exchange; finishSyncing(): .upToDate(lastSynced: now)
@Test func switchingOffLeavesTheLibraryAndTheOtherDeviceAlone() // B off: B's library equal, A's keys still there, d.<B> gone, d.<A> present
@Test func changesMadeWhileOffAreCombinedWhenSwitchedOnAgain()
@Test func theLastDeviceToSwitchOffEmptiesICloud()             // A off, then B off: cloud.keys.isEmpty
@Test func aSyncingDeviceThatFindsICloudEmptiedPutsItsLibraryBack()
@Test func twoDevicesSwitchedOffTogetherAreCleanedUpOnTheNextOpen() // B off while d.<A> still visible; remove d.<A>; B.appOpened: empty
@Test func aDeviceUnseenForSixMonthsDoesNotBlockTheCleanUp()   // d.<A> dated now - 181 days; B off: empty
@Test func aDeviceBehindOnFormatNeverEmptiesICloud()           // format "2"; turnOff and appOpened: keys untouched
@Test func aDifferentAccountSwitchesSyncOff()                  // account Data([2]) then exchange: isOn false, keys untouched, library returned unchanged
@Test func theDeviceEntryIsRefreshedAtMostOnceADay()

// Review Focus 4
@Test func aChangeThatArrivesAfterSwitchingOffIsIgnored()      // turnOff; cloud.send(.changed): onCloudChange not called; exchange returns its input
@Test func offAndStraightBackOnKeepsTheLibraryInICloud()       // only device: turnOff empties; turnOn + exchange: every record is back
```

- [ ] **Step 2: Run** `scripts/test.sh -only-testing:MetronomeTests/LibrarySyncTests`. Expected: build failure on `turnOn`.
- [ ] **Step 3: Implement** the additions.
- [ ] **Step 4: Run** the same command. Expected: `** TEST SUCCEEDED **`.
- [ ] **Step 5: Commit** with subject `Add the sync switch, device entries and clean-up`.

---

### Task 6: The model

**Files:**
- Modify: `Metronome/MetronomeModel.swift`
- Test: `MetronomeTests/SyncModelTests.swift`

**Interfaces:**
- Consumes: `LibrarySync` from Tasks 4 and 5.
- Produces:

```swift
init(engine: ClickEngine, store: SettingsStore, haptics: HapticsPlaying, libraryStore: LibraryStore,
     sync: LibrarySync? = nil, now: @escaping () -> Date = Date.init)
private(set) var syncEnabled: Bool
/// nil while sync is off.
private(set) var syncStatus: SyncStatus?
func setSyncEnabled(_ enabled: Bool)
/// Call when the app becomes active.
func appDidBecomeActive()
```

Decisions:

- Every library mutation uses the injected `now()`.
- One private `exchangeWithCloud()`: `library = sync.exchange(library, now: now())`, then clear `loadedPresetID`, `loadedFromSetlistID` and `selectedSetlistID` by the rules of `LibraryState.sanitized()`, then write the result with `libraryStore.save` directly, not through `persistLibrary()`, so it cannot call itself. It runs from `setSyncEnabled(true)`, `appDidBecomeActive()`, `sync.onCloudChange`, and at the end of `persistLibrary()` while sync is on.
- It never calls `apply`, `engine.update`, `store.save(settings)` or any haptic. `isEdited` then follows from the existing rule.
- `syncStatus` and `syncEnabled` mirror the sync object through `onStatusChange`.
- `setSyncEnabled` plays no haptic.

- [ ] **Step 1: Write the failing tests** (`@MainActor struct`, two models on one `FakeCloudStore`, each with its own stores, the fakes from `PresetModelTests`):

```swift
@Test func aPresetMadeOnOneDeviceAppearsOnTheOther()
@Test func anArrivedTempoMarksTheLoadedPresetEditedAndKeepsTheMetronome() {
    // B loads the preset and starts. A saves 180 into it. cloud.send(.changed) on B.
    #expect(b.settings.bpm == 100)
    #expect(b.isEdited)
    #expect(b.headerSubtitle == "Edited")
    #expect(b.isPlaying)
    #expect(engineB.updates == updatesBefore)     // the engine heard nothing
    b.discardChanges()
    #expect(b.settings.bpm == 180)
}
@Test func saveChangesAfterAnArrivalSendsTheMetronomesVersionBack()   // b.saveChanges(); A exchanges: A's preset is 100
@Test func anArrivedNameShowsInTheHeaderAtOnce()                      // headerTitle changes, isEdited false

// Review Focus 5
@Test func theLoadedPresetDeletedElsewhereWhilePlayingKeepsPlaying() {
    #expect(b.isPlaying)
    #expect(b.settings.bpm == 100)
    #expect(b.loadedPreset == nil)
    #expect(b.headerSubtitle == "No preset loaded")
}
@Test func aDeletedSetlistClearsTheFilterAndTheLoadedFromSetlist()    // selectedSetlistID nil, loadedFromSetlistID nil, preset still loaded
@Test func arrivalsPlayNoHaptic()                                     // FakeHaptics counts unchanged
@Test func withSyncOffNothingReachesICloud()                          // cloud.writes == 0 after creating presets
@Test func theSwitchSurvivesRelaunch()
```

- [ ] **Step 2: Run** `scripts/test.sh -only-testing:MetronomeTests/SyncModelTests`. Expected: build failure on `setSyncEnabled`.
- [ ] **Step 3: Implement** the model changes.
- [ ] **Step 4: Run** `scripts/test.sh`. Expected: `** TEST SUCCEEDED **`.
- [ ] **Step 5: Commit** with subject `Apply arrived changes without touching the metronome`.

---

### Task 7: The real store and the app

**Files:**
- Create: `Metronome/Engine/UbiquitousCloudStore.swift`, `Metronome/Metronome.entitlements`
- Modify: `Metronome.xcodeproj/project.pbxproj` (both app configurations: `CODE_SIGN_ENTITLEMENTS = Metronome/Metronome.entitlements;`)
- Modify: `Metronome/MetronomeApp.swift`

**Interfaces:**
- Consumes: `CloudStore`, `LibrarySync`, `MetronomeModel.init(…sync:now:)`, `appDidBecomeActive()`.
- Produces: `@MainActor final class UbiquitousCloudStore: CloudStore` with `init()`.

Decisions:

- Entitlement: `com.apple.developer.ubiquity-kvstore-identifier` = `$(TeamIdentifierPrefix)$(CFBundleIdentifier)`.
- `keys` is `dictionaryRepresentation.keys`. `start()` observes `NSUbiquitousKeyValueStore.didChangeExternallyNotification` on the main queue and calls `synchronize()`. Reasons map: server change and initial sync to `.changed`, quota violation to `.quotaExceeded`, account change to `.accountChanged`.
- `account` is `FileManager.default.ubiquityIdentityToken` archived with `NSKeyedArchiver` (secure coding), nil when the token is nil.
- `MetronomeApp` builds one `UbiquitousCloudStore`, a `LibrarySync` on it, passes it to the model, calls `start()`, and calls `model.appDidBecomeActive()` when `scenePhase` becomes `.active`.
- The unit tests never create `UbiquitousCloudStore`.

- [ ] **Step 1: Add the entitlements file and the build setting.** Run `scripts/build.sh`. Expected: `** BUILD SUCCEEDED **`, and no warning that the entitlements file is copied into the app bundle; if there is one, exclude the file from the target in the synchronized group's exceptions.
- [ ] **Step 2: Implement** `UbiquitousCloudStore` and the wiring in `MetronomeApp`.
- [ ] **Step 3: Run** `scripts/test.sh`. Expected: `** TEST SUCCEEDED **`.
- [ ] **Step 4: Confirm the account identity (spec 5.1).** Launch the app in a simulator signed in to iCloud, with a temporary log line printing whether `ubiquityIdentityToken` is nil. Expected: not nil. If it is nil while signed in, make `account` return a constant non-nil value so that only the `.accountChanged` notice switches sync off, remove nothing else, and report this to the user: the `Not signed in to iCloud` status cannot then be shown. Remove the log line either way.
- [ ] **Step 5: Commit** with subject `Connect sync to iCloud key-value storage`.

Signing note for the user: a device or TestFlight build needs the iCloud capability on the App ID. Xcode's automatic signing adds it on the first build; nothing in this plan changes signing settings beyond the entitlements file.

---

### Task 8: The settings sheet

**Files:**
- Modify: `Metronome/Views/Theme.swift` (add `static let green = Color(hex: 0x4CC38A)`)
- Modify: `Metronome/Views/SettingsSheet.swift`
- Modify: `Metronome/Views/SetlistViews.swift` (`SetlistEditor`)

**Interfaces:**
- Consumes: `model.syncEnabled`, `model.syncStatus`, `model.setSyncEnabled(_:)`.
- Produces: nothing other tasks use.

Decisions, all from spec 6.10 and the Paper boards:

- The grabber, `Settings` and `Done` stay fixed; the cards scroll beneath them. The sheet's height follows the content up to the full screen.
- The iCloud card repeats the Haptics card's structure: `ICLOUD` label, a `Toggle` labelled `Sync presets and setlists` tinted amber, and, only while on, a status row of the same height with the line divider: an 8 pt dot, the text at 15 pt medium, and the detail at 13 pt medium in muted dim at the right.

| `syncStatus` | Dot | Text and its colour | Detail | Line below the card |
|---|---|---|---|---|
| nil | none; no row | none | none | `Keeps your presets and setlists the same on every device signed in to your iCloud account. Click sound and haptics stay separate on each device.` |
| `.syncing` | muted dim | `Syncing…`, muted | none | same as above |
| `.upToDate(lastSynced)` | green | `Up to date`, dial white | `Last synced 14:32` today, `Last synced 9 Nov` otherwise, none when nil | same as above |
| `.notSignedIn` | amber | `Not signed in to iCloud`, amber | none | `Sign in to iCloud in the Settings app to sync. Until then your presets and setlists stay on this iPhone.` |
| `.full` | amber | `iCloud storage is full`, amber | none | `Delete presets or setlists you no longer need to make room. Until then some changes stay on this iPhone.` |
| `.needsUpdate` | amber | `Update the app to keep syncing`, amber | none | `Another of your devices has a newer version of the app. Until this one is updated, your presets and setlists stay on this iPhone.` |

- The time and the date follow the phone's own formats (`Date.FormatStyle`: time shortened; day and abbreviated month).
- VoiceOver: the toggle reads its label and state; the status row is one element reading the text and the detail, for example "Up to date, last synced 14:32"; the dot is hidden from accessibility.
- `SetlistEditor` dismisses itself when `model.library.setlist(id: setlistID)` becomes nil, and the library then shows All presets (the model has already cleared the filter).

- [ ] **Step 1: Implement** the three changes.
- [ ] **Step 2: Run** `scripts/test.sh`. Expected: `** TEST SUCCEEDED **`.
- [ ] **Step 3: Check in the simulator** with the `run` skill, on iPhone 17 Pro: open Settings; the sheet scrolls with the title fixed; the iCloud card matches board A; switch on and compare with board B, or with board C when the simulator is not signed in to iCloud. Take a screenshot of each state reached. On an iPhone SE simulator, confirm the sheet still scrolls to the last line.
- [ ] **Step 4: Commit** with subject `Add the iCloud card to the settings sheet`.

---

### Task 9: Specification status and the two-device check

**Files:**
- Modify: `docs/specification.md` (section 14 "iCloud sync" lines, section 15)

- [ ] **Step 1: Tick** each checklist line that the unit tests or the simulator check verified, with a note in the document's existing style saying how. Leave unticked, with a note, every line that needs two devices on one iCloud account.
- [ ] **Step 2: Rewrite section 15** to say everything is built, as it read before, unless something in this plan was not built; then list that.
- [ ] **Step 3: Run** `scripts/test.sh`. Expected: `** TEST SUCCEEDED **`.
- [ ] **Step 4: Commit** with subject `Record what of iCloud sync is verified`.
- [ ] **Step 5: Hand the user the two-device list**, which only they can run: two phones or a phone and a second simulator on one iCloud account; switch on A, then B; create, rename, change tempo, delete and reorder on each; switch B off and on; switch both off and confirm a fresh install with sync on finds nothing.
