import SwiftUI

/// Stage mode (9.4), full screen over the metronome screen: the setlist's songs as large tiles.
struct StageModeView: View {
    @Environment(MetronomeModel.self) private var model

    private static let tileGap: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            let sideMargin = proxy.size.width < ScreenLayout.narrowWidth
                ? ScreenLayout.narrowSideMargin : Theme.sideMargin
            VStack(spacing: 0) {
                titleRow
                    .frame(height: 48)
                    .padding(.top, 6)
                    .padding(.horizontal, sideMargin)
                // The margins are inside the scroll view, so the playing tile's glow is not cut.
                ScrollView {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: Self.tileGap), count: 2),
                        spacing: Self.tileGap
                    ) {
                        ForEach(model.stageTiles) { tile in
                            StageTileView(tile: tile) { model.tapStageTile(tile.id) }
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                    .padding(.horizontal, sideMargin)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.ink.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    /// The setlist's name with `Stage mode` under it at the left, and `Done` at the right, set
    /// as Sync mode's title row.
    private var titleRow: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(setlistName)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(Theme.dialWhite)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text("Stage mode")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // One heading: the setlist's name, then "Stage mode".
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Button { model.leaveStageMode() } label: {
                Text("Done")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.amber)
                    .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!model.canLeaveStageMode)
            .opacity(model.canLeaveStageMode ? 1 : 0.4)
        }
    }

    private var setlistName: String {
        model.stageMode.flatMap { model.library.setlist(id: $0.setlistID) }?.name ?? ""
    }
}
