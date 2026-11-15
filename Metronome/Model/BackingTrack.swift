import Foundation

/// Bars of click alone before the track starts; the raw value is the number of bars.
enum CountIn: Int, Codable, CaseIterable, Sendable {
    case off = 0, oneBar = 1, twoBars = 2
}

/// An audio file that plays locked to a song's click. Only these settings sync; the file stays on the device.
struct BackingTrack: Codable, Equatable, Sendable {
    /// Names the device's copy of the file.
    var fileID: UUID
    /// The file's name as shown to the user.
    var fileName: String
    /// Hundredths of a second, so 0.01 s steps compare exactly.
    var firstBeat: Int
    var countIn: CountIn
    /// -1 (Click end) ... 0 (centre) ... +1 (Track end).
    var mix: Double

    init(fileID: UUID, fileName: String, firstBeat: Int, countIn: CountIn = .twoBars, mix: Double = 0) {
        self.fileID = fileID
        self.fileName = fileName
        self.firstBeat = max(firstBeat, 0)
        self.countIn = countIn
        self.mix = min(max(mix, -1), 1)
    }

    var firstBeatSeconds: TimeInterval {
        TimeInterval(firstBeat) / 100
    }
}
