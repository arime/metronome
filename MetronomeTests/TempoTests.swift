import Testing
@testable import Metronome

struct TempoTests {
    @Test func clampsToTheRange() {
        #expect(Tempo.clamp(10) == 30)
        #expect(Tempo.clamp(999) == 300)
        #expect(Tempo.clamp(120) == 120)
        #expect(Tempo.defaultBPM == 120)
    }

    @Test func namesFollowTheSpecTable() {
        let bpms = [30, 39, 40, 59, 60, 65, 66, 75, 76, 107, 108, 119, 120, 155, 156, 175, 176, 199, 200, 300]
        #expect(bpms.map(Tempo.name(for:)) == [
            "Grave", "Grave", "Largo", "Largo", "Larghetto", "Larghetto", "Adagio", "Adagio",
            "Andante", "Andante", "Moderato", "Moderato", "Allegro", "Allegro", "Vivace", "Vivace",
            "Presto", "Presto", "Prestissimo", "Prestissimo",
        ])
    }

    @Test func arcFractionIsLinearOverTheRange() {
        #expect(Tempo.arcFraction(for: 30) == 0)
        #expect(Tempo.arcFraction(for: 300) == 1)
        #expect(Tempo.bpm(forArcFraction: 0.5) == 165)
    }

    @Test func arcFractionOutsideTheArcClamps() {
        #expect(Tempo.bpm(forArcFraction: -1) == 30)
        #expect(Tempo.bpm(forArcFraction: 2) == 300)
    }

    @Test func everyBPMSurvivesARoundTripThroughTheArc() {
        #expect((30...300).allSatisfy { Tempo.bpm(forArcFraction: Tempo.arcFraction(for: $0)) == $0 })
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

    @Test func aTurnCanStartAnywhereOnTheDial() {
        #expect(DialGeometry.startsDrag(dx: 0, dy: 0, dialDiameter: 300) == true)
        #expect(DialGeometry.startsDrag(dx: 0, dy: -60, dialDiameter: 300) == true)
        #expect(DialGeometry.startsDrag(dx: 165, dy: 0, dialDiameter: 300) == true)
        #expect(DialGeometry.startsDrag(dx: 166, dy: 0, dialDiameter: 300) == false)
    }

    @Test func theDeadZoneScalesWithTheDial() {
        #expect(isClose(DialGeometry.deadZoneRadius(dialDiameter: 300), 30))
        #expect(isClose(DialGeometry.deadZoneRadius(dialDiameter: 150), 15))
    }
}

struct DialDragTests {
    private func isClose(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-9 }

    private func drag(_ startFraction: Double, _ dx: Double, _ dy: Double) -> DialDrag {
        DialDrag(startFraction: startFraction, dx: dx, dy: dy, dialDiameter: 300)
    }

    @Test func aTouchThatDoesNotMoveChangesNothing() {
        var turn = drag(0.4, 120, 0)
        #expect(isClose(turn.move(dx: 120, dy: 0), 0.4))
    }

    @Test func theDialTurnsByTheAngleTravelledWhereverTheDragBegan() {
        // From 3 o'clock a quarter turn clockwise to 6 o'clock: 90 of the arc's 270 degrees.
        var fromRight = drag(0.2, 120, 0)
        #expect(isClose(fromRight.move(dx: 0, dy: 120), 0.2 + 90.0 / 270))
        // The same quarter turn begun at 9 o'clock gives the same change.
        var fromLeft = drag(0.2, -120, 0)
        #expect(isClose(fromLeft.move(dx: 0, dy: -120), 0.2 + 90.0 / 270))
    }

    @Test func aTurnCloseToTheCentreCountsTheSameAngle() {
        // On the number, 40 pt out: the same quarter turn gives the same change.
        var turn = drag(0.2, 40, 0)
        #expect(isClose(turn.move(dx: 0, dy: 40), 0.2 + 90.0 / 270))
    }

    @Test func anticlockwiseSlowsDown() {
        var turn = drag(0.5, 0, -120)
        #expect(isClose(turn.move(dx: -120, dy: 0), 0.5 - 90.0 / 270))
    }

    @Test func crossingSixOClockIsASmallStep() {
        var turn = drag(0.5, 10, 120)
        let moved = turn.move(dx: -10, dy: 120)
        #expect(moved > 0.5)
        #expect(moved < 0.55)
    }

    @Test func itStopsAtTheEndsAndTurnsBackAtOnce() {
        var turn = drag(0.9, 0, -120)
        #expect(turn.move(dx: 120, dy: 0) == 1)
        #expect(isClose(turn.move(dx: 0, dy: -120), 1 - 90.0 / 270))
    }

    @Test func theDeadZoneChangesNothing() {
        // Through the centre from 12 o'clock to 6 o'clock would be half a turn by angle.
        var turn = drag(0.5, 0, -40)
        #expect(isClose(turn.move(dx: 0, dy: -10), 0.5))
        #expect(isClose(turn.move(dx: 0, dy: 10), 0.5))
        #expect(isClose(turn.move(dx: 0, dy: 40), 0.5))
    }

    @Test func leavingTheDeadZoneCarriesOnWithoutAJump() {
        var turn = drag(0.5, 0, -40)
        turn.move(dx: 0, dy: 0)
        // Out at 3 o'clock: the first point outside only sets the angle.
        #expect(isClose(turn.move(dx: 40, dy: 0), 0.5))
        // Then a quarter turn clockwise counts as usual.
        #expect(isClose(turn.move(dx: 0, dy: 40), 0.5 + 90.0 / 270))
    }

    @Test func aTurnThatStartsInTheDeadZoneBeginsWhenItLeaves() {
        var turn = drag(0.5, 5, 0)
        #expect(isClose(turn.move(dx: 40, dy: 0), 0.5))
        #expect(isClose(turn.move(dx: 0, dy: 40), 0.5 + 90.0 / 270))
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
        #expect(entry(2, 5, 1).isValid)
        #expect(entry(3, 0, 0).isValid)
        #expect(entry(3, 0, 1).isValid == false)
    }

    @Test func tooHighIsOnlyAboveTheRange() {
        #expect(entry(3, 0).isTooHigh == false)
        #expect(entry(3, 0, 0).isTooHigh == false)
        #expect(entry(3, 0, 1).isTooHigh)
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
