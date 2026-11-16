import SwiftUI

/// Turns backing tracks on or off for the whole app. Shown in the header only for a song with a
/// backing track. Never amber, so the Save button stays the header's only amber thing.
/// Works only while stopped; while playing it is dimmed and takes no touches.
struct TrackSwitchButton: View {
    @Environment(MetronomeModel.self) private var model

    /// The fill while on; off has the mute button's surface fill.
    private static let onFill = Color(hex: 0x3A3A40)

    var body: some View {
        let isOn = model.backingTracksOn
        let isPlaying = model.isPlaying
        Button {
            model.toggleBackingTracks()
        } label: {
            Image(systemName: "music.note")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Theme.dialWhite)
                .frame(width: 40, height: 40)
                .background(isOn ? Self.onFill : Theme.surface, in: Circle())
                // Drawn at 40 pt; the touch area reaches 2 pt further for a 44 pt target.
                .contentShape(Circle().inset(by: -2))
        }
        .buttonStyle(.plain)
        .opacity(isPlaying ? 0.4 : 1)
        .allowsHitTesting(!isPlaying)
        .disabled(isPlaying)
        .accessibilityLabel("Backing tracks")
        .accessibilityValue(isOn ? "on" : "off")
    }
}
