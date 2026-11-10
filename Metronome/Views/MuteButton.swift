import SwiftUI

/// Silences the click while the metronome keeps running. Amber while muted.
struct MuteButton: View {
    @Environment(MetronomeModel.self) private var model

    var body: some View {
        let isMuted = model.isMuted
        Button {
            model.toggleMute()
        } label: {
            Image(systemName: isMuted ? "speaker.slash" : "speaker.wave.2")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isMuted ? Theme.amber : Theme.dialWhite)
                .frame(width: 40, height: 40)
                .background(isMuted ? Theme.amberTint : Theme.surface, in: Circle())
                .overlay(Circle().strokeBorder(Theme.amber, lineWidth: 1.5).opacity(isMuted ? 1 : 0))
                // Drawn at 40 pt; the touch area reaches 2 pt further for a 44 pt target.
                .contentShape(Circle().inset(by: -2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Click sound")
        .accessibilityValue(isMuted ? "muted" : "on")
        .accessibilityHint("Silences the click while the metronome keeps running")
    }
}
