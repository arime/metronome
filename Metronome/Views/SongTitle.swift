import SwiftUI

/// The loaded song's name in the header. Tapping it always opens the library; saving
/// and reverting unsaved changes belong to the header menu.
struct SongTitle: View {
    @Environment(MetronomeModel.self) private var model
    let openLibrary: () -> Void

    var body: some View {
        Button(action: openLibrary) { label }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(model.headerAccessibilityLabel)
            .accessibilityHint("Opens the library")
            .accessibilityAddTraits(.isButton)
    }

    private var label: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(model.headerTitle)
                    .font(.system(size: 20, weight: .heavy))
                    .tracking(-0.2)
                    .foregroundStyle(Theme.dialWhite)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.muted)
            }
            if let subtitle = model.headerSubtitle {
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
