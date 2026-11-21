import Foundation
import Testing
@testable import Metronome

/// What Track content's file-name row shows, in each of its states (6.12).
struct TrackCardTests {
    private let songID = UUID()
    private let track = BackingTrack(fileID: UUID(), fileName: "Song.m4a", offset: 50)

    @Test func aPlayableTrackShowsItsNameAndSync() {
        let card = TrackCard.state(loadedSongID: songID, track: track, isPlayable: true)
        #expect(card == .playable(fileName: "Song.m4a"))
        #expect(card.text == "Song.m4a")
        #expect(card.textStyle == .fileName)
        #expect(card.pill == .sync)
        #expect(card.hasFile)
        #expect(card.accessibilityLabel == "Backing track, Song.m4a")
    }

    @Test func aMissingFileShowsItsNameAndChooseFile() {
        let card = TrackCard.state(loadedSongID: songID, track: track, isPlayable: false)
        #expect(card == .missing(fileName: "Song.m4a", fileID: track.fileID))
        #expect(card.text == "Song.m4a")
        #expect(card.textStyle == .missingFileName)
        #expect(card.pill == .chooseFile(.missingTrack(fileID: track.fileID)))
        #expect(card.hasFile == false)
        #expect(card.accessibilityLabel == "Track missing, Song.m4a")
    }

    @Test func aSongWithoutATrackShowsNoTrackSelectedAndChooseFile() {
        let card = TrackCard.state(loadedSongID: songID, track: nil, isPlayable: false)
        #expect(card == .noTrack(songID: songID))
        #expect(card.text == "No track selected")
        #expect(card.textStyle == .noTrack)
        #expect(card.pill == .chooseFile(.song(id: songID)))
        #expect(card.hasFile == false)
        #expect(card.accessibilityLabel == "No track selected")
    }

    @Test func nothingLoadedShowsNoTrackSelectedWithoutAButton() {
        let card = TrackCard.state(loadedSongID: nil, track: nil, isPlayable: false)
        #expect(card == .nothingLoaded)
        #expect(card.text == "No track selected")
        #expect(card.textStyle == .noTrack)
        #expect(card.pill == nil)
        #expect(card.hasFile == false)
        #expect(card.accessibilityLabel == "No track selected")
    }
}
