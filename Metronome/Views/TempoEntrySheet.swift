import SwiftUI

/// Types a tempo: a bottom sheet with its own number keys. Opened by tapping the BPM
/// number, on the dial or in the preset sheet. Nothing changes until Set tempo is pressed.
struct TempoEntrySheet: View {
    @Environment(MetronomeModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    /// Shown dimmed in the field until the first key.
    let current: Int
    let set: (Int) -> Void

    @State private var entry = TempoEntry()
    /// The sheet's height. Starts near the usual height, then follows the content.
    @State private var sheetHeight: CGFloat = 520

    private static let keyRows = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
    private static let keyGap: CGFloat = 8

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Tempo")
                    .font(.system(size: 26, weight: .heavy))
                    .tracking(-0.52)
                    .foregroundStyle(Theme.dialWhite)
                Spacer(minLength: 12)
                Text("\(Tempo.range.lowerBound) to \(Tempo.range.upperBound) BPM")
                    .font(.system(size: 13, weight: entry.isTooHigh ? .semibold : .medium))
                    .foregroundStyle(entry.isTooHigh ? Theme.amber : Theme.muted)
            }
            field
            keypad
            // Cancel until the digits make a tempo that can be set, so there is always a
            // visible way back: before the first key, and while the digits are out of range.
            Button(action: entry.isValid ? setTempo : { dismiss() }) {
                Text(entry.isValid ? "Set tempo" : "Cancel")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(entry.isValid ? Theme.ink : Theme.dialWhite)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(entry.isValid ? Theme.amber : Color.clear, in: Capsule())
                    .overlay(Capsule().strokeBorder(entry.isValid ? Color.clear : Theme.line, lineWidth: 1))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.sideMargin)
        // Room for the drag indicator above, and a margin below the button.
        .padding(.top, 36)
        .padding(.bottom, 24)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height.rounded(.up)
        } action: { height in
            sheetHeight = height
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .preferredColorScheme(.dark)
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(Theme.surface)
    }

    /// The typed digits, or the current tempo in a dimmer colour until the first key.
    private var field: some View {
        HStack(spacing: 10) {
            Text(entry.digits.isEmpty ? "\(current)" : entry.digits)
                .font(.system(size: 64, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(entry.digits.isEmpty ? Theme.mutedDim : Theme.dialWhite)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Theme.amber)
                .frame(width: 3, height: 52)
            SectionLabel(text: "BPM", color: Theme.amber)
                .padding(.leading, 6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 92)
        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.amber, lineWidth: 1.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tempo")
        .accessibilityValue(entry.digits.isEmpty ? "Nothing typed" : "\(entry.digits) beats per minute")
    }

    private var keypad: some View {
        VStack(spacing: Self.keyGap) {
            ForEach(Self.keyRows, id: \.self) { row in
                HStack(spacing: Self.keyGap) {
                    ForEach(row, id: \.self) { digit in
                        digitKey(digit)
                    }
                }
            }
            HStack(spacing: Self.keyGap) {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .accessibilityHidden(true)
                digitKey(0)
                Button {
                    model.keypadTapped()
                    entry.deleteLast()
                } label: {
                    Image(systemName: "delete.left")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Theme.dialWhite)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete")
            }
        }
    }

    private func digitKey(_ digit: Int) -> some View {
        Button {
            model.keypadTapped()
            entry.append(digit)
        } label: {
            Text("\(digit)")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Theme.dialWhite)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func setTempo() {
        guard let bpm = entry.value, entry.isValid else { return }
        set(bpm)
        dismiss()
    }
}
