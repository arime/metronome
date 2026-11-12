import Testing
@testable import Metronome

struct MetronomeSettingsTests {
    @Test func startsWithTheDefaults() {
        let settings = MetronomeSettings()
        #expect(settings.bpm == 120)
        #expect(settings.timeSignature == .fourFour)
        #expect(settings.accents == [1])
    }

    @Test func setBPMClamps() {
        var settings = MetronomeSettings()
        settings.setBPM(999)
        #expect(settings.bpm == 300)
        settings.setBPM(-5)
        #expect(settings.bpm == 30)
    }

    @Test func anyCombinationOfAccentsIsAllowedIncludingNone() {
        var settings = MetronomeSettings()
        settings.toggleAccent(beat: 3)
        #expect(settings.accents == [1, 3])
        settings.toggleAccent(beat: 1)
        settings.toggleAccent(beat: 3)
        #expect(settings.accents.isEmpty)
    }

    @Test func accentsOutsideTheBarAreIgnored() {
        var settings = MetronomeSettings()
        settings.toggleAccent(beat: 5)
        settings.toggleAccent(beat: 0)
        #expect(settings.accents == [1])
    }

    @Test func reselectingTheSameSignatureChangesNothing() {
        var settings = MetronomeSettings()
        settings.toggleAccent(beat: 2)
        #expect(settings.setTimeSignature(.fourFour) == false)
        #expect(settings.accents == [1, 2])
    }

    @Test func changingTheSignatureResetsAccentsToBeatOne() {
        var settings = MetronomeSettings()
        settings.toggleAccent(beat: 1)
        settings.toggleAccent(beat: 2)
        #expect(settings.setTimeSignature(.sevenEight) == true)
        #expect(settings.timeSignature == .sevenEight)
        #expect(settings.accents == [1])
    }
}
