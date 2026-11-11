import SwiftUI

/// The settings, sized to its content (specification 6.10). Its first setting is the click sound.
struct SettingsSheet: View {
    @Environment(MetronomeModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .title2) private var titleSize = 26.0
    @ScaledMetric(relativeTo: .body) private var rowHeight = 44.0
    /// The sheet's height. Starts near the usual height, then follows the content.
    @State private var sheetHeight: CGFloat = 520

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Settings")
                        .font(.system(size: titleSize, weight: .heavy))
                        .tracking(-0.52)
                        .foregroundStyle(Theme.dialWhite)
                    Spacer()
                    Button("Done") { dismiss() }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.amber)
                        .buttonStyle(.plain)
                }
                VStack(alignment: .leading, spacing: 10) {
                    clickSoundCard
                    Text("Use your phone's volume buttons to set how loud the click is.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, 4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 10) {
                    hapticsCard
                    Text("A tap on every beat, and a tick when you change a setting.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, 4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 20)
            // Room for the drag indicator above, and a margin below.
            .padding(.top, 32)
            .padding(.bottom, 24)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height.rounded(.up)
            } action: { height in
                sheetHeight = height
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .presentationBackground(Theme.surface)
    }

    private var clickSoundCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(text: "CLICK SOUND")
                Spacer()
                Text("Tap to hear it")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.mutedDim)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .accessibilityElement(children: .combine)
            ForEach(ClickSound.allCases, id: \.self) { sound in
                row(sound)
            }
        }
        .padding(.bottom, 4)
        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var hapticsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: "HAPTICS")
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
            Toggle(isOn: Binding(
                get: { model.hapticsEnabled },
                set: { model.setHapticsEnabled($0) }
            )) {
                Text("Haptic feedback")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.dialWhite)
            }
            .tint(Theme.amber)
            .padding(.trailing, 16)
            .frame(minHeight: rowHeight)
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.line).frame(height: 1)
            }
            .padding(.leading, 16)
        }
        .padding(.bottom, 4)
        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func row(_ sound: ClickSound) -> some View {
        let isSelected = sound == model.clickSound
        return Button {
            model.selectClickSound(sound)
        } label: {
            HStack(spacing: 12) {
                Text(sound.name)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Theme.amber : Theme.dialWhite)
                Spacer(minLength: 0)
                // A fixed slot, so the names line up whether or not a row is selected.
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.amber)
                    .opacity(isSelected ? 1 : 0)
                    .frame(width: 20)
            }
            .padding(.trailing, 16)
            .frame(minHeight: rowHeight)
            // Dividers start at the text edge, as in iOS lists.
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.line).frame(height: 1)
            }
            .padding(.leading, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(sound.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Selects this sound and plays a preview")
    }
}
