import SwiftUI

/// The three save controls in the gap at the bottom of the dial, shown while the loaded
/// song has unsaved changes: Revert on the left, Save in the middle, Save as new song
/// on the right. Save is the only coloured one. On a dial too small for them, the Save
/// button in the header takes their place (DialGeometry.fitsSaveControls).
struct DialSaveControls: View {
    @Environment(MetronomeModel.self) private var model
    @State private var isSaveAsShown = false

    private var button: CGFloat { DialGeometry.saveControlsButton }

    var body: some View {
        HStack(spacing: DialGeometry.saveControlsSpacing) {
            RoundSaveControl(symbol: "arrow.uturn.backward", size: button) {
                model.discardChanges()
            }
            .accessibilityLabel("Revert")
            .accessibilityHint(model.revertDescription.map { "Goes back to \($0)" } ?? "")
            .opacity(model.isSaveConfirmed ? 0 : 1)
            .allowsHitTesting(!model.isSaveConfirmed)
            .accessibilityHidden(model.isSaveConfirmed)

            savePill

            RoundSaveControl(symbol: "plus.square.on.square", size: button) {
                isSaveAsShown = true
            }
            .accessibilityLabel("Save as new song")
            .opacity(model.isSaveConfirmed ? 0 : 1)
            .allowsHitTesting(!model.isSaveConfirmed)
            .accessibilityHidden(model.isSaveConfirmed)
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

    /// Amber and solid while it is a button. After Save it keeps its size and place and
    /// reads Saved, in green on a green tint, for a moment.
    private var savePill: some View {
        Button {
            model.saveChanges()
        } label: {
            ZStack {
                Text("Save")
                    .foregroundStyle(Theme.ink)
                    .opacity(model.isSaveConfirmed ? 0 : 1)
                HStack(spacing: 4) {
                    Text("Saved")
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .heavy))
                }
                .foregroundStyle(Theme.green)
                .opacity(model.isSaveConfirmed ? 1 : 0)
            }
            .font(.system(size: 15, weight: .bold))
            .fixedSize()
            .frame(width: DialGeometry.saveControlsPillWidth, height: button)
            .background(model.isSaveConfirmed ? Theme.green.opacity(0.16) : Theme.amber, in: Capsule())
            // Drawn 38 pt tall; the touch area is 44 pt.
            .contentShape(Rectangle().inset(by: -3))
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!model.isSaveConfirmed)
        .accessibilityLabel(model.isSaveConfirmed ? "Saved" : "Save changes")
    }
}

/// A round control beside the Save pill: dark, with a thin outline, so that it reads as
/// secondary to Save.
private struct RoundSaveControl: View {
    let symbol: String
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.dialWhite)
                .frame(width: size, height: size)
                .background(Theme.surface, in: Circle())
                .overlay(Circle().strokeBorder(Theme.line, lineWidth: 1))
                // Drawn 38 pt; the touch area is 44 × 44 pt, which leaves 2 pt between it
                // and the Save pill's.
                .contentShape(Rectangle().inset(by: -3))
        }
        .buttonStyle(.plain)
    }
}
