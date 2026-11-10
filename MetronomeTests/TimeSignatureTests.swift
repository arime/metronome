import Testing
@testable import Metronome

struct TimeSignatureTests {
    @Test func listsTheEightSignaturesInOrder() {
        #expect(TimeSignature.allCases.map(\.rawValue) == ["2/4", "3/4", "4/4", "5/4", "6/8", "7/8", "9/8", "12/8"])
    }

    @Test func beatsPerBarIsTheTopNumber() {
        #expect(TimeSignature.allCases.map(\.beatsPerBar) == [2, 3, 4, 5, 6, 7, 9, 12])
    }

    @Test func hintsMatchThePicker() {
        #expect(TimeSignature.allCases.map(\.hint) == ["March", "Waltz", "Common", "Odd", "Compound", "Odd", "Compound", "Compound"])
    }
}
