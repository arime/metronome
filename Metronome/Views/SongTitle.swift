import SwiftUI

/// The loaded song's name in the header. Tapping it always opens the library; saving
/// and reverting unsaved changes belong to the Save button beside it.
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

/// The round amber button in the header while the loaded song has unsaved changes. It
/// opens a menu with the three ways out: saving the changes into the song, saving them as
/// a new song, and going back to the saved one. After a save it shows a green tick for a
/// moment in the same place, then goes away.
struct SaveButton: View {
    @Environment(MetronomeModel.self) private var model
    @State private var isSaveAsShown = false

    static let size: CGFloat = 40

    var body: some View {
        ZStack {
            Menu {
                Button {
                    model.saveChanges()
                } label: {
                    Label("Save changes", systemImage: "square.and.arrow.down")
                }
                Button {
                    isSaveAsShown = true
                } label: {
                    Label("Save as new song", systemImage: "plus.square.on.square")
                }
                Button {
                    model.discardChanges()
                } label: {
                    // A title with the saved values on a second line; on one line the
                    // item wraps in the system menu.
                    Text("Revert")
                    if let saved = model.revertDescription {
                        Text(saved)
                    }
                    Image(systemName: "arrow.uturn.backward")
                }
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    // The symbol's tray sits low; lifted a little so it looks centred.
                    .offset(y: -1)
                    .frame(width: Self.size, height: Self.size)
                    .background(Theme.amber, in: Circle())
                    // Drawn 40 pt; the touch area is 44 pt.
                    .contentShape(Circle().inset(by: -2))
            }
            .accessibilityLabel("Unsaved changes")
            .accessibilityHint("Save, save as a new song, or revert")
            // After Save the tick takes its place; the menu stays laid out underneath,
            // unseen and untouchable, so nothing moves.
            .opacity(model.isSaveConfirmed ? 0 : 1)
            .allowsHitTesting(!model.isSaveConfirmed)
            .accessibilityHidden(model.isSaveConfirmed)

            if model.isSaveConfirmed {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Theme.green)
                    .frame(width: Self.size, height: Self.size)
                    .background(Theme.green.opacity(0.16), in: Circle())
                    .transition(.opacity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Saved")
            }
        }
        .animation(.easeOut(duration: 0.15), value: model.isSaveConfirmed)
        .onChange(of: model.isSaveConfirmed) { _, isConfirmed in
            // The change is silent on screen for VoiceOver, so it is spoken.
            if isConfirmed { AccessibilityNotification.Announcement("Saved").post() }
        }
        .sheet(isPresented: $isSaveAsShown) {
            SongSheet(purpose: .saveAsNew)
                .environment(model)
        }
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
