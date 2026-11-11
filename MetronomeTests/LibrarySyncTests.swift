import Foundation
import Testing
@testable import Metronome

@MainActor
struct LibrarySyncTests {
    private let t0 = Date(timeIntervalSince1970: 2_000_000_000)
    private let cloud = FakeCloudStore()

    private func t(_ n: Double) -> Date {
        t0 + n
    }

    private func settings(_ bpm: Int) -> MetronomeSettings {
        MetronomeSettings(bpm: bpm, timeSignature: .fourFour, accents: [1])
    }

    /// One device: its own defaults, sync turned on, on the shared fake iCloud.
    private func device() -> LibrarySync {
        let sync = LibrarySync(cloud: cloud, defaults: UserDefaults(suiteName: UUID().uuidString)!)
        sync.turnOn(now: t0)
        return sync
    }

    private func names(_ library: Library) -> [String] {
        library.presets.map(\.name).sorted()
    }

    private func keys(withPrefix prefix: String) -> [String] {
        cloud.keys.filter { $0.hasPrefix(prefix) }
    }

    @Test func aSecondDeviceGetsTheFirstOnesLibraryNextToItsOwn() {
        let a = device(), b = device()
        var libraryA = Library()
        libraryA.addPreset(name: "From A", settings: settings(100), now: t(1))
        var libraryB = Library()
        libraryB.addPreset(name: "From B", settings: settings(120), now: t(2))

        libraryA = a.exchange(libraryA, now: t(10))
        libraryB = b.exchange(libraryB, now: t(11))
        #expect(names(libraryB) == ["From A", "From B"])

        libraryA = a.exchange(libraryA, now: t(12))
        #expect(names(libraryA) == ["From A", "From B"])
    }

    @Test func aLaterChangeOnEitherDeviceReachesTheOther() {
        let a = device(), b = device()
        var libraryA = Library()
        let preset = libraryA.addPreset(name: "Song", settings: settings(100), now: t(1))!
        libraryA = a.exchange(libraryA, now: t(2))
        var libraryB = b.exchange(Library(), now: t(3))

        libraryB.renamePreset(preset.id, to: "Renamed", now: t(10))
        libraryB = b.exchange(libraryB, now: t(11))
        libraryA = a.exchange(libraryA, now: t(12))
        #expect(libraryA.preset(id: preset.id)?.name == "Renamed")

        libraryA.updatePreset(preset.id, settings: settings(150), now: t(20))
        libraryA = a.exchange(libraryA, now: t(21))
        libraryB = b.exchange(libraryB, now: t(22))
        #expect(libraryB.preset(id: preset.id)?.settings.bpm == 150)
        #expect(libraryB.preset(id: preset.id)?.name == "Renamed")
    }

    @Test func anExchangeWithNothingNewWritesNothing() {
        let sync = device()
        var library = Library()
        library.addPreset(name: "Song", settings: settings(100), now: t(1))
        let list = library.addSetlist(name: "Gig", now: t(1))
        library.add(library.presets[0].id, toSetlist: list.id, now: t(2))

        library = sync.exchange(library, now: t(3))
        let written = cloud.writes
        #expect(written > 0)

        let again = sync.exchange(library, now: t(4))
        #expect(cloud.writes == written)
        #expect(again == library)
        #expect(sync.status == .upToDate(lastSynced: t(3)))
    }

    @Test func anItemMissingFromICloudIsPutBack() {
        let sync = device()
        var library = Library()
        library.addPreset(name: "Song", settings: settings(100), now: t(1))
        library.addSetlist(name: "Gig", now: t(1))
        library = sync.exchange(library, now: t(2))
        let before = Dictionary(uniqueKeysWithValues: cloud.keys.map { ($0, cloud.data(forKey: $0)) })

        for key in cloud.keys { cloud.remove(key) }
        let again = sync.exchange(library, now: t(3))

        #expect(again == library)
        #expect(Dictionary(uniqueKeysWithValues: cloud.keys.map { ($0, cloud.data(forKey: $0)) }) == before)
        #expect(keys(withPrefix: "p.").count == 1)
    }

    @Test func aMarkerOlderThanAYearIsRemovedFromDeviceAndICloud() {
        let sync = device()
        var library = Library()
        let preset = library.addPreset(name: "Song", settings: settings(100), now: t(0))!
        library.deletePreset(preset.id, now: t(0))
        library = sync.exchange(library, now: t(1))
        #expect(keys(withPrefix: "p.").count == 1)

        library = sync.exchange(library, now: t(0) + 366 * 86_400)
        #expect(keys(withPrefix: "p.").isEmpty)
        #expect(library.itemCount == 0)
    }

    @Test func theOldestMarkersGoFirstWhenTheLibraryDoesNotFit() {
        let sync = device()
        var library = Library()
        var deleted: [UUID] = []
        for index in 0..<1010 {
            let id = library.addPreset(name: "P\(index)", settings: settings(100), now: t(0))!.id
            if index < 20 { deleted.append(id) }
        }
        for (index, id) in deleted.enumerated() {
            library.deletePreset(id, now: t(100 + Double(index)))
        }

        library = sync.exchange(library, now: t(5_000))

        #expect(library.itemCount == 999)
        #expect(deleted.prefix(11).allSatisfy { library.presetRecords[$0] == nil })
        #expect(deleted.suffix(9).allSatisfy { library.presetRecords[$0]?.deleted != nil })
        #expect(keys(withPrefix: "p.").count == 999)
        #expect(sync.status == .upToDate(lastSynced: t(5_000)))
    }

    @Test func aLibraryThatCannotFitIsFullAndKeepsWorking() {
        let sync = device()
        var library = Library()
        for index in 0..<1005 {
            library.addPreset(name: "P\(index)", settings: settings(100), now: t(0))
        }

        let result = sync.exchange(library, now: t(1))

        #expect(sync.status == .full)
        #expect(result == library)
        #expect(keys(withPrefix: "p.").isEmpty)
    }

    @Test func aQuotaNoticeSetsFull() {
        let sync = device()
        var library = Library()
        library.addPreset(name: "Song", settings: settings(100), now: t(1))
        library = sync.exchange(library, now: t(2))
        #expect(sync.status == .upToDate(lastSynced: t(2)))

        cloud.send(.quotaExceeded)
        #expect(sync.status == .full)

        _ = sync.exchange(library, now: t(3))
        #expect(sync.status == .full)
    }

    @Test func aChangeOrAnAccountChangeDoesNotCrashOrChangeTheStatus() {
        let sync = device()
        cloud.send(.changed)
        cloud.send(.accountChanged)
        #expect(sync.status == .upToDate(lastSynced: nil))
    }

    @Test func aNewerFormatStopsSyncWithoutChangingICloud() {
        let sync = device()
        cloud.plant(Data("2".utf8), forKey: "format")
        cloud.plant(Data("{}".utf8), forKey: "p.\(UUID().uuidString)")
        let before = Dictionary(uniqueKeysWithValues: cloud.keys.map { ($0, cloud.data(forKey: $0)) })
        var library = Library()
        library.addPreset(name: "Song", settings: settings(100), now: t(1))

        let result = sync.exchange(library, now: t(2))

        #expect(sync.status == .needsUpdate)
        #expect(result == library)
        #expect(Dictionary(uniqueKeysWithValues: cloud.keys.map { ($0, cloud.data(forKey: $0)) }) == before)
        #expect(cloud.writes == 0)
    }

    @Test func notSignedInWaitsWithoutTouchingICloud() {
        let sync = device()
        cloud.account = nil
        var library = Library()
        library.addPreset(name: "Song", settings: settings(100), now: t(1))

        let result = sync.exchange(library, now: t(2))

        #expect(sync.status == .notSignedIn)
        #expect(result == library)
        #expect(cloud.writes == 0)
        #expect(cloud.keys.isEmpty)
    }

    @Test func whileOffNothingHappens() {
        let sync = LibrarySync(cloud: cloud, defaults: UserDefaults(suiteName: UUID().uuidString)!)
        var library = Library()
        library.addPreset(name: "Song", settings: settings(100), now: t(1))

        #expect(sync.status == nil)
        #expect(sync.exchange(library, now: t(2)) == library)
        #expect(cloud.writes == 0)
    }

    // Review Focus 3
    @Test func unreadableDataIsSkippedKeptOrRepaired() {
        let a = device(), b = device()
        var libraryA = Library()
        let owned = libraryA.addPreset(name: "Mine", settings: settings(100), now: t(1))!
        var libraryB = Library()
        libraryB.addPreset(name: "Theirs", settings: settings(130), now: t(1))
        _ = b.exchange(libraryB, now: t(2))

        let unknownKey = "p.\(UUID().uuidString)"
        cloud.plant(Data("garbage".utf8), forKey: "p.\(owned.id.uuidString)")
        cloud.plant(Data("garbage".utf8), forKey: unknownKey)
        cloud.plant(Data("anything".utf8), forKey: "x.future")

        libraryA = a.exchange(libraryA, now: t(3))

        #expect(names(libraryA) == ["Mine", "Theirs"])
        let repaired = cloud.data(forKey: "p.\(owned.id.uuidString)")
        #expect(repaired.flatMap { try? JSONDecoder().decode(PresetRecord.self, from: $0) }?.id == owned.id)
        #expect(cloud.data(forKey: unknownKey) == Data("garbage".utf8))
        #expect(cloud.data(forKey: "x.future") == Data("anything".utf8))
    }
}
