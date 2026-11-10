import SwiftUI

/// The one screen. Its layout is the same stopped and playing, so nothing moves on Start.
struct MetronomeScreen: View {
    @Environment(MetronomeModel.self) private var model

    var body: some View {
        GeometryReader { proxy in
            let layout = ScreenLayout(
                width: proxy.size.width,
                height: proxy.size.height,
                hasBottomInset: proxy.safeAreaInsets.bottom > 0,
                beats: model.settings.timeSignature.beatsPerBar
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
                    VStack(alignment: .leading, spacing: 14) {
                        SectionLabel(text: "ACCENTS")
                        AccentTiles(singleRowTileHeight: layout.tileHeight)
                    }
                }
                .padding(.top, layout.settingsTopGap)
                Spacer(minLength: ScreenLayout.buttonTopGap)
                StartStopButton()
                    .padding(.bottom, layout.bottomPadding)
            }
            .padding(.horizontal, layout.sideMargin)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.ink.ignoresSafeArea())
        // Labels follow Dynamic Type up to the largest size that still fits the layout.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var header: some View {
        HStack(spacing: 10) {
            if model.isPlaying {
                Circle().fill(Theme.amber).frame(width: 8, height: 8)
                SectionLabel(text: "PLAYING", color: Theme.dialWhite)
            } else {
                SectionLabel(text: "TEMPO")
            }
            Spacer()
            MuteButton()
        }
        .frame(height: 40)
    }
}

/// Fits the fixed parts of the screen into the available space (specification 5.8).
/// The dial shrinks first, down to 240 pt; then the gaps and tiles shrink; then the dial
/// shrinks as far as it must. The screen never scrolls.
struct ScreenLayout {
    let dialDiameter: CGFloat
    let sectionGap: CGFloat
    let settingsTopGap: CGFloat
    let tileHeight: CGFloat
    let bottomPadding: CGFloat
    let sideMargin: CGFloat
    /// Height of everything except the dial and the bottom padding.
    let fixedHeight: CGFloat

    /// The least space kept between the accent tiles and the Start button.
    static let buttonTopGap: CGFloat = 16
    static let narrowSideMargin: CGFloat = 16
    /// Screens narrower than this get the narrow side margins.
    static let narrowWidth: CGFloat = 360

    static let fullDial: CGFloat = 300
    /// The dial shrinks this far before the gaps and tiles give way.
    static let roomyMinimumDial: CGFloat = 240
    /// A safety floor only; no supported iPhone gets near it (the smallest is about 108 pt).
    static let minimumDial: CGFloat = 80

    init(width: CGFloat, height: CGFloat, hasBottomInset: Bool, beats: Int) {
        sideMargin = width < Self.narrowWidth ? Self.narrowSideMargin : Theme.sideMargin
        // Phones with a home indicator already have the design's bottom margin.
        bottomPadding = hasBottomInset ? 0 : 16

        func partsHeight(sectionGap: CGFloat, settingsTopGap: CGFloat, tileHeight: CGFloat) -> CGFloat {
            let header: CGFloat = 8 + 40
            let dialTop: CGFloat = 12
            let controls: CGFloat = 4 + 56
            let row: CGFloat = 60
            let accentsLabel: CGFloat = 16 + 14
            let tiles = AccentTiles.height(forBeats: beats, singleRowTileHeight: tileHeight)
            let button: CGFloat = Self.buttonTopGap + 68
            return header + dialTop + controls + settingsTopGap + row + sectionGap + accentsLabel + tiles + button
        }

        let roomy = partsHeight(sectionGap: 22, settingsTopGap: 26, tileHeight: 76)
        let available = height - bottomPadding
        if available - roomy >= Self.roomyMinimumDial {
            sectionGap = 22
            settingsTopGap = 26
            tileHeight = 76
            fixedHeight = roomy
            dialDiameter = min(Self.fullDial, available - roomy)
        } else {
            sectionGap = 16
            settingsTopGap = 16
            tileHeight = 56
            let compact = partsHeight(sectionGap: 16, settingsTopGap: 16, tileHeight: 56)
            fixedHeight = compact
            dialDiameter = min(Self.fullDial, max(Self.minimumDial, available - compact))
        }
    }
}
