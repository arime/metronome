import SwiftUI

struct StartStopButton: View {
    @Environment(MetronomeModel.self) private var model

    var body: some View {
        let isPlaying = model.isPlaying
        Button {
            model.togglePlayback()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 17, weight: .bold))
                Text(isPlaying ? "Stop" : "Start")
                    .font(.system(size: 18, weight: .bold))
                    .tracking(-0.18)
            }
            .foregroundStyle(isPlaying ? Theme.amber : Theme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 68)
            .background(isPlaying ? Theme.surface : Theme.amber, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.amber, lineWidth: 1.5).opacity(isPlaying ? 1 : 0))
            .shadow(color: isPlaying ? .clear : Theme.amber.opacity(0.28), radius: 20)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
