import SwiftUI

/// The one screen. Its layout is the same stopped and playing, so nothing moves on Start.
struct MetronomeScreen: View {
    @Environment(MetronomeModel.self) private var model
    @State private var isLibraryShown = false
    @State private var isSettingsShown = false
    /// The song that the library, when opened from the header menu's New setlist, makes a
    /// new setlist with.
    @State private var newSetlistSongID: UUID?
    /// Follows the model's stage mode, but is set only once no sheet is in the way.
    @State private var isStageShown = false

    var body: some View {
        screen
            .background(Theme.ink.ignoresSafeArea())
            // Captured here, so that the body reads the ID and the sheet gets the one set
            // together with isLibraryShown rather than an earlier one.
            .sheet(isPresented: $isLibraryShown, onDismiss: libraryClosed) { [newSetlistSongID] in
                LibrarySheet(newSetlistWith: newSetlistSongID)
                    .environment(model)
            }
            .sheet(isPresented: $isSettingsShown) {
                SettingsSheet()
                    .environment(model)
            }
            // Sync mode over the metronome screen. It follows the model, so it also closes when Sync
            // mode ends by itself; closing it by hand leaves Sync mode as Done does.
            .sheet(isPresented: syncModeShown) {
                SyncModeView()
                    .environment(model)
            }
            .fullScreenCover(isPresented: $isStageShown) {
                StageModeView()
                    .environment(model)
            }
            // From the header menu stage mode opens at once. From a setlist's menu the library
            // is still closing, and a cover presented then is dropped, so libraryClosed opens it.
            .onChange(of: model.stageMode != nil) { _, isOn in
                if !isOn {
                    isStageShown = false
                } else if !isLibraryShown {
                    // Only the header menu, closed by now, and a setlist's menu in the library enter it.
                    isStageShown = true
                }
            }
            // Labels follow Dynamic Type up to the largest size that still fits the layout.
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            #if DEBUG
            .onAppear {
                switch ScreenshotScene.current {
                case .library?, .librarySelect?, .setlist?, .setlistSearch?, .setlistSelect?, .emptyLibrary?:
                    isLibraryShown = true
                case .settings?: isSettingsShown = true
                // Stage mode was entered before the screen was there to follow it.
                case .stage?, .stagePlaying?: isStageShown = model.stageMode != nil
                default: break
                }
            }
            #endif
    }

    private func libraryClosed() {
        newSetlistSongID = nil
        if model.stageMode != nil { isStageShown = true }
    }

    private var syncModeShown: Binding<Bool> {
        Binding(
            get: { model.isSyncModeShown },
            set: { shown in if !shown { model.leaveSyncMode() } }
        )
    }

    /// The one layout for every song (6, 6.8): the header, the dial, the controls centred
    /// between the knob's lower edge and the player card, and the card at the bottom.
    private var screen: some View {
        GeometryReader { proxy in
            let layout = MetronomeLayout(
                width: proxy.size.width,
                height: proxy.size.height,
                hasBottomInset: proxy.safeAreaInsets.bottom > 0,
                beats: model.settings.timeSignature.beatsPerBar
            )
            VStack(spacing: 0) {
                header
                    .padding(.top, 8)
                // The frame ends at the knob's lower edge; the rest of the dial's square
                // overflows into the gap below without taking room.
                TempoDial(diameter: layout.dialDiameter)
                    .frame(height: layout.dialFrameHeight, alignment: .top)
                    .padding(.top, MetronomeLayout.dialTopGap)
                    .padding(.bottom, layout.controlsGap)
                TempoControls(height: layout.rowHeight)
                TimeSignatureRow(sideMargin: layout.sideMargin, height: layout.rowHeight)
                    .padding(.top, layout.innerGap)
                AccentTiles(singleRowTileHeight: layout.tileHeight)
                    .padding(.top, layout.innerGap)
                Spacer(minLength: layout.controlsGap)
                PlayerCard()
                    .padding(.bottom, layout.bottomPadding)
            }
            .padding(.horizontal, layout.sideMargin)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Title, the Backing tracks switch for a song with a backing track, the Sound button and
    /// the menu button, which carries the badge while the song has unsaved changes.
    private var header: some View {
        HStack(spacing: 8) {
            SongTitle { isLibraryShown = true }
            if model.loadedTrack != nil {
                TrackSwitchButton()
            }
            SoundButton()
            HeaderMenuButton(
                openSettings: { isSettingsShown = true },
                newSetlist: { songID in
                    newSetlistSongID = songID
                    isLibraryShown = true
                }
            )
        }
        .frame(height: 40)
    }
}
