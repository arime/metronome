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

/// Every preset and setlist, and the rules that keep them consistent.
struct Library: Codable, Equatable, Sendable {
    static let maxNameLength = 60
    static let defaultSetlistName = "New setlist"

    /// In order of creation.
    private(set) var presets: [Preset] = []
    private(set) var setlists: [Setlist] = []

    init() {}

    /// A name with the spaces at its ends removed and cut to the limit; nil when nothing is left.
    static func cleanName(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxNameLength))
    }

    // MARK: - Reading

    func preset(id: UUID) -> Preset? {
        presets.first { $0.id == id }
    }

    func setlist(id: UUID) -> Setlist? {
        setlists.first { $0.id == id }
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

    @discardableResult
    mutating func addPreset(name: String, settings: MetronomeSettings) -> Preset? {
        guard let name = Self.cleanName(name) else { return nil }
        let preset = Preset(id: UUID(), name: name, settings: settings.sanitized())
        presets.append(preset)
        return preset
    }

    /// An empty name is not accepted; the old one is kept.
    mutating func renamePreset(_ id: UUID, to name: String) {
        guard let name = Self.cleanName(name), let index = presets.firstIndex(where: { $0.id == id }) else { return }
        presets[index].name = name
    }

    mutating func updatePreset(_ id: UUID, settings: MetronomeSettings) {
        guard let index = presets.firstIndex(where: { $0.id == id }) else { return }
        presets[index].settings = settings.sanitized()
    }

    /// Removes the preset from the library and from every setlist.
    mutating func deletePreset(_ id: UUID) {
        presets.removeAll { $0.id == id }
        for index in setlists.indices {
            setlists[index].presetIDs.removeAll { $0 == id }
        }
    }

    // MARK: - Setlists

    @discardableResult
    mutating func addSetlist(name: String, now: Date) -> Setlist {
        let setlist = Setlist(
            id: UUID(), name: Self.cleanName(name) ?? Self.defaultSetlistName, presetIDs: [], lastUsed: now
        )
        setlists.append(setlist)
        return setlist
    }

    /// An empty name is not accepted; the old one is kept.
    mutating func renameSetlist(_ id: UUID, to name: String) {
        guard let name = Self.cleanName(name), let index = setlists.firstIndex(where: { $0.id == id }) else { return }
        setlists[index].name = name
    }

    /// The presets stay in the library.
    mutating func deleteSetlist(_ id: UUID) {
        setlists.removeAll { $0.id == id }
    }

    /// A copy with the same presets in the same order. The presets are shared, not copied.
    @discardableResult
    mutating func duplicateSetlist(_ id: UUID, now: Date) -> Setlist? {
        guard let original = setlist(id: id) else { return nil }
        let name = Self.cleanName(original.name + " copy") ?? original.name
        let copy = Setlist(id: UUID(), name: name, presetIDs: original.presetIDs, lastUsed: now)
        setlists.append(copy)
        return copy
    }

    /// Adds the preset at the end. A preset is in a setlist only once.
    mutating func add(_ presetID: UUID, toSetlist id: UUID) {
        guard preset(id: presetID) != nil, let index = setlists.firstIndex(where: { $0.id == id }),
              !setlists[index].presetIDs.contains(presetID)
        else { return }
        setlists[index].presetIDs.append(presetID)
    }

    /// The preset stays in the library.
    mutating func remove(_ presetID: UUID, fromSetlist id: UUID) {
        guard let index = setlists.firstIndex(where: { $0.id == id }) else { return }
        setlists[index].presetIDs.removeAll { $0 == presetID }
    }

    /// Accepts only a rearrangement of the presets the setlist already has.
    mutating func reorder(setlist id: UUID, to order: [UUID]) {
        guard let index = setlists.firstIndex(where: { $0.id == id }),
              order.count == setlists[index].presetIDs.count,
              Set(order) == Set(setlists[index].presetIDs)
        else { return }
        setlists[index].presetIDs = order
    }

    mutating func touchSetlist(_ id: UUID, now: Date) {
        guard let index = setlists.firstIndex(where: { $0.id == id }) else { return }
        setlists[index].lastUsed = now
    }

    /// Drops references to presets that no longer exist, and repeated entries.
    func sanitized() -> Library {
        var copy = self
        let known = Set(presets.map(\.id))
        for index in copy.setlists.indices {
            var seen = Set<UUID>()
            copy.setlists[index].presetIDs = copy.setlists[index].presetIDs.filter {
                known.contains($0) && seen.insert($0).inserted
            }
        }
        return copy
    }
}
