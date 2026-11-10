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

    @Test func loadingAppliesTheSettingsWithoutStarting() {
        let model = makeModel()
        let preset = model.createPreset(name: "Song", settings: settings(90, .sixEight), addingTo: nil)!
        model.loadPreset(preset.id, from: nil)
        #expect(model.settings == preset.settings)
        #expect(model.isPlaying == false)
        #expect(model.headerTitle == "Song")
        #expect(model.headerSubtitle == "All presets")
        #expect(store.load() == preset.settings)
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
        #expect(model.headerSubtitle == "Edited · 2 of 3")
        model.setBPM(100)
        #expect(model.isEdited == false)
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
        #expect(model.headerSubtitle == "All presets")
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
        #expect(model.headerSubtitle == "All presets")
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
