import Foundation

/// Turns a file chosen in the Files picker into a `PickedTrack`: a copy in a new folder of its
/// own, under the file's own name, checked as audio and with its first sound found.
///
/// Every copy lives under one folder of the temporary directory. The song sheet discards its copy
/// once it is saved or dropped, and the folder is emptied at launch for any copy a crash left behind.
enum PickedFileReader {
    static let defaultFolder = FileManager.default.temporaryDirectory
        .appending(path: "PickedTracks", directoryHint: .isDirectory)

    /// Throws when the file cannot be copied or read as audio; then nothing is left behind.
    static func read(_ picked: URL, into root: URL = defaultFolder) throws -> PickedTrack {
        let manager = FileManager.default
        let folder = root.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let copy = folder.appending(path: picked.lastPathComponent)
        do {
            // A file from the picker can be opened only while access is held; the copy is made then.
            let isAccessing = picked.startAccessingSecurityScopedResource()
            defer { if isAccessing { picked.stopAccessingSecurityScopedResource() } }
            try manager.createDirectory(at: folder, withIntermediateDirectories: true)
            try manager.copyItem(at: picked, to: copy)
        } catch {
            try? manager.removeItem(at: folder)
            throw error
        }
        do {
            _ = try TrackAudio.length(of: copy)
            let offset = try TrackAudio.firstSound(in: copy)
            return PickedTrack(url: copy, fileName: picked.lastPathComponent, offset: offset)
        } catch {
            try? manager.removeItem(at: folder)
            throw error
        }
    }

    /// Deletes a pick's copy and its folder.
    static func discard(_ picked: PickedTrack) {
        try? FileManager.default.removeItem(at: picked.url.deletingLastPathComponent())
    }

    /// Deletes every copy left in the folder.
    static func emptyFolder(_ root: URL = defaultFolder) {
        try? FileManager.default.removeItem(at: root)
    }
}
