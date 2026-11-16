import Foundation
import Testing
@testable import Metronome

@Suite struct BackingTrackRecordTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func t(_ n: Double) -> Date {
        t0 + n
    }

    private func settings(_ bpm: Int) -> MetronomeSettings {
        MetronomeSettings(bpm: bpm, timeSignature: .fourFour, accents: [1])
    }

    private func record() -> SongRecord {
        SongRecord(id: UUID(), name: "Song", settings: settings(100), created: t(0), now: t(0))
    }

    private func track(firstBeat: Int = 150) -> BackingTrack {
        BackingTrack(fileID: UUID(), fileName: "Song.m4a", firstBeat: firstBeat)
    }

    @Test func aSongWithoutATrackPartHasNoTrack() {
        let record = record()
        #expect(record.song?.track == nil)
        #expect(record.parts[SongRecord.trackKey] == nil)
    }

    @Test func settingATrackRoundTrips() {
        var record = record()
        let track = BackingTrack(fileID: UUID(), fileName: "Song.m4a", firstBeat: 237, countIn: .oneBar, mix: -0.4)
        record.setTrack(track, now: t(5))
        #expect(record.song?.track == track)
    }

    @Test func removingATrackWritesNullAndReadsAsNone() {
        var record = record()
        record.setTrack(track(), now: t(5))
        record.setTrack(nil, now: t(10))
        #expect(record.parts[SongRecord.trackKey]?.value == .null)
        #expect(record.song?.track == nil)
        #expect(record.song != nil)
    }

    @Test func settingTheSameTrackDoesNotRestampThePart() {
        var record = record()
        let track = track()
        record.setTrack(track, now: t(5))
        record.setTrack(track, now: t(10))
        #expect(record.parts[SongRecord.trackKey]?.time == t(5))
    }

    @Test func aNudgedFirstBeatRestampsOnlyTheTrackPart() {
        var record = record()
        var track = track()
        record.setTrack(track, now: t(5))
        track.firstBeat += 1
        record.setTrack(track, now: t(10))
        #expect(record.parts[SongRecord.trackKey]?.time == t(10))
        #expect(record.parts[SongRecord.nameKey]?.time == t(0))
        #expect(record.parts[SongRecord.tempoKey]?.time == t(0))
        #expect(record.parts[SongRecord.meterKey]?.time == t(0))
        #expect(record.song?.track?.firstBeat == 151)
    }

    @Test func anUnreadableTrackPartLeavesTheSongReadable() {
        var record = record()
        record.parts[SongRecord.trackKey] = Part(time: t(5), value: .string("x"))
        #expect(record.song != nil)
        #expect(record.song?.track == nil)
    }

    @Test func theNewerTrackPartWinsWhenCombining() {
        var base = record()
        let track = track()
        base.setTrack(track, now: t(1))
        var a = base; a.setName("Renamed", now: t(20))
        var nudged = track; nudged.firstBeat = 200
        var b = base; b.setTrack(nudged, now: t(10))
        var older = track; older.firstBeat = 120
        a.setTrack(older, now: t(5))
        let merged = a.merged(with: b)
        #expect(merged.song?.track == nudged)
        #expect(merged.song?.name == "Renamed")
        #expect(merged == b.merged(with: a))
    }

    @Test func aTrackRemovedLaterWinsOverAnOlderNudge() {
        var base = record()
        let track = track()
        base.setTrack(track, now: t(1))
        var a = base; var nudged = track; nudged.firstBeat = 300; a.setTrack(nudged, now: t(10))
        var b = base; b.setTrack(nil, now: t(20))
        let merged = a.merged(with: b)
        #expect(merged.song?.track == nil)
        #expect(merged.song != nil)
        #expect(merged == b.merged(with: a))
    }

    @Test func referencedFileIDsLeaveOutDeletedSongsAndSongsWithoutTracks() {
        var library = Library()
        let kept = track()
        let removed = track()
        library.addSong(name: "Kept", settings: settings(100), track: kept, now: t(0))
        let gone = library.addSong(name: "Gone", settings: settings(100), track: removed, now: t(0))!
        let plain = library.addSong(name: "Plain", settings: settings(100), now: t(0))!
        library.deleteSong(gone.id, now: t(5))
        #expect(library.song(id: plain.id)?.track == nil)
        #expect(library.referencedFileIDs == [kept.fileID])
    }

    /// A song whose track part holds `value` as it arrived, for example from a later version.
    private func record(trackPart value: JSONValue) -> SongRecord {
        var record = record()
        record.parts[SongRecord.trackKey] = Part(time: t(5), value: value)
        return record
    }

    /// A track part as this version writes it, with `changes` on top.
    private func trackPart(_ fileID: UUID, _ changes: [String: JSONValue] = [:]) -> JSONValue {
        let fields: [String: JSONValue] = [
            "fileID": .string(fileID.uuidString), "fileName": .string("Song.m4a"),
            "firstBeat": .number(48), "countIn": .number(2), "mix": .number(0),
        ]
        return .object(fields.merging(changes) { $1 })
    }

    @Test func aTrackPartThisVersionCannotReadStillKeepsItsFile() {
        let unknownCountIn = UUID(), extraField = UUID()
        let laterCountIn = record(trackPart: trackPart(unknownCountIn, ["countIn": .number(4)]))
        let laterField = record(trackPart: trackPart(extraField, ["swing": .number(0.6)]))
        let empty = record(trackPart: .null)
        let noIdentifier = record(trackPart: .object(["fileName": .string("Song.m4a")]))
        #expect(laterCountIn.song?.track == nil)
        var library = Library()
        library.merge(songs: [laterCountIn, laterField, empty, noIdentifier], setlists: [])
        #expect(library.referencedFileIDs == [unknownCountIn, extraField])
    }

    @Test func aLibraryWithTracksEncodesAndDecodesUnchanged() throws {
        var library = Library()
        let song = library.addSong(name: "With", settings: settings(100), track: track(), now: t(0))!
        library.addSong(name: "Without", settings: settings(120), now: t(0))
        library.setTrack(song.id, to: track(firstBeat: 42), now: t(5))
        let decoded = try JSONDecoder().decode(Library.self, from: JSONEncoder().encode(library))
        #expect(decoded == library)
        #expect(decoded.song(id: song.id)?.track?.firstBeat == 42)
    }

    @Test func mixAndFirstBeatAreKeptInRange() {
        let high = BackingTrack(fileID: UUID(), fileName: "a", firstBeat: -5, mix: 3)
        #expect(high.mix == 1)
        #expect(high.firstBeat == 0)
        let low = BackingTrack(fileID: UUID(), fileName: "a", firstBeat: 250, mix: -2)
        #expect(low.mix == -1)
        #expect(low.firstBeat == 250)
        #expect(low.firstBeatSeconds == 2.5)
        #expect(low.countIn == .twoBars)
    }
}
