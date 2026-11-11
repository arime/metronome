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
    /// A device entry younger than this means the device still uses iCloud.
    static let deviceLifetime: TimeInterval = 180 * 86_400
    /// A device entry is refreshed at most this often.
    static let deviceRefresh: TimeInterval = 86_400

    private static let onKey = "metronome.sync.on"
    private static let deviceIDKey = "metronome.sync.deviceID"
    private static let everOnKey = "metronome.sync.everOn"
    private static let accountKey = "metronome.sync.account"
    private static let deviceRefreshedKey = "metronome.sync.deviceRefreshed"
    private static let lastSyncedKey = "metronome.sync.lastSynced"
    private static let formatKey = "format"
    private static let presetPrefix = "p.", setlistPrefix = "s.", devicePrefix = "d."

    private let cloud: CloudStore
    private let defaults: UserDefaults
    private let syncingDelay: Duration
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    private(set) var isOn: Bool
    /// nil while off.
    private(set) var status: SyncStatus?

    /// Called on the main actor when iCloud reports a change while sync is on.
    var onCloudChange: (() -> Void)?
    /// Called whenever `status` or `isOn` changes.
    var onStatusChange: (() -> Void)?

    /// True from switching on until the short wait is over; it hides only "up to date".
    private var syncing = false
    private var syncingTask: Task<Void, Never>?
    /// What the last exchange found; nil before the first one after switching on.
    private var found: SyncStatus?
    /// True inside `update`, so a change made within another one is announced once.
    private var updating = false

    /// Set when iCloud reported that it is full; cleared by an exchange in which the library
    /// fits and is smaller than the one that was exchanged last before the notice.
    private var quotaFull = false
    private var sizeBeforeNotice: Size?
    private var lastSize: Size?

    private struct Size {
        var items: Int
        var bytes: Int
    }

    init(cloud: CloudStore, defaults: UserDefaults = .standard, syncingDelay: Duration = .seconds(2)) {
        self.cloud = cloud
        self.defaults = defaults
        self.syncingDelay = syncingDelay
        isOn = defaults.bool(forKey: Self.onKey)
        status = isOn ? .upToDate(lastSynced: defaults.object(forKey: Self.lastSyncedKey) as? Date) : nil
        cloud.onChange = { [weak self] change in
            self?.handle(change)
        }
    }

    // MARK: - The switch

    /// Remembers the switch, registers this device and shows "syncing" for a moment.
    /// The caller exchanges the library next.
    func turnOn(now: Date) {
        update {
            isOn = true
            defaults.set(true, forKey: Self.onKey)
            defaults.set(true, forKey: Self.everOnKey)
            if defaults.string(forKey: Self.deviceIDKey) == nil {
                defaults.set(UUID().uuidString, forKey: Self.deviceIDKey)
            }
            if let account = cloud.account {
                defaults.set(account, forKey: Self.accountKey)
                if !cloudFormatIsNewer { writeDeviceEntry(now: now) }
            }
            found = nil
            syncing = true
            syncingTask?.cancel()
            syncingTask = Task { [weak self, syncingDelay] in
                do { try await Task.sleep(for: syncingDelay) } catch { return }
                self?.finishSyncing()
            }
        }
    }

    /// Leaves "syncing" for what the last exchange found; called after the short wait or on the
    /// first change from iCloud.
    func finishSyncing() {
        update {
            syncing = false
            syncingTask?.cancel()
            syncingTask = nil
        }
    }

    /// Removes this device's entry, and empties iCloud when no other live entry is left.
    /// The library on the device stays. Nothing in iCloud is touched when not signed in, when
    /// the account is not the one sync was switched on with, or when iCloud's format is newer.
    func turnOff(now: Date) {
        guard isOn else { return }
        if cloud.account != nil, accountMatches, !cloudFormatIsNewer {
            if let key = deviceEntryKey, cloud.data(forKey: key) != nil {
                cloud.remove(key)
            }
            if !hasLiveDeviceEntry(now: now) { removeEverything() }
        }
        switchOffHere()
    }

    /// Call when the app becomes active: refreshes the device entry when on, and when off after
    /// having been on, empties iCloud if no device is left that uses it.
    func appOpened(now: Date) {
        if isOn {
            guard !turnOffIfAccountDiffers() else { return }
            guard cloud.account != nil, !cloudFormatIsNewer else { return }
            let refreshed = defaults.object(forKey: Self.deviceRefreshedKey) as? Date
            if refreshed.map({ now.timeIntervalSince($0) >= Self.deviceRefresh }) ?? true {
                writeDeviceEntry(now: now)
            }
        } else {
            guard defaults.bool(forKey: Self.everOnKey), let account = cloud.account,
                  account == rememberedAccount, !cloudFormatIsNewer,
                  !hasLiveDeviceEntry(now: now), !cloud.keys.isEmpty else { return }
            removeEverything()
        }
    }

    private func switchOffHere() {
        update {
            isOn = false
            defaults.set(false, forKey: Self.onKey)
            syncing = false
            syncingTask?.cancel()
            syncingTask = nil
            found = nil
            quotaFull = false
            sizeBeforeNotice = nil
            lastSize = nil
        }
    }

    /// Runs a change and tells the owner once if it changed `isOn` or `status`.
    private func update(_ change: () -> Void) {
        guard !updating else { return change() }
        updating = true
        let before = (isOn, status)
        change()
        status = currentStatus
        updating = false
        if before.0 != isOn || before.1 != status { onStatusChange?() }
    }

    private var currentStatus: SyncStatus? {
        guard isOn else { return nil }
        var current = found ?? .upToDate(lastSynced: lastSynced)
        if case .upToDate = current { current = .upToDate(lastSynced: lastSynced) }
        if syncing, case .upToDate = current { return .syncing }
        return current
    }

    private var lastSynced: Date? {
        defaults.object(forKey: Self.lastSyncedKey) as? Date
    }

    // MARK: - Account

    private var rememberedAccount: Data? {
        defaults.data(forKey: Self.accountKey)
    }

    /// True when no account is remembered yet or the signed-in one is the remembered one.
    private var accountMatches: Bool {
        guard let remembered = rememberedAccount, let current = cloud.account else { return true }
        return remembered == current
    }

    /// Remembers the account at the first sight of one; switches sync off here, leaving iCloud
    /// alone, when a different one is signed in. True when it switched off.
    private func turnOffIfAccountDiffers() -> Bool {
        guard let current = cloud.account else { return false }
        guard let remembered = rememberedAccount else {
            defaults.set(current, forKey: Self.accountKey)
            return false
        }
        guard remembered != current else { return false }
        switchOffHere()
        return true
    }

    // MARK: - Device entries

    private var deviceEntryKey: String? {
        defaults.string(forKey: Self.deviceIDKey).map { Self.devicePrefix + $0 }
    }

    private func writeDeviceEntry(now: Date) {
        guard let key = deviceEntryKey else { return }
        cloud.set(Data(String(now.timeIntervalSince1970).utf8), forKey: key)
        defaults.set(now, forKey: Self.deviceRefreshedKey)
    }

    /// Another device's entry younger than the lifetime; one whose date cannot be read does not count.
    private func hasLiveDeviceEntry(now: Date) -> Bool {
        cloud.keys.contains { key in
            guard key.hasPrefix(Self.devicePrefix), key != deviceEntryKey,
                  let seconds = cloud.data(forKey: key)
                      .flatMap({ String(data: $0, encoding: .utf8) })
                      .flatMap({ Double($0) }) else { return false }
            return now.timeIntervalSince(Date(timeIntervalSince1970: seconds)) < Self.deviceLifetime
        }
    }

    /// Every key, including the format and keys of kinds this version does not know.
    private func removeEverything() {
        for key in cloud.keys { cloud.remove(key) }
    }

    private var cloudFormatIsNewer: Bool {
        cloudFormat.map { $0 > Self.format } ?? false
    }

    // MARK: - Changes from iCloud

    private func handle(_ change: CloudChange) {
        switch change {
        case .quotaExceeded:
            guard isOn else { return }
            update {
                quotaFull = true
                sizeBeforeNotice = lastSize
                found = .full
            }
        case .changed:
            guard isOn else { return }
            finishSyncing()
            onCloudChange?()
        case .accountChanged:
            guard isOn else { return }
            switchOffHere()
        }
    }

    // MARK: - Exchange

    /// Combines the library with iCloud and writes back what iCloud lacks or has older.
    /// Returns the input unchanged while off, not signed in, or when iCloud has a newer format.
    func exchange(_ library: Library, now: Date) -> Library {
        var result = library
        update { result = runExchange(library, now: now) }
        return result
    }

    private func runExchange(_ library: Library, now: Date) -> Library {
        guard isOn, !turnOffIfAccountDiffers() else { return library }
        if cloudFormatIsNewer {
            found = .needsUpdate
            return library
        }
        guard cloud.account != nil else {
            found = .notSignedIn
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
        found = restricted ? .full : .upToDate(lastSynced: lastSynced)
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
