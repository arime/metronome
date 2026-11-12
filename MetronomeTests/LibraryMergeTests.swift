import Foundation
import Testing
@testable import Metronome

struct LibraryMergeTests {
    private let t0 = Date(timeIntervalSince1970: 2_000_000_000)

    private func t(_ n: Double) -> Date {
        t0 + n
    }

    private func settings(_ bpm: Int) -> MetronomeSettings {
        MetronomeSettings(bpm: bpm, timeSignature: .fourFour, accents: [1])
    }

    @Test func aDeletedSongLeavesAMarkerAndComesBackIntoItsSetlist() {
        var a = Library()
        let song = a.addSong(name: "Song", settings: settings(100), now: t(0))!
        let setlist = a.addSetlist(name: "Gig", now: t(0))
        a.add(song.id, toSetlist: setlist.id, now: t(1))
        var b = a
        a.deleteSong(song.id, now: t(10))
        #expect(a.songs.isEmpty)
        #expect(a.setlist(id: setlist.id)?.songIDs.isEmpty == true)
        #expect(a.itemCount == 2)
        b.updateSong(song.id, settings: settings(160), now: t(20))
        a.merge(songs: Array(b.songRecords.values), setlists: Array(b.setlistRecords.values))
        #expect(a.song(id: song.id)?.settings.bpm == 160)
        #expect(a.setlist(id: setlist.id)?.songIDs == [song.id])
    }

    @Test func twoLibrariesAreCombinedNotReplaced() {
        var a = Library()
        var b = Library()
        let one = a.addSong(name: "One", settings: settings(90), now: t(0))!
        let two = b.addSong(name: "Two", settings: settings(110), now: t(0))!
        a.merge(songs: Array(b.songRecords.values), setlists: [])
        #expect(Set(a.songs.map(\.id)) == [one.id, two.id])
    }

    @Test func aLocalEditWinsOverAnArrivedChangeFromAClockFarAhead() {
        var a = Library()
        let song = a.addSong(name: "Song", settings: settings(100), now: t(0))!
        var b = a
        b.updateSong(song.id, settings: settings(200), now: t(86_400))
        a.merge(songs: Array(b.songRecords.values), setlists: [])
        a.updateSong(song.id, settings: settings(130), now: t(60))
        b.merge(songs: Array(a.songRecords.values), setlists: [])
        #expect(a.song(id: song.id)?.settings.bpm == 130)
        #expect(b.song(id: song.id)?.settings.bpm == 130)
    }

    @Test func songsCreatedAtTheSameInstantKeepTheirOrder() {
        var library = Library()
        let ids = (0..<5).map { _ in library.addSong(name: "Same", settings: settings(100), now: t(0))!.id }
        #expect(library.songs.map(\.id) == ids)
    }

    @Test func markersCanBePurgedByAgeAndOldestFirst() {
        var library = Library()
        let ids = (0..<3).map { library.addSong(name: "P\($0)", settings: settings(100), now: t(0))!.id }
        library.deleteSong(ids[0], now: t(10))
        library.deleteSong(ids[1], now: t(20))
        library.deleteSong(ids[2], now: t(30))
        #expect(library.dropOldestMarkers(1) == [ids[0]])
        #expect(library.purgeMarkers(before: t(25)) == [ids[1]])
        #expect(library.itemCount == 1)
    }

    @Test func aLibraryMadeBeforeSyncKeepsItsOrderAndLosesToAnyRealChange() {
        let old = [
            Song(id: UUID(), name: "b", settings: settings(90)),
            Song(id: UUID(), name: "a", settings: settings(80)),
        ]
        let gig = Setlist(id: UUID(), name: "Gig", songIDs: [old[1].id, old[0].id], lastUsed: t(0))
        let first = Library(legacySongs: old, legacySetlists: [gig])
        #expect(first.songs.map(\.id) == old.map(\.id))
        #expect(first.setlist(id: gig.id)?.songIDs == [old[1].id, old[0].id])
        #expect(first == Library(legacySongs: old, legacySetlists: [gig]))
    }

    @Test func aMergedInMarkerIsRememberedEvenForASongTheLibraryNeverHad() {
        var a = Library()
        let song = a.addSong(name: "Song", settings: settings(100), now: t(0))!
        var b = a
        b.deleteSong(song.id, now: t(10))
        var c = Library()
        c.merge(songs: Array(b.songRecords.values), setlists: [])
        #expect(c.songs.isEmpty)
        #expect(c.itemCount == 1)
        #expect(c.songRecords[song.id]?.deleted != nil)
    }

    @Test func aLibraryEncodesAsSortedRecordListsAndComesBack() throws {
        var library = Library()
        let song = library.addSong(name: "Song", settings: settings(100), now: t(0))!
        let gig = library.addSetlist(name: "Gig", now: t(0))
        library.add(song.id, toSetlist: gig.id, now: t(1))
        let data = try JSONEncoder().encode(library)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["songs", "setlists"])
        #expect(try JSONDecoder().decode(Library.self, from: data) == library)
    }

    @Test func aSongRemovedAndAddedAgainIsLastInItsSetlist() {
        var library = Library()
        let ids = (0..<3).map { library.addSong(name: "P\($0)", settings: settings(100), now: t(0))!.id }
        let gig = library.addSetlist(name: "Gig", now: t(0))
        for (index, id) in ids.enumerated() {
            library.add(id, toSetlist: gig.id, now: t(Double(index + 1)))
        }
        library.reorder(setlist: gig.id, to: ids, now: t(5))
        library.remove(ids[1], fromSetlist: gig.id, now: t(10))
        library.add(ids[1], toSetlist: gig.id, now: t(20))
        #expect(library.setlist(id: gig.id)?.songIDs == [ids[0], ids[2], ids[1]])
    }

    @Test func aSetlistOnlyAcceptsARearrangementOfItsVisibleSongs() {
        var library = Library()
        let ids = (0..<3).map { library.addSong(name: "P\($0)", settings: settings(100), now: t(0))!.id }
        let gig = library.addSetlist(name: "Gig", now: t(0))
        for (index, id) in ids.enumerated() {
            library.add(id, toSetlist: gig.id, now: t(Double(index + 1)))
        }
        library.deleteSong(ids[1], now: t(10))
        library.reorder(setlist: gig.id, to: [ids[2], ids[0]], now: t(11))
        #expect(library.setlist(id: gig.id)?.songIDs == [ids[2], ids[0]])
        library.reorder(setlist: gig.id, to: ids, now: t(12))
        #expect(library.setlist(id: gig.id)?.songIDs == [ids[2], ids[0]])
    }
}
