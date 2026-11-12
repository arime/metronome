import SwiftUI

/// − / Tap tempo / +
struct TempoControls: View {
    @Environment(MetronomeModel.self) private var model
    @ScaledMetric(relativeTo: .subheadline) private var tapLabelSize = 15.0
    /// Goes up by one per tap; restarts the wait for the end of the series.
    @State private var tapCount = 0
    /// True from a tap until the series would start over, two seconds later.
    @State private var isTapping = false

    var body: some View {
        HStack(spacing: 16) {
            StepButton(symbol: "minus", label: "Slower") { model.nudgeBPM(by: -1) }
            Button {
                model.tapTempo(at: ProcessInfo.processInfo.systemUptime)
                tapCount += 1
                isTapping = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "hand.tap")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.amber)
                    // Both labels are laid out, so the pill keeps its width when they swap.
                    // They take no touches themselves: a touch on the invisible one would
                    // otherwise be lost instead of reaching the button.
                    ZStack {
                        tapLabel("Tap tempo").opacity(isTapping ? 0 : 1)
                        tapLabel("Tap again").opacity(isTapping ? 1 : 0)
                    }
                    .allowsHitTesting(false)
                }
                .padding(.horizontal, 28)
                .frame(height: 56)
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
            StepButton(symbol: "plus", label: "Faster") { model.nudgeBPM(by: 1) }
        }
    }

    private func tapLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: tapLabelSize, weight: .semibold))
            .foregroundStyle(Theme.dialWhite)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
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
