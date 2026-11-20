import Foundation
import Testing
@testable import Metronome

/// A clock the tests move by hand, so that a later change really is later.
@MainActor
private final class Clock {
    private var current = Date(timeIntervalSince1970: 2_000_000_000)

    func now() -> Date {
        current
    }

    func advance() {
        current += 10
    }
}

@MainActor
struct SyncModelTests {
    private let cloud = FakeCloudStore()
    private let clock = Clock()

    /// One phone: its own model, fakes and stores, with sync on the shared fake iCloud.
    private struct Device {
        let model: MetronomeModel
        let engine: FakeClickEngine
        let haptics: FakeHaptics
        let sync: LibrarySync
        /// Where the library store keeps the library, so a test can tell whether it was saved.
        let libraryDefaults: UserDefaults
    }

    private func settings(_ bpm: Int) -> MetronomeSettings {
        MetronomeSettings(bpm: bpm, timeSignature: .fourFour, accents: [1])
    }

    /// Devices are numbered in the order they are made: the first is 0 for `cloud.send`.
    private func makeDevice(defaults: UserDefaults = UserDefaults(suiteName: UUID().uuidString)!, on: Bool = true) -> Device {
        let engine = FakeClickEngine()
        let haptics = FakeHaptics()
        let clock = clock
        let sync = LibrarySync(cloud: cloud, defaults: defaults, syncingDelay: .seconds(3600))
        let libraryDefaults = UserDefaults(suiteName: UUID().uuidString)!
        let model = MetronomeModel(
            engine: engine,
            store: SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!),
            haptics: haptics,
            libraryStore: LibraryStore(defaults: libraryDefaults),
            sync: sync,
            now: { clock.now() },
            trackFiles: .temporary()
        )
        if on { model.setSyncEnabled(true) }
        return Device(model: model, engine: engine, haptics: haptics, sync: sync, libraryDefaults: libraryDefaults)
    }

    /// Device A makes "Song" at 100 BPM; B has it after a notice from iCloud.
    private func twoDevicesSharingASong() -> (a: Device, b: Device, song: Song) {
        let a = makeDevice(), b = makeDevice()
        clock.advance()
        let song = a.model.createSong(name: "Song", settings: settings(100), addingTo: nil)!
        cloud.send(.changed, toDevice: 1)
        return (a, b, song)
    }

    @Test func aSongMadeOnOneDeviceAppearsOnTheOther() {
        let (_, b, song) = twoDevicesSharingASong()
        #expect(b.model.library.song(id: song.id)?.name == "Song")
        #expect(b.model.library.song(id: song.id)?.settings == settings(100))
    }

    @Test func anArrivedTempoMarksTheLoadedSongEditedAndKeepsTheMetronome() {
        let (a, b, song) = twoDevicesSharingASong()
        b.model.togglePlayback()
        b.model.loadSong(song.id, from: nil)
        let updateBefore = b.engine.lastUpdate
        #expect(updateBefore == settings(100))

        clock.advance()
        a.model.loadSong(song.id, from: nil)
        a.model.setBPM(180)
        a.model.saveChanges()
        cloud.send(.changed, toDevice: 1)

        #expect(b.model.settings.bpm == 100)
        #expect(b.model.isEdited)
        #expect(b.model.headerSubtitle == nil)
        #expect(b.model.headerAccessibilityLabel.contains("edited"))
        #expect(b.model.isPlaying)
        #expect(b.engine.lastUpdate == updateBefore)
        #expect(b.engine.startCount == 1)
        #expect(b.engine.stopCount == 0)
        b.model.discardChanges()
        #expect(b.model.settings.bpm == 180)
    }

    @Test func saveChangesAfterAnArrivalSendsTheMetronomesVersionBack() {
        let (a, b, song) = twoDevicesSharingASong()
        b.model.loadSong(song.id, from: nil)
        clock.advance()
        a.model.loadSong(song.id, from: nil)
        a.model.setBPM(180)
        a.model.saveChanges()
        cloud.send(.changed, toDevice: 1)

        clock.advance()
        b.model.saveChanges()
        a.model.appDidBecomeActive()

        #expect(a.model.library.song(id: song.id)?.settings.bpm == 100)
        #expect(b.model.isEdited == false)
    }

    @Test func lastPlayedTimesAndOrdersStayOnTheDevice() throws {
        let (a, b, song) = twoDevicesSharingASong()
        clock.advance()
        let other = try #require(a.model.createSong(name: "Other", settings: settings(90), addingTo: nil))
        cloud.send(.changed, toDevice: 1)
        b.model.loadSong(song.id, from: nil)
        clock.advance()
        b.model.loadSong(other.id, from: nil)
        let bLoadedOther = clock.now()
        b.model.songOrder = .recentlyPlayed
        b.model.setlistOrder = .recentlyUsed

        clock.advance()
        a.model.loadSong(other.id, from: nil)
        a.model.deleteSong(song.id)
        cloud.send(.changed, toDevice: 1)

        #expect(b.model.library.song(id: song.id) == nil)
        #expect(b.model.lastPlayed == [other.id: bLoadedOther])
        #expect(b.model.songOrder == .recentlyPlayed)
        #expect(b.model.setlistOrder == .recentlyUsed)
        #expect(a.model.lastPlayed == [other.id: clock.now()])
        #expect(a.model.songOrder == .name)
        #expect(a.model.setlistOrder == .name)
    }

    @Test func anArrivedNameShowsInTheHeaderAtOnce() {
        let (a, b, song) = twoDevicesSharingASong()
        b.model.loadSong(song.id, from: nil)
        #expect(b.model.headerTitle == "Song")

        clock.advance()
        a.model.renameSong(song.id, to: "Ballad")
        cloud.send(.changed, toDevice: 1)

        #expect(b.model.headerTitle == "Ballad")
        #expect(b.model.isEdited == false)
    }

    @Test func theLoadedSongDeletedElsewhereWhilePlayingKeepsPlaying() {
        let (a, b, song) = twoDevicesSharingASong()
        b.model.loadSong(song.id, from: nil, start: true)

        clock.advance()
        a.model.deleteSong(song.id)
        cloud.send(.changed, toDevice: 1)

        #expect(b.model.isPlaying)
        #expect(b.model.settings.bpm == 100)
        #expect(b.model.loadedSong == nil)
        #expect(b.model.headerSubtitle == "No song loaded")
        #expect(b.engine.stopCount == 0)
    }

    @Test func theLoadedSongDeletedElsewhereCountsAfresh() {
        let (a, b, song) = twoDevicesSharingASong()
        b.model.loadSong(song.id, from: nil, start: true)
        for beat in [1, 2, 3, 4, 1, 2, 3, 4, 1] {
            b.engine.onBeat?(ScheduledBeat(beat: beat, isAccented: beat == 1, sampleTime: 0))
        }
        #expect(b.model.readout().bar == "Bar 3")

        clock.advance()
        a.model.deleteSong(song.id)
        cloud.send(.changed, toDevice: 1)

        #expect(b.model.loadedSong == nil)
        #expect(b.model.readout().time == "0:00")
        #expect(b.model.readout().bar == "Bar 1")
    }

    @Test func aDeletedSetlistClearsTheFilterAndTheLoadedFromSetlist() {
        let a = makeDevice(), b = makeDevice()
        clock.advance()
        let song = a.model.createSong(name: "Song", settings: settings(100), addingTo: nil)!
        let setlist = a.model.createSetlist()
        a.model.setSong(song.id, inSetlist: setlist, included: true)
        cloud.send(.changed, toDevice: 1)
        b.model.loadSong(song.id, from: setlist)
        b.model.selectFilter(setlist)
        #expect(b.model.loadedFromSetlistID == setlist)
        #expect(b.model.selectedSetlistID == setlist)

        clock.advance()
        a.model.deleteSetlist(setlist)
        cloud.send(.changed, toDevice: 1)

        #expect(b.model.selectedSetlistID == nil)
        #expect(b.model.loadedFromSetlistID == nil)
        #expect(b.model.loadedSongID == song.id)
    }

    @Test func aTickedSongTakenOutElsewhereLeavesTheSelection() throws {
        let a = makeDevice(), b = makeDevice()
        clock.advance()
        let songs = try ["S1", "S2", "S3"].map {
            try #require(a.model.createSong(name: $0, settings: settings(100), addingTo: nil))
        }
        let setlist = a.model.createSetlist()
        a.model.addSongs(songs.map(\.id), toSetlist: setlist)
        cloud.send(.changed, toDevice: 1)
        var ticks = SongSelection()
        ticks.toggle(songs[0].id)
        ticks.toggle(songs[1].id)

        clock.advance()
        a.model.removeSongs([songs[1].id], fromSetlist: setlist)
        cloud.send(.changed, toDevice: 1)

        let members = try #require(b.model.library.setlist(id: setlist)).songIDs
        ticks.keep(only: Set(members))
        #expect(ticks.ids == [songs[0].id])
        #expect(ticks.title == "1 selected")
        #expect(b.model.library.song(id: songs[1].id) != nil)
    }

    @Test func steppingThroughASetlistWritesNothingToICloud() throws {
        let device = makeDevice()
        clock.advance()
        let setlist = device.model.createSetlist()
        var songs: [UUID] = []
        for (index, name) in ["One", "Two", "Three"].enumerated() {
            let song = try #require(device.model.createSong(name: name, settings: settings(100 + index), addingTo: nil))
            device.model.setSong(song.id, inSetlist: setlist, included: true)
            songs.append(song.id)
        }
        clock.advance()
        device.model.loadSong(songs[0], from: setlist)
        cloud.forgetWrites()

        clock.advance()
        device.model.goToNext()
        clock.advance()
        device.model.goToNext()
        clock.advance()
        device.model.goToPrevious()
        clock.advance()
        device.model.selectFilter(setlist)

        #expect(device.model.loadedSongID == songs[1])
        #expect(cloud.writes == 0)
    }

    @Test func arrivalsPlayNoHaptic() {
        let (a, b, song) = twoDevicesSharingASong()
        b.model.loadSong(song.id, from: nil, start: true)
        let selections = b.haptics.selectionCount
        let transports = b.haptics.transportCount
        let beats = b.haptics.beats

        clock.advance()
        a.model.renameSong(song.id, to: "Ballad")
        _ = a.model.createSong(name: "Other", settings: settings(90), addingTo: nil)
        cloud.send(.changed, toDevice: 1)
        b.model.appDidBecomeActive()

        #expect(b.model.library.songs.count == 2)
        #expect(b.haptics.selectionCount == selections)
        #expect(b.haptics.transportCount == transports)
        #expect(b.haptics.beats == beats)
    }

    /// The stored library is replaced by a marker; a save would overwrite it.
    @Test func aNoticeThatBringsNothingNewSavesNothing() {
        let (_, b, _) = twoDevicesSharingASong()
        let library = b.model.library
        let marker = Data("not saved again".utf8)
        b.libraryDefaults.set(marker, forKey: "metronome.library.v2")

        clock.advance()
        cloud.send(.changed, toDevice: 1)

        #expect(b.model.library == library)
        #expect(b.libraryDefaults.data(forKey: "metronome.library.v2") == marker)
    }

    @Test func withSyncOffNothingReachesICloud() {
        let device = makeDevice(on: false)
        cloud.forgetWrites()
        _ = device.model.createSong(name: "Song", settings: settings(100), addingTo: nil)
        let setlist = device.model.createSetlist()
        device.model.renameSetlist(setlist, to: "Gig")
        device.model.appDidBecomeActive()

        #expect(cloud.writes == 0)
        #expect(device.model.syncEnabled == false)
        #expect(device.model.syncStatus == nil)
    }

    @Test func theSwitchSurvivesRelaunch() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let first = makeDevice(defaults: defaults, on: false)
        #expect(first.model.syncEnabled == false)
        first.model.setSyncEnabled(true)
        #expect(first.model.syncEnabled)
        #expect(first.model.syncStatus == .syncing)

        let relaunched = makeDevice(defaults: defaults, on: false)
        #expect(relaunched.model.syncEnabled)
        #expect(relaunched.model.syncStatus != nil)

        relaunched.model.setSyncEnabled(false)
        #expect(relaunched.model.syncEnabled == false)
        #expect(relaunched.model.syncStatus == nil)
    }

    // MARK: - Stage mode

    /// A makes S1, S2 and S3 and a setlist of them; B has them and shows the setlist in stage mode.
    private func stageModeOnTheOtherDevice() throws -> (a: Device, b: Device, songs: [UUID], setlist: UUID) {
        let a = makeDevice(), b = makeDevice()
        clock.advance()
        let songs = try ["S1", "S2", "S3"].map {
            try #require(a.model.createSong(name: $0, settings: settings(100), addingTo: nil)).id
        }
        let setlist = a.model.createSetlist()
        a.model.addSongs(songs, toSetlist: setlist)
        cloud.send(.changed, toDevice: 1)
        b.model.enterStageMode(setlistID: setlist)
        try #require(b.model.stageMode != nil)
        return (a, b, songs, setlist)
    }

    @Test func stageModeFollowsAReorderFromAnotherDevice() throws {
        let (a, b, songs, setlist) = try stageModeOnTheOtherDevice()
        b.model.loadSong(songs[0], from: setlist)

        clock.advance()
        a.model.reorderSetlist(setlist, to: [songs[2], songs[0], songs[1]])
        cloud.send(.changed, toDevice: 1)

        #expect(b.model.stageTiles.map(\.song.id) == [songs[2], songs[0], songs[1]])
        #expect(b.model.stageTiles.map(\.number) == [1, 2, 3])
        #expect(b.model.stageTiles.map(\.mark) == [.none, .active, .none])
    }

    @Test func theActiveMarkGoesWhenItsSongLeavesTheSetlist() throws {
        let (a, b, songs, setlist) = try stageModeOnTheOtherDevice()
        b.model.loadSong(songs[0], from: setlist)
        try #require(b.model.stageTiles.map(\.mark) == [.active, .none, .none])

        clock.advance()
        a.model.removeSongs([songs[0]], fromSetlist: setlist)
        cloud.send(.changed, toDevice: 1)

        #expect(b.model.stageTiles.map(\.song.id) == [songs[1], songs[2]])
        #expect(b.model.stageTiles.map(\.mark) == [.none, .none])
    }

    @Test func stageModeClosesWhenItsSetlistIsDeletedElsewhere() throws {
        let (a, b, _, setlist) = try stageModeOnTheOtherDevice()

        clock.advance()
        a.model.deleteSetlist(setlist)
        cloud.send(.changed, toDevice: 1)

        #expect(b.model.stageMode == nil)
    }

    @Test func stageModeClosesWhenItsSetlistIsEmptiedElsewhere() throws {
        let (a, b, songs, setlist) = try stageModeOnTheOtherDevice()

        clock.advance()
        a.model.removeSongs(songs, fromSetlist: setlist)
        cloud.send(.changed, toDevice: 1)

        #expect(b.model.library.setlist(id: setlist)?.songIDs == [])
        #expect(b.model.stageMode == nil)
    }

    @Test func stageModeClosesOnceStoppedWhenItsSetlistGoesWhilePlaying() throws {
        let (a, b, songs, setlist) = try stageModeOnTheOtherDevice()
        b.model.tapStageTile(songs[0])
        try #require(b.model.isPlaying)

        clock.advance()
        a.model.deleteSetlist(setlist)
        cloud.send(.changed, toDevice: 1)

        #expect(b.model.stageMode != nil)
        #expect(b.model.isPlaying)
        #expect(b.model.canLeaveStageMode)
        b.model.stop()
        #expect(b.model.stageMode == nil)
    }

    @Test func stageModeClosesOnceStoppedWhenItsSetlistIsEmptiedWhilePlaying() throws {
        let (a, b, songs, setlist) = try stageModeOnTheOtherDevice()
        b.model.tapStageTile(songs[0])
        try #require(b.model.isPlaying)

        clock.advance()
        a.model.removeSongs(songs, fromSetlist: setlist)
        cloud.send(.changed, toDevice: 1)

        #expect(b.model.library.setlist(id: setlist)?.songIDs == [])
        #expect(b.model.isPlaying)
        #expect(b.model.stageMode != nil)
        #expect(b.model.canLeaveStageMode)
        b.model.stop()
        #expect(b.model.stageMode == nil)
    }

    @Test func stoppingASongWithNoTileMarksNothing() throws {
        let (a, b, songs, setlist) = try stageModeOnTheOtherDevice()
        b.model.tapStageTile(songs[1])
        try #require(b.model.stagePlayingSongID == songs[1])

        clock.advance()
        a.model.removeSongs([songs[1]], fromSetlist: setlist)
        cloud.send(.changed, toDevice: 1)
        try #require(b.model.isPlaying)
        try #require(b.model.stagePlayingSongID == nil)

        b.model.stop()
        #expect(b.model.stageTiles.map(\.mark) == [.none, .none])
    }

    /// Back in the setlist, the song still plays with no tile: it was not loaded from it again.
    @Test func stoppingASongThatCameBackWithNoTileMarksNothing() throws {
        let (a, b, songs, setlist) = try stageModeOnTheOtherDevice()
        b.model.tapStageTile(songs[1])
        try #require(b.model.stagePlayingSongID == songs[1])

        clock.advance()
        a.model.removeSongs([songs[1]], fromSetlist: setlist)
        cloud.send(.changed, toDevice: 1)
        clock.advance()
        a.model.addSongs([songs[1]], toSetlist: setlist)
        cloud.send(.changed, toDevice: 1)
        try #require(b.model.isPlaying)
        try #require(b.model.library.setlist(id: setlist)?.songIDs.contains(songs[1]) == true)
        try #require(b.model.stagePlayingSongID == nil)

        b.model.stop()
        #expect(b.model.stageTiles.map(\.mark) == [.none, .none, .none])
    }

    @Test func thePlayingSongLeavingTheSetlistLeavesDoneWorking() throws {
        let (a, b, songs, setlist) = try stageModeOnTheOtherDevice()
        b.model.tapStageTile(songs[1])
        try #require(b.model.stagePlayingSongID == songs[1])

        clock.advance()
        a.model.removeSongs([songs[1]], fromSetlist: setlist)
        cloud.send(.changed, toDevice: 1)

        #expect(b.model.isPlaying)
        #expect(b.model.stagePlayingSongID == nil)
        #expect(b.model.canLeaveStageMode)
        #expect(b.model.stageTiles.map(\.song.id) == [songs[0], songs[2]])
        #expect(b.model.stageTiles.allSatisfy { $0.isDimmed })
        b.model.tapStageTile(songs[0])
        #expect(b.model.isPlaying)
        #expect(b.model.loadedSongID == songs[1])
    }
}
