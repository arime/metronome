import SwiftUI

/// One tile per beat. Tapping toggles the accent; while playing, the sounding beat lights up.
struct AccentTiles: View {
    @Environment(MetronomeModel.self) private var model
    /// Height of a tile when all beats fit in one row.
    let singleRowTileHeight: CGFloat

    nonisolated static let rowGap: CGFloat = 10
    /// The gap between neighbouring tiles in a row.
    nonisolated static let tileGap: CGFloat = 10
    nonisolated static let twoRowTileHeight: CGFloat = 44

    /// Up to seven beats fit in one row; 9 wraps 5 + 4 and 12 wraps 6 + 6.
    nonisolated static func rows(forBeats beats: Int) -> [[Int]] {
        guard beats > 7 else { return [Array(1...max(beats, 1))] }
        let firstRow = (beats + 1) / 2
        return [Array(1...firstRow), Array((firstRow + 1)...beats)]
    }

    nonisolated static func height(forBeats beats: Int, singleRowTileHeight: CGFloat) -> CGFloat {
        beats > 7 ? twoRowTileHeight * 2 + rowGap : singleRowTileHeight
    }

    var body: some View {
        let rows = Self.rows(forBeats: model.settings.timeSignature.beatsPerBar)
        let isCompact = rows.count > 1
        VStack(spacing: Self.rowGap) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: Self.tileGap) {
                    ForEach(row, id: \.self) { beat in
                        BeatTile(
                            beat: beat,
                            isAccented: model.settings.accents.contains(beat),
                            isSounding: model.currentBeat == beat,
                            soundsAccented: model.lastBeat?.isAccented ?? false,
                            isCompact: isCompact,
                            height: isCompact ? Self.twoRowTileHeight : singleRowTileHeight
                        ) {
                            model.toggleAccent(beat: beat)
                        }
                    }
                }
            }
        }
    }
}

struct BeatTile: View {
    let beat: Int
    let isAccented: Bool
    let isSounding: Bool
    /// Whether the beat that is sounding right now was scheduled as accented.
    let soundsAccented: Bool
    /// True on the two-row layout, whose tiles are smaller.
    let isCompact: Bool
    let height: CGFloat
    /// The fill of a tile that is neither accented nor sounding.
    var idleFill = Theme.surface
    let toggle: () -> Void

    /// How the tile looks. While it sounds it follows the beat as it was scheduled, so
    /// it always agrees with the click and the haptic; an accent toggled just before
    /// the beat shows from the next time round. Idle tiles follow the setting.
    private var looksAccented: Bool {
        isSounding ? soundsAccented : isAccented
    }

    private var fill: Color {
        if isSounding { return looksAccented ? Theme.amber : Theme.dialWhite }
        return looksAccented ? Theme.amberTint : idleFill
    }

    private var foreground: Color {
        if isSounding { return Theme.ink }
        return looksAccented ? Theme.amber : Theme.mutedDim
    }

    /// Smaller on the two-row layout and on the shorter tiles used on small phones.
    private var numberSize: CGFloat {
        if isCompact { return 20 }
        return height >= 70 ? 28 : 22
    }

    /// The number alone says the beat; the fill, border and weight say the accent.
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: isCompact ? 14 : 20, style: .continuous)
        Button(action: toggle) {
            Text("\(beat)")
                .font(.system(size: numberSize, weight: looksAccented ? .heavy : .semibold))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(fill, in: shape)
                .overlay(
                    shape.strokeBorder(Theme.amber, lineWidth: 1.5)
                        .opacity(looksAccented && !isSounding ? 1 : 0)
                )
                .shadow(color: isSounding && looksAccented ? Theme.amber.opacity(0.55) : .clear, radius: 18)
                .contentShape(TileTouchArea())
                // Lights at once on its beat; fades back to idle over 150 ms afterwards.
                .animation(isSounding ? nil : .easeOut(duration: 0.15), value: isSounding)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Beat \(beat)")
        .accessibilityValue(isAccented ? "accented" : "not accented")
        .accessibilityHint("Toggles the accent")
    }
}

/// A tile's touch area. Tiles narrower than the 44 pt minimum reach into the gaps on
/// either side, by at most half a gap so that neighbouring areas never overlap.
private struct TileTouchArea: Shape {
    static let minimumWidth: CGFloat = 44

    func path(in rect: CGRect) -> Path {
        let missing = max(0, Self.minimumWidth - rect.width)
        let reach = min(AccentTiles.tileGap / 2, missing / 2)
        return Path(rect.insetBy(dx: -reach, dy: 0))
    }
}
