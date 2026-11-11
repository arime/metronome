import Foundation

/// Named metronome settings, usually a song or a practice setup.
struct Preset: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var settings: MetronomeSettings
}

/// A named, ordered selection of presets. It refers to presets; it does not own them.
struct Setlist: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var presetIDs: [UUID]
    var lastUsed: Date
}

/// Every preset and setlist, kept as records that say when each part last changed,
/// so a copy from another device can be combined with this one.
struct Library: Codable, Equatable, Sendable {
    static let maxNameLength = 60
    static let defaultSetlistName = "New setlist"

    /// Every preset record by id, deleted ones included, so a delete marker can be passed on.
    private(set) var presetRecords: [UUID: PresetRecord] = [:]
    private(set) var setlistRecords: [UUID: SetlistRecord] = [:]

    init() {}

    /// A library made before sync: every part at SyncClock.legacy, creation times and
    /// membership `added` times at legacy + index seconds, in the given order.
    init(legacyPresets: [Preset], legacySetlists: [Setlist]) {
        for (index, preset) in legacyPresets.enumerated() {
            let created = SyncClock.legacy.addingTimeInterval(Double(index))
            presetRecords[preset.id] = PresetRecord(
                id: preset.id, name: preset.name, settings: preset.settings, created: created, now: SyncClock.legacy
            )
        }
        for setlist in legacySetlists {
            var record = SetlistRecord(
                id: setlist.id, name: setlist.name, presetIDs: setlist.presetIDs, now: SyncClock.legacy
            )
            var seen = Set<UUID>()
            for (index, presetID) in setlist.presetIDs.enumerated() where seen.insert(presetID).inserted {
                record.members[presetID.uuidString]?.added = SyncClock.legacy.addingTimeInterval(Double(index))
            }
            record.lastUsed = setlist.lastUsed
            setlistRecords[setlist.id] = record
        }
    }

    /// A name with the spaces at its ends removed and cut to the limit; nil when nothing is left.
    static func cleanName(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxNameLength))
    }

    // MARK: - Reading

    /// Alive presets by `created`, then uuidString.
    var presets: [Preset] {
        presetRecords.values
            .filter { $0.preset != nil }
            .sorted { ($0.created, $0.id.uuidString) < ($1.created, $1.id.uuidString) }
            .compactMap(\.preset)
    }

    /// Alive setlists by uuidString, each with the visible presetIDs.
    var setlists: [Setlist] {
        let alive = alivePresetIDs
        return setlistRecords.values
            .filter { $0.deleted == nil }
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { setlist(from: $0, alive: alive) }
    }

    private var alivePresetIDs: Set<UUID> {
        Set(presetRecords.values.filter { $0.preset != nil }.map(\.id))
    }

    private func setlist(from record: SetlistRecord, alive: Set<UUID>) -> Setlist {
        Setlist(
            id: record.id,
            name: record.name ?? Self.defaultSetlistName,
            presetIDs: record.presetIDs(alive: alive),
            lastUsed: record.lastUsed
        )
    }

    func preset(id: UUID) -> Preset? {
        presetRecords[id]?.preset
    }

    func setlist(id: UUID) -> Setlist? {
        guard let record = setlistRecords[id], record.deleted == nil else { return nil }
        return setlist(from: record, alive: alivePresetIDs)
    }

    /// A–Z ignoring case; presets with the same name keep their order of creation.
    var sortedPresets: [Preset] {
        presets.enumerated().sorted { first, second in
            switch first.element.name.localizedCaseInsensitiveCompare(second.element.name) {
            case .orderedAscending: true
            case .orderedDescending: false
            case .orderedSame: first.offset < second.offset
            }
        }.map(\.element)
    }

    /// The setlist's presets in the setlist's order.
    func presets(inSetlist id: UUID) -> [Preset] {
        (setlist(id: id)?.presetIDs ?? []).compactMap(preset(id:))
    }

    func setlistCount(containing presetID: UUID) -> Int {
        setlists.filter { $0.presetIDs.contains(presetID) }.count
    }

    var setlistsByRecency: [Setlist] {
        setlists.sorted { $0.lastUsed > $1.lastUsed }
    }

    // MARK: - Presets

    /// Its creation time is later than every other preset's, so creation order survives equal clock readings.
    @discardableResult
    mutating func addPreset(name: String, settings: MetronomeSettings, now: Date) -> Preset? {
        guard let name = Self.cleanName(name) else { return nil }
        let created = SyncClock.stamp(now, after: presetRecords.values.map(\.created).max())
        let record = PresetRecord(id: UUID(), name: name, settings: settings.sanitized(), created: created, now: now)
        presetRecords[record.id] = record
        return record.preset
    }

    /// An empty name is not accepted; the old one is kept.
    mutating func renamePreset(_ id: UUID, to name: String, now: Date) {
        guard let name = Self.cleanName(name), preset(id: id) != nil else { return }
        presetRecords[id]?.setName(name, now: now)
    }

    mutating func updatePreset(_ id: UUID, settings: MetronomeSettings, now: Date) {
        guard preset(id: id) != nil else { return }
        presetRecords[id]?.setSettings(settings.sanitized(), now: now)
    }

    /// Leaves a marker. Setlists are not edited: the preset is hidden from them,
    /// and returns to them if it comes back.
    mutating func deletePreset(_ id: UUID, now: Date) {
        guard preset(id: id) != nil else { return }
        presetRecords[id]?.delete(now: now)
    }

    // MARK: - Setlists

    @discardableResult
    mutating func addSetlist(name: String, now: Date) -> Setlist {
        let record = SetlistRecord(
            id: UUID(), name: Self.cleanName(name) ?? Self.defaultSetlistName, presetIDs: [], now: now
        )
        setlistRecords[record.id] = record
        return setlist(from: record, alive: alivePresetIDs)
    }

    /// An empty name is not accepted; the old one is kept.
    mutating func renameSetlist(_ id: UUID, to name: String, now: Date) {
        guard let name = Self.cleanName(name), setlist(id: id) != nil else { return }
        setlistRecords[id]?.setName(name, now: now)
    }

    /// Leaves a marker. The presets stay in the library.
    mutating func deleteSetlist(_ id: UUID, now: Date) {
        guard setlist(id: id) != nil else { return }
        setlistRecords[id]?.delete(now: now)
    }

    /// A copy with the same visible presets in the same order. The presets are shared, not copied.
    @discardableResult
    mutating func duplicateSetlist(_ id: UUID, now: Date) -> Setlist? {
        guard let original = setlist(id: id) else { return nil }
        let name = Self.cleanName(original.name + " copy") ?? original.name
        let record = SetlistRecord(id: UUID(), name: name, presetIDs: original.presetIDs, now: now)
        setlistRecords[record.id] = record
        return setlist(from: record, alive: alivePresetIDs)
    }

    /// Adds the preset at the end. A preset is in a setlist only once.
    mutating func add(_ presetID: UUID, toSetlist id: UUID, now: Date) {
        guard preset(id: presetID) != nil, setlist(id: id) != nil else { return }
        setlistRecords[id]?.add(presetID, now: now)
    }

    /// The preset stays in the library.
    mutating func remove(_ presetID: UUID, fromSetlist id: UUID, now: Date) {
        guard setlist(id: id) != nil else { return }
        setlistRecords[id]?.remove(presetID, now: now)
    }

    /// Accepts only a rearrangement of the presets the setlist shows, and stores that whole order.
    mutating func reorder(setlist id: UUID, to order: [UUID], now: Date) {
        guard let current = setlist(id: id)?.presetIDs,
              order.count == current.count,
              Set(order) == Set(current)
        else { return }
        setlistRecords[id]?.reorder(to: order, now: now)
    }

    mutating func touchSetlist(_ id: UUID, now: Date) {
        guard setlist(id: id) != nil else { return }
        setlistRecords[id]?.touch(now: now)
    }

    /// References to missing presets are already left out when a setlist is read, so there is nothing to drop.
    func sanitized() -> Library {
        self
    }

    // MARK: - Combining

    /// Records from elsewhere combined into this library. Records it does not have yet are added,
    /// deleted ones too, so the marker can be passed on.
    mutating func merge(presets incoming: [PresetRecord], setlists incomingSetlists: [SetlistRecord]) {
        for record in incoming {
            presetRecords[record.id] = presetRecords[record.id].map { $0.merged(with: record) } ?? record
        }
        for record in incomingSetlists {
            setlistRecords[record.id] = setlistRecords[record.id].map { $0.merged(with: record) } ?? record
        }
    }

    /// Presets, setlists and markers together.
    var itemCount: Int {
        presetRecords.count + setlistRecords.count
    }

    /// Removes the records of deleted items whose marker is older than the cutoff; returns the ids removed.
    mutating func purgeMarkers(before cutoff: Date) -> [UUID] {
        removeMarkers(markers.filter { $0.time < cutoff })
    }

    /// Removes the records of the oldest deleted items, at most `count`; returns the ids removed.
    mutating func dropOldestMarkers(_ count: Int) -> [UUID] {
        removeMarkers(Array(markers.prefix(max(count, 0))))
    }

    /// Deleted items, oldest marker first, then by uuidString.
    private var markers: [(id: UUID, time: Date)] {
        let presetMarkers = presetRecords.values.compactMap { record in
            record.deleted.map { (id: record.id, time: $0) }
        }
        let setlistMarkers = setlistRecords.values.compactMap { record in
            record.deleted.map { (id: record.id, time: $0) }
        }
        return (presetMarkers + setlistMarkers).sorted { ($0.time, $0.id.uuidString) < ($1.time, $1.id.uuidString) }
    }

    private mutating func removeMarkers(_ removed: [(id: UUID, time: Date)]) -> [UUID] {
        for marker in removed {
            presetRecords[marker.id] = nil
            setlistRecords[marker.id] = nil
        }
        return removed.map(\.id)
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case presets, setlists
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let presets = try container.decode([PresetRecord].self, forKey: .presets)
        let setlists = try container.decode([SetlistRecord].self, forKey: .setlists)
        merge(presets: presets, setlists: setlists)
    }

    /// Each list sorted by uuidString, so the same library always encodes the same way.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(presetRecords.values.sorted { $0.id.uuidString < $1.id.uuidString }, forKey: .presets)
        try container.encode(setlistRecords.values.sorted { $0.id.uuidString < $1.id.uuidString }, forKey: .setlists)
    }
}
