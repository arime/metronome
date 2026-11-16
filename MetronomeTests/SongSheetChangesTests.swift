import Foundation
import Testing
@testable import Metronome

@Suite struct SongSheetChangesTests {
    private let saved = MetronomeSettings(bpm: 120, timeSignature: .fourFour, accents: [1, 3])
    private var song: Song { Song(id: UUID(), name: "Harbour Lights", settings: saved) }

    // MARK: - Edit song

    @Test func editSongWithNothingChangedCannotSave() {
        #expect(SongSheetChanges(editing: song).canSave(name: "Harbour Lights", settings: saved) == false)
    }

    @Test func editSongIgnoresSpacesAtTheEndsOfTheName() {
        #expect(SongSheetChanges(editing: song).canSave(name: "  Harbour Lights ", settings: saved) == false)
    }

    @Test func editSongWithANewNameCanSave() {
        #expect(SongSheetChanges(editing: song).canSave(name: "Harbour Lights II", settings: saved))
    }

    @Test func editSongWithAnErasedNameCannotSave() {
        #expect(SongSheetChanges(editing: song).canSave(name: "  ", settings: saved) == false)
    }

    @Test func editSongWithAnErasedNameAndAChangedTempoCannotSave() {
        var settings = saved
        settings.setBPM(121)
        #expect(SongSheetChanges(editing: song).canSave(name: "", settings: settings) == false)
    }

    @Test func editSongWithAChangedTempoCanSave() {
        var settings = saved
        settings.setBPM(121)
        #expect(SongSheetChanges(editing: song).canSave(name: "Harbour Lights", settings: settings))
    }

    @Test func editSongWithChangedAccentsCanSave() {
        var settings = saved
        settings.toggleAccent(beat: 2)
        #expect(SongSheetChanges(editing: song).canSave(name: "Harbour Lights", settings: settings))
    }

    @Test func editSongWithAChangedTimeSignatureCanSave() {
        var settings = saved
        settings.setTimeSignature(.threeFour)
        #expect(SongSheetChanges(editing: song).canSave(name: "Harbour Lights", settings: settings))
    }

    @Test func editSongChangedAndChangedBackCannotSave() {
        var settings = saved
        settings.setBPM(140)
        settings.setBPM(120)
        settings.toggleAccent(beat: 2)
        settings.toggleAccent(beat: 2)
        #expect(SongSheetChanges(editing: song).canSave(name: "Harbour Lights", settings: settings) == false)
    }

    @Test func editSongSignatureChangedAndBackCanSaveWhenAccentsWereReset() {
        var settings = saved
        settings.setTimeSignature(.threeFour)
        settings.setTimeSignature(.fourFour)
        // Changing the signature reset the accents to beat 1, so beat 3 is no longer accented.
        #expect(SongSheetChanges(editing: song).canSave(name: "Harbour Lights", settings: settings))
    }

    // MARK: - New song

    @Test func newSongWithoutANameCannotSave() {
        #expect(SongSheetChanges.newSong.canSave(name: "", settings: saved) == false)
    }

    @Test func newSongWithOnlySpacesTypedCannotSave() {
        #expect(SongSheetChanges.newSong.canSave(name: "   ", settings: saved) == false)
    }

    @Test func newSongWithANameCanSave() {
        #expect(SongSheetChanges.newSong.canSave(name: "Copper Sky", settings: saved))
    }

    @Test func newSongWithChangedSettingsButNoNameCannotSave() {
        var settings = saved
        settings.setBPM(96)
        #expect(SongSheetChanges.newSong.canSave(name: "", settings: settings) == false)
    }

    // MARK: - Backing track

    private var pickedTrack: PickedTrack {
        PickedTrack(url: URL(filePath: "/tmp/Take.wav"), fileName: "Take.wav", offset: 0)
    }

    @Test func attachingOrRemovingATrackMakesSaveReady() {
        let changes = SongSheetChanges(editing: song)
        #expect(changes.canSave(name: "Harbour Lights", settings: saved, track: .attach(pickedTrack)))
        #expect(changes.canSave(name: "Harbour Lights", settings: saved, track: .remove))
        #expect(changes.canSave(name: "Harbour Lights", settings: saved, track: .keep) == false)
    }

    @Test func aTrackAloneDoesNotReplaceTheName() {
        #expect(SongSheetChanges.newSong.canSave(name: "", settings: saved, track: .attach(pickedTrack)) == false)
    }

    // MARK: - The Backing track row

    private let savedTrack = BackingTrack(fileID: UUID(), fileName: "Song.m4a", offset: 48, bpm: 120)

    @Test func theRowShowsNoTrack() {
        #expect(TrackRowState(saved: nil, isSavedMissing: false, edit: .keep) == .none)
    }

    @Test func theRowShowsTheSavedTrack() {
        #expect(TrackRowState(saved: savedTrack, isSavedMissing: false, edit: .keep) == .file("Song.m4a"))
    }

    @Test func theRowShowsASavedTrackAsMissing() {
        #expect(TrackRowState(saved: savedTrack, isSavedMissing: true, edit: .keep) == .missing)
    }

    @Test func theRowShowsAFilePickedForASongWithoutATrack() {
        #expect(TrackRowState(saved: nil, isSavedMissing: false, edit: .attach(pickedTrack)) == .file("Take.wav"))
    }

    @Test func theRowShowsAFilePickedToReplaceTheSavedOne() {
        #expect(TrackRowState(saved: savedTrack, isSavedMissing: false, edit: .attach(pickedTrack)) == .file("Take.wav"))
    }

    @Test func aFilePickedForAMissingTrackKeepsTheSavedName() {
        #expect(TrackRowState(saved: savedTrack, isSavedMissing: true, edit: .attach(pickedTrack)) == .file("Song.m4a"))
    }

    @Test func theRowShowsARemovedTrackAsNone() {
        #expect(TrackRowState(saved: savedTrack, isSavedMissing: false, edit: .remove) == .none)
        #expect(TrackRowState(saved: savedTrack, isSavedMissing: true, edit: .remove) == .none)
    }
}
