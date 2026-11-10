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
                // Always a scroll view, so the controls keep their state when the layout
                // changes; it only moves when the content cannot fit.
                ScrollView {
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
                    }
                    .padding(.horizontal, layout.sideMargin)
                }
                .scrollDisabled(!layout.needsScrolling)
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
                // Glows and ripples reach past the content; only cut them off when scrolling.
                .scrollClipDisabled(!layout.needsScrolling)
                StartStopButton()
                    .padding(.horizontal, layout.sideMargin)
                    .padding(.top, ScreenLayout.buttonTopGap)
                    .padding(.bottom, layout.bottomPadding)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Scrolled content would otherwise show through behind the status bar.
            .overlay(alignment: .top) {
                Theme.ink
                    .ignoresSafeArea(edges: .top)
                    .frame(height: 0)
            }
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

/// Fits the fixed parts of the screen into the available space (specification 5.8).
/// The dial shrinks first, down to 240 pt; then the gaps and tiles shrink; then the dial
/// shrinks to 200 pt; and if that is still too tall, everything above the button scrolls.
struct ScreenLayout {
    let dialDiameter: CGFloat
    let sectionGap: CGFloat
    let settingsTopGap: CGFloat
    let tileHeight: CGFloat
    let bottomPadding: CGFloat
    let sideMargin: CGFloat
    /// Height of everything except the dial and the bottom padding.
    let fixedHeight: CGFloat
    /// True when even the smallest layout is taller than the screen.
    let needsScrolling: Bool

    /// The least space kept between the accent tiles and the Start button.
    static let buttonTopGap: CGFloat = 16
    static let narrowSideMargin: CGFloat = 16
    /// Screens narrower than this get the narrow side margins.
    static let narrowWidth: CGFloat = 360

    static let fullDial: CGFloat = 300
    /// The dial shrinks this far before the gaps and tiles give way.
    static let roomyMinimumDial: CGFloat = 240
    static let minimumDial: CGFloat = 200

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
            needsScrolling = false
        } else {
            sectionGap = 16
            settingsTopGap = 16
            tileHeight = 56
            let compact = partsHeight(sectionGap: 16, settingsTopGap: 16, tileHeight: 56)
            fixedHeight = compact
            dialDiameter = min(Self.fullDial, max(Self.minimumDial, available - compact))
            needsScrolling = available - compact < Self.minimumDial
        }
    }
}
