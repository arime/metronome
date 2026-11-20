import Testing
@testable import Metronome

struct HeaderToggleTests {
    @Test func soundOnIsLitWithWaves() {
        let toggle = HeaderToggle.sound(isMuted: false)
        #expect(toggle.isOn)
        #expect(toggle.icon == .speakerWithWaves)
        #expect(toggle.label == "Click sound")
        #expect(toggle.accessibilityValue == "on")
        #expect(!toggle.isDimmed)
    }

    @Test func soundOffShowsTheCross() {
        let toggle = HeaderToggle.sound(isMuted: true)
        #expect(!toggle.isOn)
        #expect(toggle.icon == .speakerWithCross)
        #expect(toggle.label == "Click sound")
        #expect(toggle.accessibilityValue == "off")
    }

    @Test func backingTracksReadsLikeSound() {
        let toggle = HeaderToggle.backingTracks(isOn: true, isPlaying: false)
        #expect(toggle.isOn)
        #expect(toggle.icon == .note)
        #expect(toggle.label == "Backing tracks")
        #expect(toggle.accessibilityValue == "on")
        #expect(!toggle.isDimmed)
    }

    @Test func backingTracksOffShowsTheSlash() {
        let toggle = HeaderToggle.backingTracks(isOn: false, isPlaying: false)
        #expect(!toggle.isOn)
        #expect(toggle.icon == .noteWithSlash)
        #expect(toggle.accessibilityValue == "off")
        #expect(!toggle.isDimmed)
    }

    @Test func backingTracksIsDimmedWhilePlaying() {
        #expect(HeaderToggle.backingTracks(isOn: true, isPlaying: true).isDimmed)
        #expect(HeaderToggle.backingTracks(isOn: false, isPlaying: true).isDimmed)
        // The Sound button works playing too, so it takes no playing state and is never dimmed.
        #expect(!HeaderToggle.sound(isMuted: false).isDimmed)
        #expect(!HeaderToggle.sound(isMuted: true).isDimmed)
    }
}
