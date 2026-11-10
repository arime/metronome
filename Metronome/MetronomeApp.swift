import SwiftUI

@main
struct MetronomeApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = MetronomeModel(
        engine: AudioClickEngine(),
        store: SettingsStore(),
        haptics: Haptics()
    )

    var body: some Scene {
        WindowGroup {
            MetronomeScreen()
                .environment(model)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { _, phase in
                    // Locking the phone or leaving the app stops playback.
                    if phase == .background { model.appDidLeaveForeground() }
                }
                .onChange(of: model.isPlaying) { _, isPlaying in
                    // Keep the screen awake while the metronome runs.
                    UIApplication.shared.isIdleTimerDisabled = isPlaying
                }
        }
    }
}
