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

    @Test func aDeletedPresetLeavesAMarkerAndComesBackIntoItsSetlist() {
        var a = Library()
        let preset = a.addPreset(name: "Song", settings: settings(100), now: t(0))!
        let setlist = a.addSetlist(name: "Gig", now: t(0))
        a.add(preset.id, toSetlist: setlist.id, now: t(1))
        var b = a
        a.deletePreset(preset.id, now: t(10))
        #expect(a.presets.isEmpty)
        #expect(a.setlist(id: setlist.id)?.presetIDs.isEmpty == true)
        #expect(a.itemCount == 2)
        b.updatePreset(preset.id, settings: settings(160), now: t(20))
        a.merge(presets: Array(b.presetRecords.values), setlists: Array(b.setlistRecords.values))
        #expect(a.preset(id: preset.id)?.settings.bpm == 160)
        #expect(a.setlist(id: setlist.id)?.presetIDs == [preset.id])
    }

    @Test func twoLibrariesAreCombinedNotReplaced() {
        var a = Library()
        var b = Library()
        let one = a.addPreset(name: "One", settings: settings(90), now: t(0))!
        let two = b.addPreset(name: "Two", settings: settings(110), now: t(0))!
        a.merge(presets: Array(b.presetRecords.values), setlists: [])
        #expect(Set(a.presets.map(\.id)) == [one.id, two.id])
    }

    @Test func aLocalEditWinsOverAnArrivedChangeFromAClockFarAhead() {
        var a = Library()
        let preset = a.addPreset(name: "Song", settings: settings(100), now: t(0))!
        var b = a
        b.updatePreset(preset.id, settings: settings(200), now: t(86_400))
        a.merge(presets: Array(b.presetRecords.values), setlists: [])
        a.updatePreset(preset.id, settings: settings(130), now: t(60))
        b.merge(presets: Array(a.presetRecords.values), setlists: [])
        #expect(a.preset(id: preset.id)?.settings.bpm == 130)
        #expect(b.preset(id: preset.id)?.settings.bpm == 130)
    }

    @Test func presetsCreatedAtTheSameInstantKeepTheirOrder() {
        var library = Library()
        let ids = (0..<5).map { _ in library.addPreset(name: "Same", settings: settings(100), now: t(0))!.id }
        #expect(library.presets.map(\.id) == ids)
    }

    @Test func markersCanBePurgedByAgeAndOldestFirst() {
        var library = Library()
        let ids = (0..<3).map { library.addPreset(name: "P\($0)", settings: settings(100), now: t(0))!.id }
        library.deletePreset(ids[0], now: t(10))
        library.deletePreset(ids[1], now: t(20))
        library.deletePreset(ids[2], now: t(30))
        #expect(library.dropOldestMarkers(1) == [ids[0]])
        #expect(library.purgeMarkers(before: t(25)) == [ids[1]])
        #expect(library.itemCount == 1)
    }

    @Test func aLibraryMadeBeforeSyncKeepsItsOrderAndLosesToAnyRealChange() {
        let old = [
            Preset(id: UUID(), name: "b", settings: settings(90)),
            Preset(id: UUID(), name: "a", settings: settings(80)),
        ]
        let gig = Setlist(id: UUID(), name: "Gig", presetIDs: [old[1].id, old[0].id], lastUsed: t(0))
        let first = Library(legacyPresets: old, legacySetlists: [gig])
        #expect(first.presets.map(\.id) == old.map(\.id))
        #expect(first.setlist(id: gig.id)?.presetIDs == [old[1].id, old[0].id])
        #expect(first == Library(legacyPresets: old, legacySetlists: [gig]))
    }

    @Test func aMergedInMarkerIsRememberedEvenForAPresetTheLibraryNeverHad() {
        var a = Library()
        let preset = a.addPreset(name: "Song", settings: settings(100), now: t(0))!
        var b = a
        b.deletePreset(preset.id, now: t(10))
        var c = Library()
        c.merge(presets: Array(b.presetRecords.values), setlists: [])
        #expect(c.presets.isEmpty)
        #expect(c.itemCount == 1)
        #expect(c.presetRecords[preset.id]?.deleted != nil)
    }

    @Test func aLibraryEncodesAsSortedRecordListsAndComesBack() throws {
        var library = Library()
        let preset = library.addPreset(name: "Song", settings: settings(100), now: t(0))!
        let gig = library.addSetlist(name: "Gig", now: t(0))
        library.add(preset.id, toSetlist: gig.id, now: t(1))
        let data = try JSONEncoder().encode(library)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["presets", "setlists"])
        #expect(try JSONDecoder().decode(Library.self, from: data) == library)
    }

    @Test func aPresetRemovedAndAddedAgainIsLastInItsSetlist() {
        var library = Library()
        let ids = (0..<3).map { library.addPreset(name: "P\($0)", settings: settings(100), now: t(0))!.id }
        let gig = library.addSetlist(name: "Gig", now: t(0))
        for (index, id) in ids.enumerated() {
            library.add(id, toSetlist: gig.id, now: t(Double(index + 1)))
        }
        library.reorder(setlist: gig.id, to: ids, now: t(5))
        library.remove(ids[1], fromSetlist: gig.id, now: t(10))
        library.add(ids[1], toSetlist: gig.id, now: t(20))
        #expect(library.setlist(id: gig.id)?.presetIDs == [ids[0], ids[2], ids[1]])
    }

    @Test func aSetlistOnlyAcceptsARearrangementOfItsVisiblePresets() {
        var library = Library()
        let ids = (0..<3).map { library.addPreset(name: "P\($0)", settings: settings(100), now: t(0))!.id }
        let gig = library.addSetlist(name: "Gig", now: t(0))
        for (index, id) in ids.enumerated() {
            library.add(id, toSetlist: gig.id, now: t(Double(index + 1)))
        }
        library.deletePreset(ids[1], now: t(10))
        library.reorder(setlist: gig.id, to: [ids[2], ids[0]], now: t(11))
        #expect(library.setlist(id: gig.id)?.presetIDs == [ids[2], ids[0]])
        library.reorder(setlist: gig.id, to: ids, now: t(12))
        #expect(library.setlist(id: gig.id)?.presetIDs == [ids[2], ids[0]])
    }
}
