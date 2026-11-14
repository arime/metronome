import SwiftUI

/// The one screen. Its layout is the same stopped and playing, so nothing moves on Start.
struct MetronomeScreen: View {
    @Environment(MetronomeModel.self) private var model
    @State private var isLibraryShown = false
    @State private var isSettingsShown = false

    var body: some View {
        GeometryReader { proxy in
            let layout = ScreenLayout(
                width: proxy.size.width,
                height: proxy.size.height,
                hasBottomInset: proxy.safeAreaInsets.bottom > 0,
                beats: model.settings.timeSignature.beatsPerBar,
                hasSetlist: model.position != nil
            )
            VStack(spacing: 0) {
                header
                    .padding(.top, 8)
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
            .padding(.horizontal, layout.sideMargin)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.ink.ignoresSafeArea())
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

    /// Title, the Save button while the song has unsaved changes, mute and gear.
    private var header: some View {
        HStack(spacing: 8) {
            SongTitle { isLibraryShown = true }
            if model.isSaveOffered {
                SaveButton()
                    .transition(.opacity)
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

/// Says what Next leads to, above the transport row. At the last song it says so, and
/// keeps its height, so the footer does not move from song to song.
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
struct ScreenLayout {
    let dialDiameter: CGFloat
    let sectionGap: CGFloat
    let settingsTopGap: CGFloat
    let tileHeight: CGFloat
    let bottomPadding: CGFloat
    let sideMargin: CGFloat
    /// Height of everything except the dial and the bottom padding.
    let fixedHeight: CGFloat
    /// True when the next-up line is shown above the transport row.
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

        struct Fit {
            let dial, sectionGap, settingsTopGap, tileHeight, fixedHeight: CGFloat
        }

        func fit(nextLine: Bool) -> Fit {
            func partsHeight(sectionGap: CGFloat, settingsTopGap: CGFloat, tileHeight: CGFloat) -> CGFloat {
                let header: CGFloat = 8 + 40
                let dialTop: CGFloat = 12
                let controls: CGFloat = 4 + TempoControls.height
                let row: CGFloat = 60
                let tiles = AccentTiles.height(forBeats: beats, singleRowTileHeight: tileHeight)
                let nextUp: CGFloat = nextLine ? Self.nextLineHeight + Self.nextLineGap : 0
                let button: CGFloat = Self.buttonTopGap + nextUp + 68
                return header + dialTop + controls + settingsTopGap + row + sectionGap + tiles + button
            }

            let roomy = partsHeight(sectionGap: 22, settingsTopGap: 26, tileHeight: 76)
            if available - roomy >= Self.roomyMinimumDial {
                return Fit(
                    dial: min(largestDial, available - roomy),
                    sectionGap: 22, settingsTopGap: 26, tileHeight: 76, fixedHeight: roomy
                )
            }
            let compact = partsHeight(sectionGap: 16, settingsTopGap: 16, tileHeight: 56)
            return Fit(
                dial: min(largestDial, max(Self.minimumDial, available - compact)),
                sectionGap: 16, settingsTopGap: 16, tileHeight: 56, fixedHeight: compact
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
        sectionGap = chosen.sectionGap
        settingsTopGap = chosen.settingsTopGap
        tileHeight = chosen.tileHeight
        fixedHeight = chosen.fixedHeight
    }
}
