import Foundation

/// The app's own copies of backing-track files, one per identifier, named <uuid>.<original extension>.
/// They stay on this device and are never synced (spec 5.1).
struct TrackFileStore: Sendable {
    let directory: URL

    /// Defaults to Application Support/BackingTracks, which the device backup includes. Created on first use.
    init(directory: URL = TrackFileStore.defaultDirectory) {
        self.directory = directory
    }

    static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "BackingTracks", directoryHint: .isDirectory)
    }

    /// nil when no copy is here.
    func url(for fileID: UUID) -> URL? {
        copies().first { Self.identifier(of: $0) == fileID }
    }

    func hasFile(_ fileID: UUID) -> Bool {
        url(for: fileID) != nil
    }

    /// Copies the file in, replacing any copy under the same identifier. Keeps the source's extension.
    /// The copy is made under a temporary name first, so a failed copy leaves the old one in place.
    func store(_ source: URL, as fileID: UUID) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let incoming = directory.appending(path: Self.incomingPrefix + UUID().uuidString)
        try manager.copyItem(at: source, to: incoming)
        for old in copies() where Self.identifier(of: old) == fileID {
            try? manager.removeItem(at: old)
        }
        var name = fileID.uuidString
        if !source.pathExtension.isEmpty {
            name += ".\(source.pathExtension)"
        }
        do {
            try manager.moveItem(at: incoming, to: directory.appending(path: name))
        } catch {
            try? manager.removeItem(at: incoming)
            throw error
        }
    }

    /// Deletes every copy whose identifier is not in the set, and any copy left half made
    /// when the app was ended during `store`.
    func removeAll(except keep: Set<UUID>) {
        for url in copies() {
            if let id = Self.identifier(of: url) {
                guard !keep.contains(id) else { continue }
            } else {
                guard url.lastPathComponent.hasPrefix(Self.incomingPrefix) else { continue }
            }
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// The name of a copy being made starts with this.
    private static let incomingPrefix = ".incoming-"

    /// The files in the directory; empty when it does not exist yet.
    private func copies() -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
    }

    /// The identifier a copy is named after, or nil for anything else in the directory.
    private static func identifier(of url: URL) -> UUID? {
        UUID(uuidString: url.deletingPathExtension().lastPathComponent)
    }
}
