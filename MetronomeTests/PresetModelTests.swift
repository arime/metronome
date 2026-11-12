import Foundation
import Testing
@testable import Metronome

@MainActor
struct PresetModelTests {
    private let engine = FakeClickEngine()
    private let haptics = FakeHaptics()
    private let store = SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    private let libraryStore = LibraryStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)

    private func makeModel() -> MetronomeModel {
        MetronomeModel(engine: engine, store: store, haptics: haptics, libraryStore: libraryStore)
    }

    private func settings(_ bpm: Int, _ signature: TimeSignature = .fourFour) -> MetronomeSettings {
        MetronomeSettings(bpm: bpm, timeSignature: signature, accents: [1])
    }

    /// A model with three presets in a setlist, in the order slow, mid, fast.
    private func modelWithSetlist() -> (model: MetronomeModel, presets: [Preset], setlist: UUID) {
        let model = makeModel()
        let presets = [("Slow", 60), ("Mid", 100), ("Fast", 180)].map {
            model.createPreset(name: $0.0, settings: settings($0.1), addingTo: nil)!
        }
        let setlist = model.createSetlist()
        presets.forEach { model.setPreset($0.id, inSetlist: setlist, included: true) }
        return (model, presets, setlist)
    }

    @Test func nothingIsLoadedAtFirst() {
        let model = makeModel()
        #expect(model.loadedPreset == nil)
        #expect(model.isEdited == false)
        #expect(model.headerTitle == "Library")
        #expect(model.headerSubtitle == "No preset loaded")
        #expect(model.position == nil)
    }

    @Test func creatingAPresetFromTheLibraryDoesNotLoadIt() {
        let model = makeModel()
        let preset = model.createPreset(name: "Song", settings: settings(90), addingTo: nil)
        #expect(preset != nil)
        #expect(model.loadedPreset == nil)
        #expect(model.settings.bpm == 120)
    }

    @Test func namingTheCurrentSettingsLoadsTheNewPreset() {
        let model = makeModel()
        model.setBPM(132)
        engine.lastUpdate = nil
        let preset = model.createPreset(name: "Song", settings: model.settings, addingTo: nil)
        #expect(model.loadedPreset == preset)
        #expect(model.loadedFromSetlistID == nil)
        #expect(model.headerTitle == "Song")
        #expect(model.isEdited == false)
        #expect(engine.lastUpdate == nil)
    }

    @Test func namingTheCurrentSettingsInASetlistLoadsItFromThatSetlist() {
        let (model, _, setlist) = modelWithSetlist()
        let preset = model.createPreset(name: "Song", settings: model.settings, addingTo: setlist)!
        #expect(model.loadedPreset == preset)
        #expect(model.loadedFromSetlistID == setlist)
        #expect(model.position?.index == 3)
        #expect(model.position?.count == 4)
    }

    @Test func aNewPresetIsNotLoadedWhileAnotherIsLoaded() {
        let (model, presets, setlist) = modelWithSetlist()
        model.loadPreset(presets[0].id, from: setlist)
        model.createPreset(name: "Song", settings: model.settings, addingTo: nil)
        #expect(model.loadedPreset?.id == presets[0].id)
    }

    @Test func nextPresetIsTheOneNextWouldLoad() {
        let (model, presets, setlist) = modelWithSetlist()
        #expect(model.nextPreset == nil)
        model.loadPreset(presets[0].id, from: setlist)
        #expect(model.nextPreset?.id == presets[1].id)
        model.loadPreset(presets[2].id, from: setlist)
        #expect(model.nextPreset == nil)
        model.clearPreset()
        model.loadPreset(presets[0].id, from: nil)
        #expect(model.nextPreset == nil)
    }

    @Test func loadingFromAllPresetsKeepsTheSetlistBeingSteppedThrough() {
        let (model, presets, setlist) = modelWithSetlist()
        let other = model.createPreset(name: "Other", settings: settings(70), addingTo: nil)!
        model.loadPreset(presets[0].id, from: setlist)
        model.loadPreset(presets[2].id, from: nil)
        #expect(model.loadedFromSetlistID == setlist)
        #expect(model.position?.index == 2)
        // A preset that is not in the setlist leaves it.
        model.loadPreset(other.id, from: nil)
        #expect(model.loadedFromSetlistID == nil)
        #expect(model.position == nil)
    }

    @Test func removingAPresetFromASetlistCanBeUndoneInPlace() {
        let (model, presets, setlist) = modelWithSetlist()
        let removal = model.removePreset(presets[1].id, fromSetlist: setlist)
        #expect(removal?.presetName == "Mid")
        #expect(model.library.presets(inSetlist: setlist).map(\.name) == ["Slow", "Fast"])
        model.undo(removal!)
        #expect(model.library.presets(inSetlist: setlist).map(\.name) == ["Slow", "Mid", "Fast"])
    }

    @Test func undoingARemovalBringsBackTheLoadedPresetsPlace() {
        let (model, presets, setlist) = modelWithSetlist()
        model.loadPreset(presets[1].id, from: setlist)
        let removal = model.removePreset(presets[1].id, fromSetlist: setlist)!
        #expect(model.position == nil)
        model.undo(removal)
        #expect(model.position?.index == 1)
        #expect(model.position?.count == 3)
    }

    @Test func undoAfterTheSetlistChangedPutsThePresetAtTheEnd() {
        let (model, presets, setlist) = modelWithSetlist()
        let removal = model.removePreset(presets[0].id, fromSetlist: setlist)!
        model.removePreset(presets[1].id, fromSetlist: setlist)
        model.undo(removal)
        #expect(model.library.presets(inSetlist: setlist).map(\.name) == ["Fast", "Slow"])
    }

    @Test func removingAPresetThatIsNotInTheSetlistGivesNothingToUndo() {
        let (model, _, setlist) = modelWithSetlist()
        let other = model.createPreset(name: "Other", settings: settings(70), addingTo: nil)!
        #expect(model.removePreset(other.id, fromSetlist: setlist) == nil)
    }

    @Test func theLibraryShowsTheSetlistTheLoadedPresetCameFrom() {
        let (model, presets, setlist) = modelWithSetlist()
        model.loadPreset(presets[0].id, from: setlist)
        model.selectFilter(nil)
        model.showLoadedSetlist()
        #expect(model.selectedSetlistID == setlist)
    }

    @Test func withoutALoadedSetlistTheLibraryKeepsTheListChosenLast() {
        let (model, presets, setlist) = modelWithSetlist()
        model.clearPreset()
        model.selectFilter(setlist)
        model.loadPreset(presets[0].id, from: nil)
        model.clearPreset()
        model.showLoadedSetlist()
        #expect(model.selectedSetlistID == setlist)
        model.selectFilter(nil)
        model.showLoadedSetlist()
        #expect(model.selectedSetlistID == nil)
    }

    @Test func aNewSetlistLeftUntouchedIsDiscarded() {
        let model = makeModel()
        let untouched = model.createSetlist()
        model.discardSetlistIfUntouched(untouched)
        #expect(model.library.setlists.isEmpty)
        #expect(model.selectedSetlistID == nil)
    }

    @Test func aNewSetlistWithANameOrAPresetIsKept() {
        let model = makeModel()
        let preset = model.createPreset(name: "Song", settings: settings(90), addingTo: nil)!
        let named = model.createSetlist()
        model.renameSetlist(named, to: "Friday gig")
        model.discardSetlistIfUntouched(named)
        let filled = model.createSetlist()
        model.setPreset(preset.id, inSetlist: filled, included: true)
        model.discardSetlistIfUntouched(filled)
        #expect(model.library.setlists.count == 2)
    }

    @Test func loadingAppliesTheSettingsWithoutStarting() {
        let model = makeModel()
        let preset = model.createPreset(name: "Song", settings: settings(90, .sixEight), addingTo: nil)!
        model.loadPreset(preset.id, from: nil)
        #expect(model.settings == preset.settings)
        #expect(model.isPlaying == false)
        #expect(model.headerTitle == "Song")
        #expect(model.headerSubtitle == nil)
        #expect(store.load() == preset.settings)
    }

    @Test func clearingThePresetKeepsTheSettingsAndPlayback() {
        let (model, presets, setlist) = modelWithSetlist()
        model.loadPreset(presets[1].id, from: setlist, start: true)
        model.nudgeBPM(by: 4)
        let edited = model.settings
        engine.lastUpdate = nil
        model.clearPreset()
        #expect(model.loadedPreset == nil)
        #expect(model.loadedFromSetlistID == nil)
        #expect(model.position == nil)
        #expect(model.isEdited == false)
        #expect(model.headerSubtitle == "No preset loaded")
        #expect(model.settings == edited)
        #expect(model.isPlaying)
        // The click does not change, so the engine hears nothing.
        #expect(engine.lastUpdate == nil)
        // The preset itself is untouched.
        #expect(model.library.preset(id: presets[1].id)?.settings.bpm == 100)
    }

    @Test func clearingThePresetIsRemembered() {
        let model = makeModel()
        let preset = model.createPreset(name: "Song", settings: settings(90), addingTo: nil)!
        model.loadPreset(preset.id, from: nil)
        model.clearPreset()
        #expect(makeModel().loadedPreset == nil)
    }

    @Test func thePlayButtonLoadsAndStarts() {
        let model = makeModel()
        let preset = model.createPreset(name: "Song", settings: settings(90), addingTo: nil)!
        model.loadPreset(preset.id, from: nil, start: true)
        #expect(model.isPlaying)
        #expect(engine.startCount == 1)
    }

    @Test func loadingWhilePlayingKeepsPlayingAndStartsANewBar() {
        let model = makeModel()
        let preset = model.createPreset(name: "Song", settings: settings(90, .threeFour), addingTo: nil)!
        model.togglePlayback()
        model.loadPreset(preset.id, from: nil, start: true)
        #expect(model.isPlaying)
        #expect(engine.startCount == 1)
        #expect(engine.stopCount == 0)
        #expect(engine.lastUpdate == preset.settings)
        #expect(engine.lastUpdateStartedNewBar == true)
    }

    @Test func changingASettingMarksThePresetEdited() {
        let (model, presets, setlist) = modelWithSetlist()
        model.loadPreset(presets[1].id, from: setlist)
        #expect(model.isEdited == false)
        #expect(model.headerSubtitle == "New setlist · 2 of 3")
        model.setBPM(104)
        #expect(model.isEdited)
        #expect(model.headerSubtitle == "New setlist · 2 of 3")
        #expect(model.headerAccessibilityLabel == "Mid, edited, New setlist · 2 of 3")
        model.setBPM(100)
        #expect(model.isEdited == false)
        #expect(model.headerAccessibilityLabel == "Mid, New setlist · 2 of 3")
    }

    @Test func aPresetLoadedOnItsOwnHasNoSecondLineEvenWhenEdited() {
        let model = makeModel()
        let preset = model.createPreset(name: "Song", settings: settings(90), addingTo: nil)!
        model.loadPreset(preset.id, from: nil)
        model.setBPM(96)
        #expect(model.isEdited)
        #expect(model.headerSubtitle == nil)
        #expect(model.headerAccessibilityLabel == "Song, edited")
    }

    @Test func saveChangesWritesIntoThePreset() {
        let model = makeModel()
        let preset = model.createPreset(name: "Song", settings: settings(90), addingTo: nil)!
        model.loadPreset(preset.id, from: nil)
        model.setBPM(96)
        model.saveChanges()
        #expect(model.isEdited == false)
        #expect(model.library.preset(id: preset.id)?.settings.bpm == 96)
    }

    @Test func discardChangesRestoresThePreset() {
        let model = makeModel()
        let preset = model.createPreset(name: "Song", settings: settings(90), addingTo: nil)!
        model.loadPreset(preset.id, from: nil)
        model.setBPM(96)
        model.toggleAccent(beat: 3)
        model.discardChanges()
        #expect(model.settings == preset.settings)
        #expect(model.isEdited == false)
    }

    @Test func revertingTempoAndAccentsKeepsTheBarWhilePlaying() {
        let model = makeModel()
        let preset = model.createPreset(name: "Song", settings: settings(90), addingTo: nil)!
        model.loadPreset(preset.id, from: nil, start: true)
        model.setBPM(96)
        model.toggleAccent(beat: 3)
        model.discardChanges()
        #expect(engine.lastUpdate == preset.settings)
        #expect(engine.lastUpdateStartedNewBar == false)
        #expect(model.isPlaying)
    }

    @Test func revertingTheTimeSignatureStartsANewBar() {
        let model = makeModel()
        let preset = model.createPreset(name: "Song", settings: settings(90), addingTo: nil)!
        model.loadPreset(preset.id, from: nil, start: true)
        model.selectTimeSignature(.sixEight)
        model.discardChanges()
        #expect(engine.lastUpdate == preset.settings)
        #expect(engine.lastUpdateStartedNewBar == true)
    }

    @Test func revertDescriptionNamesTheSavedValues() {
        let model = makeModel()
        #expect(model.revertDescription == nil)
        let preset = model.createPreset(name: "Song", settings: settings(90, .sixEight), addingTo: nil)!
        model.loadPreset(preset.id, from: nil)
        model.setBPM(96)
        #expect(model.revertDescription == "90 BPM · 6/8")
    }

    /// A model whose Save button waits only briefly before it goes away.
    private func modelWithShortSaveOfferDelay() -> MetronomeModel {
        MetronomeModel(
            engine: engine, store: store, haptics: haptics, libraryStore: libraryStore,
            saveOfferDelay: .milliseconds(20)
        )
    }

    @Test func saveStaysOfferedWhileTheTempoPassesTheSavedValue() {
        let model = makeModel()
        let preset = model.createPreset(name: "Song", settings: settings(130), addingTo: nil)!
        model.loadPreset(preset.id, from: nil)
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
        let preset = model.createPreset(name: "Song", settings: settings(130), addingTo: nil)!
        model.loadPreset(preset.id, from: nil)
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
        let preset = model.createPreset(name: "Song", settings: settings(130), addingTo: nil)!
        model.loadPreset(preset.id, from: nil)
        model.setBPM(129)
        model.setBPM(130)
        model.setBPM(131)
        try await Task.sleep(for: .milliseconds(200))
        #expect(model.isSaveOffered)
    }

    @Test func savingConfirmsInTheButtonAndThenTakesItAway() async throws {
        let model = MetronomeModel(
            engine: engine, store: store, haptics: haptics, libraryStore: libraryStore,
            saveConfirmationTime: .milliseconds(20)
        )
        let preset = model.createPreset(name: "Song", settings: settings(90), addingTo: nil)!
        model.loadPreset(preset.id, from: nil)
        model.setBPM(96)
        model.saveChanges()
        #expect(model.library.preset(id: preset.id)?.settings.bpm == 96)
        #expect(model.isSaveConfirmed)
        #expect(model.isSaveOffered)
        #expect(haptics.successCount == 1)
        // A second tap during the confirmation does nothing.
        model.saveChanges()
        #expect(haptics.successCount == 1)
        for _ in 0..<300 where model.isSaveOffered {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(model.isSaveConfirmed == false)
        #expect(model.isSaveOffered == false)
    }

    @Test func aChangeDuringTheConfirmationBringsSaveBack() {
        let model = makeModel()
        let preset = model.createPreset(name: "Song", settings: settings(90), addingTo: nil)!
        model.loadPreset(preset.id, from: nil)
        model.setBPM(96)
        model.saveChanges()
        model.setBPM(97)
        #expect(model.isSaveConfirmed == false)
        #expect(model.isSaveOffered)
        #expect(model.isEdited)
    }

    @Test func revertingAndLoadingTakeTheSaveOfferAwayAtOnce() {
        let (model, presets, setlist) = modelWithSetlist()
        model.loadPreset(presets[0].id, from: setlist)
        model.setBPM(70)
        model.discardChanges()
        #expect(model.isSaveOffered == false)
        model.setBPM(70)
        model.goToNext()
        #expect(model.isSaveOffered == false)
        model.setBPM(104)
        model.clearPreset()
        #expect(model.isSaveOffered == false)
    }

    @Test func loadingAnotherPresetDropsUnsavedEdits() {
        let (model, presets, setlist) = modelWithSetlist()
        model.loadPreset(presets[0].id, from: setlist)
        model.setBPM(66)
        model.loadPreset(presets[1].id, from: setlist)
        #expect(model.library.preset(id: presets[0].id)?.settings.bpm == 60)
        #expect(model.settings.bpm == 100)
        #expect(model.isEdited == false)
    }

    @Test func saveAsNewPresetLoadsTheNewOne() {
        let (model, presets, setlist) = modelWithSetlist()
        model.loadPreset(presets[0].id, from: setlist)
        model.setBPM(66)
        let made = model.saveAsNewPreset(name: "Slow, faster", settings: model.settings)
        #expect(made != nil)
        #expect(model.loadedPreset?.id == made?.id)
        #expect(model.isEdited == false)
        #expect(model.position == nil)
        #expect(model.headerSubtitle == nil)
        #expect(model.library.preset(id: presets[0].id)?.settings.bpm == 60)
    }

    @Test func previousAndNextStepThroughTheSetlistAndStopAtTheEnds() {
        let (model, presets, setlist) = modelWithSetlist()
        model.loadPreset(presets[0].id, from: setlist)
        #expect(model.position?.index == 0)
        #expect(model.position?.count == 3)
        #expect(model.canGoPrevious == false)
        #expect(model.canGoNext)
        model.goToPrevious()
        #expect(model.loadedPreset?.id == presets[0].id)
        model.goToNext()
        model.goToNext()
        #expect(model.loadedPreset?.id == presets[2].id)
        #expect(model.settings.bpm == 180)
        #expect(model.canGoNext == false)
        model.goToNext()
        #expect(model.loadedPreset?.id == presets[2].id)
        model.goToPrevious()
        #expect(model.loadedPreset?.id == presets[1].id)
    }

    @Test func aPresetLoadedFromAllPresetsHasNoPosition() {
        let (model, presets, _) = modelWithSetlist()
        model.loadPreset(presets[1].id, from: nil)
        #expect(model.position == nil)
        #expect(model.canGoNext == false)
    }

    @Test func deletingTheLoadedPresetKeepsTheSettings() {
        let (model, presets, setlist) = modelWithSetlist()
        model.loadPreset(presets[2].id, from: setlist)
        model.deletePreset(presets[2].id)
        #expect(model.loadedPreset == nil)
        #expect(model.settings.bpm == 180)
        #expect(model.headerTitle == "Library")
        #expect(model.library.presets(inSetlist: setlist).count == 2)
    }

    @Test func removingTheLoadedPresetFromItsSetlistFallsBackToAllPresets() {
        let (model, presets, setlist) = modelWithSetlist()
        model.loadPreset(presets[1].id, from: setlist)
        model.setPreset(presets[1].id, inSetlist: setlist, included: false)
        #expect(model.loadedPreset?.id == presets[1].id)
        #expect(model.position == nil)
        #expect(model.headerSubtitle == nil)
    }

    @Test func aNewPresetCanGoStraightIntoASetlist() {
        let (model, _, setlist) = modelWithSetlist()
        let made = model.createPreset(name: "Encore", settings: settings(130), addingTo: setlist)!
        #expect(model.library.presets(inSetlist: setlist).last?.id == made.id)
    }

    @Test func setlistsCanBeRenamedReorderedDuplicatedAndDeleted() {
        let (model, presets, setlist) = modelWithSetlist()
        model.renameSetlist(setlist, to: "Friday gig")
        model.reorderSetlist(setlist, to: [presets[2].id, presets[0].id, presets[1].id])
        #expect(model.library.presets(inSetlist: setlist).map(\.name) == ["Fast", "Slow", "Mid"])
        let copy = model.duplicateSetlist(setlist)
        #expect(copy != nil)
        #expect(model.selectedSetlistID == copy)
        #expect(model.library.setlist(id: copy!)?.name == "Friday gig copy")
        model.deleteSetlist(copy!)
        #expect(model.selectedSetlistID == nil)
        #expect(model.library.setlists.count == 1)
        #expect(model.library.presets.count == 3)
    }

    @Test func deletingTheLoadedFromSetlistKeepsThePresetLoaded() {
        let (model, presets, setlist) = modelWithSetlist()
        model.loadPreset(presets[1].id, from: setlist)
        model.deleteSetlist(setlist)
        #expect(model.loadedPreset?.id == presets[1].id)
        #expect(model.position == nil)
    }

    @Test func everythingIsRestoredAfterRelaunch() {
        let (model, presets, setlist) = modelWithSetlist()
        model.selectFilter(setlist)
        model.loadPreset(presets[1].id, from: setlist)
        let relaunched = makeModel()
        #expect(relaunched.library == model.library)
        #expect(relaunched.loadedPreset?.id == presets[1].id)
        #expect(relaunched.position?.index == 1)
        #expect(relaunched.selectedSetlistID == setlist)
        #expect(relaunched.settings.bpm == 100)
        #expect(relaunched.isPlaying == false)
        relaunched.goToNext()
        #expect(relaunched.loadedPreset?.id == presets[2].id)
    }
}
