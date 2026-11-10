import SwiftUI

/// Colours and shared metrics from the v0.1 design.
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

    /// The small dot on an idle, unaccented tile.
    static let tileDot = Color(hex: 0x3A3A3F)
    /// Hint text on the selected (amber) picker option.
    static let amberShade = Color(hex: 0x3A2A08)

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
