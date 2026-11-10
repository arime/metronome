import SwiftUI

/// The loaded preset's name in the header. Tapping it opens the library, or,
/// when the preset has unsaved changes, a menu for saving or discarding them.
struct PresetTitle: View {
    @Environment(MetronomeModel.self) private var model
    let openLibrary: () -> Void

    @State private var isSaveAsShown = false

    var body: some View {
        Group {
            if model.isEdited {
                Menu {
                    Button("Save changes") { model.saveChanges() }
                    Button("Save as new preset") { isSaveAsShown = true }
                    Button("Discard changes") { model.discardChanges() }
                    Button("Open library", action: openLibrary)
                } label: {
                    label
                }
            } else {
                Button(action: openLibrary) { label }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(model.headerTitle), \(model.headerSubtitle)")
        .accessibilityHint(model.isEdited ? "Opens save options" : "Opens the library")
        .accessibilityAddTraits(.isButton)
        .sheet(isPresented: $isSaveAsShown) {
            NewPresetSheet(purpose: .saveAsNew)
                .environment(model)
        }
    }

    private var label: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                if model.isPlaying {
                    Circle().fill(Theme.amber).frame(width: 8, height: 8)
                }
                Text(model.headerTitle)
                    .font(.system(size: 20, weight: .heavy))
                    .tracking(-0.2)
                    .foregroundStyle(Theme.dialWhite)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.muted)
            }
            Text(model.headerSubtitle)
                .font(.system(size: 13, weight: model.isEdited ? .semibold : .medium))
                .foregroundStyle(model.isEdited ? Theme.amber : Theme.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// A 40 pt round button in the header, as used for Previous and Next.
struct HeaderRoundButton: View {
    let symbol: String
    let label: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.dialWhite)
                .frame(width: 40, height: 40)
                .background(Theme.surface, in: Circle())
                .opacity(isEnabled ? 1 : 0.35)
                // Drawn at 40 pt; the touch area reaches 2 pt further for a 44 pt target.
                .contentShape(Circle().inset(by: -2))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }
}
