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

    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: UUID().uuidString)!
    }

    /// A sync object whose two-second wait never ends by itself; tests end it with finishSyncing().
    private func makeSync(_ defaults: UserDefaults) -> LibrarySync {
        LibrarySync(cloud: cloud, defaults: defaults, syncingDelay: .seconds(3600))
    }

    /// One device: its own defaults, sync turned on and past its first wait, on the shared fake
    /// iCloud. What switching on wrote is not counted in `cloud.writes`.
    private func device(_ defaults: UserDefaults? = nil) -> LibrarySync {
        let sync = makeSync(defaults ?? freshDefaults())
        sync.turnOn(now: t0)
        sync.finishSyncing()
        cloud.forgetWrites()
        return sync
    }

    /// Switched on while not signed in, so no device entry has been written.
    private func deviceWithoutEntry() -> LibrarySync {
        let account = cloud.account
        cloud.account = nil
        let sync = device()
        cloud.account = account
        return sync
    }

    private func entryKey(_ defaults: UserDefaults) -> String {
        "d." + defaults.string(forKey: "metronome.sync.deviceID")!
    }

    private func snapshot() -> [String: Data?] {
        Dictionary(uniqueKeysWithValues: cloud.keys.map { ($0, cloud.data(forKey: $0)) })
    }

    private func names(_ library: Library) -> [String] {
        library.songs.map(\.name).sorted()
    }

    private func keys(withPrefix prefix: String) -> [String] {
        cloud.keys.filter { $0.hasPrefix(prefix) }
    }

    @Test func aSecondDeviceGetsTheFirstOnesLibraryNextToItsOwn() {
        let a = device(), b = device()
        var libraryA = Library()
        libraryA.addSong(name: "From A", settings: settings(100), now: t(1))
        var libraryB = Library()
        libraryB.addSong(name: "From B", settings: settings(120), now: t(2))

        libraryA = a.exchange(libraryA, now: t(10))
        libraryB = b.exchange(libraryB, now: t(11))
        #expect(names(libraryB) == ["From A", "From B"])

        libraryA = a.exchange(libraryA, now: t(12))
        #expect(names(libraryA) == ["From A", "From B"])
    }

    @Test func aLaterChangeOnEitherDeviceReachesTheOther() {
        let a = device(), b = device()
        var libraryA = Library()
        let song = libraryA.addSong(name: "Song", settings: settings(100), now: t(1))!
        libraryA = a.exchange(libraryA, now: t(2))
        var libraryB = b.exchange(Library(), now: t(3))

        libraryB.renameSong(song.id, to: "Renamed", now: t(10))
        libraryB = b.exchange(libraryB, now: t(11))
        libraryA = a.exchange(libraryA, now: t(12))
        #expect(libraryA.song(id: song.id)?.name == "Renamed")

        libraryA.updateSong(song.id, settings: settings(150), now: t(20))
        libraryA = a.exchange(libraryA, now: t(21))
        libraryB = b.exchange(libraryB, now: t(22))
        #expect(libraryB.song(id: song.id)?.settings.bpm == 150)
        #expect(libraryB.song(id: song.id)?.name == "Renamed")
    }

    @Test func anExchangeWithNothingNewWritesNothing() {
        let sync = device()
        var library = Library()
        library.addSong(name: "Song", settings: settings(100), now: t(1))
        let list = library.addSetlist(name: "Gig", now: t(1))
        library.add(library.songs[0].id, toSetlist: list.id, now: t(2))

        library = sync.exchange(library, now: t(3))
        let written = cloud.writes
        #expect(written > 0)

        let again = sync.exchange(library, now: t(4))
        #expect(cloud.writes == written)
        #expect(again == library)
        #expect(sync.status == .upToDate(lastSynced: t(3)))
    }

    @Test func aRecordWithAnUnknownLargeIntegerIsNotRewritten() {
        let sync = device()
        var library = Library()
        let song = library.addSong(name: "Song", settings: settings(100), now: t(1))!
        library = sync.exchange(library, now: t(2))
        let key = "song.\(song.id.uuidString)"
        let written = String(decoding: cloud.data(forKey: key)!, as: UTF8.self)
        let planted = Data(written.replacingOccurrences(
            of: "\"parts\":{",
            with: "\"parts\":{\"future\":{\"time\":0,\"value\":9007199254740993},"
        ).utf8)
        #expect(String(decoding: planted, as: UTF8.self).contains("9007199254740993"))
        cloud.plant(planted, forKey: key)
        cloud.forgetWrites()

        _ = sync.exchange(library, now: t(3))

        #expect(cloud.data(forKey: key) == planted)
        #expect(cloud.writes == 0)
    }

    @Test func aRecordWithOtherKeyOrderOrSpacingIsNotRewritten() {
        let sync = device()
        var library = Library()
        let song = library.addSong(name: "Song", settings: settings(100), now: t(1))!
        let list = library.addSetlist(name: "Gig", now: t(1))
        library.add(song.id, toSetlist: list.id, now: t(2))
        library = sync.exchange(library, now: t(3))
        var planted: [String: Data] = [:]
        for key in ["song.\(song.id.uuidString)", "s.\(list.id.uuidString)"] {
            let object = try! JSONSerialization.jsonObject(with: cloud.data(forKey: key)!)
            let data = try! JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted])
            #expect(data != cloud.data(forKey: key))
            cloud.plant(data, forKey: key)
            planted[key] = data
        }
        cloud.forgetWrites()

        let again = sync.exchange(library, now: t(4))

        #expect(again == library)
        for (key, data) in planted {
            #expect(cloud.data(forKey: key) == data)
        }
        #expect(cloud.writes == 0)
    }

    @Test func anItemMissingFromICloudIsPutBack() {
        let sync = deviceWithoutEntry()
        var library = Library()
        library.addSong(name: "Song", settings: settings(100), now: t(1))
        library.addSetlist(name: "Gig", now: t(1))
        library = sync.exchange(library, now: t(2))
        let before = Dictionary(uniqueKeysWithValues: cloud.keys.map { ($0, cloud.data(forKey: $0)) })

        for key in cloud.keys { cloud.remove(key) }
        let again = sync.exchange(library, now: t(2))

        #expect(again == library)
        #expect(Dictionary(uniqueKeysWithValues: cloud.keys.map { ($0, cloud.data(forKey: $0)) }) == before)
        #expect(keys(withPrefix: "song.").count == 1)
    }

    @Test func aMarkerOlderThanAYearIsRemovedFromDeviceAndICloud() {
        let sync = device()
        var library = Library()
        let song = library.addSong(name: "Song", settings: settings(100), now: t(0))!
        library.deleteSong(song.id, now: t(0))
        library = sync.exchange(library, now: t(1))
        #expect(keys(withPrefix: "song.").count == 1)

        library = sync.exchange(library, now: t(0) + 366 * 86_400)
        #expect(keys(withPrefix: "song.").isEmpty)
        #expect(library.itemCount == 0)
    }

    @Test func theOldestMarkersGoFirstWhenTheLibraryDoesNotFit() {
        let sync = device()
        var library = Library()
        var deleted: [UUID] = []
        for index in 0..<1010 {
            let id = library.addSong(name: "P\(index)", settings: settings(100), now: t(0))!.id
            if index < 20 { deleted.append(id) }
        }
        for (index, id) in deleted.enumerated() {
            library.deleteSong(id, now: t(100 + Double(index)))
        }

        library = sync.exchange(library, now: t(5_000))

        #expect(library.itemCount == 998)
        #expect(deleted.prefix(12).allSatisfy { library.songRecords[$0] == nil })
        #expect(deleted.suffix(8).allSatisfy { library.songRecords[$0]?.deleted != nil })
        #expect(keys(withPrefix: "song.").count == 998)
        #expect(sync.status == .upToDate(lastSynced: t(5_000)))
    }

    @Test func aLibraryThatCannotFitIsFullAndKeepsWorking() {
        let sync = device()
        var library = Library()
        for index in 0..<1005 {
            library.addSong(name: "P\(index)", settings: settings(100), now: t(0))
        }

        let result = sync.exchange(library, now: t(1))

        #expect(sync.status == .full)
        #expect(result == library)
        #expect(keys(withPrefix: "song.").isEmpty)
    }

    @Test func aQuotaNoticeSetsFull() {
        let sync = device()
        var library = Library()
        library.addSong(name: "Song", settings: settings(100), now: t(1))
        library = sync.exchange(library, now: t(2))
        #expect(sync.status == .upToDate(lastSynced: t(2)))

        cloud.send(.quotaExceeded)
        #expect(sync.status == .full)

        _ = sync.exchange(library, now: t(3))
        #expect(sync.status == .full)
    }

    @Test func aChangeDoesNotChangeTheStatus() {
        let sync = device()
        cloud.send(.changed)
        #expect(sync.status == .upToDate(lastSynced: nil))
    }

    @Test func anAccountChangeNoticeWithADifferentAccountSwitchesSyncOffWithoutTouchingICloud() {
        let sync = device()
        cloud.plant(Data("2".utf8), forKey: "format")
        let before = snapshot()
        cloud.account = Data([2])

        cloud.send(.accountChanged)

        #expect(!sync.isOn)
        #expect(sync.status == nil)
        #expect(snapshot() == before)
        #expect(cloud.writes == 0)
    }

    @Test func anAccountChangeNoticeWithNoAccountKeepsSyncOnAndWaiting() {
        let sync = device()
        var announced = 0
        sync.onStatusChange = { announced += 1 }
        cloud.account = nil

        cloud.send(.accountChanged)

        #expect(sync.isOn)
        #expect(sync.status == .notSignedIn)
        #expect(announced == 1)
    }

    @Test func anAccountChangeNoticeWithTheSameAccountBackAsksForAnExchange() {
        let sync = device()
        var calls = 0
        sync.onCloudChange = { calls += 1 }

        cloud.send(.accountChanged)

        #expect(sync.isOn)
        #expect(calls == 1)
    }

    @Test func switchingOnSignedOutForgetsAnOldAccount() {
        let defaults = freshDefaults()
        defaults.set(Data([1]), forKey: "metronome.sync.account")
        let sync = makeSync(defaults)
        cloud.account = nil
        sync.turnOn(now: t0)
        cloud.account = Data([2])
        var library = Library()
        library.addSong(name: "Song", settings: settings(100), now: t(1))

        _ = sync.exchange(library, now: t(2))

        #expect(sync.isOn)
        #expect(keys(withPrefix: "song.").count == 1)
    }

    @Test func aFormatThatCannotBeReadCountsAsNewer() {
        let sync = device()
        var library = Library()
        library.addSong(name: "Song", settings: settings(100), now: t(1))
        _ = sync.exchange(library, now: t(2))
        cloud.plant(Data([0xFF, 0xFE]), forKey: "format")
        let before = snapshot()
        let writes = cloud.writes

        let result = sync.exchange(library, now: t(3))
        #expect(sync.status == .needsUpdate)
        #expect(result == library)
        sync.turnOff(now: t(4))
        sync.appOpened(now: t(5))

        #expect(snapshot() == before)
        #expect(cloud.writes == writes)
    }

    @Test func aDeviceThatNeverSawItsAccountDoesNotCleanUpOnIt() {
        let sync = makeSync(freshDefaults())
        cloud.account = nil
        sync.turnOn(now: t0)
        cloud.account = Data([1])
        cloud.plant(Data("2".utf8), forKey: "format")
        cloud.plant(Data("{}".utf8), forKey: "song.\(UUID().uuidString)")
        let before = snapshot()

        sync.turnOff(now: t(1))
        sync.appOpened(now: t(2))

        #expect(snapshot() == before)
        #expect(cloud.writes == 0)
    }

    @Test func aNewerFormatStopsSyncWithoutChangingICloud() {
        let sync = device()
        cloud.plant(Data("3".utf8), forKey: "format")
        cloud.plant(Data("{}".utf8), forKey: "song.\(UUID().uuidString)")
        let before = Dictionary(uniqueKeysWithValues: cloud.keys.map { ($0, cloud.data(forKey: $0)) })
        var library = Library()
        library.addSong(name: "Song", settings: settings(100), now: t(1))

        let result = sync.exchange(library, now: t(2))

        #expect(sync.status == .needsUpdate)
        #expect(result == library)
        #expect(Dictionary(uniqueKeysWithValues: cloud.keys.map { ($0, cloud.data(forKey: $0)) }) == before)
        #expect(cloud.writes == 0)
    }

    @Test func songsUnderFormat1KeysMoveToSongKeysAndTheFormatGoesUp() throws {
        let sync = device()
        let record = SongRecord(id: UUID(), name: "Old", settings: settings(100), created: t(0), now: t(0))
        let data = try JSONEncoder().encode(record)
        cloud.plant(Data("1".utf8), forKey: "format")
        cloud.plant(data, forKey: "p.\(record.id.uuidString)")

        let result = sync.exchange(Library(), now: t(1))

        #expect(result.song(id: record.id)?.name == "Old")
        #expect(keys(withPrefix: "p.").isEmpty)
        let moved = cloud.data(forKey: "song.\(record.id.uuidString)")
        #expect(moved.flatMap { try? JSONDecoder().decode(SongRecord.self, from: $0) } == record)
        #expect(cloud.data(forKey: "format") == Data("2".utf8))
        #expect(sync.status == .upToDate(lastSynced: t(1)))
    }

    @Test func aChangeAnOlderVersionWritesUnderAFormat1KeyIsCombinedIn() throws {
        let sync = device()
        var library = Library()
        let song = library.addSong(name: "Song", settings: settings(100), now: t(1))!
        library = sync.exchange(library, now: t(2))
        var old = try #require(cloud.data(forKey: "song.\(song.id.uuidString)")
            .flatMap { try? JSONDecoder().decode(SongRecord.self, from: $0) })
        old.setName("Renamed", now: t(3))
        cloud.plant(try JSONEncoder().encode(old), forKey: "p.\(song.id.uuidString)")

        library = sync.exchange(library, now: t(4))

        #expect(library.song(id: song.id)?.name == "Renamed")
        #expect(keys(withPrefix: "p.").isEmpty)
        #expect(keys(withPrefix: "song.").count == 1)
    }

    @Test func aFormat1KeyThatCannotBeReadIsLeftAlone() {
        let sync = device()
        let key = "p.\(UUID().uuidString)"
        cloud.plant(Data("garbage".utf8), forKey: key)

        _ = sync.exchange(Library(), now: t(1))

        #expect(cloud.data(forKey: key) == Data("garbage".utf8))
    }

    @Test func notSignedInWaitsWithoutTouchingICloud() {
        let sync = deviceWithoutEntry()
        cloud.account = nil
        var library = Library()
        library.addSong(name: "Song", settings: settings(100), now: t(1))

        let result = sync.exchange(library, now: t(2))

        #expect(sync.status == .notSignedIn)
        #expect(result == library)
        #expect(cloud.writes == 0)
        #expect(cloud.keys.isEmpty)
    }

    @Test func whileOffNothingHappens() {
        let sync = makeSync(freshDefaults())
        var library = Library()
        library.addSong(name: "Song", settings: settings(100), now: t(1))

        #expect(sync.status == nil)
        #expect(sync.exchange(library, now: t(2)) == library)
        #expect(cloud.writes == 0)
    }

    // Review Focus 3
    @Test func unreadableDataIsSkippedKeptOrRepaired() {
        let a = device(), b = device()
        var libraryA = Library()
        let owned = libraryA.addSong(name: "Mine", settings: settings(100), now: t(1))!
        var libraryB = Library()
        libraryB.addSong(name: "Theirs", settings: settings(130), now: t(1))
        _ = b.exchange(libraryB, now: t(2))

        let unknownKey = "song.\(UUID().uuidString)"
        cloud.plant(Data("garbage".utf8), forKey: "song.\(owned.id.uuidString)")
        cloud.plant(Data("garbage".utf8), forKey: unknownKey)
        cloud.plant(Data("anything".utf8), forKey: "x.future")

        libraryA = a.exchange(libraryA, now: t(3))

        #expect(names(libraryA) == ["Mine", "Theirs"])
        let repaired = cloud.data(forKey: "song.\(owned.id.uuidString)")
        #expect(repaired.flatMap { try? JSONDecoder().decode(SongRecord.self, from: $0) }?.id == owned.id)
        #expect(cloud.data(forKey: unknownKey) == Data("garbage".utf8))
        #expect(cloud.data(forKey: "x.future") == Data("anything".utf8))
    }

    // MARK: - The switch, devices and clean-up

    @Test func syncIsOffAtFirstAndTheSwitchIsRemembered() {
        let defaults = freshDefaults()
        let sync = makeSync(defaults)
        #expect(!sync.isOn)
        #expect(sync.status == nil)

        sync.turnOn(now: t0)

        #expect(sync.isOn)
        #expect(makeSync(defaults).isOn)
    }

    @Test func switchingOnShowsSyncingThenUpToDate() {
        let sync = makeSync(freshDefaults())
        sync.turnOn(now: t0)
        #expect(sync.status == .syncing)

        var library = Library()
        library.addSong(name: "Song", settings: settings(100), now: t(1))
        _ = sync.exchange(library, now: t(2))
        #expect(sync.status == .syncing)

        sync.finishSyncing()
        #expect(sync.status == .upToDate(lastSynced: t(2)))
    }

    @Test func syncingShowsAProblemAtOnce() {
        let sync = makeSync(freshDefaults())
        cloud.account = nil
        sync.turnOn(now: t0)
        #expect(sync.status == .syncing)

        _ = sync.exchange(Library(), now: t(1))
        #expect(sync.status == .notSignedIn)
    }

    @Test func switchingOffLeavesTheLibraryAndTheOtherDeviceAlone() {
        let defaultsA = freshDefaults(), defaultsB = freshDefaults()
        let a = device(defaultsA), b = device(defaultsB)
        var libraryA = Library()
        libraryA.addSong(name: "From A", settings: settings(100), now: t(1))
        var libraryB = Library()
        libraryB.addSong(name: "From B", settings: settings(120), now: t(2))
        libraryA = a.exchange(libraryA, now: t(10))
        libraryB = b.exchange(libraryB, now: t(11))
        let songKeys = Set(keys(withPrefix: "song."))
        #expect(songKeys.count == 2)

        b.turnOff(now: t(20))

        #expect(!b.isOn)
        #expect(b.status == nil)
        #expect(b.exchange(libraryB, now: t(21)) == libraryB)
        #expect(Set(keys(withPrefix: "song.")) == songKeys)
        #expect(cloud.data(forKey: "format") != nil)
        #expect(cloud.data(forKey: entryKey(defaultsB)) == nil)
        #expect(cloud.data(forKey: entryKey(defaultsA)) != nil)
        #expect(names(a.exchange(libraryA, now: t(22))) == ["From A", "From B"])
    }

    @Test func changesMadeWhileOffAreCombinedWhenSwitchedOnAgain() {
        let a = device(), b = device()
        var libraryA = Library()
        libraryA.addSong(name: "Early A", settings: settings(100), now: t(1))
        var libraryB = Library()
        libraryB.addSong(name: "Early B", settings: settings(110), now: t(1))
        libraryA = a.exchange(libraryA, now: t(2))
        libraryB = b.exchange(libraryB, now: t(3))

        b.turnOff(now: t(10))
        libraryB.addSong(name: "Late B", settings: settings(120), now: t(11))
        libraryA.addSong(name: "Late A", settings: settings(130), now: t(12))
        libraryA = a.exchange(libraryA, now: t(13))

        b.turnOn(now: t(20))
        libraryB = b.exchange(libraryB, now: t(21))
        libraryA = a.exchange(libraryA, now: t(22))

        let all = ["Early A", "Early B", "Late A", "Late B"]
        #expect(names(libraryB) == all)
        #expect(names(libraryA) == all)
    }

    @Test func theLastDeviceToSwitchOffEmptiesICloud() {
        let a = device(), b = device()
        var library = Library()
        library.addSong(name: "Song", settings: settings(100), now: t(1))
        library = a.exchange(library, now: t(2))
        _ = b.exchange(library, now: t(3))

        a.turnOff(now: t(10))
        #expect(!cloud.keys.isEmpty)

        b.turnOff(now: t(11))
        #expect(cloud.keys.isEmpty)
    }

    @Test func switchingOffRemovesKeysOfKindsTheAppDoesNotKnow() {
        let sync = device()
        cloud.plant(Data("anything".utf8), forKey: "x.future")

        sync.turnOff(now: t(1))

        #expect(cloud.keys.isEmpty)
    }

    @Test func aSyncingDeviceThatFindsICloudEmptiedPutsItsLibraryBack() {
        let a = device()
        var library = Library()
        library.addSong(name: "Song", settings: settings(100), now: t(1))
        let list = library.addSetlist(name: "Gig", now: t(1))
        library = a.exchange(library, now: t(2))
        let before = snapshot()

        for key in cloud.keys { cloud.remove(key) }
        let again = a.exchange(library, now: t(3))

        #expect(again == library)
        #expect(keys(withPrefix: "song.").count == 1)
        #expect(keys(withPrefix: "s.") == ["s.\(list.id.uuidString)"])
        #expect(cloud.data(forKey: "format") != nil)
        #expect(snapshot().filter { $0.key.hasPrefix("song.") || $0.key.hasPrefix("s.") }
            == before.filter { $0.key.hasPrefix("song.") || $0.key.hasPrefix("s.") })
    }

    @Test func aSyncingDevicePutsItsEntryBackWhenICloudWasEmptied() {
        let defaultsA = freshDefaults(), defaultsB = freshDefaults()
        let a = device(defaultsA), b = device(defaultsB)
        var library = Library()
        library.addSong(name: "Song", settings: settings(100), now: t(1))
        library = a.exchange(library, now: t(2))

        b.turnOff(now: t(10))
        for key in cloud.keys { cloud.remove(key) }
        library = a.exchange(library, now: t(11))

        #expect(cloud.data(forKey: entryKey(defaultsA)) != nil)
        #expect(keys(withPrefix: "song.").count == 1)
        let before = snapshot()
        b.appOpened(now: t(12))
        #expect(snapshot() == before)
    }

    @Test func twoDevicesSwitchedOffTogetherAreCleanedUpOnTheNextOpen() {
        let defaultsA = freshDefaults(), defaultsB = freshDefaults()
        let a = device(defaultsA), b = device(defaultsB)
        var library = Library()
        library.addSong(name: "Song", settings: settings(100), now: t(1))
        _ = a.exchange(library, now: t(2))

        b.turnOff(now: t(10))
        #expect(!cloud.keys.isEmpty)

        cloud.remove(entryKey(defaultsA))
        b.appOpened(now: t(11))

        #expect(cloud.keys.isEmpty)
    }

    @Test func aDeviceUnseenForSixMonthsDoesNotBlockTheCleanUp() {
        let b = device()
        var library = Library()
        library.addSong(name: "Song", settings: settings(100), now: t(1))
        _ = b.exchange(library, now: t(2))
        let stale = t0 - 181 * 86_400
        cloud.plant(Data(String(stale.timeIntervalSince1970).utf8), forKey: "d.stale")
        cloud.plant(Data("not a number".utf8), forKey: "d.unreadable")

        b.turnOff(now: t0)

        #expect(cloud.keys.isEmpty)
    }

    @Test func aDeviceBehindOnFormatNeverEmptiesICloud() {
        let sync = device()
        var library = Library()
        library.addSong(name: "Song", settings: settings(100), now: t(1))
        _ = sync.exchange(library, now: t(2))
        cloud.plant(Data("3".utf8), forKey: "format")
        let before = snapshot()
        let writes = cloud.writes

        sync.turnOff(now: t(10))
        sync.appOpened(now: t(11))

        #expect(snapshot() == before)
        #expect(cloud.writes == writes)
    }

    @Test func aDifferentAccountSwitchesSyncOff() {
        let sync = device()
        var library = Library()
        library.addSong(name: "Song", settings: settings(100), now: t(1))
        library = sync.exchange(library, now: t(2))
        cloud.account = Data([2])
        let before = snapshot()
        let writes = cloud.writes
        library.addSong(name: "Newer", settings: settings(120), now: t(3))

        let result = sync.exchange(library, now: t(4))

        #expect(!sync.isOn)
        #expect(sync.status == nil)
        #expect(result == library)
        #expect(snapshot() == before)
        #expect(cloud.writes == writes)
    }

    @Test func aDifferentAccountAtAppOpenSwitchesSyncOff() {
        let sync = device()
        _ = sync.exchange(Library(), now: t(1))
        cloud.account = Data([2])
        let before = snapshot()

        sync.appOpened(now: t(2))

        #expect(!sync.isOn)
        #expect(snapshot() == before)
    }

    @Test func switchingOffInAnotherAccountTouchesNothingInICloud() {
        let sync = device()
        var library = Library()
        library.addSong(name: "Song", settings: settings(100), now: t(1))
        _ = sync.exchange(library, now: t(2))
        cloud.account = Data([2])
        let before = snapshot()
        let writes = cloud.writes

        sync.turnOff(now: t(3))

        #expect(!sync.isOn)
        #expect(snapshot() == before)
        #expect(cloud.writes == writes)
    }

    @Test func openingInAnotherAccountAfterSwitchingOffCleansNothingUp() {
        let defaultsA = freshDefaults()
        _ = device(defaultsA)
        let b = device()
        var library = Library()
        library.addSong(name: "Song", settings: settings(100), now: t(1))
        _ = b.exchange(library, now: t(2))
        b.turnOff(now: t(3))
        #expect(!cloud.keys.isEmpty)

        cloud.account = Data([2])
        cloud.remove(entryKey(defaultsA))
        let before = snapshot()
        let writes = cloud.writes

        b.appOpened(now: t(4))

        #expect(snapshot() == before)
        #expect(cloud.writes == writes)
    }

    @Test func switchingOffWhileNotSignedInTouchesNothingInICloud() {
        let sync = device()
        _ = sync.exchange(Library(), now: t(1))
        let before = snapshot()
        cloud.account = nil

        sync.turnOff(now: t(2))

        #expect(!sync.isOn)
        #expect(snapshot() == before)
    }

    @Test func theDeviceEntryIsRefreshedAtMostOnceADay() {
        let defaults = freshDefaults()
        let sync = device(defaults)
        #expect(cloud.data(forKey: entryKey(defaults)) == Data(String(t0.timeIntervalSince1970).utf8))

        sync.appOpened(now: t0 + 3_600)
        #expect(cloud.writes == 0)

        let due = t0 + LibrarySync.deviceRefresh
        sync.appOpened(now: due)
        #expect(cloud.writes == 1)
        #expect(cloud.data(forKey: entryKey(defaults)) == Data(String(due.timeIntervalSince1970).utf8))

        sync.appOpened(now: due + 60)
        #expect(cloud.writes == 1)
    }

    @Test func aChangeFromICloudEndsSyncingAndIsPassedOn() {
        let sync = makeSync(freshDefaults())
        sync.turnOn(now: t0)
        var calls = 0
        var statusWhenCalled: SyncStatus?
        sync.onCloudChange = {
            calls += 1
            statusWhenCalled = sync.status
        }

        cloud.send(.changed)

        #expect(calls == 1)
        #expect(statusWhenCalled == .upToDate(lastSynced: nil))
    }

    @Test func theOwnerHearsOfEachChangeOfStatusOrSwitchOnce() {
        let sync = makeSync(freshDefaults())
        var calls = 0
        sync.onStatusChange = { calls += 1 }

        sync.turnOn(now: t0)
        #expect(calls == 1)

        _ = sync.exchange(Library(), now: t(1))
        #expect(calls == 1)

        sync.finishSyncing()
        #expect(calls == 2)
        sync.finishSyncing()
        #expect(calls == 2)

        cloud.account = Data([2])
        _ = sync.exchange(Library(), now: t(2))
        #expect(calls == 3)
    }

    // Review Focus 4
    @Test func aChangeThatArrivesAfterSwitchingOffIsIgnored() {
        let sync = device()
        var library = Library()
        library.addSong(name: "Song", settings: settings(100), now: t(1))
        var calls = 0
        sync.onCloudChange = { calls += 1 }

        sync.turnOff(now: t(2))
        cloud.send(.changed)

        #expect(calls == 0)
        #expect(sync.exchange(library, now: t(3)) == library)
    }

    @Test func offAndStraightBackOnKeepsTheLibraryInICloud() {
        let sync = device()
        var library = Library()
        library.addSong(name: "Song", settings: settings(100), now: t(1))
        let list = library.addSetlist(name: "Gig", now: t(1))
        library.add(library.songs[0].id, toSetlist: list.id, now: t(2))
        library = sync.exchange(library, now: t(3))
        let records = snapshot().filter { $0.key.hasPrefix("song.") || $0.key.hasPrefix("s.") }

        sync.turnOff(now: t(10))
        #expect(cloud.keys.isEmpty)

        sync.turnOn(now: t(11))
        let again = sync.exchange(library, now: t(12))

        #expect(again == library)
        #expect(snapshot().filter { $0.key.hasPrefix("song.") || $0.key.hasPrefix("s.") } == records)
    }
}
