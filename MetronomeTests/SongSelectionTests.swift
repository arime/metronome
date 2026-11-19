import Foundation
import Testing
@testable import Metronome

struct SongSelectionTests {
    private func song(_ name: String) -> Song {
        Song(id: UUID(), name: name, settings: MetronomeSettings())
    }

    @Test func theTitleCountsTheTicks() {
        let ids = (0..<3).map { _ in UUID() }
        var selection = SongSelection()
        #expect(selection.title == "Select songs")
        selection.toggle(ids[0])
        #expect(selection.title == "1 selected")
        selection.toggle(ids[1])
        selection.toggle(ids[2])
        #expect(selection.title == "3 selected")
        #expect(selection.count == 3)
    }

    @Test func togglingTwiceUnticks() {
        let id = UUID()
        var selection = SongSelection()
        selection.toggle(id)
        #expect(selection.contains(id))
        selection.toggle(id)
        #expect(!selection.contains(id))
        #expect(selection == SongSelection())
    }

    @Test func aSongThatIsGoneLeavesTheSelection() {
        let ids = (0..<3).map { _ in UUID() }
        var selection = SongSelection()
        ids.forEach { selection.toggle($0) }
        selection.keep(only: [ids[0], ids[2], UUID()])
        #expect(selection.ids == [ids[0], ids[2]])
        #expect(selection.count == 2)
        #expect(selection.title == "2 selected")
    }

    @Test func orderedFollowsTheGivenSongs() {
        let songs = ["A", "B", "C", "D"].map(song)
        var selection = SongSelection()
        selection.toggle(songs[3].id)
        selection.toggle(songs[0].id)
        selection.toggle(songs[2].id)
        #expect(selection.ordered(in: songs) == [songs[0].id, songs[2].id, songs[3].id])
        #expect(selection.ordered(in: Array(songs.reversed())) == [songs[3].id, songs[2].id, songs[0].id])
    }

    @Test func theDeletionTextNamesTheCounts() {
        #expect(SongsDeletion.title(count: 3) == "Delete 3 songs?")
        #expect(SongsDeletion.message(setlistCount: 0) == nil)
        #expect(SongsDeletion.message(setlistCount: 1) == "They will also be removed from 1 setlist.")
        #expect(SongsDeletion.message(setlistCount: 2) == "They will also be removed from 2 setlists.")
    }
}
