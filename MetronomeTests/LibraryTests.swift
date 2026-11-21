import Foundation
import Testing
@testable import Metronome

struct LibraryTests {
    private let now = Date(timeIntervalSince1970: 1_000)

    private func settings(_ bpm: Int) -> MetronomeSettings {
        MetronomeSettings(bpm: bpm, timeSignature: .fourFour, accents: [1])
    }

    @Test func settingsInitialiserSanitizes() {
        let made = MetronomeSettings(bpm: 900, timeSignature: .threeFour, accents: [1, 5])
        #expect(made.bpm == 300)
        #expect(made.timeSignature == .threeFour)
        #expect(made.accents == [1])
    }

    @Test func songNamesAreTrimmedLimitedAndNeverEmpty() {
        var library = Library()
        #expect(library.addSong(name: "   ", settings: settings(100), now: now) == nil)
        let made = library.addSong(name: "  Slow Burn \n", settings: settings(72), now: now)
        #expect(made?.name == "Slow Burn")
        let long = library.addSong(name: String(repeating: "a", count: 80), settings: settings(100), now: now)
        #expect(long?.name.count == 60)
        #expect(library.songs.count == 2)
    }

    @Test func songsSortByNameIgnoringCaseWithTiesInCreationOrder() {
        var library = Library()
        let b = library.addSong(name: "blue", settings: settings(90), now: now)!
        let a2 = library.addSong(name: "Alpha", settings: settings(100), now: now)!
        let c = library.addSong(name: "Cold", settings: settings(110), now: now)!
        let a1 = library.addSong(name: "alpha", settings: settings(120), now: now)!
        #expect(library.sortedSongs.map(\.id) == [a2.id, a1.id, b.id, c.id])
    }

    @Test func searchMatchesPartOfTheNameIgnoringCase() {
        let song = Song(id: UUID(), name: "Harbour Lights", settings: settings(100))
        #expect(song.matches(search: "harbour"))
        #expect(song.matches(search: "LIGHT"))
        #expect(song.matches(search: "our li"))
        #expect(!song.matches(search: "lights out"))
    }

    @Test func searchIgnoresAccents() {
        let song = Song(id: UUID(), name: "Täällä Pohjantähden alla", settings: settings(100))
        #expect(song.matches(search: "taalla"))
        #expect(song.matches(search: "pohjantahden"))
        #expect(song.matches(search: "TÄÄLLÄ"))
        let plain = Song(id: UUID(), name: "Paivan kahtaa", settings: settings(100))
        #expect(plain.matches(search: "päivän"))
    }

    @Test func searchIgnoresSpacesAroundTheQuery() {
        let song = Song(id: UUID(), name: "Slow Burn", settings: settings(72))
        #expect(song.matches(search: "  burn \n"))
        #expect(song.matches(search: " slow burn "))
        #expect(!song.matches(search: "slowburn"))
    }

    @Test func anEmptySearchMatchesEverySong() {
        let song = Song(id: UUID(), name: "Cold", settings: settings(110))
        #expect(song.matches(search: ""))
        #expect(song.matches(search: "   "))
    }

    @Test func searchFiltersInOrderAndCanMatchNothing() {
        var library = Library()
        let b = library.addSong(name: "Blue Hour", settings: settings(90), now: now)!
        _ = library.addSong(name: "Cold", settings: settings(110), now: now)!
        let l = library.addSong(name: "Länsi hour", settings: settings(120), now: now)!
        #expect(library.sortedSongs.filter { $0.matches(search: "HOUR") }.map(\.id) == [b.id, l.id])
        #expect(library.sortedSongs.filter { $0.matches(search: "lansi") }.map(\.id) == [l.id])
        #expect(library.sortedSongs.filter { $0.matches(search: "xyz") }.isEmpty)
    }

    @Test func renamingAndUpdatingASong() {
        var library = Library()
        let song = library.addSong(name: "One", settings: settings(100), now: now)!
        library.renameSong(song.id, to: "  Two ", now: now + 1)
        library.renameSong(song.id, to: "   ", now: now + 2)
        library.updateSong(song.id, settings: settings(140), now: now + 3)
        #expect(library.song(id: song.id)?.name == "Two")
        #expect(library.song(id: song.id)?.settings.bpm == 140)
    }

    @Test func updatingOnlyTheMeterLeavesTheTempoPartsTimeAlone() throws {
        var library = Library()
        let added = library.addSong(name: "One", settings: settings(100), now: now)
        let song = try #require(added)
        let meter = MetronomeSettings(bpm: 100, timeSignature: .threeFour, accents: [1])
        library.updateSong(song.id, settings: meter, now: now + 10)
        let parts = try #require(library.songRecords[song.id]?.parts)
        #expect(try #require(parts[SongRecord.meterKey]?.time) > now)
        #expect(parts[SongRecord.tempoKey]?.time == now)
        #expect(library.song(id: song.id)?.settings.timeSignature == .threeFour)
        #expect(library.song(id: song.id)?.settings.bpm == 100)
    }

    @Test func updatingWithTheSameSettingsStampsNothing() throws {
        var library = Library()
        let added = library.addSong(name: "One", settings: settings(100), now: now)
        let song = try #require(added)
        let before = library
        library.updateSong(song.id, settings: settings(100), now: now + 10)
        #expect(library == before)
    }

    private func trackSong(_ library: inout Library) throws -> Song {
        let track = BackingTrack(fileID: UUID(), fileName: "Song.m4a", offset: 48)
        let added = library.addSong(name: "One", settings: settings(100), track: track, now: now)
        return try #require(added)
    }

    @Test func updatingASongWritesItsTrackSettings() throws {
        var library = Library()
        let song = try trackSong(&library)
        library.updateSong(song.id, settings: song.settings, trackSettings: TrackSettings(offset: 60), now: now + 10)
        #expect(library.song(id: song.id)?.track?.offset == 60)
        let parts = try #require(library.songRecords[song.id]?.parts)
        #expect(try #require(parts[SongRecord.trackKey]?.time) > now)
        #expect(parts[SongRecord.tempoKey]?.time == now)
        #expect(parts[SongRecord.meterKey]?.time == now)
    }

    @Test func updatingASongWithTheSameTrackSettingsStampsNothing() throws {
        var library = Library()
        let song = try trackSong(&library)
        let before = library
        library.updateSong(song.id, settings: song.settings, trackSettings: song.track?.settings, now: now + 10)
        #expect(library == before)
    }

    @Test func updatingASongWithoutATrackIgnoresTrackSettings() throws {
        var library = Library()
        let added = library.addSong(name: "One", settings: settings(100), now: now)
        let song = try #require(added)
        let before = library
        library.updateSong(song.id, settings: song.settings, trackSettings: TrackSettings(offset: 60), now: now + 10)
        #expect(library == before)
        #expect(library.song(id: song.id)?.track == nil)
    }

    @Test func aSongIsInASetlistOnlyOnceAndRemovingKeepsIt() {
        var library = Library()
        let song = library.addSong(name: "One", settings: settings(100), now: now)!
        let setlist = library.addSetlist(name: "Gig", now: now)
        library.add(song.id, toSetlist: setlist.id, now: now + 1)
        library.add(song.id, toSetlist: setlist.id, now: now + 2)
        #expect(library.setlist(id: setlist.id)?.songIDs == [song.id])
        library.remove(song.id, fromSetlist: setlist.id, now: now + 3)
        #expect(library.setlist(id: setlist.id)?.songIDs.isEmpty == true)
        #expect(library.song(id: song.id) != nil)
    }

    @Test func deletingASongHidesItFromEverySetlist() {
        var library = Library()
        let one = library.addSong(name: "One", settings: settings(100), now: now)!
        let two = library.addSong(name: "Two", settings: settings(110), now: now)!
        let gig = library.addSetlist(name: "Gig", now: now)
        let practice = library.addSetlist(name: "Practice", now: now)
        library.add(one.id, toSetlist: gig.id, now: now + 1)
        library.add(two.id, toSetlist: gig.id, now: now + 2)
        library.add(one.id, toSetlist: practice.id, now: now + 3)
        #expect(library.setlistCount(containing: one.id) == 2)
        library.deleteSong(one.id, now: now + 4)
        #expect(library.songs.map(\.id) == [two.id])
        #expect(library.setlist(id: gig.id)?.songIDs == [two.id])
        #expect(library.setlist(id: practice.id)?.songIDs.isEmpty == true)
    }

    @Test func setlistKeepsItsOwnOrderAndCanBeReordered() {
        var library = Library()
        let ids = ["C", "A", "B"].map { library.addSong(name: $0, settings: settings(100), now: now)!.id }
        let gig = library.addSetlist(name: "Gig", now: now)
        for (index, id) in ids.enumerated() {
            library.add(id, toSetlist: gig.id, now: now + Double(index + 1))
        }
        #expect(library.songs(inSetlist: gig.id).map(\.name) == ["C", "A", "B"])
        library.reorder(setlist: gig.id, to: [ids[2], ids[0], ids[1]], now: now + 10)
        #expect(library.songs(inSetlist: gig.id).map(\.name) == ["B", "C", "A"])
        // Not a rearrangement of the same songs: ignored.
        library.reorder(setlist: gig.id, to: [ids[0]], now: now + 11)
        #expect(library.songs(inSetlist: gig.id).map(\.name) == ["B", "C", "A"])
    }

    @Test func duplicatingASetlistSharesItsSongs() {
        var library = Library()
        let one = library.addSong(name: "One", settings: settings(100), now: now)!
        let gig = library.addSetlist(name: "Gig", now: now)
        library.add(one.id, toSetlist: gig.id, now: now + 1)
        let copy = library.duplicateSetlist(gig.id, now: now.addingTimeInterval(10))
        #expect(copy?.name == "Gig copy")
        #expect(copy?.songIDs == [one.id])
        #expect(copy?.id != gig.id)
        #expect(library.songs.count == 1)
        #expect(library.setlists.count == 2)
    }

    @Test func setlistNamesAreNeverEmptyAndDeletingKeepsSongs() {
        var library = Library()
        let one = library.addSong(name: "One", settings: settings(100), now: now)!
        let gig = library.addSetlist(name: "  ", now: now)
        #expect(gig.name == "Untitled")
        library.renameSetlist(gig.id, to: "Friday gig", now: now + 1)
        library.renameSetlist(gig.id, to: "  ", now: now + 2)
        #expect(library.setlist(id: gig.id)?.name == "Friday gig")
        library.add(one.id, toSetlist: gig.id, now: now + 3)
        library.deleteSetlist(gig.id, now: now + 4)
        #expect(library.setlists.isEmpty)
        #expect(library.songs.count == 1)
    }

    @Test func setlistsListMostRecentlyUsedFirst() {
        var library = Library()
        let a = library.addSetlist(name: "A", now: now)
        let b = library.addSetlist(name: "B", now: now.addingTimeInterval(1))
        #expect(library.setlistsByRecency.map(\.id) == [b.id, a.id])
        library.touchSetlist(a.id, now: now.addingTimeInterval(5))
        #expect(library.setlistsByRecency.map(\.id) == [a.id, b.id])
    }

    @Test func theMostRecentSetlistKeepsItsTime() {
        var library = Library()
        library.addSetlist(name: "A", now: now)
        let b = library.addSetlist(name: "B", now: now + 1)
        let before = library
        library.touchSetlist(b.id, now: now + 2)
        #expect(library == before)
    }

    @Test func anOlderSetlistGetsTheNewTime() {
        var library = Library()
        let a = library.addSetlist(name: "A", now: now)
        library.addSetlist(name: "B", now: now + 1)
        library.touchSetlist(a.id, now: now + 2)
        #expect(library.setlist(id: a.id)?.lastUsed == now + 2)
        #expect(library.setlistsByRecency.first?.id == a.id)
    }

    @Test func aTieStillSetsTheTime() {
        var library = Library()
        let a = library.addSetlist(name: "A", now: now)
        let b = library.addSetlist(name: "B", now: now)
        library.touchSetlist(a.id, now: now + 1)
        #expect(library.setlist(id: a.id)?.lastUsed == now + 1)
        #expect(library.setlistsByRecency.map(\.id) == [a.id, b.id])
    }

    @Test func theOnlySetlistKeepsItsTime() {
        var library = Library()
        let a = library.addSetlist(name: "A", now: now)
        let before = library
        library.touchSetlist(a.id, now: now + 1)
        #expect(library == before)
    }

    @Test func aDeletedSetlistDoesNotCount() {
        var library = Library()
        let a = library.addSetlist(name: "A", now: now + 1)
        let b = library.addSetlist(name: "B", now: now + 2)
        library.deleteSetlist(b.id, now: now + 3)
        let before = library
        library.touchSetlist(a.id, now: now + 4)
        #expect(library == before)
    }
}
