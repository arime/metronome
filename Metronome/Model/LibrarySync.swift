import Foundation

enum SyncStatus: Equatable, Sendable {
    case syncing, upToDate(lastSynced: Date?), notSignedIn, full, needsUpdate
}

/// Exchanges the library's records with iCloud: every device combines what iCloud holds with
/// its own and writes back what iCloud lacks or has older.
@MainActor
final class LibrarySync {
    static let format = 1, maxItems = 1000
    static let markerLifetime: TimeInterval = 365 * 86_400

    private static let onKey = "metronome.sync.on"
    private static let lastSyncedKey = "metronome.sync.lastSynced"
    private static let formatKey = "format"
    private static let presetPrefix = "p.", setlistPrefix = "s.", devicePrefix = "d."

    private let cloud: CloudStore
    private let defaults: UserDefaults
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    private(set) var isOn: Bool
    /// nil while off.
    private(set) var status: SyncStatus?

    /// Set when iCloud reported that it is full; cleared by an exchange in which the library
    /// fits and is smaller than the one that was exchanged last before the notice.
    private var quotaFull = false
    private var sizeBeforeNotice: Size?
    private var lastSize: Size?

    private struct Size {
        var items: Int
        var bytes: Int
    }

    init(cloud: CloudStore, defaults: UserDefaults = .standard) {
        self.cloud = cloud
        self.defaults = defaults
        isOn = defaults.bool(forKey: Self.onKey)
        status = isOn ? .upToDate(lastSynced: defaults.object(forKey: Self.lastSyncedKey) as? Date) : nil
        cloud.onChange = { [weak self] change in
            self?.handle(change)
        }
    }

    /// Smallest form: remembers that sync is on.
    func turnOn(now: Date) {
        isOn = true
        defaults.set(true, forKey: Self.onKey)
        status = .upToDate(lastSynced: lastSynced)
    }

    private var lastSynced: Date? {
        defaults.object(forKey: Self.lastSyncedKey) as? Date
    }

    private func handle(_ change: CloudChange) {
        switch change {
        case .quotaExceeded:
            guard isOn else { return }
            quotaFull = true
            sizeBeforeNotice = lastSize
            status = .full
        case .changed, .accountChanged:
            break
        }
    }

    /// Combines the library with iCloud and writes back what iCloud lacks or has older.
    /// Returns the input unchanged while off, not signed in, or when iCloud has a newer format.
    func exchange(_ library: Library, now: Date) -> Library {
        guard isOn else { return library }
        if let version = cloudFormat, version > Self.format {
            status = .needsUpdate
            return library
        }
        guard cloud.account != nil else {
            status = .notSignedIn
            return library
        }

        var result = library
        result.merge(presets: cloudPresets(), setlists: cloudSetlists())
        var changed = result != library

        let purged = result.purgeMarkers(before: now.addingTimeInterval(-Self.markerLifetime))
        changed = removeKeys(for: purged) || changed

        let deviceEntries = cloud.keys.filter { $0.hasPrefix(Self.devicePrefix) }.count
        let excess = result.itemCount + deviceEntries + 1 - Self.maxItems
        if excess > 0 {
            changed = removeKeys(for: result.dropOldestMarkers(excess)) || changed
        }
        let fits = result.itemCount + deviceEntries + 1 <= Self.maxItems

        var encoded: [String: Data] = [:]
        for (id, record) in result.presetRecords {
            encoded[Self.presetPrefix + id.uuidString] = try? encoder.encode(record)
        }
        for (id, record) in result.setlistRecords {
            encoded[Self.setlistPrefix + id.uuidString] = try? encoder.encode(record)
        }
        let size = Size(items: result.itemCount, bytes: encoded.values.reduce(0) { $0 + $1.count })

        if quotaFull, fits, isSmaller(size, than: sizeBeforeNotice) {
            quotaFull = false
        }
        let restricted = !fits || quotaFull

        for (key, data) in encoded {
            let held = cloud.data(forKey: key)
            guard held != data, !restricted || held != nil else { continue }
            cloud.set(data, forKey: key)
            changed = true
        }
        if cloud.data(forKey: Self.formatKey) == nil {
            cloud.set(Data(String(Self.format).utf8), forKey: Self.formatKey)
            changed = true
        }

        lastSize = size
        if changed { defaults.set(now, forKey: Self.lastSyncedKey) }
        status = restricted ? .full : .upToDate(lastSynced: lastSynced)
        return result
    }

    /// Smaller by item count or bytes; any size counts as smaller when none was known at the notice.
    private func isSmaller(_ size: Size, than other: Size?) -> Bool {
        guard let other else { return true }
        return size.items < other.items || size.bytes < other.bytes
    }

    // MARK: - Reading iCloud

    private var cloudFormat: Int? {
        cloud.data(forKey: Self.formatKey)
            .flatMap { String(data: $0, encoding: .utf8) }
            .flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    private func cloudPresets() -> [PresetRecord] {
        cloud.keys.filter { $0.hasPrefix(Self.presetPrefix) }.compactMap { key in
            cloud.data(forKey: key).flatMap { try? JSONDecoder().decode(PresetRecord.self, from: $0) }
        }
    }

    private func cloudSetlists() -> [SetlistRecord] {
        cloud.keys.filter { $0.hasPrefix(Self.setlistPrefix) }.compactMap { key in
            cloud.data(forKey: key).flatMap { try? JSONDecoder().decode(SetlistRecord.self, from: $0) }
        }
    }

    /// The returned ids do not say whether they were presets or setlists, so both keys go.
    /// True when a key was there to remove.
    private func removeKeys(for ids: [UUID]) -> Bool {
        var removed = false
        for id in ids {
            for prefix in [Self.presetPrefix, Self.setlistPrefix] {
                let key = prefix + id.uuidString
                guard cloud.data(forKey: key) != nil else { continue }
                cloud.remove(key)
                removed = true
            }
        }
        return removed
    }
}
