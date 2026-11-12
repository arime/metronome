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

    @Test func tempoNameIsHiddenOnASmallDial() {
        #expect(DialGeometry.showsTempoName(dialDiameter: 300))
        #expect(DialGeometry.showsTempoName(dialDiameter: 180))
        #expect(!DialGeometry.showsTempoName(dialDiameter: 179))
        #expect(!DialGeometry.showsTempoName(dialDiameter: 108))
    }

    @Test func knobScalesWithTheDialButStaysGrabbable() {
        #expect(DialGeometry.knobDiameter(dialDiameter: 300) == 28)
        #expect(isClose(DialGeometry.knobDiameter(dialDiameter: 240), 22.4))
        #expect(isClose(DialGeometry.knobDiameter(dialDiameter: 150), 16.8))
        #expect(isClose(DialGeometry.knobDiameter(dialDiameter: 108), 16.8))
        #expect(DialGeometry.knobDiameter(dialDiameter: 400) == 28)
    }

    @Test func saveControlsFitTheGapOnTheDesignDialAndLarger() {
        #expect(DialGeometry.saveControlsWidth == 176)
        #expect(DialGeometry.fitsSaveControls(dialDiameter: 300))
        #expect(DialGeometry.fitsSaveControls(dialDiameter: 310))
        #expect(DialGeometry.fitsSaveControls(dialDiameter: 340))
    }

    @Test func saveControlsGoToTheHeaderOnASmallDial() {
        // The knob at either end of the arc would touch a round button.
        #expect(!DialGeometry.fitsSaveControls(dialDiameter: 280))
        #expect(!DialGeometry.fitsSaveControls(dialDiameter: 249))
        #expect(!DialGeometry.fitsSaveControls(dialDiameter: 200))
    }

    @Test func onlyTheRingBandStartsADrag() {
        #expect(DialGeometry.startsDrag(dx: 0, dy: -104, dialDiameter: 300) == false)
        #expect(DialGeometry.startsDrag(dx: 0, dy: -105, dialDiameter: 300) == true)
        #expect(DialGeometry.startsDrag(dx: 165, dy: 0, dialDiameter: 300) == true)
        #expect(DialGeometry.startsDrag(dx: 166, dy: 0, dialDiameter: 300) == false)
    }
}

struct DialDragTests {
    private func isClose(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-9 }

    @Test func aTouchThatDoesNotMoveChangesNothing() {
        var drag = DialDrag(startFraction: 0.4, dx: 120, dy: 0)
        #expect(isClose(drag.move(dx: 120, dy: 0), 0.4))
    }

    @Test func theDialTurnsByTheAngleTravelledWhereverTheDragBegan() {
        // From 3 o'clock a quarter turn clockwise to 6 o'clock: 90 of the arc's 270 degrees.
        var fromRight = DialDrag(startFraction: 0.2, dx: 120, dy: 0)
        #expect(isClose(fromRight.move(dx: 0, dy: 120), 0.2 + 90.0 / 270))
        // The same quarter turn begun at 9 o'clock gives the same change.
        var fromLeft = DialDrag(startFraction: 0.2, dx: -120, dy: 0)
        #expect(isClose(fromLeft.move(dx: 0, dy: -120), 0.2 + 90.0 / 270))
    }

    @Test func anticlockwiseSlowsDown() {
        var drag = DialDrag(startFraction: 0.5, dx: 0, dy: -120)
        #expect(isClose(drag.move(dx: -120, dy: 0), 0.5 - 90.0 / 270))
    }

    @Test func crossingSixOClockIsASmallStep() {
        var drag = DialDrag(startFraction: 0.5, dx: 10, dy: 120)
        let moved = drag.move(dx: -10, dy: 120)
        #expect(moved > 0.5)
        #expect(moved < 0.55)
    }

    @Test func itStopsAtTheEndsAndTurnsBackAtOnce() {
        var drag = DialDrag(startFraction: 0.9, dx: 0, dy: -120)
        #expect(drag.move(dx: 120, dy: 0) == 1)
        #expect(isClose(drag.move(dx: 0, dy: -120), 1 - 90.0 / 270))
    }
}

struct TempoEntryTests {
    private func entry(_ digits: Int...) -> TempoEntry {
        var entry = TempoEntry()
        digits.forEach { entry.append($0) }
        return entry
    }

    @Test func startsEmptyAndInvalid() {
        #expect(TempoEntry().value == nil)
        #expect(TempoEntry().isValid == false)
    }

    @Test func digitsBuildATempo() {
        #expect(entry(1, 7, 4).value == 174)
        #expect(entry(1, 7, 4).isValid)
    }

    @Test func noLeadingZeroAndNoFourthDigit() {
        #expect(entry(0, 9, 6).value == 96)
        #expect(entry(1, 2, 0, 5).value == 120)
    }

    @Test func onlyTemposInRangeAreValid() {
        #expect(entry(2, 9).isValid == false)
        #expect(entry(3, 0).isValid)
        #expect(entry(2, 5, 0).isValid)
        #expect(entry(2, 5, 1).isValid == false)
    }

    @Test func tooHighIsOnlyAboveTheRange() {
        #expect(entry(2, 5).isTooHigh == false)
        #expect(entry(2, 5, 1).isTooHigh)
    }

    @Test func deleteRemovesTheLastDigit() {
        var typed = entry(1, 7, 4)
        typed.deleteLast()
        #expect(typed.value == 17)
        typed.deleteLast()
        typed.deleteLast()
        typed.deleteLast()
        #expect(typed.value == nil)
    }
}
