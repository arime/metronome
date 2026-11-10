import Foundation
import Testing

/// The tests are hosted by the app, so `@testable import Metronome` sees the real target.
/// Checked by bundle name, not identifier, so changing the identifier does not break it.
@Test func testsRunInsideTheApp() {
    #expect(Bundle.main.bundleURL.lastPathComponent == "Metronome.app")
}
