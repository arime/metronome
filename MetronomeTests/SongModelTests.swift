import Foundation
import Testing
@testable import Metronome

/// A clock the tests move by hand, so that a later load really is later.
@MainActor
private final class Clock {
    private var current = Date(timeIntervalSince1970: 2_000_000_000)

    func now() -> Date {
        current
    }

    func advance() {
        current += 10
    }
}

@MainActor
struct SongModelTests {
    private let engine = FakeClickEngine()
    private let haptics = FakeHaptics()
    private let store = SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    private let libraryStore = LibraryStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    private let clock = Clock()

    private func makeModel() -> MetronomeModel {
        let clock = clock
        return MetronomeModel(
            engine: engine, store: store, haptics: haptics, libraryStore: libraryStore,
            now: { clock.now() }, trackFiles: .temporary()
        )
    }

    private func settings(_ bpm: Int, _ signature: TimeSignature = .fourFour) -> MetronomeSettings {
        MetronomeSettings(bpm: bpm, timeSignature: signature, accents: [1])
    }

    /// A model with three songs in a setlist, in the order slow, mid, fast.
    private func modelWithSetlist() -> (model: MetronomeModel, songs: [Song], setlist: UUID) {
        let model = makeModel()
        let songs = [("Slow", 60), ("Mid", 100), ("Fast", 180)].map {
            model.createSong(name: $0.0, settings: settings($0.1), addingTo: nil)!
        }
        let setlist = model.createSetlist()
        songs.forEach { model.setSong($0.id, inSetlist: setlist, included: true) }
        return (model, songs, setlist)
    }

    @Test func nothingIsLoadedAtFirst() {
        let model = makeModel()
        #expect(model.loadedSong == nil)
        #expect(model.isEdited == false)
        #expect(model.headerTitle == "Library")
        #expect(model.headerSubtitle == "No song loaded")
        #expect(model.position == nil)
    }

    @Test func creatingASongFromTheLibraryDoesNotLoadIt() {
        let model = makeModel()
        let song = model.createSong(name: "Song", settings: settings(90), addingTo: nil)
        #expect(song != nil)
        #expect(model.loadedSong == nil)
        #expect(model.settings.bpm == 120)
    }

    @Test func namingTheCurrentSettingsLoadsTheNewSong() {
        let model = makeModel()
        model.setBPM(132)
        engine.lastUpdate = nil
        let song = model.createSong(name: "Song", settings: model.settings, addingTo: nil)
        #expect(model.loadedSong == song)
        #expect(model.loadedFromSetlistID == nil)
        #expect(model.headerTitle == "Song")
        #expect(model.isEdited == false)
        #expect(engine.lastUpdate == nil)
    }

    @Test func namingTheCurrentSettingsInASetlistLoadsItFromThatSetlist() {
        let (model, _, setlist) = modelWithSetlist()
        let song = model.createSong(name: "Song", settings: model.settings, addingTo: setlist)!
        #expect(model.loadedSong == song)
        #expect(model.loadedFromSetlistID == setlist)
        #expect(model.position?.index == 3)
        #expect(model.position?.count == 4)
    }

    @Test func aNewSongIsNotLoadedWhileAnotherIsLoaded() {
        let (model, songs, setlist) = modelWithSetlist()
        model.loadSong(songs[0].id, from: setlist)
        model.createSong(name: "Song", settings: model.settings, addingTo: nil)
        #expect(model.loadedSong?.id == songs[0].id)
    }

    @Test func aSongTappedOnTheSongsTabIsLoadedOnItsOwn() {
        let (model, songs, setlist) = modelWithSetlist()
        model.loadSong(songs[0].id, from: setlist)
        model.loadSong(songs[1].id, from: nil)
        #expect(model.loadedSong?.id == songs[1].id)
        #expect(model.loadedFromSetlistID == nil)
        #expect(model.position == nil)
        #expect(model.canGoNext == false)
        #expect(model.canGoPrevious == false)
        #expect(model.headerSubtitle == nil)
    }

    @Test func nothingIsMarkedWhileNoSongIsLoaded() {
        let (model, songs, setlist) = modelWithSetlist()
        #expect(!model.marksLoaded(songs[0].id, inSetlist: nil))
        #expect(!model.marksLoaded(songs[0].id, inSetlist: setlist))
    }

    @Test func theSongsTabMarksTheSongOnlyWhenLoadedOnItsOwn() {
        let (model, songs, setlist) = modelWithSetlist()
        model.loadSong(songs[1].id, from: setlist)
        #expect(!model.marksLoaded(songs[1].id, inSetlist: nil))
        #expect(model.marksLoaded(songs[1].id, inSetlist: setlist))
        #expect(!model.marksLoaded(songs[0].id, inSetlist: nil))
        #expect(!model.marksLoaded(songs[0].id, inSetlist: setlist))
        model.loadSong(songs[1].id, from: nil)
        #expect(model.marksLoaded(songs[1].id, inSetlist: nil))
        #expect(!model.marksLoaded(songs[1].id, inSetlist: setlist))
        #expect(!model.marksLoaded(songs[0].id, inSetlist: nil))
        #expect(!model.marksLoaded(songs[0].id, inSetlist: setlist))
    }

    @Test func aSongLoadedOnItsOwnIsMarkedOnlyInAllSongs() {
        let (model, songs, setlist) = modelWithSetlist()
        model.loadSong(songs[1].id, from: nil)
        #expect(model.loadedFromSetlistID == nil)
        #expect(model.marksLoaded(songs[1].id, inSetlist: nil))
        #expect(!model.marksLoaded(songs[1].id, inSetlist: setlist))
    }

    @Test func aSongLoadedFromAnotherSetlistIsNotMarkedInThisOne() {
        let (model, songs, setlist) = modelWithSetlist()
        let other = model.createSetlist()
        model.setSong(songs[1].id, inSetlist: other, included: true)
        model.loadSong(songs[1].id, from: other)
        #expect(model.marksLoaded(songs[1].id, inSetlist: other))
        #expect(!model.marksLoaded(songs[1].id, inSetlist: nil))
        #expect(!model.marksLoaded(songs[1].id, inSetlist: setlist))
    }

    @Test func aSongTappedOnTheSongsTabIsNotMarkedInTheSetlistBeingSteppedThrough() {
        let (model, songs, setlist) = modelWithSetlist()
        model.loadSong(songs[0].id, from: setlist)
        model.loadSong(songs[2].id, from: nil)
        #expect(!model.marksLoaded(songs[2].id, inSetlist: setlist))
        #expect(model.marksLoaded(songs[2].id, inSetlist: nil))
        #expect(!model.marksLoaded(songs[0].id, inSetlist: setlist))
    }

    @Test func removingASongFromASetlistCanBeUndoneInPlace() {
        let (model, songs, setlist) = modelWithSetlist()
        let removal = model.removeSong(songs[1].id, fromSetlist: setlist)
        #expect(removal?.text == "Removed Mid")
        #expect(model.library.songs(inSetlist: setlist).map(\.name) == ["Slow", "Fast"])
        model.undo(removal!)
        #expect(model.library.songs(inSetlist: setlist).map(\.name) == ["Slow", "Mid", "Fast"])
    }

    @Test func undoingARemovalBringsBackTheLoadedSongsPlace() {
        let (model, songs, setlist) = modelWithSetlist()
        model.loadSong(songs[1].id, from: setlist)
        let removal = model.removeSong(songs[1].id, fromSetlist: setlist)!
        #expect(model.position == nil)
        model.undo(removal)
        #expect(model.position?.index == 1)
        #expect(model.position?.count == 3)
    }

    @Test func undoAfterTheSetlistChangedPutsTheSongAtTheEnd() {
        let (model, songs, setlist) = modelWithSetlist()
        let removal = model.removeSong(songs[0].id, fromSetlist: setlist)!
        model.removeSong(songs[1].id, fromSetlist: setlist)
        model.undo(removal)
        #expect(model.library.songs(inSetlist: setlist).map(\.name) == ["Fast", "Slow"])
    }

    @Test func removingASongThatIsNotInTheSetlistGivesNothingToUndo() {
        let (model, _, setlist) = modelWithSetlist()
        let other = model.createSong(name: "Other", settings: settings(70), addingTo: nil)!
        #expect(model.removeSong(other.id, fromSetlist: setlist) == nil)
    }

    @Test func removingSeveralSongsCanBeUndoneInPlace() throws {
        let (model, songs, setlist) = modelWithSetlist()
        let removal = try #require(model.removeSongs([songs[2].id, songs[0].id], fromSetlist: setlist))
        #expect(model.library.songs(inSetlist: setlist).map(\.name) == ["Mid"])
        #expect(removal.songIDs == [songs[0].id, songs[2].id])
        #expect(removal.text == "Removed 2 songs")
        model.undo(removal)
        #expect(model.library.songs(inSetlist: setlist).map(\.name) == ["Slow", "Mid", "Fast"])
    }

    @Test func removingSongsNotInTheSetlistGivesNothingToUndo() throws {
        let (model, songs, setlist) = modelWithSetlist()
        let other = model.createSong(name: "Other", settings: settings(70), addingTo: nil)!
        #expect(model.removeSongs([other.id], fromSetlist: setlist) == nil)
        let removal = try #require(model.removeSongs([other.id, songs[1].id], fromSetlist: setlist))
        #expect(removal.songIDs == [songs[1].id])
        #expect(removal.text == "Removed Mid")
    }

    @Test func removingSeveralKeepsTheLoadedSongLoadedOnItsOwn() throws {
        let (model, songs, setlist) = modelWithSetlist()
        model.loadSong(songs[1].id, from: setlist)
        let removal = try #require(model.removeSongs([songs[0].id, songs[1].id], fromSetlist: setlist))
        #expect(removal.loadedSongID == songs[1].id)
        #expect(model.loadedSong?.id == songs[1].id)
        #expect(model.loadedFromSetlistID == nil)
        #expect(model.position == nil)
        #expect(model.headerSubtitle == nil)
    }

    @Test func undoingSeveralBringsBackTheLoadedSongsPlace() throws {
        let (model, songs, setlist) = modelWithSetlist()
        model.loadSong(songs[1].id, from: setlist)
        let removal = try #require(model.removeSongs([songs[0].id, songs[1].id], fromSetlist: setlist))
        model.undo(removal)
        #expect(model.loadedFromSetlistID == setlist)
        #expect(model.position?.index == 1)
        #expect(model.position?.count == 3)
    }

    @Test func removingSeveralWithoutTheLoadedSongLeavesItsSetlist() throws {
        let (model, songs, setlist) = modelWithSetlist()
        model.loadSong(songs[1].id, from: setlist)
        let removal = try #require(model.removeSongs([songs[0].id, songs[2].id], fromSetlist: setlist))
        #expect(model.loadedFromSetlistID == setlist)
        #expect(removal.loadedSongID == nil)
        #expect(model.position?.index == 0)
        #expect(model.position?.count == 1)
    }

    @Test func undoingSeveralAfterTheSetlistChangedPutsThemAtTheEnd() throws {
        let (model, songs, setlist) = modelWithSetlist()
        let removal = try #require(model.removeSongs([songs[0].id, songs[1].id], fromSetlist: setlist))
        model.createSong(name: "New", settings: settings(130), addingTo: setlist)
        model.undo(removal)
        #expect(model.library.songs(inSetlist: setlist).map(\.name) == ["Fast", "New", "Slow", "Mid"])
    }

    @Test func undoingSeveralSkipsASongDeletedMeanwhile() throws {
        let (model, songs, setlist) = modelWithSetlist()
        let removal = try #require(model.removeSongs([songs[0].id, songs[1].id], fromSetlist: setlist))
        model.deleteSong(songs[0].id)
        model.undo(removal)
        #expect(model.library.songs(inSetlist: setlist).map(\.name) == ["Fast", "Mid"])
    }

    @Test func undoingWhenEverySongIsGoneDoesNothing() throws {
        let (model, songs, setlist) = modelWithSetlist()
        let removal = try #require(model.removeSongs([songs[0].id, songs[1].id], fromSetlist: setlist))
        model.deleteSongs([songs[0].id, songs[1].id])
        let before = model.library
        model.undo(removal)
        #expect(model.library == before)
    }

    @Test func numbersFollowTheSetlistAfterARemoval() {
        let model = makeModel()
        let songs = ["A", "B", "C", "D"].map { model.createSong(name: $0, settings: settings(100), addingTo: nil)! }
        let setlist = model.createSetlist()
        model.addSongs(songs.map(\.id), toSetlist: setlist)
        model.removeSong(songs[1].id, fromSetlist: setlist)
        let rows = SetlistSearch.rows(model.library.songs(inSetlist: setlist), matching: "d")
        #expect(rows.map(\.number) == [3])
        #expect(rows.map(\.song.name) == ["D"])
    }

    @Test func theLibraryShowsTheSetlistTheLoadedSongCameFrom() {
        let (model, songs, setlist) = modelWithSetlist()
        model.loadSong(songs[0].id, from: setlist)
        model.selectFilter(nil)
        model.showLoadedSetlist()
        #expect(model.selectedSetlistID == setlist)
    }

    @Test func withoutALoadedSetlistTheLibraryKeepsTheListChosenLast() {
        let (model, songs, setlist) = modelWithSetlist()
        model.unloadSong()
        model.selectFilter(setlist)
        model.loadSong(songs[0].id, from: nil)
        model.unloadSong()
        model.showLoadedSetlist()
        #expect(model.selectedSetlistID == setlist)
        model.selectFilter(nil)
        model.showLoadedSetlist()
        #expect(model.selectedSetlistID == nil)
    }

    @Test func aNewSetlistIsUntitledAndShown() {
        let model = makeModel()
        let id = model.createSetlist()
        #expect(model.library.setlist(id: id)?.name == "Untitled")
        #expect(model.selectedSetlistID == id)
    }

    @Test func anUntitledEmptySetlistIsDiscarded() {
        let model = makeModel()
        let untouched = model.createSetlist()
        model.discardSetlistIfUntouched(untouched)
        #expect(model.library.setlists.isEmpty)
        #expect(model.selectedSetlistID == nil)
    }

    @Test func aSetlistWithANameOrASongIsNotDiscarded() {
        let model = makeModel()
        let song = model.createSong(name: "Song", settings: settings(90), addingTo: nil)!
        let named = model.createSetlist()
        model.renameSetlist(named, to: "Friday gig")
        model.discardSetlistIfUntouched(named)
        let filled = model.createSetlist()
        model.setSong(song.id, inSetlist: filled, included: true)
        model.discardSetlistIfUntouched(filled)
        #expect(model.library.setlists.count == 2)
    }

    @Test func renamingASetlistToNothingKeepsItsName() {
        let model = makeModel()
        let id = model.createSetlist()
        model.renameSetlist(id, to: "Friday gig")
        model.renameSetlist(id, to: "   ")
        #expect(model.library.setlist(id: id)?.name == "Friday gig")
    }

    @Test func loadingAppliesTheSettingsWithoutStarting() {
        let model = makeModel()
        let song = model.createSong(name: "Song", settings: settings(90, .sixEight), addingTo: nil)!
        model.loadSong(song.id, from: nil)
        #expect(model.settings == song.settings)
        #expect(model.isPlaying == false)
        #expect(model.headerTitle == "Song")
        #expect(model.headerSubtitle == nil)
        #expect(store.load() == song.settings)
    }

    @Test func unloadingTheSongKeepsTheSettingsAndPlayback() {
        let (model, songs, setlist) = modelWithSetlist()
        model.loadSong(songs[1].id, from: setlist, start: true)
        model.nudgeBPM(by: 4)
        let edited = model.settings
        engine.lastUpdate = nil
        model.unloadSong()
        #expect(model.loadedSong == nil)
        #expect(model.loadedFromSetlistID == nil)
        #expect(model.position == nil)
        #expect(model.isEdited == false)
        #expect(model.headerSubtitle == "No song loaded")
        #expect(model.settings == edited)
        #expect(model.isPlaying)
        // The click does not change, so the engine hears nothing.
        #expect(engine.lastUpdate == nil)
        // The song itself is untouched.
        #expect(model.library.song(id: songs[1].id)?.settings.bpm == 100)
    }

    @Test func unloadingTheSongIsRemembered() {
        let model = makeModel()
        let song = model.createSong(name: "Song", settings: settings(90), addingTo: nil)!
        model.loadSong(song.id, from: nil)
        model.unloadSong()
        #expect(makeModel().loadedSong == nil)
    }

    @Test func thePlayButtonLoadsAndStarts() {
        let model = makeModel()
        let song = model.createSong(name: "Song", settings: settings(90), addingTo: nil)!
        model.loadSong(song.id, from: nil, start: true)
        #expect(model.isPlaying)
        #expect(engine.startCount == 1)
    }

    @Test func loadingWhilePlayingKeepsPlayingAndStartsANewBar() {
        let model = makeModel()
        let song = model.createSong(name: "Song", settings: settings(90, .threeFour), addingTo: nil)!
        model.togglePlayback()
        model.loadSong(song.id, from: nil, start: true)
        #expect(model.isPlaying)
        #expect(engine.startCount == 1)
        #expect(engine.stopCount == 0)
        #expect(engine.lastUpdate == song.settings)
        #expect(engine.lastUpdateStartedNewBar == true)
    }

    @Test func changingASettingMarksTheSongEdited() {
        let (model, songs, setlist) = modelWithSetlist()
        model.loadSong(songs[1].id, from: setlist)
        #expect(model.isEdited == false)
        #expect(model.headerSubtitle == "Untitled · 2 of 3")
        model.setBPM(104)
        #expect(model.isEdited)
        #expect(model.headerSubtitle == "Untitled · 2 of 3")
        #expect(model.headerAccessibilityLabel == "Mid, edited, Untitled · 2 of 3")
        model.setBPM(100)
        #expect(model.isEdited == false)
        #expect(model.headerAccessibilityLabel == "Mid, Untitled · 2 of 3")
    }

    @Test func aSongLoadedOnItsOwnHasNoSecondLineEvenWhenEdited() {
        let model = makeModel()
        let song = model.createSong(name: "Song", settings: settings(90), addingTo: nil)!
        model.loadSong(song.id, from: nil)
        model.setBPM(96)
        #expect(model.isEdited)
        #expect(model.headerSubtitle == nil)
        #expect(model.headerAccessibilityLabel == "Song, edited")
    }

    @Test func saveChangesWritesIntoTheSong() {
        let model = makeModel()
        let song = model.createSong(name: "Song", settings: settings(90), addingTo: nil)!
        model.loadSong(song.id, from: nil)
        model.setBPM(96)
        model.saveChanges()
        #expect(model.isEdited == false)
        #expect(model.library.song(id: song.id)?.settings.bpm == 96)
    }

    @Test func editingASongWritesItsNameAndSettings() {
        let model = makeModel()
        let song = model.createSong(name: "Song", settings: settings(90), addingTo: nil)!
        model.editSong(song.id, name: "Ballad", settings: settings(72, .threeFour))
        let edited = model.library.song(id: song.id)
        #expect(edited?.name == "Ballad")
        #expect(edited?.settings.bpm == 72)
        #expect(edited?.settings.timeSignature == .threeFour)
        // Not loaded: the metronome is not touched.
        #expect(model.settings.bpm != 72)
        #expect(model.loadedSong == nil)
    }

    @Test func editingKeepsTheOldNameWhenTheNewOneIsEmpty() {
        let model = makeModel()
        let song = model.createSong(name: "Song", settings: settings(90), addingTo: nil)!
        model.editSong(song.id, name: "  ", settings: settings(72))
        #expect(model.library.song(id: song.id)?.name == "Song")
        #expect(model.library.song(id: song.id)?.settings.bpm == 90)
    }

    @Test func editingTheLoadedSongSetsTheMetronomeToIt() {
        let model = makeModel()
        let song = model.createSong(name: "Song", settings: settings(90), addingTo: nil)!
        model.loadSong(song.id, from: nil)
        model.setBPM(96)
        #expect(model.isSaveOffered)
        model.editSong(song.id, name: "Song", settings: settings(110))
        #expect(model.settings.bpm == 110)
        #expect(model.isEdited == false)
        #expect(model.isSaveOffered == false)
    }

    @Test func renamingTheLoadedSongInEditKeepsUnsavedChanges() {
        let model = makeModel()
        let song = model.createSong(name: "Song", settings: settings(90), addingTo: nil)!
        model.loadSong(song.id, from: nil)
        model.setBPM(96)
        model.editSong(song.id, name: "Ballad", settings: song.settings)
        #expect(model.headerTitle == "Ballad")
        #expect(model.settings.bpm == 96)
        #expect(model.isEdited)
        #expect(model.isSaveOffered)
    }

    @Test func editingTheTempoAloneKeepsTheBarWhilePlaying() {
        let model = makeModel()
        let song = model.createSong(name: "Song", settings: settings(90), addingTo: nil)!
        model.loadSong(song.id, from: nil, start: true)
        model.editSong(song.id, name: "Song", settings: settings(100))
        #expect(model.settings.bpm == 100)
        #expect(engine.lastUpdateStartedNewBar == false)
    }

    @Test func discardChangesRestoresTheSong() {
        let model = makeModel()
        let song = model.createSong(name: "Song", settings: settings(90), addingTo: nil)!
        model.loadSong(song.id, from: nil)
        model.setBPM(96)
        model.toggleAccent(beat: 3)
        model.discardChanges()
        #expect(model.settings == song.settings)
        #expect(model.isEdited == false)
    }

    @Test func revertingTempoAndAccentsKeepsTheBarWhilePlaying() {
        let model = makeModel()
        let song = model.createSong(name: "Song", settings: settings(90), addingTo: nil)!
        model.loadSong(song.id, from: nil, start: true)
        model.setBPM(96)
        model.toggleAccent(beat: 3)
        model.discardChanges()
        #expect(engine.lastUpdate == song.settings)
        #expect(engine.lastUpdateStartedNewBar == false)
        #expect(model.isPlaying)
    }

    @Test func revertingTheTimeSignatureStartsANewBar() {
        let model = makeModel()
        let song = model.createSong(name: "Song", settings: settings(90), addingTo: nil)!
        model.loadSong(song.id, from: nil, start: true)
        model.selectTimeSignature(.sixEight)
        model.discardChanges()
        #expect(engine.lastUpdate == song.settings)
        #expect(engine.lastUpdateStartedNewBar == true)
    }

    @Test func revertDescriptionNamesTheSavedValues() {
        let model = makeModel()
        #expect(model.revertDescription == nil)
        let song = model.createSong(name: "Song", settings: settings(90, .sixEight), addingTo: nil)!
        model.loadSong(song.id, from: nil)
        model.setBPM(96)
        #expect(model.revertDescription == "90 BPM · 6/8")
    }

    /// A model whose Save button waits only briefly before it goes away.
    private func modelWithShortSaveOfferDelay() -> MetronomeModel {
        MetronomeModel(
            engine: engine, store: store, haptics: haptics, libraryStore: libraryStore,
            saveOfferDelay: .milliseconds(20), trackFiles: .temporary()
        )
    }

    @Test func saveStaysOfferedWhileTheTempoPassesTheSavedValue() {
        let model = makeModel()
        let song = model.createSong(name: "Song", settings: settings(130), addingTo: nil)!
        model.loadSong(song.id, from: nil)
        #expect(model.isSaveOffered == false)
        model.setBPM(129)
        #expect(model.isSaveOffered)
        model.setBPM(130)
        #expect(model.isEdited == false)
        #expect(model.isSaveOffered)
        model.setBPM(131)
        #expect(model.isSaveOffered)
    }

    @Test func saveStopsBeingOfferedOnceTheSettingsRestOnTheSavedValues() async throws {
        let model = modelWithShortSaveOfferDelay()
        let song = model.createSong(name: "Song", settings: settings(130), addingTo: nil)!
        model.loadSong(song.id, from: nil)
        model.setBPM(129)
        model.setBPM(130)
        #expect(model.isSaveOffered)
        // The tests share the main thread, so the wait is for the outcome, up to a limit,
        // not for a fixed time.
        for _ in 0..<300 where model.isSaveOffered {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(model.isSaveOffered == false)
    }

    @Test func movingOnBeforeTheWaitIsOverKeepsSaveOffered() async throws {
        let model = modelWithShortSaveOfferDelay()
        let song = model.createSong(name: "Song", settings: settings(130), addingTo: nil)!
        model.loadSong(song.id, from: nil)
        model.setBPM(129)
        model.setBPM(130)
        model.setBPM(131)
        try await Task.sleep(for: .milliseconds(200))
        #expect(model.isSaveOffered)
    }

    @Test func savingTakesTheButtonAwayAtOnce() {
        let model = makeModel()
        let song = model.createSong(name: "Song", settings: settings(90), addingTo: nil)!
        model.loadSong(song.id, from: nil)
        model.setBPM(96)
        model.saveChanges()
        #expect(model.library.song(id: song.id)?.settings.bpm == 96)
        #expect(model.isSaveOffered == false)
        #expect(haptics.successCount == 1)
    }

    @Test func savingWhileRestingOnTheSavedValuesTakesTheButtonAwayAtOnce() {
        let model = makeModel()
        let song = model.createSong(name: "Song", settings: settings(90), addingTo: nil)!
        model.loadSong(song.id, from: nil)
        model.setBPM(96)
        model.setBPM(90)
        #expect(model.isSaveOffered)
        model.saveChanges()
        #expect(model.isSaveOffered == false)
    }

    @Test func aChangeAfterSavingBringsSaveBack() {
        let model = makeModel()
        let song = model.createSong(name: "Song", settings: settings(90), addingTo: nil)!
        model.loadSong(song.id, from: nil)
        model.setBPM(96)
        model.saveChanges()
        model.setBPM(97)
        #expect(model.isSaveOffered)
        #expect(model.isEdited)
    }

    @Test func revertingAndLoadingTakeTheSaveOfferAwayAtOnce() {
        let (model, songs, setlist) = modelWithSetlist()
        model.loadSong(songs[0].id, from: setlist)
        model.setBPM(70)
        model.discardChanges()
        #expect(model.isSaveOffered == false)
        model.setBPM(70)
        model.goToNext()
        #expect(model.isSaveOffered == false)
        model.setBPM(104)
        model.unloadSong()
        #expect(model.isSaveOffered == false)
    }

    @Test func loadingAnotherSongDropsUnsavedEdits() {
        let (model, songs, setlist) = modelWithSetlist()
        model.loadSong(songs[0].id, from: setlist)
        model.setBPM(66)
        model.loadSong(songs[1].id, from: setlist)
        #expect(model.library.song(id: songs[0].id)?.settings.bpm == 60)
        #expect(model.settings.bpm == 100)
        #expect(model.isEdited == false)
    }

    @Test func selectingTheLoadedSongKeepsUnsavedEdits() {
        let model = makeModel()
        let song = model.createSong(name: "Song", settings: settings(90), addingTo: nil)!
        model.loadSong(song.id, from: nil)
        model.setBPM(96)
        let edited = model.settings
        model.loadSong(song.id, from: nil)
        #expect(model.loadedSong?.id == song.id)
        #expect(model.settings == edited)
        #expect(model.isEdited)
        #expect(model.library.song(id: song.id)?.settings == song.settings)
    }

    @Test func selectingTheLoadedSongWhilePlayingStartsNoNewBar() {
        let model = makeModel()
        let song = model.createSong(name: "Song", settings: settings(90, .threeFour), addingTo: nil)!
        model.loadSong(song.id, from: nil, start: true)
        model.setBPM(96)
        engine.lastUpdate = nil
        engine.lastUpdateStartedNewBar = nil
        model.loadSong(song.id, from: nil, start: true)
        #expect(model.isPlaying)
        #expect(engine.startCount == 1)
        #expect(engine.stopCount == 0)
        #expect(engine.lastUpdate == nil)
        #expect(engine.lastUpdateStartedNewBar == nil)
        #expect(model.settings.bpm == 96)
    }

    @Test func selectingTheLoadedSongInASetlistLoadsItFromThatSetlist() {
        let (model, songs, setlist) = modelWithSetlist()
        model.loadSong(songs[1].id, from: nil)
        #expect(model.loadedFromSetlistID == nil)
        model.setBPM(104)
        let edited = model.settings
        model.loadSong(songs[1].id, from: setlist)
        #expect(model.loadedSong?.id == songs[1].id)
        #expect(model.loadedFromSetlistID == setlist)
        #expect(model.position?.index == 1)
        #expect(model.position?.count == 3)
        #expect(model.settings == edited)
        #expect(model.isEdited)
    }

    @Test func selectingTheLoadedSongOnTheSongsTabLoadsItOnItsOwn() {
        let (model, songs, setlist) = modelWithSetlist()
        model.loadSong(songs[2].id, from: setlist)
        model.setBPM(170)
        let edited = model.settings
        model.loadSong(songs[2].id, from: nil)
        #expect(model.loadedSong?.id == songs[2].id)
        #expect(model.loadedFromSetlistID == nil)
        #expect(model.position == nil)
        #expect(model.settings == edited)
        #expect(model.isEdited)
    }

    @Test func saveAsNewSongLoadsTheNewOne() {
        let (model, songs, setlist) = modelWithSetlist()
        model.loadSong(songs[0].id, from: setlist)
        model.setBPM(66)
        let made = model.saveAsNewSong(name: "Slow, faster", settings: model.settings)
        #expect(made != nil)
        #expect(model.loadedSong?.id == made?.id)
        #expect(model.isEdited == false)
        #expect(model.position == nil)
        #expect(model.headerSubtitle == nil)
        #expect(model.library.song(id: songs[0].id)?.settings.bpm == 60)
    }

    @Test func saveAsNewSongIntoTheLoadedSetlistKeepsThePlace() throws {
        let (model, songs, setlist) = modelWithSetlist()
        model.loadSong(songs[0].id, from: setlist)
        model.setBPM(66)
        let made = try #require(model.saveAsNewSong(name: "Slow, faster", settings: model.settings, addingToLoadedSetlist: true))
        #expect(model.loadedSong?.id == made.id)
        #expect(model.loadedFromSetlistID == setlist)
        #expect(model.library.setlist(id: setlist)?.songIDs == songs.map(\.id) + [made.id])
        #expect(model.position?.index == 3)
        #expect(model.position?.count == 4)
        #expect(model.canGoPrevious)
        #expect(model.canGoNext == false)
        #expect(model.isEdited == false)
        #expect(model.library.song(id: songs[0].id)?.settings.bpm == 60)
    }

    @Test func saveAsNewSongWithNoSetlistIgnoresTheSwitch() throws {
        let model = makeModel()
        model.setBPM(132)
        let made = try #require(model.saveAsNewSong(name: "Song", settings: model.settings, addingToLoadedSetlist: true))
        #expect(model.loadedSong?.id == made.id)
        #expect(model.loadedFromSetlistID == nil)
        #expect(model.position == nil)
    }

    @Test func saveAsNewSongAfterTheSetlistWasDeletedLoadsItOnItsOwn() throws {
        let (model, songs, setlist) = modelWithSetlist()
        model.loadSong(songs[0].id, from: setlist)
        model.deleteSetlist(setlist)
        let made = try #require(model.saveAsNewSong(name: "Copy", settings: model.settings, addingToLoadedSetlist: true))
        #expect(model.loadedSong?.id == made.id)
        #expect(model.loadedFromSetlistID == nil)
    }

    @Test func loadedFromSetlistFollowsTheLoadedSong() {
        let (model, songs, setlist) = modelWithSetlist()
        #expect(model.loadedFromSetlist == nil)
        model.loadSong(songs[1].id, from: setlist)
        #expect(model.loadedFromSetlist?.id == setlist)
        model.loadSong(songs[1].id, from: nil)
        #expect(model.loadedFromSetlist == nil)
        model.unloadSong()
        #expect(model.loadedFromSetlist == nil)
    }

    @Test func takingTheLoadedSongOutOfItsSetlistKeepsItLoaded() {
        let (model, songs, setlist) = modelWithSetlist()
        model.loadSong(songs[1].id, from: setlist)
        model.setSong(songs[1].id, inSetlist: setlist, included: false)
        #expect(model.loadedSong?.id == songs[1].id)
        #expect(model.loadedFromSetlistID == nil)
        #expect(model.position == nil)
        model.setSong(songs[1].id, inSetlist: setlist, included: true)
        #expect(model.library.setlist(id: setlist)?.songIDs.last == songs[1].id)
    }

    @Test func previousAndNextStepThroughTheSetlistAndStopAtTheEnds() {
        let (model, songs, setlist) = modelWithSetlist()
        model.loadSong(songs[0].id, from: setlist)
        #expect(model.position?.index == 0)
        #expect(model.position?.count == 3)
        #expect(model.canGoPrevious == false)
        #expect(model.canGoNext)
        model.goToPrevious()
        #expect(model.loadedSong?.id == songs[0].id)
        model.goToNext()
        model.goToNext()
        #expect(model.loadedSong?.id == songs[2].id)
        #expect(model.settings.bpm == 180)
        #expect(model.canGoNext == false)
        model.goToNext()
        #expect(model.loadedSong?.id == songs[2].id)
        model.goToPrevious()
        #expect(model.loadedSong?.id == songs[1].id)
    }

    @Test func aSongLoadedFromAllSongsHasNoPosition() {
        let (model, songs, _) = modelWithSetlist()
        model.loadSong(songs[1].id, from: nil)
        #expect(model.position == nil)
        #expect(model.canGoNext == false)
    }

    @Test func deletingTheLoadedSongKeepsTheSettings() {
        let (model, songs, setlist) = modelWithSetlist()
        model.loadSong(songs[2].id, from: setlist)
        model.deleteSong(songs[2].id)
        #expect(model.loadedSong == nil)
        #expect(model.settings.bpm == 180)
        #expect(model.headerTitle == "Library")
        #expect(model.library.songs(inSetlist: setlist).count == 2)
    }

    @Test func removingTheLoadedSongFromItsSetlistFallsBackToAllSongs() {
        let (model, songs, setlist) = modelWithSetlist()
        model.loadSong(songs[1].id, from: setlist)
        model.setSong(songs[1].id, inSetlist: setlist, included: false)
        #expect(model.loadedSong?.id == songs[1].id)
        #expect(model.position == nil)
        #expect(model.headerSubtitle == nil)
    }

    @Test func aNewSongCanGoStraightIntoASetlist() {
        let (model, _, setlist) = modelWithSetlist()
        let made = model.createSong(name: "Encore", settings: settings(130), addingTo: setlist)!
        #expect(model.library.songs(inSetlist: setlist).last?.id == made.id)
    }

    @Test func setlistsCanBeRenamedReorderedDuplicatedAndDeleted() {
        let (model, songs, setlist) = modelWithSetlist()
        model.renameSetlist(setlist, to: "Friday gig")
        model.reorderSetlist(setlist, to: [songs[2].id, songs[0].id, songs[1].id])
        #expect(model.library.songs(inSetlist: setlist).map(\.name) == ["Fast", "Slow", "Mid"])
        let copy = model.duplicateSetlist(setlist)
        #expect(copy != nil)
        #expect(model.selectedSetlistID == copy)
        #expect(model.library.setlist(id: copy!)?.name == "Friday gig copy")
        model.deleteSetlist(copy!)
        #expect(model.selectedSetlistID == nil)
        #expect(model.library.setlists.count == 1)
        #expect(model.library.songs.count == 3)
    }

    @Test func deletingTheLoadedFromSetlistKeepsTheSongLoaded() {
        let (model, songs, setlist) = modelWithSetlist()
        model.loadSong(songs[1].id, from: setlist)
        model.deleteSetlist(setlist)
        #expect(model.loadedSong?.id == songs[1].id)
        #expect(model.position == nil)
    }

    @Test func everythingIsRestoredAfterRelaunch() {
        let (model, songs, setlist) = modelWithSetlist()
        model.selectFilter(setlist)
        model.loadSong(songs[1].id, from: setlist)
        let relaunched = makeModel()
        #expect(relaunched.library == model.library)
        #expect(relaunched.loadedSong?.id == songs[1].id)
        #expect(relaunched.position?.index == 1)
        #expect(relaunched.selectedSetlistID == setlist)
        #expect(relaunched.settings.bpm == 100)
        #expect(relaunched.isPlaying == false)
        relaunched.goToNext()
        #expect(relaunched.loadedSong?.id == songs[2].id)
    }

    // MARK: - Last played and the orders

    @Test func loadingASongSetsItsLastPlayedTime() {
        let (model, songs, setlist) = modelWithSetlist()
        #expect(model.lastPlayed.isEmpty)
        clock.advance()
        model.loadSong(songs[1].id, from: nil)
        #expect(model.lastPlayed == [songs[1].id: clock.now()])
        clock.advance()
        model.loadSong(songs[2].id, from: setlist)
        #expect(model.lastPlayed[songs[2].id] == clock.now())
    }

    @Test func previousAndNextSetTheLastPlayedTime() {
        let (model, songs, setlist) = modelWithSetlist()
        model.loadSong(songs[0].id, from: setlist)
        clock.advance()
        model.goToNext()
        #expect(model.lastPlayed[songs[1].id] == clock.now())
        clock.advance()
        model.goToPrevious()
        #expect(model.lastPlayed[songs[0].id] == clock.now())
    }

    @Test func tappingTheLoadedSongAgainKeepsItsTime() {
        let (model, songs, setlist) = modelWithSetlist()
        model.loadSong(songs[1].id, from: setlist)
        let loadedAt = clock.now()
        clock.advance()
        model.loadSong(songs[1].id, from: setlist)
        model.loadSong(songs[1].id, from: nil)
        #expect(model.lastPlayed == [songs[1].id: loadedAt])
    }

    @Test func saveAsNewSongAndNamingTheSettingsSetTheTime() throws {
        let model = makeModel()
        model.setBPM(132)
        clock.advance()
        let named = try #require(model.createSong(name: "Named", settings: model.settings, addingTo: nil))
        #expect(model.loadedSong?.id == named.id)
        #expect(model.lastPlayed[named.id] == clock.now())
        clock.advance()
        let made = try #require(model.saveAsNewSong(name: "Copy", settings: model.settings))
        #expect(model.lastPlayed[made.id] == clock.now())
        clock.advance()
        let other = try #require(model.createSong(name: "Other", settings: model.settings, addingTo: nil))
        #expect(model.loadedSong?.id == made.id)
        #expect(model.lastPlayed[other.id] == nil)
    }

    @Test func restoringTheLoadedSongAtLaunchSetsNoTime() {
        let (model, songs, setlist) = modelWithSetlist()
        model.loadSong(songs[1].id, from: setlist)
        clock.advance()
        let relaunched = makeModel()
        #expect(relaunched.loadedSong?.id == songs[1].id)
        #expect(relaunched.lastPlayed == model.lastPlayed)
    }

    @Test func deletingASongDropsItsLastPlayedTime() {
        let (model, songs, _) = modelWithSetlist()
        model.loadSong(songs[1].id, from: nil)
        clock.advance()
        model.loadSong(songs[0].id, from: nil)
        model.deleteSong(songs[1].id)
        #expect(model.lastPlayed == [songs[0].id: clock.now()])
        #expect(makeModel().lastPlayed == model.lastPlayed)
    }

    @Test func theChosenOrdersAreRemembered() {
        let model = makeModel()
        #expect(model.songOrder == .name)
        #expect(model.setlistOrder == .name)
        model.songOrder = .recentlyAdded
        model.setlistOrder = .recentlyUsed
        let relaunched = makeModel()
        #expect(relaunched.songOrder == .recentlyAdded)
        #expect(relaunched.setlistOrder == .recentlyUsed)
    }

    @Test func orderedSongsFollowTheChosenOrder() {
        let (model, songs, _) = modelWithSetlist()
        model.createSong(name: "Zed", settings: settings(130), addingTo: nil)
        #expect(model.orderedSongs.map(\.name) == ["Fast", "Mid", "Slow", "Zed"])
        model.songOrder = .recentlyAdded
        #expect(model.orderedSongs.map(\.name) == ["Zed", "Fast", "Mid", "Slow"])
        model.loadSong(songs[2].id, from: nil)
        clock.advance()
        model.loadSong(songs[1].id, from: nil)
        model.songOrder = .recentlyPlayed
        #expect(model.orderedSongs.map(\.name) == ["Mid", "Fast", "Slow", "Zed"])
    }

    @Test func orderedSetlistsFollowTheChosenOrder() {
        let model = makeModel()
        let beta = model.createSetlist()
        model.renameSetlist(beta, to: "beta")
        clock.advance()
        let alpha = model.createSetlist()
        model.renameSetlist(alpha, to: "Alpha")
        #expect(model.orderedSetlists.map(\.name) == ["Alpha", "beta"])
        clock.advance()
        model.selectFilter(beta)
        // By name unless another order is chosen, so using beta does not move it.
        #expect(model.orderedSetlists.map(\.name) == ["Alpha", "beta"])
        model.setlistOrder = .recentlyUsed
        #expect(model.orderedSetlists.map(\.name) == ["beta", "Alpha"])
        model.setlistOrder = .name
        #expect(model.orderedSetlists.map(\.name) == ["Alpha", "beta"])
    }

    // MARK: - Several songs at once

    @Test func addingSeveralSongsAppendsTheNewOnesInOrder() {
        let model = makeModel()
        let songs = ["S0", "S1", "S2"].map { model.createSong(name: $0, settings: settings(100), addingTo: nil)! }
        let setlist = model.createSetlist()
        model.setSong(songs[0].id, inSetlist: setlist, included: true)
        model.addSongs([songs[2].id, songs[0].id, songs[1].id], toSetlist: setlist)
        #expect(model.library.songs(inSetlist: setlist).map(\.id) == [songs[0].id, songs[2].id, songs[1].id])
        #expect(makeModel().library == model.library)
    }

    @Test func addingSongsDoesNotCountAsUsingTheSetlist() throws {
        let (model, songs, older) = modelWithSetlist()
        let extra = model.createSong(name: "Extra", settings: settings(90), addingTo: nil)!
        clock.advance()
        let newer = model.createSetlist()
        let usedAt = try #require(model.library.setlist(id: older)?.lastUsed)
        clock.advance()
        model.addSongs([extra.id, songs[0].id], toSetlist: older)
        #expect(model.library.setlist(id: older)?.lastUsed == usedAt)
        #expect(model.library.setlistsByRecency.first?.id == newer)
    }

    @Test func addingSongsThatAreAllThereChangesNothing() {
        let (model, songs, _) = modelWithSetlist()
        let other = model.createSetlist()
        model.renameSetlist(other, to: "Other")
        model.addSongs([songs[1].id, songs[2].id], toSetlist: other)
        let before = model.library
        clock.advance()
        model.addSongs([songs[1].id, songs[2].id], toSetlist: other)
        #expect(model.library == before)
    }

    @Test func addingFromASetlistKeepsThatSetlistsOrder() {
        let (model, songs, setlist) = modelWithSetlist()
        let other = model.createSetlist()
        model.setSong(songs[1].id, inSetlist: other, included: true)
        var selection = SongSelection()
        selection.toggle(songs[2].id)
        selection.toggle(songs[0].id)
        model.addSongs(selection.ordered(in: model.library.songs(inSetlist: setlist)), toSetlist: other)
        #expect(model.library.songs(inSetlist: other).map(\.name) == ["Mid", "Slow", "Fast"])
    }

    @Test func deletingSeveralSongsRemovesThemEverywhere() {
        let (model, songs, setlist) = modelWithSetlist()
        let other = model.createSetlist()
        model.setSong(songs[2].id, inSetlist: other, included: true)
        model.setSong(songs[1].id, inSetlist: other, included: true)
        model.deleteSongs([songs[0].id, songs[2].id])
        #expect(model.library.songs.map(\.id) == [songs[1].id])
        #expect(model.library.songs(inSetlist: setlist).map(\.id) == [songs[1].id])
        #expect(model.library.songs(inSetlist: other).map(\.id) == [songs[1].id])
        #expect(makeModel().library == model.library)
    }

    @Test func deletingSeveralSongsUnloadsTheLoadedOne() {
        let (model, songs, setlist) = modelWithSetlist()
        model.loadSong(songs[2].id, from: setlist)
        model.deleteSongs([songs[0].id, songs[2].id])
        #expect(model.loadedSong == nil)
        #expect(model.loadedFromSetlistID == nil)
        #expect(model.settings.bpm == 180)
        #expect(model.headerTitle == "Library")
        #expect(model.lastPlayed[songs[2].id] == nil)
    }

    @Test func deletingSongsThatAreAlreadyGoneIsHarmless() {
        let (model, songs, setlist) = modelWithSetlist()
        model.loadSong(songs[1].id, from: setlist)
        model.deleteSong(songs[0].id)
        model.deleteSongs([songs[0].id, songs[2].id, UUID()])
        #expect(model.library.songs.map(\.id) == [songs[1].id])
        #expect(model.library.songs(inSetlist: setlist).map(\.id) == [songs[1].id])
        #expect(model.loadedSong?.id == songs[1].id)
        #expect(model.loadedFromSetlistID == setlist)
    }

    @Test func theSetlistCountCountsEachSetlistOnce() {
        let (model, songs, _) = modelWithSetlist()
        #expect(model.library.setlistCount(containingAnyOf: [songs[0].id, songs[1].id]) == 1)
        let other = model.createSetlist()
        model.setSong(songs[1].id, inSetlist: other, included: true)
        #expect(model.library.setlistCount(containingAnyOf: [songs[0].id, songs[1].id]) == 2)
        #expect(model.library.setlistCount(containingAnyOf: [songs[0].id]) == 1)
        #expect(model.library.setlistCount(containingAnyOf: []) == 0)
    }
}
