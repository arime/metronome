import SwiftUI

/// Silences the click while the metronome keeps running, stopped or playing (7.5).
struct SoundButton: View {
    @Environment(MetronomeModel.self) private var model

    var body: some View {
        HeaderToggleButton(toggle: .sound(isMuted: model.isMuted)) {
            model.toggleMute()
        }
    }
}
