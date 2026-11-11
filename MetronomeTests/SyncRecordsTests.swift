import Foundation
import Testing
@testable import Metronome

struct SyncRecordsTests {
    private let t0 = Date(timeIntervalSince1970: 2_000_000_000)

    private func t(_ n: Double) -> Date {
        t0 + n
    }

    private func settings(_ bpm: Int) -> MetronomeSettings {
        MetronomeSettings(bpm: bpm, timeSignature: .fourFour, accents: [1])
    }

    @Test func stampIsAlwaysLaterThanWhatItReplaces() {
        #expect(SyncClock.stamp(t(5), after: t(1)) == t(5))
        #expect(SyncClock.stamp(t(1), after: t(5)) == t(5).addingTimeInterval(0.001))
        #expect(SyncClock.stamp(t(1), after: nil) == t(1))
    }

    @Test func renameOnOneDeviceAndTempoOnAnotherAreBothKept() {
        let base = PresetRecord(id: UUID(), name: "Song", settings: settings(100), created: t(0), now: t(0))
        var a = base; a.setName("Renamed", now: t(10))
        var b = base; b.setSettings(settings(140), now: t(20))
        let merged = a.merged(with: b)
        #expect(merged.preset?.name == "Renamed")
        #expect(merged.preset?.settings.bpm == 140)
        #expect(merged == b.merged(with: a))
    }

    @Test func savingOnlyATempoChangeLeavesTheOtherTimesAlone() {
        var record = PresetRecord(id: UUID(), name: "Song", settings: settings(100), created: t(0), now: t(0))
        record.setSettings(settings(120), now: t(9))
        #expect(record.parts[PresetRecord.tempoKey]?.time == t(9))
        #expect(record.parts[PresetRecord.meterKey]?.time == t(0))
        #expect(record.parts[PresetRecord.nameKey]?.time == t(0))
    }

    @Test func signatureAndAccentsTravelTogether() {
        let base = PresetRecord(id: UUID(), name: "Song", settings: settings(100), created: t(0), now: t(0))
        var a = base; a.setSettings(MetronomeSettings(bpm: 100, timeSignature: .threeFour, accents: [1]), now: t(10))
        var b = base; b.setSettings(MetronomeSettings(bpm: 100, timeSignature: .fourFour, accents: [1, 3]), now: t(20))
        #expect(a.merged(with: b).preset?.settings == b.preset?.settings)
    }

    @Test func anEditAfterADeletionBringsThePresetBack() {
        let base = PresetRecord(id: UUID(), name: "Song", settings: settings(100), created: t(0), now: t(0))
        var a = base; a.delete(now: t(10))
        var b = base; b.setSettings(settings(150), now: t(20))
        let merged = a.merged(with: b)
        #expect(merged.deleted == nil)
        #expect(merged.preset?.settings.bpm == 150)
        #expect(merged.preset?.name == "Song")
    }

    @Test func aDeletionAfterAnEditStays() {
        let base = PresetRecord(id: UUID(), name: "Song", settings: settings(100), created: t(0), now: t(0))
        var a = base; a.setSettings(settings(150), now: t(10))
        var b = base; b.delete(now: t(20))
        #expect(a.merged(with: b).preset == nil)
        #expect(a.merged(with: b).deleted == t(20))
    }

    @Test func anUnknownPartSurvivesCombiningAndEncoding() throws {
        var a = PresetRecord(id: UUID(), name: "Song", settings: settings(100), created: t(0), now: t(0))
        a.parts["note"] = Part(time: t(5), value: .string("capo 2"))
        var b = a; b.setName("Other", now: t(9))
        let merged = b.merged(with: a)
        let again = try JSONDecoder().decode(PresetRecord.self, from: JSONEncoder().encode(merged))
        #expect(again.parts["note"]?.value == .string("capo 2"))
        #expect(again.preset?.name == "Other")
    }

    @Test func addingOnOneDeviceAndReorderingOnAnotherKeepsBoth() {
        let p = [UUID(), UUID(), UUID()]; let new = UUID()
        let base = SetlistRecord(id: UUID(), name: "Gig", presetIDs: p, now: t(0))
        var a = base; a.reorder(to: [p[2], p[0], p[1]], now: t(10))
        var b = base; b.add(new, now: t(20))
        let merged = a.merged(with: b)
        #expect(merged.presetIDs(alive: Set(p + [new])) == [p[2], p[0], p[1], new])
    }

    @Test func aPresetRemovedAndAddedAgainGoesToTheEnd() {
        let p = [UUID(), UUID(), UUID()]
        var record = SetlistRecord(id: UUID(), name: "Gig", presetIDs: p, now: t(0))
        record.remove(p[1], now: t(10))
        record.add(p[1], now: t(20))
        #expect(record.presetIDs(alive: Set(p)) == [p[0], p[2], p[1]])
    }

    @Test func aReorderAfterAnAddPlacesTheAddedPreset() {
        let p = [UUID(), UUID(), UUID()]
        var record = SetlistRecord(id: UUID(), name: "Gig", presetIDs: p, now: t(0))
        record.remove(p[1], now: t(10))
        record.add(p[1], now: t(20))
        record.reorder(to: [p[1], p[0], p[2]], now: t(15))
        #expect(record.presetIDs(alive: Set(p)) == [p[1], p[0], p[2]])
        // The same order as the stored one still counts as a reorder.
        record.remove(p[0], now: t(30))
        record.add(p[0], now: t(40))
        record.reorder(to: [p[1], p[0], p[2]], now: t(41))
        #expect(record.presetIDs(alive: Set(p)) == [p[1], p[0], p[2]])
    }

    @Test func membershipIsDecidedPerPresetAndHiddenForMissingPresets() {
        let p = [UUID(), UUID()]
        let base = SetlistRecord(id: UUID(), name: "Gig", presetIDs: p, now: t(0))
        var a = base; a.remove(p[0], now: t(10))
        var b = base; b.setName("Tour", now: t(5))
        let merged = a.merged(with: b)
        #expect(merged.name == "Tour")
        #expect(merged.presetIDs(alive: Set(p)) == [p[1]])
        #expect(base.presetIDs(alive: [p[0]]) == [p[0]])
    }

    @Test func lastUsedDoesNotBringADeletedSetlistBack() {
        let base = SetlistRecord(id: UUID(), name: "Gig", presetIDs: [], now: t(0))
        var a = base; a.delete(now: t(10))
        var b = base; b.touch(now: t(20))
        #expect(a.merged(with: b).deleted == t(10))
    }

    @Test func combiningGivesTheSameResultInAnyOrder() {
        let base = PresetRecord(id: UUID(), name: "Song", settings: settings(100), created: t(0), now: t(0))
        var a = base; a.setName("A", now: t(7))
        var b = base; b.setName("B", now: t(7))
        var c = base; c.delete(now: t(3))
        let one = a.merged(with: b).merged(with: c)
        let two = c.merged(with: a.merged(with: b)).merged(with: b)
        #expect(one == two)
        #expect(one.merged(with: one) == one)
    }

    @Test func combiningThreePresetCopiesIsAssociativeAroundADeletion() {
        let id = UUID()
        var x = PresetRecord(id: id, name: "Song", settings: settings(100), created: t(0), now: t(0))
        x.parts = [:]
        x.deleted = t(10)
        var y = PresetRecord(id: id, name: "Y", settings: settings(100), created: t(0), now: t(0))
        y.parts = [PresetRecord.nameKey: Part(time: t(8), value: .string("Y"))]
        var z = PresetRecord(id: id, name: "Z", settings: settings(100), created: t(0), now: t(0))
        z.parts[PresetRecord.nameKey] = Part(time: t(5), value: .string("Z"))
        z.parts[PresetRecord.tempoKey] = Part(time: t(12), value: .number(130))
        let left = x.merged(with: y).merged(with: z)
        let right = x.merged(with: y.merged(with: z))
        #expect(left == right)
        #expect(left.deleted == nil)
        #expect(left.parts[PresetRecord.nameKey]?.value == .string("Y"))
    }

    @Test func combiningThreeSetlistCopiesIsAssociativeAroundADeletion() {
        let p = [UUID(), UUID()]
        let base = SetlistRecord(id: UUID(), name: "Gig", presetIDs: p, now: t(0))
        var x = base; x.delete(now: t(10))
        var y = base; y.remove(p[0], now: t(8))
        var z = base; z.remove(p[1], now: t(5)); z.add(UUID(), now: t(12))
        let left = x.merged(with: y).merged(with: z)
        let right = x.merged(with: y.merged(with: z))
        #expect(left == right)
        #expect(left.deleted == nil)
        #expect(left.members[p[0].uuidString]?.isIn == false)
    }

    @Test func aDeletedRecordKeepsItsParts() {
        var record = PresetRecord(id: UUID(), name: "Song", settings: settings(100), created: t(0), now: t(0))
        record.delete(now: t(10))
        #expect(!record.parts.isEmpty)
        #expect(record.preset == nil)
    }

    @Test func anEditOnADeletedRecordBringsItBack() {
        var record = PresetRecord(id: UUID(), name: "Song", settings: settings(100), created: t(0), now: t(0))
        record.delete(now: t(10))
        record.setName("Back", now: t(20))
        #expect(record.deleted == nil)
        #expect(record.preset?.name == "Back")
    }
}
