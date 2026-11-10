import SwiftUI

/// The one screen. Its layout is the same stopped and playing, so nothing moves on Start.
struct MetronomeScreen: View {
    @Environment(MetronomeModel.self) private var model

    var body: some View {
        GeometryReader { proxy in
            let layout = ScreenLayout(
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
                    TimeSignatureRow()
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
            .padding(.horizontal, Theme.sideMargin)
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
        }
        .frame(height: 40)
        .accessibilityElement(children: .combine)
    }
}

/// Fits the fixed parts of the screen into the available height.
/// The dial shrinks first; on the smallest phones the gaps and tiles shrink too.
struct ScreenLayout {
    let dialDiameter: CGFloat
    let sectionGap: CGFloat
    let settingsTopGap: CGFloat
    let tileHeight: CGFloat
    let bottomPadding: CGFloat

    /// The least space kept between the accent tiles and the Start button.
    static let buttonTopGap: CGFloat = 16

    init(height: CGFloat, hasBottomInset: Bool, beats: Int) {
        // Phones with a home indicator already have the design's bottom margin.
        bottomPadding = hasBottomInset ? 0 : 16

        func fixedHeight(sectionGap: CGFloat, settingsTopGap: CGFloat, tileHeight: CGFloat) -> CGFloat {
            let header: CGFloat = 8 + 40
            let dialTop: CGFloat = 12
            let controls: CGFloat = 4 + 56
            let row: CGFloat = 60
            let accentsLabel: CGFloat = 16 + 14
            let tiles = AccentTiles.height(forBeats: beats, singleRowTileHeight: tileHeight)
            let button: CGFloat = Self.buttonTopGap + 68
            return header + dialTop + controls + settingsTopGap + row + sectionGap + accentsLabel + tiles + button
        }

        let roomy = fixedHeight(sectionGap: 22, settingsTopGap: 26, tileHeight: 76)
        let available = height - bottomPadding
        if available - roomy >= 240 {
            sectionGap = 22
            settingsTopGap = 26
            tileHeight = 76
            dialDiameter = min(300, available - roomy)
        } else {
            sectionGap = 16
            settingsTopGap = 16
            tileHeight = 56
            let compact = fixedHeight(sectionGap: 16, settingsTopGap: 16, tileHeight: 56)
            dialDiameter = min(300, max(200, available - compact))
        }
    }
}
