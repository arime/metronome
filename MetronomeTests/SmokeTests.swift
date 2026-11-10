import Foundation
import Testing

@Test func testsRunInsideTheApp() {
    #expect(Bundle.main.bundleIdentifier == "me.arime.metronome")
}
