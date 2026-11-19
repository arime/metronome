import Foundation
import Testing
@testable import Metronome

struct SetlistSearchTests {
    private func songs(_ names: [String]) -> [Song] {
        names.map { Song(id: UUID(), name: $0, settings: MetronomeSettings()) }
    }

    @Test func anEmptySearchNumbersEverySong() {
        let rows = SetlistSearch.rows(songs(["A", "B", "C"]), matching: "")
        #expect(rows.map(\.number) == [1, 2, 3])
        #expect(rows.map(\.song.name) == ["A", "B", "C"])
    }

    @Test func foundRowsKeepTheirPlaceInTheWholeSetlist() {
        let setlist = songs([
            "Harbour Lights", "Copper Sky", "Seven Bridges", "Midnight Ferry", "Waltz for June",
            "Slow Burn", "Northern Line", "Last Orders",
        ])
        let rows = SetlistSearch.rows(setlist, matching: "li")
        #expect(rows.map(\.number) == [1, 7])
        #expect(rows.map(\.song.name) == ["Harbour Lights", "Northern Line"])
    }

    @Test func spacesOnlyFindEverySong() {
        let rows = SetlistSearch.rows(songs(["A", "B", "C"]), matching: "   ")
        #expect(rows.map(\.number) == [1, 2, 3])
        #expect(rows.map(\.song.name) == ["A", "B", "C"])
    }

    @Test func nothingFoundGivesNoRows() {
        #expect(SetlistSearch.rows(songs(["A", "B", "C"]), matching: "zz").isEmpty)
    }

    @Test func matchingIgnoresCaseAndAccents() {
        let rows = SetlistSearch.rows(songs(["Häät", "Polka"]), matching: " HAAT ")
        #expect(rows.map(\.number) == [1])
        #expect(rows.map(\.song.name) == ["Häät"])
    }
}
