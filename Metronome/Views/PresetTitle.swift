import SwiftUI

/// The loaded preset's name in the header. Tapping it always opens the library; saving
/// and reverting unsaved changes belong to the save controls in the dial's gap (or, on a
/// small dial, to the Save button beside the title).
struct PresetTitle: View {
    @Environment(MetronomeModel.self) private var model
    /// False while the Save button is beside the title: it takes width from the name, and
    /// the chevron's place gives some of it back.
    var showsChevron = true
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
                if showsChevron {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.muted)
                }
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

/// The amber split pill in the header while the loaded preset has unsaved changes, on a
/// dial too small for the save controls in its gap (iPhone SE and the like). Its
/// Save part writes them into the preset in one tap; its ˅ part opens a menu with the
/// other two ways out: saving as a new preset, and going back to the saved one.
struct SaveButton: View {
    @Environment(MetronomeModel.self) private var model
    @State private var isSaveAsShown = false

    var body: some View {
        HStack(spacing: 0) {
            Button {
                model.saveChanges()
            } label: {
                Text("Save")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.leading, 16)
                    .padding(.trailing, 12)
                    .frame(height: 40)
                    // Drawn 40 pt tall; the touch area is 44 pt.
                    .contentShape(Rectangle().scale(x: 1, y: 1.1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Save changes")
            Rectangle()
                .fill(Theme.ink.opacity(0.28))
                .frame(width: 1, height: 22)
            Menu {
                Button {
                    isSaveAsShown = true
                } label: {
                    Label("Save as new preset", systemImage: "plus.square.on.square")
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
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 44, height: 40)
                    // A full-size target of its own, since a miss to the left saves.
                    // Drawn 40 pt tall; the touch area is 44 pt.
                    .contentShape(Rectangle().scale(x: 1, y: 1.1))
            }
            .accessibilityLabel("More save options")
        }
        // After Save the pill keeps its size and place and reads Saved for a moment. The
        // two parts stay laid out underneath, unseen and untouchable, so nothing moves.
        .opacity(model.isSaveConfirmed ? 0 : 1)
        .allowsHitTesting(!model.isSaveConfirmed)
        .accessibilityHidden(model.isSaveConfirmed)
        .overlay {
            if model.isSaveConfirmed {
                // Laid out like the button itself, so that nothing jumps: the word starts
                // where Save did and only gains a letter, and the tick takes the chevron's
                // place.
                HStack(spacing: 0) {
                    Text("Saved")
                        .font(.system(size: 15, weight: .bold))
                        .fixedSize()
                        .padding(.leading, 16)
                    Spacer(minLength: 0)
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .heavy))
                        .frame(width: 44)
                }
                .foregroundStyle(Theme.green)
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
        // Amber and solid while it is a button; a green tint while it only reports.
        .background(model.isSaveConfirmed ? Theme.green.opacity(0.16) : Theme.amber, in: Capsule())
        .clipShape(Capsule())
        .sheet(isPresented: $isSaveAsShown) {
            PresetSheet(purpose: .saveAsNew)
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
