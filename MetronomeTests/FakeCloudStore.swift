import Foundation
@testable import Metronome

/// iCloud key-value storage kept in memory. Two sync objects on one fake stand for two devices.
@MainActor
final class FakeCloudStore: CloudStore {
    private(set) var storage: [String: Data] = [:]
    /// Every set and remove, so a test can tell that nothing was written.
    private(set) var writes = 0
    var account: Data? = Data([1])
    var onChange: (@MainActor (CloudChange) -> Void)?
    private(set) var started = false

    var keys: [String] {
        Array(storage.keys)
    }

    func data(forKey key: String) -> Data? {
        storage[key]
    }

    func set(_ data: Data, forKey key: String) {
        storage[key] = data
        writes += 1
    }

    func remove(_ key: String) {
        storage[key] = nil
        writes += 1
    }

    func start() {
        started = true
    }

    func send(_ change: CloudChange) {
        onChange?(change)
    }

    /// Puts data in as if another device had written it, without counting a write.
    func plant(_ data: Data, forKey key: String) {
        storage[key] = data
    }
}
