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
        .accessibilityLabel([model.headerTitle, model.headerSubtitle].compactMap { $0 }.joined(separator: ", "))
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
            if let subtitle = model.headerSubtitle {
                Text(subtitle)
                    .font(.system(size: 13, weight: model.isEdited ? .semibold : .medium))
                    .foregroundStyle(model.isEdited ? Theme.amber : Theme.muted)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// A 56 pt round button beside Start / Stop, as used for Previous and Next.
struct FooterRoundButton: View {
    let symbol: String
    let label: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.dialWhite)
                .frame(width: 56, height: 56)
                .background(Theme.surface, in: Circle())
                .opacity(isEnabled ? 1 : 0.35)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }
}

/// The gear at the far right of the header. Lighter than the round buttons, as it is used far less.
struct SettingsButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(Theme.dialWhite)
                .frame(width: 32, height: 40, alignment: .trailing)
                // Drawn in a 32 pt slot; the touch area is 44 × 44 pt.
                .contentShape(Rectangle().inset(by: -6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
    }
}
