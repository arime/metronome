import Foundation

/// Something that happened in iCloud that the app has to react to.
enum CloudChange: Sendable {
    /// Another device wrote something.
    case changed
    /// iCloud refused a write because the storage is full.
    case quotaExceeded
    /// The signed-in iCloud account is no longer the one the data came from.
    case accountChanged
}

/// The small key-value storage in iCloud, behind a protocol so tests can use an in-memory copy.
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
