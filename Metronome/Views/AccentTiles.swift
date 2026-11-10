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
                            showsMark: !isCompact,
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

private struct BeatTile: View {
    let beat: Int
    let isAccented: Bool
    let isSounding: Bool
    let showsMark: Bool
    let height: CGFloat
    let toggle: () -> Void

    private var fill: Color {
        if isSounding { return isAccented ? Theme.amber : Theme.dialWhite }
        return isAccented ? Theme.amberTint : Theme.surface
    }

    private var foreground: Color {
        if isSounding { return Theme.ink }
        return isAccented ? Theme.amber : Theme.mutedDim
    }

    /// Smaller on the two-row layout and on the shorter tiles used on small phones.
    private var numberSize: CGFloat {
        if !showsMark { return 20 }
        return height >= 70 ? 28 : 22
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: showsMark ? 20 : 14, style: .continuous)
        Button(action: toggle) {
            VStack(spacing: 2) {
                if showsMark { mark }
                Text("\(beat)")
                    .font(.system(size: numberSize, weight: isAccented ? .heavy : .semibold))
                    .foregroundStyle(foreground)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(fill, in: shape)
            .overlay(
                shape.strokeBorder(Theme.amber, lineWidth: 1.5)
                    .opacity(isAccented && !isSounding ? 1 : 0)
            )
            .shadow(color: isSounding && isAccented ? Theme.amber.opacity(0.55) : .clear, radius: 18)
            .contentShape(TileTouchArea())
            // Lights at once on its beat; fades back to idle over 150 ms afterwards.
            .animation(isSounding ? nil : .easeOut(duration: 0.15), value: isSounding)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Beat \(beat)")
        .accessibilityValue(isAccented ? "accented" : "not accented")
        .accessibilityHint("Toggles the accent")
    }

    @ViewBuilder private var mark: some View {
        Group {
            if isAccented {
                Image(systemName: "chevron.up")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(foreground)
            } else {
                Circle()
                    .fill(isSounding ? Theme.ink : Theme.tileDot)
                    .frame(width: 5, height: 5)
            }
        }
        .frame(width: 18, height: 18)
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
