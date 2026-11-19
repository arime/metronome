import SwiftUI

/// The one screen. Its layout is the same stopped and playing, so nothing moves on Start.
struct MetronomeScreen: View {
    @Environment(MetronomeModel.self) private var model
    @State private var isLibraryShown = false
    @State private var isSettingsShown = false
    /// The song that the library, when opened from the header menu's New setlist, makes a
    /// new setlist with.
    @State private var newSetlistSongID: UUID?

    var body: some View {
        screen
            .background(Theme.ink.ignoresSafeArea())
            // Captured here, so that the body reads the ID and the sheet gets the one set
            // together with isLibraryShown rather than an earlier one.
            .sheet(isPresented: $isLibraryShown, onDismiss: { newSetlistSongID = nil }) { [newSetlistSongID] in
                LibrarySheet(newSetlistWith: newSetlistSongID)
                    .environment(model)
            }
            .sheet(isPresented: $isSettingsShown) {
                SettingsSheet()
                    .environment(model)
            }
            // Sync mode over the track screen. It follows the model, so it also closes when Sync
            // mode ends by itself; closing it by hand leaves Sync mode as Done does.
            .sheet(isPresented: syncModeShown) {
                SyncModeView()
                    .environment(model)
            }
            // Labels follow Dynamic Type up to the largest size that still fits the layout.
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            #if DEBUG
            .onAppear {
                switch ScreenshotScene.current {
                case .library?, .librarySelect?, .setlist?, .emptyLibrary?: isLibraryShown = true
                case .settings?: isSettingsShown = true
                default: break
                }
            }
            #endif
    }

    private var syncModeShown: Binding<Bool> {
        Binding(
            get: { model.isSyncModeShown },
            set: { shown in if !shown { model.leaveSyncMode() } }
        )
    }

    /// The plain layout, or the track screen while a track is in use, under the header.
    private var screen: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let hasBottomInset = proxy.safeAreaInsets.bottom > 0
            let beats = model.settings.timeSignature.beatsPerBar
            let hasSetlist = model.position != nil
            let layout = ScreenLayout(
                width: width, height: height, hasBottomInset: hasBottomInset, beats: beats, hasSetlist: hasSetlist
            )
            // The arrangement follows the song, not the file: a missing file still shows the
            // track screen. With Backing tracks off, the song is plain and so is the screen.
            let trackLayout = model.isTrackInUse
                ? TrackScreenLayout(
                    width: width, height: height, hasBottomInset: hasBottomInset, beats: beats, hasSetlist: hasSetlist
                )
                : nil
            VStack(spacing: 0) {
                header
                    .padding(.top, 8)
                if let trackLayout {
                    TrackScreenContent(layout: trackLayout)
                        .padding(.bottom, trackLayout.bottomPadding)
                } else {
                    TempoDial(diameter: layout.dialDiameter)
                        .padding(.top, 12)
                    TempoControls()
                        .padding(.top, 4)
                    VStack(alignment: .leading, spacing: layout.sectionGap) {
                        TimeSignatureRow(sideMargin: layout.sideMargin)
                        AccentTiles(singleRowTileHeight: layout.tileHeight)
                    }
                    .padding(.top, layout.settingsTopGap)
                    Spacer(minLength: ScreenLayout.buttonTopGap)
                    footer(showsNextLine: layout.showsNextLine)
                        .padding(.bottom, layout.bottomPadding)
                }
            }
            .padding(.horizontal, trackLayout?.sideMargin ?? layout.sideMargin)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Title, the Backing tracks switch for a song with a backing track, mute and the menu
    /// button, which carries the badge while the song has unsaved changes.
    private var header: some View {
        HStack(spacing: 8) {
            SongTitle { isLibraryShown = true }
            if model.loadedTrack != nil {
                TrackSwitchButton()
            }
            MuteButton()
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

    /// Previous and Next sit beside Start only for a song loaded from a setlist, with the
    /// next-up line above them. The footer changes with the setlist, never between Ready
    /// and Playing.
    private func footer(showsNextLine: Bool) -> some View {
        VStack(spacing: ScreenLayout.nextLineGap) {
            if showsNextLine {
                NextUpLine(next: model.nextSong)
            }
            HStack(spacing: 12) {
                if model.position != nil {
                    FooterRoundButton(symbol: "chevron.left", label: "Previous song", isEnabled: model.canGoPrevious) {
                        model.goToPrevious()
                    }
                }
                StartStopButton()
                if model.position != nil {
                    FooterRoundButton(symbol: "chevron.right", label: "Next song", isEnabled: model.canGoNext) {
                        model.goToNext()
                    }
                }
            }
        }
    }
}

/// Says what Next leads to, above the Start row or at the foot of the player card. At the last
/// song it says so, and keeps its height, so nothing moves from song to song.
struct NextUpLine: View {
    let next: Song?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let next {
                Text("NEXT")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(Theme.muted)
                    .fixedSize()
                Text(next.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.dialWhite)
                    .lineLimit(1)
                Text("\(next.settings.bpm) BPM · \(next.settings.timeSignature.rawValue)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.muted)
                    .fixedSize()
            } else {
                Text("Last song in the setlist")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: ScreenLayout.nextLineHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            next.map {
                "Next: \($0.name), \($0.settings.bpm) beats per minute, \($0.settings.timeSignature.rawValue)"
            } ?? "Last song in the setlist"
        )
    }
}

/// Fits the fixed parts of the screen into the available space (specification 6.8).
/// On a tall screen the dial grows past its 300 pt design size, up to 340 pt. On a short
/// one the dial shrinks first, down to 240 pt; then the gaps and tiles shrink; then the
/// dial shrinks as far as it must. The screen never scrolls. While a track is in use the
/// screen is the track screen, laid out by `TrackScreenLayout`.
struct ScreenLayout {
    let dialDiameter: CGFloat
    /// Below the time signature row.
    let sectionGap: CGFloat
    /// Above the time signature row.
    let settingsTopGap: CGFloat
    let tileHeight: CGFloat
    let bottomPadding: CGFloat
    let sideMargin: CGFloat
    /// Height of everything except the dial and the bottom padding.
    let fixedHeight: CGFloat
    /// True when the next-up line is shown above the Start row.
    let showsNextLine: Bool

    /// The least space kept between the accent tiles and the Start button.
    static let buttonTopGap: CGFloat = 16
    static let narrowSideMargin: CGFloat = 16
    /// Screens narrower than this get the narrow side margins.
    static let narrowWidth: CGFloat = 360

    /// The dial's size in the design.
    static let fullDial: CGFloat = 300
    /// The dial grows this far when the screen has height to spare.
    static let maximumDial: CGFloat = 340
    /// The dial shrinks this far before the gaps and tiles give way.
    static let roomyMinimumDial: CGFloat = 240
    /// A safety floor only; no supported iPhone gets near it (the smallest is about 134 pt).
    static let minimumDial: CGFloat = 80

    static let nextLineHeight: CGFloat = 18
    /// Between the next-up line and the transport row.
    static let nextLineGap: CGFloat = 14
    /// The next-up line is left out when it would push the dial below this size.
    static let nextLineMinimumDial: CGFloat = 200

    init(width: CGFloat, height: CGFloat, hasBottomInset: Bool, beats: Int, hasSetlist: Bool = false) {
        let sideMargin = width < Self.narrowWidth ? Self.narrowSideMargin : Theme.sideMargin
        self.sideMargin = sideMargin
        // Phones with a home indicator already have the design's bottom margin.
        let bottomPadding: CGFloat = hasBottomInset ? 0 : 16
        self.bottomPadding = bottomPadding
        let available = height - bottomPadding
        // The dial never grows wider than the space between the side margins.
        let largestDial = min(Self.maximumDial, max(Self.fullDial, width - 2 * sideMargin))

        struct Gaps {
            let sectionGap, settingsTopGap, tileHeight: CGFloat
        }
        let roomyGaps = Gaps(sectionGap: 22, settingsTopGap: 26, tileHeight: 76)
        let compactGaps = Gaps(sectionGap: 16, settingsTopGap: 16, tileHeight: 56)

        struct Fit {
            let dial, fixedHeight: CGFloat
            let gaps: Gaps
        }

        func fit(nextLine: Bool) -> Fit {
            func partsHeight(_ gaps: Gaps) -> CGFloat {
                let header: CGFloat = 8 + 40
                let dialTop: CGFloat = 12
                let controls: CGFloat = 4 + TempoControls.height
                let row: CGFloat = 60
                let tiles = AccentTiles.height(forBeats: beats, singleRowTileHeight: gaps.tileHeight)
                let nextUp: CGFloat = nextLine ? Self.nextLineHeight + Self.nextLineGap : 0
                let footer = Self.buttonTopGap + nextUp + 68
                return header + dialTop + controls + gaps.settingsTopGap + row + gaps.sectionGap + tiles
                    + footer
            }

            let roomy = partsHeight(roomyGaps)
            if available - roomy >= Self.roomyMinimumDial {
                return Fit(dial: min(largestDial, available - roomy), fixedHeight: roomy, gaps: roomyGaps)
            }
            let compact = partsHeight(compactGaps)
            return Fit(
                dial: min(largestDial, max(Self.minimumDial, available - compact)),
                fixedHeight: compact, gaps: compactGaps
            )
        }

        let withLine = hasSetlist ? fit(nextLine: true) : nil
        let chosen: Fit
        if let withLine, withLine.dial >= Self.nextLineMinimumDial {
            chosen = withLine
            showsNextLine = true
        } else {
            chosen = fit(nextLine: false)
            showsNextLine = false
        }
        dialDiameter = chosen.dial
        sectionGap = chosen.gaps.sectionGap
        settingsTopGap = chosen.gaps.settingsTopGap
        tileHeight = chosen.gaps.tileHeight
        fixedHeight = chosen.fixedHeight
    }
}
