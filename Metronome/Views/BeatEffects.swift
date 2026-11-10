import SwiftUI

/// Rings that leave the dial on every beat: grow from 1.0× to 1.3× and fade over 600 ms.
struct RippleLayer: View {
    let lastBeat: BeatEvent?
    let diameter: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ripples: [BeatEvent] = []

    static let duration = 0.6

    var body: some View {
        ZStack {
            ForEach(ripples, id: \.id) { ripple in
                Ripple(isAccented: ripple.isAccented)
            }
        }
        .frame(width: diameter, height: diameter)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: lastBeat) { _, beat in
            guard let beat, !reduceMotion else { return }
            ripples.append(beat)
            Task {
                try? await Task.sleep(for: .seconds(Self.duration))
                ripples.removeAll { $0.id == beat.id }
            }
        }
    }
}

private struct Ripple: View {
    let isAccented: Bool
    @State private var hasLeft = false

    var body: some View {
        Circle()
            .strokeBorder(Theme.amber, lineWidth: isAccented ? 2 : 1)
            .scaleEffect(hasLeft ? 1.3 : 1.0)
            .opacity(hasLeft ? 0 : 0.6)
            .onAppear {
                withAnimation(.easeOut(duration: RippleLayer.duration)) { hasLeft = true }
            }
    }
}

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
