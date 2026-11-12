import Foundation

/// Any JSON value, so parts the app does not know survive unchanged.
enum JSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init<T: Encodable>(encoding value: T) throws {
        self = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(value))
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }

    /// The value as the given type; nil when it does not fit.
    func decoded<T: Decodable>(_ type: T.Type) -> T? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// The same bytes on every device, so equal times can be settled the same way everywhere.
    fileprivate var canonicalBytes: [UInt8] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return (try? encoder.encode(self)).map { Array($0) } ?? []
    }
}

/// One property of a record with the time it last changed.
struct Part: Codable, Equatable, Sendable {
    var time: Date
    var value: JSONValue

    /// Newer time wins. Equal times: the value whose sorted-keys JSON is greater, byte by byte.
    func merged(with other: Part) -> Part {
        if time != other.time { return time > other.time ? self : other }
        return value.canonicalBytes.lexicographicallyPrecedes(other.value.canonicalBytes) ? other : self
    }

    fileprivate static func merge(_ first: [String: Part], _ second: [String: Part]) -> [String: Part] {
        first.merging(second) { $0.merged(with: $1) }
    }
}

enum SyncClock {
    /// Stands for "changed before sync existed": 2026-01-01 00:00 UTC.
    static let legacy = Date(timeIntervalSince1970: 1_767_225_600)

    /// max(now, previous + 1 ms); now when previous is nil.
    /// A change always gets a time later than the one it replaces, even when the clock is behind.
    static func stamp(_ now: Date, after previous: Date?) -> Date {
        guard let previous else { return now }
        return max(now, previous.addingTimeInterval(0.001))
    }
}

/// A song together with the time each of its parts last changed, so two copies can be combined.
struct SongRecord: Codable, Equatable, Sendable, Identifiable {
    static let nameKey = "name", tempoKey = "tempo", meterKey = "meter"

    let id: UUID
    var created: Date
    var parts: [String: Part]
    var deleted: Date?

    init(id: UUID, name: String, settings: MetronomeSettings, created: Date, now: Date) {
        self.id = id
        self.created = created
        self.parts = [
            Self.nameKey: Part(time: now, value: .string(name)),
            Self.tempoKey: Part(time: now, value: Self.tempoValue(settings)),
            Self.meterKey: Part(time: now, value: Self.meterValue(settings)),
        ]
    }

    private static func tempoValue(_ settings: MetronomeSettings) -> JSONValue {
        .number(Double(settings.bpm))
    }

    /// The time signature and the accents together, because accents only make sense for their signature.
    private static func meterValue(_ settings: MetronomeSettings) -> JSONValue {
        let signature = (try? JSONValue(encoding: settings.timeSignature)) ?? .null
        let accents = settings.accents.sorted().map { JSONValue.number(Double($0)) }
        return .object(["signature": signature, "accents": .array(accents)])
    }

    /// nil when deleted, or when a known part is missing or unreadable.
    var song: Song? {
        guard deleted == nil,
              let name = parts[Self.nameKey]?.value.decoded(String.self),
              let bpm = parts[Self.tempoKey]?.value.decoded(Int.self),
              case .object(let meter)? = parts[Self.meterKey]?.value,
              let signature = meter["signature"]?.decoded(TimeSignature.self),
              let accents = meter["accents"]?.decoded([Int].self)
        else { return nil }
        return Song(id: id, name: name, settings: MetronomeSettings(bpm: bpm, timeSignature: signature, accents: Set(accents)))
    }

    /// The latest part time; `created` when there are no parts.
    var lastChange: Date {
        parts.values.map(\.time).max() ?? created
    }

    /// Stamps the name only when it differs, like the other parts.
    mutating func setName(_ name: String, now: Date) {
        set(Self.nameKey, to: .string(name), now: now)
    }

    /// Stamps tempo and meter separately, each only when its value differs.
    mutating func setSettings(_ settings: MetronomeSettings, now: Date) {
        set(Self.tempoKey, to: Self.tempoValue(settings), now: now)
        set(Self.meterKey, to: Self.meterValue(settings), now: now)
    }

    private mutating func set(_ key: String, to value: JSONValue, now: Date) {
        guard parts[key]?.value != value else { return }
        parts[key] = Part(time: SyncClock.stamp(now, after: parts[key]?.time), value: value)
        dropMarkerIfEdited()
    }

    /// Only sets the marker; the parts stay, so combining with other copies stays associative.
    mutating func delete(now: Date) {
        deleted = SyncClock.stamp(now, after: lastChange)
    }

    /// An edit later than the marker brings the song back.
    private mutating func dropMarkerIfEdited() {
        if let marker = deleted, marker <= lastChange { deleted = nil }
    }

    func merged(with other: SongRecord) -> SongRecord {
        var result = self
        result.created = min(created, other.created)
        result.parts = Part.merge(parts, other.parts)
        result.deleted = [deleted, other.deleted].compactMap { $0 }.max()
        result.dropMarkerIfEdited()
        return result
    }
}

/// Whether a song is in a setlist, since when, and when it was first put there.
struct Membership: Codable, Equatable, Sendable {
    var time: Date
    var isIn: Bool
    var added: Date

    /// Newer time wins. Equal times prefer in, then the earlier `added`, so every device picks the same one.
    fileprivate func merged(with other: Membership) -> Membership {
        if time != other.time { return time > other.time ? self : other }
        if isIn != other.isIn { return isIn ? self : other }
        return added <= other.added ? self : other
    }
}

/// A setlist together with the times of its changes, so two copies can be combined.
struct SetlistRecord: Codable, Equatable, Sendable, Identifiable {
    static let nameKey = "name", orderKey = "order"

    let id: UUID
    var parts: [String: Part]
    /// Keyed by the song id's uuidString.
    var members: [String: Membership]
    var lastUsed: Date
    var deleted: Date?

    init(id: UUID, name: String, songIDs: [UUID], now: Date) {
        self.id = id
        self.parts = [
            Self.nameKey: Part(time: now, value: .string(name)),
            Self.orderKey: Part(time: now, value: Self.orderValue(songIDs)),
        ]
        self.members = Dictionary(
            songIDs.map { ($0.uuidString, Membership(time: now, isIn: true, added: now)) },
            uniquingKeysWith: { first, _ in first }
        )
        self.lastUsed = now
    }

    private static func orderValue(_ order: [UUID]) -> JSONValue {
        .array(order.map { .string($0.uuidString) })
    }

    var name: String? {
        parts[Self.nameKey]?.value.decoded(String.self)
    }

    /// The order part first, then the other members by `added`, then uuidString; only members that are in and alive.
    /// A position in the order part counts only for a member added no later than the order part's time,
    /// so a song added again goes to the end.
    func songIDs(alive: Set<UUID>) -> [UUID] {
        func isShown(_ id: UUID) -> Bool {
            alive.contains(id) && members[id.uuidString]?.isIn == true
        }
        func isPlaced(_ id: UUID) -> Bool {
            guard let orderTime = parts[Self.orderKey]?.time, let member = members[id.uuidString] else { return false }
            return member.added <= orderTime
        }
        var result: [UUID] = []
        var seen = Set<UUID>()
        let ordered = (parts[Self.orderKey]?.value.decoded([String].self) ?? []).compactMap(UUID.init(uuidString:))
        for id in ordered where isShown(id) && isPlaced(id) && seen.insert(id).inserted {
            result.append(id)
        }
        let rest = members.compactMap { key, member -> (id: UUID, added: Date)? in
            guard let id = UUID(uuidString: key), isShown(id), !seen.contains(id) else { return nil }
            return (id, member.added)
        }
        result += rest.sorted { ($0.added, $0.id.uuidString) < ($1.added, $1.id.uuidString) }.map(\.id)
        return result
    }

    /// The latest of the name, the order and every membership time. lastUsed does not count.
    var lastChange: Date {
        (parts.values.map(\.time) + members.values.map(\.time)).max() ?? .distantPast
    }

    /// Stamps the name only when it differs.
    mutating func setName(_ name: String, now: Date) {
        setPart(Self.nameKey, to: .string(name), now: now)
    }

    /// Does not touch the order part.
    mutating func add(_ songID: UUID, now: Date) {
        let key = songID.uuidString
        guard members[key]?.isIn != true else { return }
        // Later than the order part and every other member's added time, so it lands last even when a clock is ahead.
        let latest = [members[key]?.time, parts[Self.orderKey]?.time, members.values.map(\.added).max()]
        let time = SyncClock.stamp(now, after: latest.compactMap { $0 }.max())
        members[key] = Membership(time: time, isIn: true, added: time)
        dropMarkerIfEdited()
    }

    mutating func remove(_ songID: UUID, now: Date) {
        let key = songID.uuidString
        guard var member = members[key], member.isIn else { return }
        member.time = SyncClock.stamp(now, after: member.time)
        member.isIn = false
        members[key] = member
        dropMarkerIfEdited()
    }

    /// The order part's time is never earlier than the `added` time of a member it lists,
    /// so a reorder right after an add still places that member.
    mutating func reorder(to order: [UUID], now: Date) {
        let value = Self.orderValue(order)
        let previous = parts[Self.orderKey]
        let latestAdded = order.compactMap { members[$0.uuidString]?.added }.max()
        if previous?.value == value, latestAdded.map({ $0 <= previous!.time }) ?? true { return }
        let after = [previous?.time, latestAdded].compactMap { $0 }.max()
        parts[Self.orderKey] = Part(time: SyncClock.stamp(now, after: after), value: value)
        dropMarkerIfEdited()
    }

    private mutating func setPart(_ key: String, to value: JSONValue, now: Date) {
        guard parts[key]?.value != value else { return }
        parts[key] = Part(time: SyncClock.stamp(now, after: parts[key]?.time), value: value)
        dropMarkerIfEdited()
    }

    /// An edit later than the marker brings the setlist back.
    private mutating func dropMarkerIfEdited() {
        if let marker = deleted, marker <= lastChange { deleted = nil }
    }

    /// lastUsed becomes the later of itself and now.
    mutating func touch(now: Date) {
        lastUsed = max(lastUsed, now)
    }

    /// Only sets the marker; the parts and members stay, so combining stays associative.
    mutating func delete(now: Date) {
        deleted = SyncClock.stamp(now, after: lastChange)
    }

    func merged(with other: SetlistRecord) -> SetlistRecord {
        var result = self
        result.parts = Part.merge(parts, other.parts)
        result.members = members.merging(other.members) { $0.merged(with: $1) }
        result.lastUsed = max(lastUsed, other.lastUsed)
        result.deleted = [deleted, other.deleted].compactMap { $0 }.max()
        result.dropMarkerIfEdited()
        return result
    }
}
