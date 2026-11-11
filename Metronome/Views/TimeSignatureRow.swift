import SwiftUI

/// Shows the current time signature; tapping it opens the picker sheet.
struct TimeSignatureRow: View {
    @Environment(MetronomeModel.self) private var model
    /// The screen's side margin, which the picker shares.
    var sideMargin: CGFloat = Theme.sideMargin
    @State private var isPickerShown = false
    @ScaledMetric(relativeTo: .body) private var labelSize = 16.0

    var body: some View {
        Button {
            isPickerShown = true
        } label: {
            HStack(spacing: 12) {
                Text("Time signature")
                    .font(.system(size: labelSize, weight: .medium))
                    .foregroundStyle(Theme.dialWhite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Time signature")
        .accessibilityValue(model.settings.timeSignature.rawValue)
        .accessibilityAddTraits(.isButton)
        .sheet(isPresented: $isPickerShown) {
            TimeSignaturePicker(selected: model.settings.timeSignature, sideMargin: sideMargin) { signature in
                model.selectTimeSignature(signature)
                isPickerShown = false
            }
        }
        #if DEBUG
        .onAppear {
            if ScreenshotScene.current == .timeSignature { isPickerShown = true }
        }
        #endif
    }
}

/// The bottom sheet: a 4 × 2 grid of signatures.
struct TimeSignaturePicker: View {
    let selected: TimeSignature
    var sideMargin: CGFloat = Theme.sideMargin
    let choose: (TimeSignature) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
    @ScaledMetric(relativeTo: .title2) private var titleSize = 26.0
    @ScaledMetric(relativeTo: .caption) private var hintSize = 12.0
    /// The sheet's height. Starts at the height for the default text size, then follows the content.
    @State private var sheetHeight: CGFloat = 300

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Time signature")
                .font(.system(size: titleSize, weight: .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .tracking(-0.52)
                .foregroundStyle(Theme.dialWhite)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(TimeSignature.allCases, id: \.self) { signature in
                    option(signature)
                }
            }
        }
        .padding(.horizontal, sideMargin)
        // Room for the drag indicator above, and a margin below the grid.
        .padding(.top, 36)
        .padding(.bottom, 30)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height.rounded(.up)
        } action: { height in
            sheetHeight = height
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .presentationDetents([.height(sheetHeight)])
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
                    .font(.system(size: hintSize, weight: isSelected ? .semibold : .regular))
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
