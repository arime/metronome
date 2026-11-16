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

    private func track(offset: Int = 150) -> BackingTrack {
        BackingTrack(fileID: UUID(), fileName: "Song.m4a", offset: offset, bpm: 120)
    }

    @Test func aSongWithoutATrackPartHasNoTrack() {
        let record = record()
        #expect(record.song?.track == nil)
        #expect(record.parts[SongRecord.trackKey] == nil)
    }

    @Test func settingATrackRoundTrips() {
        var record = record()
        let track = BackingTrack(fileID: UUID(), fileName: "Song.m4a", offset: 237, bpm: 120, countIn: .oneBar, mix: -0.4)
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

    @Test func aNudgedOffsetRestampsOnlyTheTrackPart() {
        var record = record()
        var track = track()
        record.setTrack(track, now: t(5))
        track.offset += 1
        record.setTrack(track, now: t(10))
        #expect(record.parts[SongRecord.trackKey]?.time == t(10))
        #expect(record.parts[SongRecord.nameKey]?.time == t(0))
        #expect(record.parts[SongRecord.tempoKey]?.time == t(0))
        #expect(record.parts[SongRecord.meterKey]?.time == t(0))
        #expect(record.song?.track?.offset == 151)
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
        var nudged = track; nudged.offset = 200
        var b = base; b.setTrack(nudged, now: t(10))
        var older = track; older.offset = 120
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
        var a = base; var nudged = track; nudged.offset = 300; a.setTrack(nudged, now: t(10))
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
        library.setTrack(song.id, to: track(offset: 42), now: t(5))
        let decoded = try JSONDecoder().decode(Library.self, from: JSONEncoder().encode(library))
        #expect(decoded == library)
        #expect(decoded.song(id: song.id)?.track?.offset == 42)
    }

    @Test func mixAndOffsetAreKeptInRange() {
        let high = BackingTrack(fileID: UUID(), fileName: "a", offset: -5, bpm: 120, mix: 3)
        #expect(high.mix == 1)
        #expect(high.offset == 0)
        let low = BackingTrack(fileID: UUID(), fileName: "a", offset: 250, bpm: 120, mix: -2)
        #expect(low.mix == -1)
        #expect(low.offset == 250)
        #expect(low.offsetSeconds == 2.5)
        #expect(low.countIn == .twoBars)
    }

    @Test func theTrackPartKeepsItsStoredKeyNames() throws {
        let value = try JSONValue(encoding: BackingTrack(fileID: UUID(), fileName: "a", offset: 48, bpm: 120))
        guard case .object(let fields) = value else { Issue.record("not an object"); return }
        #expect(fields["firstBeat"] == .number(48))
        #expect(fields["bpm"] == .number(120))
        #expect(fields["offset"] == nil)
    }

    // MARK: - The track's tempo

    /// A song at 96 BPM whose track part, set at t(1), was written by a build without the track's tempo.
    private func recordWithoutTrackTempo(_ fileID: UUID = UUID()) -> SongRecord {
        var record = SongRecord(id: UUID(), name: "Song", settings: settings(96), created: t(1), now: t(1))
        record.parts[SongRecord.trackKey] = Part(time: t(1), value: .object([
            "fileID": .string(fileID.uuidString), "fileName": .string("Song.m4a"),
            "firstBeat": .number(48), "countIn": .number(2), "mix": .number(0),
        ]))
        return record
    }

    @Test func aTrackStoredWithoutATempoTakesTheSongsTempo() {
        let record = recordWithoutTrackTempo()
        #expect(record.song?.track?.bpm == 96)
        #expect(record.song?.track?.offset == 48)
    }

    @Test func fillingInTheTempoStampsNothing() throws {
        var record = recordWithoutTrackTempo()
        let part = record.parts[SongRecord.trackKey]
        record.setTrack(try #require(record.song?.track), now: t(5))
        #expect(record.parts[SongRecord.trackKey] == part)
    }

    @Test func theNextTrackChangeWritesTheTempoIn() throws {
        var record = recordWithoutTrackTempo()
        var track = try #require(record.song?.track)
        track.offset += 1
        record.setTrack(track, now: t(5))
        let part = try #require(record.parts[SongRecord.trackKey])
        #expect(part.time == t(5))
        guard case .object(let fields) = part.value else { Issue.record("not an object"); return }
        #expect(fields["bpm"] == .number(96))
    }

    @Test func aSongTempoSetHereLeavesTheTrackTempo() throws {
        let record = recordWithoutTrackTempo()
        var library = Library()
        library.merge(songs: [record], setlists: [])
        library.updateSong(record.id, settings: settings(100), now: t(5))
        #expect(library.song(id: record.id)?.settings.bpm == 100)
        #expect(library.song(id: record.id)?.track?.bpm == 96)
        #expect(library.songRecords[record.id]?.parts[SongRecord.trackKey]?.time == t(1))
    }

    @Test func aSongTempoFromAnotherDeviceLeavesTheTrackTempo() throws {
        let record = recordWithoutTrackTempo()
        // The other device's copy, as an earlier build changes the tempo: the track part untouched.
        var other = record
        other.parts[SongRecord.tempoKey] = Part(time: t(5), value: .number(100))
        var library = Library()
        library.merge(songs: [record], setlists: [])
        library.merge(songs: [other], setlists: [])
        let merged = try #require(library.songRecords[record.id])
        #expect(merged.song?.settings.bpm == 100)
        #expect(merged.song?.track?.bpm == 96)
        #expect(merged.parts[SongRecord.trackKey]?.time == t(1))
        #expect(merged == other.merged(with: record))
    }

    @Test func aSongTempoSetHereThenSyncedKeepsTheTrackTempoOnBothDevices() throws {
        let record = recordWithoutTrackTempo()
        var here = record
        here.setSettings(settings(100), now: t(5))
        let there = record.merged(with: here)
        #expect(there.song?.track?.bpm == 96)
        #expect(here.merged(with: record).song?.track?.bpm == 96)
        #expect(there == here.merged(with: record))
    }

    @Test func theTrackTempoIsKeptInRange() throws {
        #expect(BackingTrack(fileID: UUID(), fileName: "a", offset: 0, bpm: 10).bpm == 30)
        #expect(BackingTrack(fileID: UUID(), fileName: "a", offset: 0, bpm: 400).bpm == 300)
        for (stored, read) in [(10, 30), (400, 300)] {
            var record = record()
            record.parts[SongRecord.trackKey] = Part(time: t(5), value: trackPart(UUID(), ["bpm": .number(Double(stored))]))
            #expect(record.song?.track?.bpm == read)
        }
    }
}
