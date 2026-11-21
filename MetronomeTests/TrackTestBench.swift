import Foundation
import Testing
@testable import Metronome

extension TrackFileStore {
    /// A store in a new temporary directory. Every model built in the tests gets one of its own,
    /// so no save can delete the track files of the app installed on the simulator.
    static func temporary() -> TrackFileStore {
        TrackFileStore(directory: FileManager.default.temporaryDirectory.appending(path: "TrackFiles-\(UUID().uuidString)"))
    }
}

/// Stores, fakes and a temporary directory for track files, removed when the bench goes away.
/// Shared by the suites that test a model with backing tracks.
@MainActor
final class TrackTestBench {
    let root: URL
    let trackFiles: TrackFileStore
    let engine = FakeClickEngine()
    let haptics = FakeHaptics()
    let settingsStore = SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    /// Where the library store keeps the library; counts the saves.
    let libraryDefaults = CountingDefaults(suiteName: UUID().uuidString)!
    let libraryStore: LibraryStore

    init() throws {
        libraryStore = LibraryStore(defaults: libraryDefaults)
        root = FileManager.default.temporaryDirectory.appending(path: "TrackTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        trackFiles = TrackFileStore(directory: root.appending(path: "Tracks"))
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    /// A file outside the store, as the song sheet hands over a picked file.
    func sourceFile(named name: String = "Song.m4a") throws -> URL {
        let folder = root.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: name)
        try Data("audio".utf8).write(to: url)
        return url
    }

    /// A track at 0.48 s whose file is stored, unless `missing`.
    func makeTrack(countIn: CountIn = .twoBars, mix: Double = 0, missing: Bool = false) throws -> BackingTrack {
        let track = BackingTrack(fileID: UUID(), fileName: "Song.m4a", offset: 48, countIn: countIn, mix: mix)
        if !missing {
            try trackFiles.store(try sourceFile(), as: track.fileID)
        }
        return track
    }

    /// A model whose loaded song is at `bpm` in 4/4, with the metronome on the song's settings, and
    /// a track whose offset is 0.48 s. With `missing` the track's file is not stored.
    func makeModel(
        bpm: Int = 120, length: TimeInterval = 222, countIn: CountIn = .twoBars, mix: Double = 0,
        missing: Bool = false
    ) throws -> MetronomeModel {
        let track = try makeTrack(countIn: countIn, mix: mix, missing: missing)
        let settings = MetronomeSettings(bpm: bpm, timeSignature: .fourFour, accents: [1])
        var library = Library()
        let added = library.addSong(name: "Song", settings: settings, track: track, now: Date())
        let song = try #require(added)
        libraryStore.save(LibraryState(library: library, loadedSongID: song.id))
        settingsStore.save(settings)
        return relaunch(length: length)
    }

    /// A new model on the same stores, as after the app is opened again.
    func relaunch(length: TimeInterval = 222) -> MetronomeModel {
        MetronomeModel(
            engine: engine, store: settingsStore, haptics: haptics, libraryStore: libraryStore,
            trackFiles: trackFiles, lengthOfTrack: { _ in length }
        )
    }
}

/// Counts every value written, so a test can tell how often the library was saved.
final class CountingDefaults: UserDefaults {
    private(set) var writes = 0

    override func set(_ value: Any?, forKey defaultName: String) {
        writes += 1
        super.set(value, forKey: defaultName)
    }
}
