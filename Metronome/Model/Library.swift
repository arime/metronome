import Foundation

/// Named metronome settings for a song or a practice setup.
struct Song: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var settings: MetronomeSettings
    var track: BackingTrack? = nil
}

extension Song {
    /// True when the name contains the query, ignoring case, accents and the spaces at the
    /// query's ends. A query with nothing else in it matches every song.
    func matches(search query: String) -> Bool {
        nameMatches(name, search: query)
    }
}

extension Setlist {
    /// The same rule as `Song.matches(search:)`.
    func matches(search query: String) -> Bool {
        nameMatches(name, search: query)
    }
}

private func nameMatches(_ name: String, search query: String) -> Bool {
    let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return true }
    return name.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
}

/// A named, ordered selection of songs. It refers to songs; it does not own them.
struct Setlist: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var songIDs: [UUID]
    var lastUsed: Date

    /// Read only from a library saved before sync, which called songs presets.
    private enum CodingKeys: String, CodingKey {
        case id, name, lastUsed
        case songIDs = "presetIDs"
    }
}

/// Every song and setlist, kept as records that say when each part last changed,
/// so a copy from another device can be combined with this one.
struct Library: Codable, Equatable, Sendable {
    static let maxNameLength = 60
    /// A setlist given no name. A new setlist left Untitled and empty is not kept.
    static let defaultSetlistName = "Untitled"

    /// Every song record by id, deleted ones included, so a delete marker can be passed on.
    private(set) var songRecords: [UUID: SongRecord] = [:]
    private(set) var setlistRecords: [UUID: SetlistRecord] = [:]

    init() {}

    /// A library made before sync: every part at SyncClock.legacy, creation times and
    /// membership `added` times at legacy + index seconds, in the given order.
    init(legacySongs: [Song], legacySetlists: [Setlist]) {
        for (index, song) in legacySongs.enumerated() {
            let created = SyncClock.legacy.addingTimeInterval(Double(index))
            songRecords[song.id] = SongRecord(
                id: song.id, name: song.name, settings: song.settings, created: created, now: SyncClock.legacy
            )
        }
        for setlist in legacySetlists {
            var record = SetlistRecord(
                id: setlist.id, name: setlist.name, songIDs: setlist.songIDs, now: SyncClock.legacy
            )
            var seen = Set<UUID>()
            for (index, songID) in setlist.songIDs.enumerated() where seen.insert(songID).inserted {
                record.members[songID.uuidString]?.added = SyncClock.legacy.addingTimeInterval(Double(index))
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

    /// Alive songs by `created`, then uuidString.
    var songs: [Song] {
        songRecords.values
            .filter { $0.song != nil }
            .sorted { ($0.created, $0.id.uuidString) < ($1.created, $1.id.uuidString) }
            .compactMap(\.song)
    }

    /// Alive setlists by uuidString, each with the visible songIDs.
    var setlists: [Setlist] {
        let alive = aliveSongIDs
        return setlistRecords.values
            .filter { $0.deleted == nil }
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { setlist(from: $0, alive: alive) }
    }

    private var aliveSongIDs: Set<UUID> {
        Set(songRecords.values.filter { $0.song != nil }.map(\.id))
    }

    private func setlist(from record: SetlistRecord, alive: Set<UUID>) -> Setlist {
        Setlist(
            id: record.id,
            name: record.name ?? Self.defaultSetlistName,
            songIDs: record.songIDs(alive: alive),
            lastUsed: record.lastUsed
        )
    }

    func song(id: UUID) -> Song? {
        songRecords[id]?.song
    }

    func setlist(id: UUID) -> Setlist? {
        guard let record = setlistRecords[id], record.deleted == nil else { return nil }
        return setlist(from: record, alive: aliveSongIDs)
    }

    /// A–Z ignoring case; songs with the same name keep their order of creation.
    var sortedSongs: [Song] {
        songs.enumerated().sorted { first, second in
            Self.inNameOrder(first.element.name, second.element.name) { first.offset < second.offset }
        }.map(\.element)
    }

    /// A–Z ignoring case, by the phone's language rules; `tie` decides between equal names.
    static func inNameOrder(_ first: String, _ second: String, tie: () -> Bool) -> Bool {
        switch first.localizedCaseInsensitiveCompare(second) {
        case .orderedAscending: true
        case .orderedDescending: false
        case .orderedSame: tie()
        }
    }

    /// The setlist's songs in the setlist's order.
    func songs(inSetlist id: UUID) -> [Song] {
        (setlist(id: id)?.songIDs ?? []).compactMap(song(id:))
    }

    func setlistCount(containing songID: UUID) -> Int {
        setlists.filter { $0.songIDs.contains(songID) }.count
    }

    /// The setlists that hold any of the songs, each counted once.
    func setlistCount(containingAnyOf songIDs: Set<UUID>) -> Int {
        setlists.filter { !songIDs.isDisjoint(with: $0.songIDs) }.count
    }

    var setlistsByRecency: [Setlist] {
        setlists.sorted { $0.lastUsed > $1.lastUsed }
    }

    // MARK: - Songs

    /// Its creation time is later than every other song's, so creation order survives equal clock readings.
    @discardableResult
    mutating func addSong(name: String, settings: MetronomeSettings, track: BackingTrack? = nil, now: Date) -> Song? {
        guard let name = Self.cleanName(name) else { return nil }
        let created = SyncClock.stamp(now, after: songRecords.values.map(\.created).max())
        var record = SongRecord(id: UUID(), name: name, settings: settings.sanitized(), created: created, now: now)
        record.setTrack(track, now: now)
        songRecords[record.id] = record
        return record.song
    }

    /// An empty name is not accepted; the old one is kept.
    mutating func renameSong(_ id: UUID, to name: String, now: Date) {
        guard let name = Self.cleanName(name), song(id: id) != nil else { return }
        songRecords[id]?.setName(name, now: now)
    }

    mutating func updateSong(_ id: UUID, settings: MetronomeSettings, now: Date) {
        guard song(id: id) != nil else { return }
        songRecords[id]?.setSettings(settings.sanitized(), now: now)
    }

    /// Writes only the time signature and the accents of `settings`; the song's tempo stays.
    mutating func updateSongMeter(_ id: UUID, settings: MetronomeSettings, now: Date) {
        guard song(id: id) != nil else { return }
        songRecords[id]?.setMeter(settings.sanitized(), now: now)
    }

    /// nil removes the track.
    mutating func setTrack(_ id: UUID, to track: BackingTrack?, now: Date) {
        guard song(id: id) != nil else { return }
        songRecords[id]?.setTrack(track, now: now)
    }

    /// The file identifiers of every song that is not deleted. Read leniently from the track part,
    /// so a file is never deleted because its part holds something this version does not know (5.1).
    var referencedFileIDs: Set<UUID> {
        Set(songRecords.values.filter { $0.deleted == nil }.compactMap(\.trackFileID))
    }

    /// Leaves a marker. Setlists are not edited: the song is hidden from them,
    /// and returns to them if it comes back.
    mutating func deleteSong(_ id: UUID, now: Date) {
        guard song(id: id) != nil else { return }
        songRecords[id]?.delete(now: now)
    }

    // MARK: - Setlists

    @discardableResult
    mutating func addSetlist(name: String, now: Date) -> Setlist {
        let record = SetlistRecord(
            id: UUID(), name: Self.cleanName(name) ?? Self.defaultSetlistName, songIDs: [], now: now
        )
        setlistRecords[record.id] = record
        return setlist(from: record, alive: aliveSongIDs)
    }

    /// An empty name is not accepted; the old one is kept.
    mutating func renameSetlist(_ id: UUID, to name: String, now: Date) {
        guard let name = Self.cleanName(name), setlist(id: id) != nil else { return }
        setlistRecords[id]?.setName(name, now: now)
    }

    /// Leaves a marker. The songs stay in the library.
    mutating func deleteSetlist(_ id: UUID, now: Date) {
        guard setlist(id: id) != nil else { return }
        setlistRecords[id]?.delete(now: now)
    }

    /// A copy with the same visible songs in the same order. The songs are shared, not copied.
    @discardableResult
    mutating func duplicateSetlist(_ id: UUID, now: Date) -> Setlist? {
        guard let original = setlist(id: id) else { return nil }
        let name = Self.cleanName(original.name + " copy") ?? original.name
        let record = SetlistRecord(id: UUID(), name: name, songIDs: original.songIDs, now: now)
        setlistRecords[record.id] = record
        return setlist(from: record, alive: aliveSongIDs)
    }

    /// Adds the song at the end. A song is in a setlist only once.
    mutating func add(_ songID: UUID, toSetlist id: UUID, now: Date) {
        guard song(id: songID) != nil, setlist(id: id) != nil else { return }
        setlistRecords[id]?.add(songID, now: now)
    }

    /// The song stays in the library.
    mutating func remove(_ songID: UUID, fromSetlist id: UUID, now: Date) {
        guard setlist(id: id) != nil else { return }
        setlistRecords[id]?.remove(songID, now: now)
    }

    /// Accepts only a rearrangement of the songs the setlist shows, and stores that whole order.
    mutating func reorder(setlist id: UUID, to order: [UUID], now: Date) {
        guard let current = setlist(id: id)?.songIDs,
              order.count == current.count,
              Set(order) == Set(current)
        else { return }
        setlistRecords[id]?.reorder(to: order, now: now)
    }

    /// Sets the last-used time only when another setlist's is the same or later, so using the
    /// most recently used setlist changes nothing and sends nothing to iCloud (9.1).
    mutating func touchSetlist(_ id: UUID, now: Date) {
        guard let used = setlist(id: id) else { return }
        let othersUsedSameOrLater = setlistRecords.values.contains {
            $0.id != id && $0.deleted == nil && $0.lastUsed >= used.lastUsed
        }
        guard othersUsedSameOrLater else { return }
        setlistRecords[id]?.touch(now: now)
    }

    /// References to missing songs are already left out when a setlist is read, so there is nothing to drop.
    func sanitized() -> Library {
        self
    }

    // MARK: - Combining

    /// Records from elsewhere combined into this library. Records it does not have yet are added,
    /// deleted ones too, so the marker can be passed on.
    mutating func merge(songs incoming: [SongRecord], setlists incomingSetlists: [SetlistRecord]) {
        for record in incoming {
            songRecords[record.id] = songRecords[record.id].map { $0.merged(with: record) } ?? record
        }
        for record in incomingSetlists {
            setlistRecords[record.id] = setlistRecords[record.id].map { $0.merged(with: record) } ?? record
        }
    }

    /// Songs, setlists and markers together.
    var itemCount: Int {
        songRecords.count + setlistRecords.count
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
        let songMarkers = songRecords.values.compactMap { record in
            record.deleted.map { (id: record.id, time: $0) }
        }
        let setlistMarkers = setlistRecords.values.compactMap { record in
            record.deleted.map { (id: record.id, time: $0) }
        }
        return (songMarkers + setlistMarkers).sorted { ($0.time, $0.id.uuidString) < ($1.time, $1.id.uuidString) }
    }

    private mutating func removeMarkers(_ removed: [(id: UUID, time: Date)]) -> [UUID] {
        for marker in removed {
            songRecords[marker.id] = nil
            setlistRecords[marker.id] = nil
        }
        return removed.map(\.id)
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case songs, setlists
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let songs = try container.decode([SongRecord].self, forKey: .songs)
        let setlists = try container.decode([SetlistRecord].self, forKey: .setlists)
        merge(songs: songs, setlists: setlists)
    }

    /// Each list sorted by uuidString, so the same library always encodes the same way.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(songRecords.values.sorted { $0.id.uuidString < $1.id.uuidString }, forKey: .songs)
        try container.encode(setlistRecords.values.sorted { $0.id.uuidString < $1.id.uuidString }, forKey: .setlists)
    }
}
