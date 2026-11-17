import SwiftUI

/// The amber glow behind the BPM number: flashes to 30 % on each beat and
/// decays over half the beat interval.
struct BeatGlow: View {
    let lastBeat: BeatEvent?
    let bpm: Int
    let diameter: CGFloat

    var body: some View {
        RadialGradient(
            stops: [
                .init(color: Theme.amber.opacity(0.30), location: 0),
                .init(color: Theme.amber.opacity(0.10), location: 0.38),
                .init(color: Theme.amber.opacity(0), location: 0.66),
            ],
            center: .center,
            startRadius: 0,
            endRadius: diameter / 2
        )
        .frame(width: diameter, height: diameter)
        // Keyframes replayed on every beat: jump to full, then decay. Setting a value and
        // animating it back in one update could be merged away before it was drawn.
        .keyframeAnimator(initialValue: 0.0, trigger: lastBeat?.id) { view, level in
            view.opacity(level)
        } keyframes: { _ in
            MoveKeyframe(1.0)
            CubicKeyframe(0.0, duration: BeatPulse.decay(bpm: bpm))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The number pulse: the BPM number scales 1.0 → 1.04 and back within half the beat interval on
/// every beat. With Reduce Motion on, the trigger never changes, so the number stays still.
struct NumberPulse: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let lastBeat: BeatEvent?
    let bpm: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(
            initialValue: 1.0,
            trigger: reduceMotion ? nil : lastBeat?.id
        ) { view, scale in
            view.scaleEffect(scale)
        } keyframes: { _ in
            MoveKeyframe(1.04)
            CubicKeyframe(1.0, duration: BeatPulse.decay(bpm: bpm))
        }
    }
}

enum BeatPulse {
    /// Half the beat interval, in seconds.
    static func decay(bpm: Int) -> Double {
        30 / Double(max(bpm, 1))
    }
}
