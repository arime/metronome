import SwiftUI

/// The amber glow behind the BPM number: flashes to 30 % on each beat and
/// decays over half the beat interval.
struct BeatGlow: View {
    let lastBeat: BeatEvent?
    let bpm: Int
    let diameter: CGFloat

    @State private var level = 0.0

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
        .opacity(level)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: lastBeat) { _, beat in
            guard beat != nil else { return }
            level = 1
            withAnimation(.easeOut(duration: BeatPulse.decay(bpm: bpm))) { level = 0 }
        }
    }
}

enum BeatPulse {
    /// Half the beat interval, in seconds.
    static func decay(bpm: Int) -> Double {
        30 / Double(max(bpm, 1))
    }
}
