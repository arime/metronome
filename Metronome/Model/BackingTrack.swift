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
    var offset: Int
    var countIn: CountIn
    /// -1 (Click end) ... 0 (centre) ... +1 (Track end).
    var mix: Double

    init(fileID: UUID, fileName: String, offset: Int, countIn: CountIn = .twoBars, mix: Double = 0) {
        self.fileID = fileID
        self.fileName = fileName
        self.offset = max(offset, 0)
        self.countIn = countIn
        self.mix = min(max(mix, -1), 1)
    }

    /// Read through `init`, so stored values are kept in range too.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            fileID: try container.decode(UUID.self, forKey: .fileID),
            fileName: try container.decode(String.self, forKey: .fileName),
            offset: try container.decode(Int.self, forKey: .offset),
            countIn: try container.decode(CountIn.self, forKey: .countIn),
            mix: try container.decode(Double.self, forKey: .mix)
        )
    }

    var offsetSeconds: TimeInterval {
        TimeInterval(offset) / 100
    }

    /// The offset keeps its stored name, so tracks already on devices and in iCloud still read.
    /// The song's tempo, which the stored track part repeats, is `SongRecord`'s to write and read.
    private enum CodingKeys: String, CodingKey {
        case fileID, fileName, offset = "firstBeat", countIn, mix
    }
}
