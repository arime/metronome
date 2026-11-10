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
        #expect(library.addPreset(name: "   ", settings: settings(100)) == nil)
        let made = library.addPreset(name: "  Slow Burn \n", settings: settings(72))
        #expect(made?.name == "Slow Burn")
        let long = library.addPreset(name: String(repeating: "a", count: 80), settings: settings(100))
        #expect(long?.name.count == 60)
        #expect(library.presets.count == 2)
    }

    @Test func presetsSortByNameIgnoringCaseWithTiesInCreationOrder() {
        var library = Library()
        let b = library.addPreset(name: "blue", settings: settings(90))!
        let a2 = library.addPreset(name: "Alpha", settings: settings(100))!
        let c = library.addPreset(name: "Cold", settings: settings(110))!
        let a1 = library.addPreset(name: "alpha", settings: settings(120))!
        #expect(library.sortedPresets.map(\.id) == [a2.id, a1.id, b.id, c.id])
    }

    @Test func renamingAndUpdatingAPreset() {
        var library = Library()
        let preset = library.addPreset(name: "One", settings: settings(100))!
        library.renamePreset(preset.id, to: "  Two ")
        library.renamePreset(preset.id, to: "   ")
        library.updatePreset(preset.id, settings: settings(140))
        #expect(library.preset(id: preset.id)?.name == "Two")
        #expect(library.preset(id: preset.id)?.settings.bpm == 140)
    }

    @Test func aPresetIsInASetlistOnlyOnceAndRemovingKeepsIt() {
        var library = Library()
        let preset = library.addPreset(name: "One", settings: settings(100))!
        let setlist = library.addSetlist(name: "Gig", now: now)
        library.add(preset.id, toSetlist: setlist.id)
        library.add(preset.id, toSetlist: setlist.id)
        #expect(library.setlist(id: setlist.id)?.presetIDs == [preset.id])
        library.remove(preset.id, fromSetlist: setlist.id)
        #expect(library.setlist(id: setlist.id)?.presetIDs.isEmpty == true)
        #expect(library.preset(id: preset.id) != nil)
    }

    @Test func deletingAPresetRemovesItFromEverySetlist() {
        var library = Library()
        let one = library.addPreset(name: "One", settings: settings(100))!
        let two = library.addPreset(name: "Two", settings: settings(110))!
        let gig = library.addSetlist(name: "Gig", now: now)
        let practice = library.addSetlist(name: "Practice", now: now)
        library.add(one.id, toSetlist: gig.id)
        library.add(two.id, toSetlist: gig.id)
        library.add(one.id, toSetlist: practice.id)
        #expect(library.setlistCount(containing: one.id) == 2)
        library.deletePreset(one.id)
        #expect(library.presets.map(\.id) == [two.id])
        #expect(library.setlist(id: gig.id)?.presetIDs == [two.id])
        #expect(library.setlist(id: practice.id)?.presetIDs.isEmpty == true)
    }

    @Test func setlistKeepsItsOwnOrderAndCanBeReordered() {
        var library = Library()
        let ids = ["C", "A", "B"].map { library.addPreset(name: $0, settings: settings(100))!.id }
        let gig = library.addSetlist(name: "Gig", now: now)
        ids.forEach { library.add($0, toSetlist: gig.id) }
        #expect(library.presets(inSetlist: gig.id).map(\.name) == ["C", "A", "B"])
        library.reorder(setlist: gig.id, to: [ids[2], ids[0], ids[1]])
        #expect(library.presets(inSetlist: gig.id).map(\.name) == ["B", "C", "A"])
        // Not a rearrangement of the same presets: ignored.
        library.reorder(setlist: gig.id, to: [ids[0]])
        #expect(library.presets(inSetlist: gig.id).map(\.name) == ["B", "C", "A"])
    }

    @Test func duplicatingASetlistSharesItsPresets() {
        var library = Library()
        let one = library.addPreset(name: "One", settings: settings(100))!
        let gig = library.addSetlist(name: "Gig", now: now)
        library.add(one.id, toSetlist: gig.id)
        let copy = library.duplicateSetlist(gig.id, now: now.addingTimeInterval(10))
        #expect(copy?.name == "Gig copy")
        #expect(copy?.presetIDs == [one.id])
        #expect(copy?.id != gig.id)
        #expect(library.presets.count == 1)
        #expect(library.setlists.count == 2)
    }

    @Test func setlistNamesAreNeverEmptyAndDeletingKeepsPresets() {
        var library = Library()
        let one = library.addPreset(name: "One", settings: settings(100))!
        let gig = library.addSetlist(name: "  ", now: now)
        #expect(gig.name == "New setlist")
        library.renameSetlist(gig.id, to: "Friday gig")
        library.renameSetlist(gig.id, to: "  ")
        #expect(library.setlist(id: gig.id)?.name == "Friday gig")
        library.add(one.id, toSetlist: gig.id)
        library.deleteSetlist(gig.id)
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

struct LibraryStoreTests {
    private let defaults = UserDefaults(suiteName: UUID().uuidString)!
    private var store: LibraryStore { LibraryStore(defaults: defaults) }

    @Test func loadsAnEmptyLibraryWhenNothingIsStored() {
        #expect(store.load() == LibraryState())
    }

    @Test func unreadableDataLoadsAnEmptyLibrary() {
        defaults.set(Data("nope".utf8), forKey: "metronome.library.v1")
        #expect(store.load() == LibraryState())
    }

    @Test func savedStateComesBack() {
        var state = LibraryState()
        let preset = state.library.addPreset(
            name: "One", settings: MetronomeSettings(bpm: 90, timeSignature: .sixEight, accents: [1, 4])
        )!
        let gig = state.library.addSetlist(name: "Gig", now: Date(timeIntervalSince1970: 50))
        state.library.add(preset.id, toSetlist: gig.id)
        state.loadedPresetID = preset.id
        state.loadedFromSetlistID = gig.id
        state.selectedSetlistID = gig.id
        store.save(state)
        #expect(store.load() == state)
    }

    @Test func danglingReferencesAreDroppedOnLoad() {
        var state = LibraryState()
        let preset = state.library.addPreset(name: "One", settings: MetronomeSettings())!
        let gig = state.library.addSetlist(name: "Gig", now: Date(timeIntervalSince1970: 50))
        state.loadedPresetID = preset.id
        // Loaded from a setlist that does not contain the preset.
        state.loadedFromSetlistID = gig.id
        state.selectedSetlistID = UUID()
        store.save(state)
        let loaded = store.load()
        #expect(loaded.loadedPresetID == preset.id)
        #expect(loaded.loadedFromSetlistID == nil)
        #expect(loaded.selectedSetlistID == nil)
    }
}
