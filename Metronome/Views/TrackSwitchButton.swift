import SwiftUI

/// Turns backing tracks on or off for the whole app. Shown in the header for every song and with
/// nothing loaded. Works only while stopped; while playing it is dimmed and takes no touches (7.12).
struct TrackSwitchButton: View {
    @Environment(MetronomeModel.self) private var model

    var body: some View {
        HeaderToggleButton(toggle: .backingTracks(isOn: model.backingTracksOn, isPlaying: model.isPlaying)) {
            model.toggleBackingTracks()
        }
    }
}
