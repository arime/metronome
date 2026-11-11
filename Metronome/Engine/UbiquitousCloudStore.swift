import Foundation

/// The real iCloud key-value storage, a thin layer over NSUbiquitousKeyValueStore.
@MainActor
final class UbiquitousCloudStore: CloudStore {
    private let store = NSUbiquitousKeyValueStore.default
    private var observer: NSObjectProtocol?

    var onChange: (@MainActor (CloudChange) -> Void)?

    init() {}

    var keys: [String] { Array(store.dictionaryRepresentation.keys) }

    func data(forKey key: String) -> Data? { store.data(forKey: key) }

    func set(_ data: Data, forKey key: String) { store.set(data, forKey: key) }

    func remove(_ key: String) { store.removeObject(forKey: key) }

    /// The current account token, read fresh each time so a switch of account shows up.
    var account: Data? {
        guard let token = FileManager.default.ubiquityIdentityToken else { return nil }
        return try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
    }

    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store, queue: .main
        ) { [weak self] notification in
            // Pull out the plain integer here; the notification itself is not Sendable.
            let reason = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
            MainActor.assumeIsolated { self?.handleChange(reason: reason) }
        }
        store.synchronize()    }

    private func handleChange(reason: Int?) {
        switch reason {
        case NSUbiquitousKeyValueStoreServerChange, NSUbiquitousKeyValueStoreInitialSyncChange:
            onChange?(.changed)
        case NSUbiquitousKeyValueStoreQuotaViolationChange:
            onChange?(.quotaExceeded)
        case NSUbiquitousKeyValueStoreAccountChange:
            onChange?(.accountChanged)
        default:
            break
        }
    }
}
