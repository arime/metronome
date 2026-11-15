import SwiftUI

/// − / Tap tempo / +, from margin to margin: the pill fills the space between the round buttons.
struct TempoControls: View {
    nonisolated static let height: CGFloat = 60
    @Environment(MetronomeModel.self) private var model

    var body: some View {
        HStack(spacing: 12) {
            StepButton(symbol: "minus", label: "Slower", size: Self.height) { model.nudgeBPM(by: -1) }
            TapTempoPill(height: Self.height)
            StepButton(symbol: "plus", label: "Faster", size: Self.height) { model.nudgeBPM(by: 1) }
        }
    }
}

/// The outlined Tap tempo pill, with the hand icon. It fills the width it is given. While a
/// series is open, from a tap until it would start over two seconds later, the outline is
/// amber and the label changes. Used on both tempo rows and in the Sync sheet.
struct TapTempoPill: View {
    @Environment(MetronomeModel.self) private var model
    var idleLabel = "Tap tempo"
    var seriesLabel = "Tap again"
    let height: CGFloat
    var iconSpacing: CGFloat = 8
    var horizontalPadding: CGFloat = 20
    var minimumScaleFactor: CGFloat = 0.7
    @ScaledMetric(relativeTo: .subheadline) private var labelSize = 15.0
    /// Goes up by one per tap; restarts the wait for the end of the series.
    @State private var tapCount = 0
    /// True from a tap until the series would start over, two seconds later.
    @State private var isTapping = false

    var body: some View {
        Button {
            model.tapTempo(at: ProcessInfo.processInfo.systemUptime)
            tapCount += 1
            isTapping = true
        } label: {
            HStack(spacing: iconSpacing) {
                Image(systemName: "hand.tap")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.amber)
                // Both labels are laid out, so the pill keeps its width when they swap.
                // They take no touches themselves: a touch on the invisible one would
                // otherwise be lost instead of reaching the button.
                ZStack {
                    label(idleLabel).opacity(isTapping ? 0 : 1)
                    label(seriesLabel).opacity(isTapping ? 1 : 0)
                }
                .allowsHitTesting(false)
            }
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay(Capsule().strokeBorder(isTapping ? Theme.amber : Theme.line, lineWidth: isTapping ? 1.5 : 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tap tempo")
        .task(id: tapCount) {
            guard tapCount > 0 else { return }
            try? await Task.sleep(for: .seconds(TapTempo.seriesTimeout))
            if !Task.isCancelled { isTapping = false }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: labelSize, weight: .semibold))
            .foregroundStyle(Theme.dialWhite)
            .lineLimit(1)
            .minimumScaleFactor(minimumScaleFactor)
    }
}

/// A round button that steps once on tap and repeats while held:
/// after 400 ms, ten steps per second.
struct StepButton: View {
    let symbol: String
    let label: String
    var size: CGFloat = 56
    var fill: Color = Theme.surface
    let step: () -> Void

    /// True while a finger is down. Gesture state goes back to false when the
    /// gesture is cancelled as well as when it ends, so a hold can never outlive the touch.
    @GestureState private var isPressed = false

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.36, weight: .semibold))
            .foregroundStyle(Theme.dialWhite)
            .frame(width: size, height: size)
            .background(fill, in: Circle())
            .opacity(isPressed ? 0.7 : 1)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, pressed, _ in pressed = true }
            )
            // The first step is taken at once, so even the quickest tap counts.
            .onChange(of: isPressed) { _, pressed in
                if pressed { step() }
            }
            // The repeat belongs to the press itself: SwiftUI cancels this task the moment
            // the press ends or the button goes away, so it cannot be left running. A task
            // kept in the view's own state could outlive two very quick taps and keep
            // stepping until the tempo hit the end of its range.
            .task(id: isPressed) {
                guard isPressed else { return }
                do {
                    try await Task.sleep(for: .milliseconds(400))
                    while true {
                        step()
                        try await Task.sleep(for: .milliseconds(100))
                    }
                } catch {
                    // Cancelled: the press ended.
                }
            }
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, step)
    }
}
