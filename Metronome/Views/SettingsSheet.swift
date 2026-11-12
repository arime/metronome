import SwiftUI

/// The settings, sized to its content up to the screen's height (specification 6.10). The title stays fixed and the cards scroll beneath it.
struct SettingsSheet: View {
    @Environment(MetronomeModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .title2) private var titleSize = 26.0
    @ScaledMetric(relativeTo: .body) private var rowHeight = 44.0
    /// The measured heights of the fixed title row and of the scrolling cards. The sheet is as
    /// tall as both together, up to the screen; beyond that the cards scroll under the title.
    @State private var headerHeight: CGFloat = 70
    @State private var contentHeight: CGFloat = 450

    var body: some View {
        VStack(spacing: 0) {
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
            .padding(.horizontal, 20)
            // Room for the drag indicator above, and a gap before the cards.
            .padding(.top, 32)
            .padding(.bottom, 18)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height.rounded(.up)
            } action: { height in
                headerHeight = height
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    clickSoundCard
                    // The footnotes keep 8 pt below them, so each group stands apart from the next.
                    footnote("Set the click volume with your phone's volume buttons.")
                    hapticsCard
                    screenCard
                    iCloudCard
                        .padding(.top, 8)
                    footnote(syncText.footer)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height.rounded(.up)
                } action: { height in
                    contentHeight = height
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .presentationDetents([.height(headerHeight + contentHeight)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .presentationBackground(Theme.surface)
    }

    private var syncText: SyncStatusText {
        SyncStatusText(status: model.syncStatus, now: Date(), calendar: .current)
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var clickSoundCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: "CLICK SOUND")
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
            ForEach(ClickSound.allCases, id: \.self) { sound in
                row(sound)
            }
        }
        .padding(.bottom, 4)
        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var hapticsCard: some View {
        plainCard {
            toggleRow("Haptic feedback", isOn: Binding(
                get: { model.hapticsEnabled },
                set: { model.setHapticsEnabled($0) }
            ))
        }
    }

    private var screenCard: some View {
        plainCard {
            toggleRow("Keep screen awake", isOn: Binding(
                get: { model.keepScreenAwake },
                set: { model.setKeepScreenAwake($0) }
            ))
        }
    }

    private var iCloudCard: some View {
        card(label: "ICLOUD") {
            toggleRow("Sync songs and setlists", isOn: Binding(
                get: { model.syncEnabled },
                set: { model.setSyncEnabled($0) }
            ))
            if let status = syncText.row {
                statusRow(status)
            }
        }
    }

    /// A raised card with a section label above its rows.
    private func card<Rows: View>(label: String, @ViewBuilder rows: () -> Rows) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: label)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
            rows()
        }
        .padding(.bottom, 4)
        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// A raised card holding a single row, with no label: the row's name says it.
    private func plainCard<Rows: View>(@ViewBuilder rows: () -> Rows) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            rows()
        }
        .padding(.vertical, 4)
        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// A row with a label and a switch.
    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.dialWhite)
        }
        .tint(Theme.amber)
        .frame(minHeight: rowHeight)
        .padding(.horizontal, 16)
    }

    /// A divider above a row, inset by the same 16 pt on both sides.
    private func divider() -> some View {
        Rectangle().fill(Theme.line).frame(height: 1)
    }

    /// The sync status: a dot, the status and, at the right, a detail. Read as one line.
    private func statusRow(_ status: SyncStatusText.Row) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color(status.dot))
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(status.text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(color(status.textTone))
            Spacer(minLength: 8)
            if let detail = status.detail {
                Text(detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.mutedDim)
            }
        }
        .frame(minHeight: rowHeight)
        .overlay(alignment: .top) { divider() }
        .padding(.horizontal, 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(status.detail.map { "\(status.text), \($0.lowercasedFirst)" } ?? status.text)
    }

    private func color(_ tone: SyncStatusText.Tone) -> Color {
        switch tone {
        case .muted: Theme.muted
        case .mutedDim: Theme.mutedDim
        case .dialWhite: Theme.dialWhite
        case .amber: Theme.amber
        case .green: Theme.green
        }
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
            .frame(minHeight: rowHeight)
            .overlay(alignment: .top) { divider() }
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(sound.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Selects this sound and plays a preview")
    }
}

private extension String {
    /// "Last synced 14:32" read after a comma: "last synced 14:32".
    var lowercasedFirst: String { prefix(1).lowercased() + dropFirst() }
}
