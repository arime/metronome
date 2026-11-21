import Foundation

/// What the player card's Track content shows in its file-name row, and whether the track's file
/// can be played there (6.12). Read only while Backing tracks is on.
enum TrackCard: Equatable {
    case playable(fileName: String)
    case missing(fileName: String, fileID: UUID)
    case noTrack(songID: UUID)
    case nothingLoaded

    /// Dial white, amber, muted.
    enum TextStyle: Equatable { case fileName, missingFileName, noTrack }
    enum Pill: Equatable { case sync, chooseFile(ChooseFileTarget) }

    static func state(loadedSongID: UUID?, track: BackingTrack?, isPlayable: Bool) -> TrackCard {
        if let track {
            return isPlayable
                ? .playable(fileName: track.fileName)
                : .missing(fileName: track.fileName, fileID: track.fileID)
        }
        return loadedSongID.map { .noTrack(songID: $0) } ?? .nothingLoaded
    }

    /// The file's name, or `No track selected`.
    var text: String {
        switch self {
        case .playable(let fileName), .missing(let fileName, _): fileName
        case .noTrack, .nothingLoaded: "No track selected"
        }
    }

    var textStyle: TextStyle {
        switch self {
        case .playable: .fileName
        case .missing: .missingFileName
        case .noTrack, .nothingLoaded: .noTrack
        }
    }

    /// The pill at the row's right end; none with nothing loaded, as a track belongs to a song.
    var pill: Pill? {
        switch self {
        case .playable: .sync
        case .missing(_, let fileID): .chooseFile(.missingTrack(fileID: fileID))
        case .noTrack(let songID): .chooseFile(.song(id: songID))
        case .nothingLoaded: nil
        }
    }

    /// Whether there is a file to play: only then do the progress bar, Rewind and Fast-forward
    /// work and read in VoiceOver.
    var hasFile: Bool {
        if case .playable = self { return true }
        return false
    }

    var accessibilityLabel: String {
        switch self {
        case .playable(let fileName): "Backing track, \(fileName)"
        case .missing(let fileName, _): "Track missing, \(fileName)"
        case .noTrack, .nothingLoaded: "No track selected"
        }
    }
}
