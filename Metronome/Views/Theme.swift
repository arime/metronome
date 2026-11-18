import SwiftUI

/// Colours and shared metrics from the v1.0 design.
enum Theme {
    static let ink = Color(hex: 0x0B0B0C)
    static let surface = Color(hex: 0x17171A)
    static let surfaceRaised = Color(hex: 0x222226)
    static let line = Color(hex: 0x2A2A2E)
    static let dialWhite = Color(hex: 0xF3EEE6)
    static let muted = Color(hex: 0x8A8780)
    static let mutedDim = Color(hex: 0x6B6963)
    static let amber = Color(hex: 0xFFB224)
    static let amberTint = Color(hex: 0x1E1A12)
    /// Remove and delete actions only.
    static let red = Color(hex: 0xE5484D)
    /// Confirmations only: the sync status dot when up to date.
    static let green = Color(hex: 0x4CC38A)

    /// Unlit ticks on the dial: 3:1 against ink, so the rest of the range can be seen.
    static let tick = Color(hex: 0x606066)

    /// The selected segment of a switch-like control, and buttons that sit on surface raised.
    static let surfaceSelected = Color(hex: 0x3A3A3F)

    static let sideMargin: CGFloat = 24
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// The small spaced-out capitals used for section labels.
struct SectionLabel: View {
    let text: String
    var color: Color = Theme.muted

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .tracking(2.34)
            .foregroundStyle(color)
    }
}

/// Closes a sheet without saving: an outlined pill with no fill, always enabled. Sits at the
/// left of the sheet's commit button; the caller gives it its width.
struct CancelPill: View {
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Cancel")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.dialWhite)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// A sheet's commit button: amber with ink text when ready. Until then it is surface raised
/// with muted text, still readable but plainly not ready, and disabled. Dimmed amber made the
/// text almost vanish.
struct CommitPill: View {
    let title: String
    let font: Font
    let height: CGFloat
    let isReady: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(font)
                .foregroundStyle(isReady ? Theme.ink : Theme.muted)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(isReady ? Theme.amber : Theme.surfaceRaised, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isReady)
    }
}
