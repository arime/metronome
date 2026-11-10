import Testing
@testable import Metronome

struct TempoTests {
    @Test func clampsToTheRange() {
        #expect(Tempo.clamp(10) == 30)
        #expect(Tempo.clamp(999) == 250)
        #expect(Tempo.clamp(120) == 120)
        #expect(Tempo.defaultBPM == 120)
    }

    @Test func namesFollowTheSpecTable() {
        let bpms = [30, 39, 40, 59, 60, 65, 66, 75, 76, 107, 108, 119, 120, 155, 156, 175, 176, 199, 200, 250]
        #expect(bpms.map(Tempo.name(for:)) == [
            "Grave", "Grave", "Largo", "Largo", "Larghetto", "Larghetto", "Adagio", "Adagio",
            "Andante", "Andante", "Moderato", "Moderato", "Allegro", "Allegro", "Vivace", "Vivace",
            "Presto", "Presto", "Prestissimo", "Prestissimo",
        ])
    }

    @Test func arcFractionIsLinearOverTheRange() {
        #expect(Tempo.arcFraction(for: 30) == 0)
        #expect(Tempo.arcFraction(for: 250) == 1)
        #expect(Tempo.bpm(forArcFraction: 0.5) == 140)
    }

    @Test func arcFractionOutsideTheArcClamps() {
        #expect(Tempo.bpm(forArcFraction: -1) == 30)
        #expect(Tempo.bpm(forArcFraction: 2) == 250)
    }

    @Test func everyBPMSurvivesARoundTripThroughTheArc() {
        #expect((30...250).allSatisfy { Tempo.bpm(forArcFraction: Tempo.arcFraction(for: $0)) == $0 })
    }
}

struct DialGeometryTests {
    private func isClose(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-9 }

    @Test func mapsTouchAngleToArcFraction() {
        #expect(isClose(DialGeometry.arcFraction(dx: 0, dy: -1), 0.5))
        #expect(isClose(DialGeometry.arcFraction(dx: -1, dy: 0), 1.0 / 6))
        #expect(isClose(DialGeometry.arcFraction(dx: 1, dy: 0), 5.0 / 6))
    }

    @Test func touchesInTheGapClampToTheNearerEnd() {
        #expect(DialGeometry.arcFraction(dx: -0.1, dy: 1) == 0)
        #expect(DialGeometry.arcFraction(dx: 0.1, dy: 1) == 1)
    }

    @Test func onlyTheRingBandStartsADrag() {
        #expect(DialGeometry.startsDrag(dx: 0, dy: -104, dialDiameter: 300) == false)
        #expect(DialGeometry.startsDrag(dx: 0, dy: -105, dialDiameter: 300) == true)
        #expect(DialGeometry.startsDrag(dx: 165, dy: 0, dialDiameter: 300) == true)
        #expect(DialGeometry.startsDrag(dx: 166, dy: 0, dialDiameter: 300) == false)
    }
}
