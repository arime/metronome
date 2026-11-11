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
        #expect(made.bpm == 250)
        #expect(made.timeSignature == .threeFour)
        #expect(made.accents == [1])
    }

    @Test func presetNamesAreTrimmedLimitedAndNeverEmpty() {
        var library = Library()
        #expect(library.addPreset(name: "   ", settings: settings(100), now: now) == nil)
        let made = library.addPreset(name: "  Slow Burn \n", settings: settings(72), now: now)
        #expect(made?.name == "Slow Burn")
        let long = library.addPreset(name: String(repeating: "a", count: 80), settings: settings(100), now: now)
        #expect(long?.name.count == 60)
        #expect(library.presets.count == 2)
    }

    @Test func presetsSortByNameIgnoringCaseWithTiesInCreationOrder() {
        var library = Library()
        let b = library.addPreset(name: "blue", settings: settings(90), now: now)!
        let a2 = library.addPreset(name: "Alpha", settings: settings(100), now: now)!
        let c = library.addPreset(name: "Cold", settings: settings(110), now: now)!
        let a1 = library.addPreset(name: "alpha", settings: settings(120), now: now)!
        #expect(library.sortedPresets.map(\.id) == [a2.id, a1.id, b.id, c.id])
    }

    @Test func renamingAndUpdatingAPreset() {
        var library = Library()
        let preset = library.addPreset(name: "One", settings: settings(100), now: now)!
        library.renamePreset(preset.id, to: "  Two ", now: now + 1)
        library.renamePreset(preset.id, to: "   ", now: now + 2)
        library.updatePreset(preset.id, settings: settings(140), now: now + 3)
        #expect(library.preset(id: preset.id)?.name == "Two")
        #expect(library.preset(id: preset.id)?.settings.bpm == 140)
    }

    @Test func aPresetIsInASetlistOnlyOnceAndRemovingKeepsIt() {
        var library = Library()
        let preset = library.addPreset(name: "One", settings: settings(100), now: now)!
        let setlist = library.addSetlist(name: "Gig", now: now)
        library.add(preset.id, toSetlist: setlist.id, now: now + 1)
        library.add(preset.id, toSetlist: setlist.id, now: now + 2)
        #expect(library.setlist(id: setlist.id)?.presetIDs == [preset.id])
        library.remove(preset.id, fromSetlist: setlist.id, now: now + 3)
        #expect(library.setlist(id: setlist.id)?.presetIDs.isEmpty == true)
        #expect(library.preset(id: preset.id) != nil)
    }

    @Test func deletingAPresetHidesItFromEverySetlist() {
        var library = Library()
        let one = library.addPreset(name: "One", settings: settings(100), now: now)!
        let two = library.addPreset(name: "Two", settings: settings(110), now: now)!
        let gig = library.addSetlist(name: "Gig", now: now)
        let practice = library.addSetlist(name: "Practice", now: now)
        library.add(one.id, toSetlist: gig.id, now: now + 1)
        library.add(two.id, toSetlist: gig.id, now: now + 2)
        library.add(one.id, toSetlist: practice.id, now: now + 3)
        #expect(library.setlistCount(containing: one.id) == 2)
        library.deletePreset(one.id, now: now + 4)
        #expect(library.presets.map(\.id) == [two.id])
        #expect(library.setlist(id: gig.id)?.presetIDs == [two.id])
        #expect(library.setlist(id: practice.id)?.presetIDs.isEmpty == true)
    }

    @Test func setlistKeepsItsOwnOrderAndCanBeReordered() {
        var library = Library()
        let ids = ["C", "A", "B"].map { library.addPreset(name: $0, settings: settings(100), now: now)!.id }
        let gig = library.addSetlist(name: "Gig", now: now)
        for (index, id) in ids.enumerated() {
            library.add(id, toSetlist: gig.id, now: now + Double(index + 1))
        }
        #expect(library.presets(inSetlist: gig.id).map(\.name) == ["C", "A", "B"])
        library.reorder(setlist: gig.id, to: [ids[2], ids[0], ids[1]], now: now + 10)
        #expect(library.presets(inSetlist: gig.id).map(\.name) == ["B", "C", "A"])
        // Not a rearrangement of the same presets: ignored.
        library.reorder(setlist: gig.id, to: [ids[0]], now: now + 11)
        #expect(library.presets(inSetlist: gig.id).map(\.name) == ["B", "C", "A"])
    }

    @Test func duplicatingASetlistSharesItsPresets() {
        var library = Library()
        let one = library.addPreset(name: "One", settings: settings(100), now: now)!
        let gig = library.addSetlist(name: "Gig", now: now)
        library.add(one.id, toSetlist: gig.id, now: now + 1)
        let copy = library.duplicateSetlist(gig.id, now: now.addingTimeInterval(10))
        #expect(copy?.name == "Gig copy")
        #expect(copy?.presetIDs == [one.id])
        #expect(copy?.id != gig.id)
        #expect(library.presets.count == 1)
        #expect(library.setlists.count == 2)
    }

    @Test func setlistNamesAreNeverEmptyAndDeletingKeepsPresets() {
        var library = Library()
        let one = library.addPreset(name: "One", settings: settings(100), now: now)!
        let gig = library.addSetlist(name: "  ", now: now)
        #expect(gig.name == "New setlist")
        library.renameSetlist(gig.id, to: "Friday gig", now: now + 1)
        library.renameSetlist(gig.id, to: "  ", now: now + 2)
        #expect(library.setlist(id: gig.id)?.name == "Friday gig")
        library.add(one.id, toSetlist: gig.id, now: now + 3)
        library.deleteSetlist(gig.id, now: now + 4)
        #expect(library.setlists.isEmpty)
        #expect(library.presets.count == 1)
    }

    @Test func setlistsListMostRecentlyUsedFirst() {
        var library = Library()
        let a = library.addSetlist(name: "A", now: now)
        let b = library.addSetlist(name: "B", now: now.addingTimeInterval(1))
        #expect(library.setlistsByRecency.map(\.id) == [b.id, a.id])
        library.touchSetlist(a.id, now: now.addingTimeInterval(5))
        #expect(library.setlistsByRecency.map(\.id) == [a.id, b.id])
    }
}
