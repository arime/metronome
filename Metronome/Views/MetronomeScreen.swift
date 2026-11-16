import SwiftUI

/// The one screen. Its layout is the same stopped and playing, so nothing moves on Start.
struct MetronomeScreen: View {
    @Environment(MetronomeModel.self) private var model
    @State private var isLibraryShown = false
    @State private var isSettingsShown = false

    var body: some View {
        GeometryReader { proxy in
            // The arrangement follows the song, not the file: a missing file still shows the card.
            // With Backing tracks off, the song is plain and so is the screen.
            let hasTrack = model.isTrackInUse
            let layout = ScreenLayout(
                width: proxy.size.width,
                height: proxy.size.height,
                hasBottomInset: proxy.safeAreaInsets.bottom > 0,
                beats: model.settings.timeSignature.beatsPerBar,
                hasSetlist: model.position != nil,
                hasTrack: hasTrack
            )
            VStack(spacing: 0) {
                header
                    .padding(.top, 8)
                TempoDial(diameter: layout.dialDiameter)
                    .padding(.top, 12)
                if hasTrack {
                    TrackTempoRow(sideMargin: layout.sideMargin)
                        .padding(.top, layout.settingsTopGap)
                    AccentTiles(singleRowTileHeight: layout.tileHeight)
                        .padding(.top, layout.sectionGap)
                    Spacer(minLength: ScreenLayout.playerCardTopGap)
                    PlayerCard(showsNextLine: layout.showsNextLine)
                        .padding(.bottom, layout.bottomPadding)
                } else {
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
            .padding(.horizontal, layout.sideMargin)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.ink.ignoresSafeArea())
        // Sync mode is the model's; closing the sheet any way is Done.
        .sheet(isPresented: Binding(get: { model.isSyncModeShown }, set: { if !$0 { model.leaveSyncMode() } })) {
            SyncSheet()
                .environment(model)
        }
        // Labels follow Dynamic Type up to the largest size that still fits the layout.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        #if DEBUG
        .onAppear {
            switch ScreenshotScene.current {
            case .library?, .setlist?: isLibraryShown = true
            case .settings?: isSettingsShown = true
            default: break
            }
        }
        #endif
    }

    /// Title, the Save button while the song has unsaved changes, the Backing tracks switch for
    /// a song with a backing track, mute and gear.
    private var header: some View {
        HStack(spacing: 8) {
            SongTitle { isLibraryShown = true }
            if model.isSaveOffered {
                SaveButton()
                    // Fades in, but leaves at once, so that after Save only the menu's own
                    // closing animation is left on screen.
                    .transition(.asymmetric(insertion: .opacity, removal: .identity))
            }
            if model.loadedTrack != nil {
                TrackSwitchButton()
            }
            MuteButton()
            SettingsButton { isSettingsShown = true }
        }
        .frame(height: 40)
        .animation(.easeOut(duration: 0.15), value: model.isSaveOffered)
        .sheet(isPresented: $isLibraryShown) {
            LibrarySheet()
                .environment(model)
        }
        .sheet(isPresented: $isSettingsShown) {
            SettingsSheet()
                .environment(model)
        }
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
/// dial shrinks as far as it must. The screen never scrolls.
///
/// While a track is in use the screen has its own arrangement (6.12): one tempo and time
/// signature row in place of two, and the player card, pinned to the bottom, in place of the
/// Start row and the next-up line. The card never shrinks; the next-up line inside it adds
/// 30 pt. There the gaps around the row stay put, and the compact fit shrinks only the tiles.
struct ScreenLayout {
    let dialDiameter: CGFloat
    /// Below the time signature row; with a track, below the tempo and time signature row.
    let sectionGap: CGFloat
    /// Above the time signature row; with a track, between the dial and the row.
    let settingsTopGap: CGFloat
    let tileHeight: CGFloat
    let bottomPadding: CGFloat
    let sideMargin: CGFloat
    /// Height of everything except the dial and the bottom padding.
    let fixedHeight: CGFloat
    /// True when the next-up line is shown: above the Start row, or inside the player card.
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

    /// The tempo and time signature row of the track arrangement.
    static let trackRowHeight: CGFloat = 56
    /// The player card without the next-up line, which never shrinks: 12 + 30 + 12 + 40 + 12 + 68 + 18.
    static let playerCardHeight: CGFloat = 192
    /// The next-up line inside the player card with its gap: 18 + 12.
    static let playerNextLineHeight: CGFloat = 30
    /// The least space kept between the accent tiles and the player card.
    static let playerCardTopGap: CGFloat = 16

    init(
        width: CGFloat, height: CGFloat, hasBottomInset: Bool, beats: Int, hasSetlist: Bool = false,
        hasTrack: Bool = false
    ) {
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
        let roomyGaps = hasTrack
            ? Gaps(sectionGap: 12, settingsTopGap: 10, tileHeight: 76)
            : Gaps(sectionGap: 22, settingsTopGap: 26, tileHeight: 76)
        let compactGaps = hasTrack
            ? Gaps(sectionGap: 12, settingsTopGap: 10, tileHeight: 56)
            : Gaps(sectionGap: 16, settingsTopGap: 16, tileHeight: 56)

        struct Fit {
            let dial, fixedHeight: CGFloat
            let gaps: Gaps
        }

        func fit(nextLine: Bool) -> Fit {
            func partsHeight(_ gaps: Gaps) -> CGFloat {
                let header: CGFloat = 8 + 40
                let dialTop: CGFloat = 12
                // The track arrangement has no separate tempo controls; its one row holds them.
                let controls: CGFloat = hasTrack ? 0 : 4 + TempoControls.height
                let row: CGFloat = hasTrack ? Self.trackRowHeight : 60
                let tiles = AccentTiles.height(forBeats: beats, singleRowTileHeight: gaps.tileHeight)
                let footer: CGFloat
                if hasTrack {
                    let nextUp: CGFloat = nextLine ? Self.playerNextLineHeight : 0
                    footer = Self.playerCardTopGap + Self.playerCardHeight + nextUp
                } else {
                    let nextUp: CGFloat = nextLine ? Self.nextLineHeight + Self.nextLineGap : 0
                    footer = Self.buttonTopGap + nextUp + 68
                }
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
