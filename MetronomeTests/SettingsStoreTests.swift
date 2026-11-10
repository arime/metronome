import Foundation
import Testing
@testable import Metronome

struct SettingsStoreTests {
    private let defaults: UserDefaults
    private let store: SettingsStore
    private let key = "metronome.settings.v1"

    init() {
        defaults = UserDefaults(suiteName: UUID().uuidString)!
        store = SettingsStore(defaults: defaults)
    }

    @Test func loadsDefaultsWhenNothingIsStored() {
        #expect(store.load() == MetronomeSettings())
    }

    @Test func savedSettingsComeBack() {
        var custom = MetronomeSettings()
        custom.setBPM(87)
        custom.setTimeSignature(.sevenEight)
        custom.toggleAccent(beat: 4)
        store.save(custom)
        #expect(store.load() == custom)
    }

    @Test func unreadableDataLoadsDefaults() {
        defaults.set(Data("not json".utf8), forKey: key)
        #expect(store.load() == MetronomeSettings())
    }

    @Test func outOfRangeValuesAreSanitized() {
        defaults.set(Data(#"{"bpm":900,"timeSignature":"3/4","accents":[1,5]}"#.utf8), forKey: key)
        let loaded = store.load()
        #expect(loaded.bpm == 250)
        #expect(loaded.timeSignature == .threeFour)
        #expect(loaded.accents == [1])
    }

    @Test func unknownTimeSignatureLoadsDefaults() {
        defaults.set(Data(#"{"bpm":100,"timeSignature":"11/16","accents":[1]}"#.utf8), forKey: key)
        #expect(store.load() == MetronomeSettings())
    }
}
