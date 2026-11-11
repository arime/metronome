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
            now: { clock.now() }
        )
        if on { model.setSyncEnabled(true) }
        return Device(model: model, engine: engine, haptics: haptics, sync: sync, libraryDefaults: libraryDefaults)
    }

    /// Device A makes "Song" at 100 BPM; B has it after a notice from iCloud.
    private func twoDevicesSharingASong() -> (a: Device, b: Device, song: Preset) {
        let a = makeDevice(), b = makeDevice()
        clock.advance()
        let song = a.model.createPreset(name: "Song", settings: settings(100), addingTo: nil)!
        cloud.send(.changed, toDevice: 1)
        return (a, b, song)
    }

    @Test func aPresetMadeOnOneDeviceAppearsOnTheOther() {
        let (_, b, song) = twoDevicesSharingASong()
        #expect(b.model.library.preset(id: song.id)?.name == "Song")
        #expect(b.model.library.preset(id: song.id)?.settings == settings(100))
    }

    @Test func anArrivedTempoMarksTheLoadedPresetEditedAndKeepsTheMetronome() {
        let (a, b, song) = twoDevicesSharingASong()
        b.model.togglePlayback()
        b.model.loadPreset(song.id, from: nil)
        let updateBefore = b.engine.lastUpdate
        #expect(updateBefore == settings(100))

        clock.advance()
        a.model.loadPreset(song.id, from: nil)
        a.model.setBPM(180)
        a.model.saveChanges()
        cloud.send(.changed, toDevice: 1)

        #expect(b.model.settings.bpm == 100)
        #expect(b.model.isEdited)
        #expect(b.model.headerSubtitle == "Edited")
        #expect(b.model.isPlaying)
        #expect(b.engine.lastUpdate == updateBefore)
        #expect(b.engine.startCount == 1)
        #expect(b.engine.stopCount == 0)
        b.model.discardChanges()
        #expect(b.model.settings.bpm == 180)
    }

    @Test func saveChangesAfterAnArrivalSendsTheMetronomesVersionBack() {
        let (a, b, song) = twoDevicesSharingASong()
        b.model.loadPreset(song.id, from: nil)
        clock.advance()
        a.model.loadPreset(song.id, from: nil)
        a.model.setBPM(180)
        a.model.saveChanges()
        cloud.send(.changed, toDevice: 1)

        clock.advance()
        b.model.saveChanges()
        a.model.appDidBecomeActive()

        #expect(a.model.library.preset(id: song.id)?.settings.bpm == 100)
        #expect(b.model.isEdited == false)
    }

    @Test func anArrivedNameShowsInTheHeaderAtOnce() {
        let (a, b, song) = twoDevicesSharingASong()
        b.model.loadPreset(song.id, from: nil)
        #expect(b.model.headerTitle == "Song")

        clock.advance()
        a.model.renamePreset(song.id, to: "Ballad")
        cloud.send(.changed, toDevice: 1)

        #expect(b.model.headerTitle == "Ballad")
        #expect(b.model.isEdited == false)
    }

    @Test func theLoadedPresetDeletedElsewhereWhilePlayingKeepsPlaying() {
        let (a, b, song) = twoDevicesSharingASong()
        b.model.loadPreset(song.id, from: nil, start: true)

        clock.advance()
        a.model.deletePreset(song.id)
        cloud.send(.changed, toDevice: 1)

        #expect(b.model.isPlaying)
        #expect(b.model.settings.bpm == 100)
        #expect(b.model.loadedPreset == nil)
        #expect(b.model.headerSubtitle == "No preset loaded")
        #expect(b.engine.stopCount == 0)
    }

    @Test func aDeletedSetlistClearsTheFilterAndTheLoadedFromSetlist() {
        let a = makeDevice(), b = makeDevice()
        clock.advance()
        let song = a.model.createPreset(name: "Song", settings: settings(100), addingTo: nil)!
        let setlist = a.model.createSetlist()
        a.model.setPreset(song.id, inSetlist: setlist, included: true)
        cloud.send(.changed, toDevice: 1)
        b.model.loadPreset(song.id, from: setlist)
        b.model.selectFilter(setlist)
        #expect(b.model.loadedFromSetlistID == setlist)
        #expect(b.model.selectedSetlistID == setlist)

        clock.advance()
        a.model.deleteSetlist(setlist)
        cloud.send(.changed, toDevice: 1)

        #expect(b.model.selectedSetlistID == nil)
        #expect(b.model.loadedFromSetlistID == nil)
        #expect(b.model.loadedPresetID == song.id)
    }

    @Test func arrivalsPlayNoHaptic() {
        let (a, b, song) = twoDevicesSharingASong()
        b.model.loadPreset(song.id, from: nil, start: true)
        let selections = b.haptics.selectionCount
        let transports = b.haptics.transportCount
        let beats = b.haptics.beats

        clock.advance()
        a.model.renamePreset(song.id, to: "Ballad")
        _ = a.model.createPreset(name: "Other", settings: settings(90), addingTo: nil)
        cloud.send(.changed, toDevice: 1)
        b.model.appDidBecomeActive()

        #expect(b.model.library.presets.count == 2)
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
        _ = device.model.createPreset(name: "Song", settings: settings(100), addingTo: nil)
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
}
