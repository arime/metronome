import UIKit

@MainActor
protocol HapticsPlaying {
    /// One tap per beat, stronger on accented beats.
    func beat(accented: Bool)
    /// A tick for each tempo step, tap-tempo tap and accent toggle.
    func selection()
    /// Start and Stop.
    func transport()
}

@MainActor
final class Haptics: HapticsPlaying {
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let selectionGenerator = UISelectionFeedbackGenerator()

    func beat(accented: Bool) {
        if accented {
            rigid.impactOccurred(intensity: 1.0)
            rigid.prepare()
        } else {
            light.impactOccurred(intensity: 0.5)
            light.prepare()
        }
    }

    func selection() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    func transport() {
        medium.impactOccurred()
        light.prepare()
        rigid.prepare()
    }
}
