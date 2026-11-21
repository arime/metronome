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
        BackingTrack(fileID: UUID(), fileName: "Song.m4a", offset: offset)
    }

    @Test func aSongWithoutATrackPartHasNoTrack() {
        let record = record()
        #expect(record.song?.track == nil)
        #expect(record.parts[SongRecord.trackKey] == nil)
    }

    @Test func settingATrackRoundTrips() {
        var record = record()
        let track = BackingTrack(fileID: UUID(), fileName: "Song.m4a", offset: 237, countIn: .oneBar, mix: -0.4)
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
        let high = BackingTrack(fileID: UUID(), fileName: "a", offset: -5, mix: 3)
        #expect(high.mix == 1)
        #expect(high.offset == 0)
        let low = BackingTrack(fileID: UUID(), fileName: "a", offset: 250, mix: -2)
        #expect(low.mix == -1)
        #expect(low.offset == 250)
        #expect(low.offsetSeconds == 2.5)
        #expect(low.countIn == .twoBars)
    }

    @Test func theTrackPartKeepsItsStoredKeyNames() throws {
        let value = try JSONValue(encoding: BackingTrack(fileID: UUID(), fileName: "a", offset: 48))
        guard case .object(let fields) = value else { Issue.record("not an object"); return }
        #expect(fields["firstBeat"] == .number(48))
        #expect(fields["bpm"] == nil)
        #expect(fields["offset"] == nil)
    }

    // MARK: - A track part without a tempo

    /// A song at 96 BPM whose track part, set at t(1), was written by a build that wrote no tempo into it.
    private func recordWithoutTrackTempo(_ fileID: UUID = UUID()) -> SongRecord {
        var record = SongRecord(id: UUID(), name: "Song", settings: settings(96), created: t(1), now: t(1))
        record.parts[SongRecord.trackKey] = Part(time: t(1), value: .object([
            "fileID": .string(fileID.uuidString), "fileName": .string("Song.m4a"),
            "firstBeat": .number(48), "countIn": .number(2), "mix": .number(0),
        ]))
        return record
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

    @Test func mergingLeavesATrackPartWithoutATempoAlone() throws {
        let record = recordWithoutTrackTempo()
        // Another copy whose tempo changed while its track part stayed as it was.
        var other = record
        other.parts[SongRecord.tempoKey] = Part(time: t(5), value: .number(100))
        let merged = record.merged(with: other)
        var expected = record
        expected.parts[SongRecord.tempoKey] = other.parts[SongRecord.tempoKey]
        #expect(merged == expected)
        guard case .object(let fields)? = merged.parts[SongRecord.trackKey]?.value else {
            Issue.record("not an object"); return
        }
        #expect(fields["bpm"] == nil)
        #expect(merged.merged(with: other) == merged)
    }

    // MARK: - The song's tempo in the track part

    private func trackFields(_ record: SongRecord?) -> [String: JSONValue]? {
        guard case .object(let fields)? = record?.parts[SongRecord.trackKey]?.value else { return nil }
        return fields
    }

    /// A song at 100 BPM whose track part, set at t(5), holds the song's tempo.
    private func recordWithTrack(_ track: BackingTrack) -> SongRecord {
        var record = record()
        record.setTrack(track, now: t(5))
        return record
    }

    @Test func theTrackPartHoldsTheSongsTempo() throws {
        var library = Library()
        let added = library.addSong(name: "Song", settings: settings(100), track: track(), now: t(0))
        let record = library.songRecords[try #require(added).id]
        #expect(trackFields(record)?[SongRecord.trackTempoKey] == .number(100))
        #expect(record?.parts[SongRecord.tempoKey]?.value == .number(100))
    }

    @Test func aTempoSetHereIsWrittenIntoBothParts() {
        let track = track()
        var record = recordWithTrack(track)
        record.setSettings(settings(110), now: t(10))
        #expect(record.parts[SongRecord.tempoKey] == Part(time: t(10), value: .number(110)))
        #expect(record.parts[SongRecord.trackKey]?.time == t(10))
        #expect(trackFields(record)?[SongRecord.trackTempoKey] == .number(110))
        #expect(record.parts[SongRecord.meterKey]?.time == t(0))
        #expect(record.song?.settings.bpm == 110)
        #expect(record.song?.track == track)
    }

    @Test func aTempoLeftAloneStampsNeitherPart() {
        var record = recordWithTrack(track())
        record.setSettings(MetronomeSettings(bpm: 100, timeSignature: .fourFour, accents: [1, 3]), now: t(10))
        #expect(record.parts[SongRecord.tempoKey]?.time == t(0))
        #expect(record.parts[SongRecord.trackKey]?.time == t(5))
        #expect(record.parts[SongRecord.meterKey]?.time == t(10))
    }

    @Test func aTrackPartsTempoIsTheSongsTempo() {
        let record = record(trackPart: trackPart(UUID(), ["bpm": .number(168)]))
        let parts = record.parts
        #expect(record.song?.settings.bpm == 168)
        #expect(record.song?.track?.offset == 48)
        #expect(record.parts == parts)
    }

    @Test func savingTheReadTempoOverwritesTheTempoPart() {
        var record = record(trackPart: trackPart(UUID(), ["bpm": .number(168)]))
        record.setSettings(settings(168), now: t(10))
        #expect(record.parts[SongRecord.tempoKey] == Part(time: t(10), value: .number(168)))
        #expect(record.parts[SongRecord.trackKey]?.time == t(5))
    }

    @Test func aTrackPartWithoutATempoLeavesTheTempoToTheTempoPart() {
        var record = recordWithoutTrackTempo()
        let part = record.parts[SongRecord.trackKey]
        #expect(record.song?.settings.bpm == 96)
        record.setSettings(settings(100), now: t(5))
        #expect(record.song?.settings.bpm == 100)
        #expect(record.parts[SongRecord.trackKey] == part)
        #expect(record.parts[SongRecord.trackKey]?.time == t(1))
        #expect(trackFields(record)?[SongRecord.trackTempoKey] == nil)
    }

    @Test func anUnreadableTrackPartsTempoIsNotUsed() {
        let record = record(trackPart: trackPart(UUID(), ["countIn": .number(4), "bpm": .number(168)]))
        #expect(record.song?.track == nil)
        #expect(record.song?.settings.bpm == 100)
    }

    @Test func theTrackPartsTempoIsKeptInRange() {
        for (stored, read) in [(10, 30), (400, 300)] {
            let record = record(trackPart: trackPart(UUID(), ["bpm": .number(Double(stored))]))
            #expect(record.song?.settings.bpm == read)
        }
    }

    @Test func theNewerTrackPartBringsItsTempo() {
        let track = track()
        let base = recordWithTrack(track)
        var a = base
        a.setSettings(settings(110), now: t(10))
        var b = base
        var nudged = track
        nudged.offset += 1
        b.setTrack(nudged, now: t(20))
        #expect(a.merged(with: b).song?.settings.bpm == 100)
        #expect(a.merged(with: b) == b.merged(with: a))
    }

    // MARK: - The encoded record, as builds with a tempo for the track read and write it

    /// What a build with a tempo for the track apart from the song's decodes: the tempo part as a
    /// whole number, and a track part whose tempo is required, as its track type required it.
    private struct TwoTempoBuildSong: Decodable {
        struct TempoPart: Decodable { let value: Int }
        struct TrackPart: Decodable { let value: Track }
        struct Track: Decodable {
            let fileID: UUID, fileName: String, firstBeat: Int, bpm: Int, countIn: Int, mix: Double
        }
        struct Parts: Decodable { let tempo: TempoPart, track: TrackPart }
        let parts: Parts
    }

    @Test func aBuildWithTwoTemposFindsTheSongsTempoInBothParts() throws {
        let track = track()
        var record = recordWithTrack(track)
        record.setSettings(settings(110), now: t(10))
        let read = try JSONDecoder().decode(TwoTempoBuildSong.self, from: JSONEncoder().encode(record))
        #expect(read.parts.tempo.value == 110)
        #expect(read.parts.track.value.bpm == 110)
        #expect(read.parts.track.value.fileID == track.fileID)
        #expect(read.parts.track.value.firstBeat == 150)
    }

    @Test func aRecordWithTwoTemposReadsAtTheTracksTempoAndIsWrittenBackUnchanged() throws {
        let fileID = UUID()
        let json = """
            {"created":0,"id":"\(UUID().uuidString)","parts":{\
            "meter":{"time":0,"value":{"accents":[1],"signature":"4/4"}},\
            "name":{"time":0,"value":"Song"},\
            "tempo":{"time":0,"value":120},\
            "track":{"time":1,"value":{"bpm":168,"countIn":2,"fileID":"\(fileID.uuidString)",\
            "fileName":"Song.m4a","firstBeat":48,"mix":0}}}}
            """
        let record = try JSONDecoder().decode(SongRecord.self, from: Data(json.utf8))
        #expect(record.song?.settings.bpm == 168)
        #expect(record.song?.track?.fileID == fileID)
        #expect(record.song?.track?.offset == 48)
        let written = try JSONSerialization.jsonObject(with: JSONEncoder().encode(record)) as? NSDictionary
        let original = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? NSDictionary
        #expect(written != nil)
        #expect(written == original)
    }
}
