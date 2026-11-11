import SwiftUI

@main
struct MetronomeApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: MetronomeModel
    private let cloud: UbiquitousCloudStore

    init() {
        let cloud = UbiquitousCloudStore()
        self.cloud = cloud
        _model = State(initialValue: MetronomeModel(
            engine: AudioClickEngine(),
            store: SettingsStore(),
            haptics: Haptics(),
            libraryStore: LibraryStore(),
            sync: LibrarySync(cloud: cloud)
        ))
        cloud.start()
    }

    var body: some Scene {
        WindowGroup {
            MetronomeScreen()
                .environment(model)
                .preferredColorScheme(.dark)
                .task {
                    // A cold launch may not report a change of phase; a second call is harmless,
                    // because an exchange with nothing new writes nothing.
                    model.appDidBecomeActive()
                }
                .onChange(of: scenePhase) { _, phase in
                    // Locking the phone or leaving the app stops playback.
                    if phase == .background { model.appDidLeaveForeground() }
                    if phase == .active { model.appDidBecomeActive() }
                }
                .onChange(of: model.screenStaysAwake, initial: true) { _, staysAwake in
                    // Keep the screen awake while the metronome runs, or always with the setting on.
                    // iOS applies this only while the app is in the foreground.
                    UIApplication.shared.isIdleTimerDisabled = staysAwake
                }
        }
    }
}
