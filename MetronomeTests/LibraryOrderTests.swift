import Foundation
import Testing
@testable import Metronome

struct LibraryOrderTests {
    private let t0 = Date(timeIntervalSince1970: 2_000_000_000)

    private func t(_ n: Double) -> Date {
        t0 + n
    }

    /// Songs created in the given order, one second apart.
    private func library(songs names: [String]) -> (library: Library, songs: [Song]) {
        var library = Library()
        let songs = names.enumerated().map { index, name in
            library.addSong(name: name, settings: MetronomeSettings(), now: t(Double(index)))!
        }
        return (library, songs)
    }

    @Test func nameOrderIsTheSortedSongs() {
        let (library, _) = library(songs: ["b", "C", "a", "B"])
        #expect(library.songs(orderedBy: .name, lastPlayed: [:]) == library.sortedSongs)
        #expect(library.songs(orderedBy: .name, lastPlayed: [:]).map(\.name) == ["a", "b", "B", "C"])
    }

    @Test func recentlyAddedIsNewestFirst() {
        let (library, _) = library(songs: ["A", "C", "B"])
        #expect(library.songs(orderedBy: .recentlyAdded, lastPlayed: [:]).map(\.name) == ["B", "C", "A"])
    }

    @Test func recentlyPlayedPutsNeverPlayedLastByName() {
        let (library, songs) = library(songs: ["D", "B", "C", "A"])
        let c = songs[2], a = songs[3]
        let order = library.songs(orderedBy: .recentlyPlayed, lastPlayed: [c.id: t(200), a.id: t(100)])
        #expect(order.map(\.name) == ["C", "A", "B", "D"])
    }

    // Review Focus 4
    @Test func equalNamesAndTimesKeepAStableOrder() {
        let (library, songs) = library(songs: ["Same", "Same"])
        let s1 = songs[0].id, s2 = songs[1].id
        #expect(library.songs(orderedBy: .name, lastPlayed: [:]).map(\.id) == [s1, s2])
        let played = [s1: t(100), s2: t(100)]
        #expect(library.songs(orderedBy: .recentlyPlayed, lastPlayed: played).map(\.id) == [s1, s2])
    }

    @Test func setlistsByNameIgnoreCase() {
        var library = Library()
        library.addSetlist(name: "beta", now: t(0))
        library.addSetlist(name: "Alpha", now: t(1))
        #expect(library.setlists(orderedBy: .name).map(\.name) == ["Alpha", "beta"])
    }

    @Test func setlistsWithTheSameNameAreMostRecentFirst() {
        var library = Library()
        let older = library.addSetlist(name: "Gig", now: t(0))
        let newer = library.addSetlist(name: "gig", now: t(1))
        library.addSetlist(name: "Rehearsal", now: t(2))
        #expect(library.setlists(orderedBy: .name).map(\.id).prefix(2) == [newer.id, older.id])
        library.touchSetlist(older.id, now: t(3))
        #expect(library.setlists(orderedBy: .name).map(\.id).prefix(2) == [older.id, newer.id])
    }

    @Test func recentlyUsedIsTheRecencyOrder() {
        var library = Library()
        let first = library.addSetlist(name: "First", now: t(0))
        library.addSetlist(name: "Second", now: t(1))
        library.addSetlist(name: "Third", now: t(2))
        library.touchSetlist(first.id, now: t(3))
        #expect(library.setlists(orderedBy: .recentlyUsed) == library.setlistsByRecency)
        #expect(library.setlists(orderedBy: .recentlyUsed).map(\.name) == ["First", "Third", "Second"])
    }

    @Test func aSetlistMatchesLikeASong() {
        let gig = Setlist(id: UUID(), name: "Friday gig", songIDs: [], lastUsed: t0)
        #expect(gig.matches(search: "fri"))
        #expect(gig.matches(search: " GIG "))
        #expect(gig.matches(search: ""))
        #expect(gig.matches(search: "   "))
        #expect(!gig.matches(search: "sat"))
        let wedding = Setlist(id: UUID(), name: "Häät", songIDs: [], lastUsed: t0)
        #expect(wedding.matches(search: "haat"))
    }

    @Test func theOrdersHaveTheirTitles() {
        #expect(SongOrder.allCases.map(\.title) == ["Name", "Recently added", "Recently played"])
        #expect(SetlistOrder.allCases.map(\.title) == ["Recently used", "Name"])
    }
}
