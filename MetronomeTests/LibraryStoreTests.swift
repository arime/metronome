import Foundation
import Testing
@testable import Metronome

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
        let song = state.library.addSong(
            name: "One", settings: MetronomeSettings(bpm: 90, timeSignature: .sixEight, accents: [1, 4]),
            now: Date(timeIntervalSince1970: 40)
        )!
        let gig = state.library.addSetlist(name: "Gig", now: Date(timeIntervalSince1970: 50))
        state.library.add(song.id, toSetlist: gig.id, now: Date(timeIntervalSince1970: 60))
        state.loadedSongID = song.id
        state.loadedFromSetlistID = gig.id
        state.selectedSetlistID = gig.id
        store.save(state)
        #expect(store.load() == state)
    }

    @Test func danglingReferencesAreDroppedOnLoad() {
        var state = LibraryState()
        let song = state.library.addSong(
            name: "One", settings: MetronomeSettings(), now: Date(timeIntervalSince1970: 40)
        )!
        let gig = state.library.addSetlist(name: "Gig", now: Date(timeIntervalSince1970: 50))
        state.loadedSongID = song.id
        // Loaded from a setlist that does not contain the song.
        state.loadedFromSetlistID = gig.id
        state.selectedSetlistID = UUID()
        store.save(state)
        let loaded = store.load()
        #expect(loaded.loadedSongID == song.id)
        #expect(loaded.loadedFromSetlistID == nil)
        #expect(loaded.selectedSetlistID == nil)
    }

    private let t0 = Date(timeIntervalSince1970: 2_000_000_000)

    private func t(_ n: Double) -> Date {
        t0 + n
    }

    private var signatureJSON: String {
        String(decoding: try! JSONEncoder().encode(TimeSignature.fourFour), as: UTF8.self)
    }

    @Test func anOldLibraryIsConvertedInFull() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let p = UUID(); let s = UUID()
        let old = """
        {"library":{"presets":[{"id":"\(p)","name":"Song","settings":{"bpm":96,"timeSignature":\(signatureJSON),"accents":[1]}}],
        "setlists":[{"id":"\(s)","name":"Gig","presetIDs":["\(p)"],"lastUsed":0}]},
        "loadedPresetID":"\(p)","loadedFromSetlistID":"\(s)","selectedSetlistID":"\(s)"}
        """
        defaults.set(Data(old.utf8), forKey: "metronome.library.v1")
        let state = LibraryStore(defaults: defaults).load()
        #expect(state.library.song(id: p)?.settings.bpm == 96)
        #expect(state.library.setlist(id: s)?.songIDs == [p])
        #expect(state.loadedSongID == p)
        #expect(state.loadedFromSetlistID == s)
        #expect(state.selectedSetlistID == s)
        #expect(state.library.songRecords[p]?.parts[SongRecord.tempoKey]?.time == SyncClock.legacy)
    }

    // Review Focus 2
    @Test func anEditOnThePhoneThatUpdatedFirstSurvivesTheOtherPhonesOldCopy() {
        let old = [Song(id: UUID(), name: "Song", settings: MetronomeSettings(bpm: 100, timeSignature: .fourFour, accents: [1]))]
        var first = Library(legacySongs: old, legacySetlists: [])
        first.updateSong(old[0].id, settings: MetronomeSettings(bpm: 150, timeSignature: .fourFour, accents: [1]), now: t(100))
        var deleted = Library(legacySongs: old, legacySetlists: [])
        deleted.deleteSong(old[0].id, now: t(100))
        let late = Library(legacySongs: old, legacySetlists: [])
        first.merge(songs: Array(late.songRecords.values), setlists: [])
        deleted.merge(songs: Array(late.songRecords.values), setlists: [])
        #expect(first.song(id: old[0].id)?.settings.bpm == 150)
        #expect(deleted.songs.isEmpty)
    }

    @Test func theNewFormatRoundTripsAndWinsOverTheOldKey() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set(Data("not json".utf8), forKey: "metronome.library.v1")
        var library = Library()
        let song = library.addSong(name: "New", settings: MetronomeSettings(), now: t(0))!
        let state = LibraryState(library: library, loadedSongID: song.id)
        LibraryStore(defaults: defaults).save(state)
        #expect(LibraryStore(defaults: defaults).load() == state)
    }
}
