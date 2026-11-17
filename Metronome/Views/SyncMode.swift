import SwiftUI

/// Sync mode (6.13), a full-height sheet over the track screen: its own header, then the time
/// signature row, the accent tiles, the two tap pads, the Tempo and Offset steppers, the count-in
/// and the mix, and the playback card pinned to the bottom. The same stopped and playing. The pads
/// take the height the other parts leave; when even their least height does not fit, the part
/// between the header and the card scrolls.
struct SyncModeView: View {
    @Environment(MetronomeModel.self) private var model

    var body: some View {
        GeometryReader { proxy in
            let layout = SyncModeLayout(
                width: proxy.size.width,
                height: proxy.size.height,
                hasBottomInset: proxy.safeAreaInsets.bottom > 0,
                beats: model.settings.timeSignature.beatsPerBar
            )
            VStack(spacing: 0) {
                SyncModeHeader()
                    .frame(height: SyncModeLayout.headerHeight - SyncModeLayout.headerTopGap)
                    .padding(.top, SyncModeLayout.headerTopGap)
                // A scroll view only where the parts do not fit, so that elsewhere none can delay or
                // claim a touch on a pad.
                if layout.scrollOverflow > 0 {
                    ScrollView { parts(layout) }
                } else {
                    parts(layout)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
                PlaybackCard()
                    .padding(.top, SyncModeLayout.cardTopGap)
            }
            .padding(.horizontal, layout.sideMargin)
            .padding(.bottom, layout.bottomPadding)
        }
        .preferredColorScheme(.dark)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        // The screen's own ink, not the surface of the other sheets: the steppers, the count-in,
        // the time signature row and the playback card are surface and would not stand out on it.
        .presentationBackground(Theme.ink)
    }

    /// Everything between the header and the playback card.
    private func parts(_ layout: SyncModeLayout) -> some View {
        VStack(spacing: 0) {
            TimeSignatureRow(sideMargin: layout.sideMargin)
                .padding(.top, SyncModeLayout.rowTopGap)
            // Two-row signatures keep their 44 pt tiles whatever the single-row height is.
            AccentTiles(singleRowTileHeight: layout.tileHeight)
                .padding(.top, SyncModeLayout.tilesTopGap)
            TapPads(showsHandIcon: layout.showsHandIcon)
                .frame(height: layout.padHeight)
                .padding(.top, SyncModeLayout.padGap)
            SyncSteppers()
                .padding(.top, SyncModeLayout.padGap)
            CountInRow()
                .padding(.top, SyncModeLayout.countInTopGap)
            MixRow()
                .padding(.top, SyncModeLayout.mixTopGap)
        }
    }
}

/// The sheet's title row, set as the other sheets set theirs: `Sync` with the file name 2 pt
/// below it at the left, and `Done` at the right.
private struct SyncModeHeader: View {
    @Environment(MetronomeModel.self) private var model

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Sync")
                    .font(.system(size: 26, weight: .heavy))
                    .tracking(-0.52)
                    .foregroundStyle(Theme.dialWhite)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                Text(model.loadedTrack?.fileName ?? "")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button { model.leaveSyncMode() } label: {
                Text("Done")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.amber)
                    // The text sits at the right edge; the touch area is at least 44 × 44.
                    .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Done")
        }
    }
}

/// Tap tempo above the Tempo stepper and Tap on beat 1 above the Offset stepper, 10 pt apart and
/// sharing the width equally, as the steppers do.
private struct TapPads: View {
    let showsHandIcon: Bool

    var body: some View {
        HStack(spacing: 10) {
            TapTempoPad(showsHandIcon: showsHandIcon)
            TapOnBeat1Pad(showsHandIcon: showsHandIcon)
        }
    }
}

/// Sets the track's tempo by the plain tap tempo's rules (7.11). Works stopped and playing and is
/// never dimmed. While a series is open, from a tap until it would start over two seconds later,
/// the title reads `Tap again`.
private struct TapTempoPad: View {
    @Environment(MetronomeModel.self) private var model
    let showsHandIcon: Bool

    /// Goes up by one per tap; restarts the wait for the end of the series.
    @State private var tapCount = 0
    /// True from a tap until the series would start over, two seconds later.
    @State private var isTapping = false

    var body: some View {
        SyncTapPad(showsHandIcon: showsHandIcon, onTouch: tap) {
            // Both titles are laid out, so the pad's content keeps its size when they swap.
            ZStack {
                TapPadTitle(text: "Tap tempo").opacity(isTapping ? 0 : 1)
                TapPadTitle(text: "Tap again").opacity(isTapping ? 1 : 0)
            }
        }
        .accessibilityRepresentation {
            Button("Tap tempo", action: tap)
        }
        .task(id: tapCount) {
            guard tapCount > 0 else { return }
            try? await Task.sleep(for: .seconds(TapTempo.seriesTimeout))
            if !Task.isCancelled { isTapping = false }
        }
    }

    private func tap() {
        model.tapTrackTempo(at: ProcessInfo.processInfo.systemUptime)
        tapCount += 1
        isTapping = true
    }
}

/// Sets the offset from the place being heard (7.11). It works only while the file itself plays;
/// otherwise it is dimmed and a touch does nothing.
private struct TapOnBeat1Pad: View {
    @Environment(MetronomeModel.self) private var model
    let showsHandIcon: Bool

    var body: some View {
        // Whether the file has started is read from the engine and not observed, so it is read
        // again while playing. The timeline stays in place, so a touch survives Start and Stop.
        TimelineView(.animation(minimumInterval: 0.1, paused: !model.isPlaying)) { _ in pad }
    }

    private var pad: some View {
        // Read at most every 0.1 s, so it only dims the pad. A touch always goes to the model,
        // which takes it only when it can count, so none is lost as the file starts.
        let canTap = model.canTapDownbeat
        return SyncTapPad(showsHandIcon: showsHandIcon, onTouch: { model.tapDownbeat() }) {
            TapPadTitle(text: "Tap on beat 1")
        }
        // A button for VoiceOver, dimmed when a tap cannot count.
        .accessibilityRepresentation {
            Button("Tap on beat 1") { model.tapDownbeat() }
                .disabled(!canTap)
        }
        .opacity(canTap ? 1 : 0.4)
    }
}

/// One tap pad: the amber tint fill, a 1.5 pt amber outline and 24 pt corners, with the hand icon
/// and the title centred 8 pt apart, or the title alone on a short pad. A touch counts when the
/// finger comes down, so a slide or the lift adds nothing.
private struct SyncTapPad<Title: View>: View {
    let showsHandIcon: Bool
    let onTouch: () -> Void
    @ViewBuilder let title: Title

    /// True while a finger is down; back to false when the touch ends or is cancelled.
    @GestureState private var isPressed = false

    private static var cornerRadius: CGFloat { 24 }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
        VStack(spacing: 8) {
            if showsHandIcon {
                Image(systemName: "hand.tap")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Theme.amber)
            }
            title
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.amberTint, in: shape)
        .overlay(shape.strokeBorder(Theme.amber, lineWidth: 1.5))
        .contentShape(shape)
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($isPressed) { _, pressed, _ in pressed = true }
        )
        .onChange(of: isPressed) { _, pressed in
            if pressed { onTouch() }
        }
    }
}

/// A pad's title: 20 pt heavy dial white on one line, scaled down when the pad is too narrow for it.
private struct TapPadTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 20, weight: .heavy))
            .foregroundStyle(Theme.dialWhite)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}
