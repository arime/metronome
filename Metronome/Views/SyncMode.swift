import SwiftUI

/// Sync mode (6.13), in place of the track screen's header and content: its own header, then
/// the time signature row, the accent tiles, the tap pad, the Tempo and Offset steppers, the
/// count-in and the mix, and the playback card pinned to the bottom. The same stopped and
/// playing. The pad takes the height the other parts leave; when even its least height does not
/// fit, the part between the header and the card scrolls.
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
                    .frame(height: SyncModeLayout.headerHeight - 8)
                    .padding(.top, 8)
                // A scroll view only where the parts do not fit, so that elsewhere none can delay or
                // claim a touch on the pad.
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
    }

    /// Everything between the header and the playback card.
    private func parts(_ layout: SyncModeLayout) -> some View {
        VStack(spacing: 0) {
            TimeSignatureRow(sideMargin: layout.sideMargin)
                .padding(.top, SyncModeLayout.rowTopGap)
            // Two-row signatures keep their 44 pt tiles whatever the single-row height is.
            AccentTiles(singleRowTileHeight: layout.tileHeight)
                .padding(.top, SyncModeLayout.tilesTopGap)
            TapPad(showsHandIcon: layout.showsHandIcon)
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

/// `Sync` with the file name 2 pt below it at the left, and `Done` at the right.
private struct SyncModeHeader: View {
    @Environment(MetronomeModel.self) private var model

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Sync")
                    .font(.system(size: 20, weight: .heavy))
                    .tracking(-0.2)
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

/// Where downbeats are tapped along with the track (7.11). A touch counts when the finger comes
/// down, so a slide or the lift adds nothing. It works only while the file itself plays; otherwise
/// it is dimmed and a touch does nothing. Start over in its top right corner forgets the run and is
/// never a tap.
private struct TapPad: View {
    @Environment(MetronomeModel.self) private var model
    let showsHandIcon: Bool

    /// True while a finger is down; back to false when the touch ends or is cancelled.
    @GestureState private var isPressed = false

    private static let cornerRadius: CGFloat = 24
    /// Room kept at the right for Start over when the text stands at the left.
    private static let startOverClearance: CGFloat = 128

    var body: some View {
        // Whether the file has started is read from the engine and not observed, so it is read
        // again while playing. The timeline stays in place, so a touch survives Start and Stop.
        TimelineView(.animation(minimumInterval: 0.1, paused: !model.isPlaying)) { _ in pad }
    }

    private var pad: some View {
        let canTap = model.canTapDownbeat
        let shape = RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
        return labels
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.amberTint, in: shape)
            .overlay(shape.strokeBorder(Theme.amber, lineWidth: 1.5))
            .contentShape(shape)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, pressed, _ in pressed = true }
            )
            .onChange(of: isPressed) { _, pressed in
                if pressed { model.tapDownbeat() }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Tap on beat 1")
            .accessibilityValue(model.tapRun.spokenCountLine ?? "")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { model.tapDownbeat() }
            .disabled(!canTap)
            // Laid over the pad and not inside it, so a touch on it never reaches the pad's gesture.
            .overlay(alignment: .topTrailing) {
                StartOverButton(isDimmedAlone: canTap)
                    .padding(.top, 12 - StartOverButton.touchInset)
                    .padding(.trailing, 14 - StartOverButton.touchInset)
            }
            .opacity(canTap ? 1 : 0.4)
    }

    /// Centred under the hand icon on a tall pad; at the left and centred vertically on a short
    /// one. The count line keeps its place before the first tap, so nothing moves on the first tap.
    @ViewBuilder
    private var labels: some View {
        let countLine = model.tapRun.countLine
        let title = Text("Tap on beat 1")
            .font(.system(size: 22, weight: .heavy))
            .foregroundStyle(Theme.dialWhite)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        let count = Text(countLine ?? " ")
            .font(.system(size: 14, weight: .medium).monospacedDigit())
            .foregroundStyle(Theme.muted)
            .lineLimit(1)
            .opacity(countLine == nil ? 0 : 1)
        if showsHandIcon {
            VStack(spacing: 6) {
                Image(systemName: "hand.tap")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Theme.amber)
                title
                count
            }
            .padding(.horizontal, 16)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                title
                count
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)
            .padding(.trailing, Self.startOverClearance)
        }
    }
}

/// A 30 pt outlined pill with a touch area of at least 44 × 44. A touch on it, even while it is
/// dimmed, is kept from the pad below.
private struct StartOverButton: View {
    @Environment(MetronomeModel.self) private var model
    /// True when it is dimmed on its own; while the whole pad is dimmed, it is dimmed with it.
    let isDimmedAlone: Bool

    /// How far the touch area reaches past the pill above and below: (44 − 30) / 2.
    static let touchInset: CGFloat = 7

    var body: some View {
        let isEmpty = model.tapRun.isEmpty
        Button { model.startTapRunOver() } label: {
            Text("Start over")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.dialWhite)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 14)
                .frame(height: 30)
                .overlay(Capsule().strokeBorder(Color(hex: 0x3A3423), lineWidth: 1))
                .opacity(isEmpty && isDimmedAlone ? 0.4 : 1)
                .padding(Self.touchInset)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isEmpty)
        .accessibilityLabel("Start over")
        // A disabled button lets touches through; this keeps them from the pad.
        .background(Color.clear.contentShape(Rectangle()).onTapGesture {})
    }
}
