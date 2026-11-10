import SwiftUI

/// Shows the current time signature; tapping it opens the picker sheet.
struct TimeSignatureRow: View {
    @Environment(MetronomeModel.self) private var model
    @State private var isPickerShown = false

    var body: some View {
        Button {
            isPickerShown = true
        } label: {
            HStack(spacing: 12) {
                Text("Time signature")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.dialWhite)
                Spacer(minLength: 0)
                Text(model.settings.timeSignature.rawValue)
                    .font(.system(size: 24, weight: .heavy))
                    .tracking(-0.48)
                    .foregroundStyle(Theme.amber)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 16, height: 16)
            }
            .padding(.leading, 20)
            .padding(.trailing, 18)
            .frame(height: 60)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isPickerShown) {
            TimeSignaturePicker(selected: model.settings.timeSignature) { signature in
                model.selectTimeSignature(signature)
                isPickerShown = false
            }
        }
    }
}

/// The bottom sheet: a 4 × 2 grid of signatures.
private struct TimeSignaturePicker: View {
    let selected: TimeSignature
    let choose: (TimeSignature) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Time signature")
                .font(.system(size: 26, weight: .heavy))
                .tracking(-0.52)
                .foregroundStyle(Theme.dialWhite)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(TimeSignature.allCases, id: \.self) { signature in
                    option(signature)
                }
            }
        }
        .padding(.horizontal, Theme.sideMargin)
        .padding(.top, 36)
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .presentationBackground(Theme.surface)
    }

    private func option(_ signature: TimeSignature) -> some View {
        let isSelected = signature == selected
        return Button {
            choose(signature)
        } label: {
            VStack(spacing: 2) {
                Text(signature.rawValue)
                    .font(.system(size: 26, weight: isSelected ? .heavy : .bold))
                    .foregroundStyle(isSelected ? Theme.ink : Theme.dialWhite)
                Text(signature.hint)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Theme.amberShade : Theme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 84)
            .background(
                isSelected ? Theme.amber : Theme.surfaceRaised,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .shadow(color: isSelected ? Theme.amber.opacity(0.35) : .clear, radius: 14)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(signature.rawValue), \(signature.hint)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
