import SwiftUI

/// − / Tap tempo / +
struct TempoControls: View {
    @Environment(MetronomeModel.self) private var model
    @ScaledMetric(relativeTo: .subheadline) private var tapLabelSize = 15.0

    var body: some View {
        HStack(spacing: 16) {
            StepButton(symbol: "minus", label: "Slower") { model.nudgeBPM(by: -1) }
            Button {
                model.tapTempo(at: ProcessInfo.processInfo.systemUptime)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "hand.tap")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.amber)
                    Text("Tap tempo")
                        .font(.system(size: tapLabelSize, weight: .semibold))
                        .foregroundStyle(Theme.dialWhite)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 28)
                .frame(height: 56)
                .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            StepButton(symbol: "plus", label: "Faster") { model.nudgeBPM(by: 1) }
        }
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
    @State private var repeating: Task<Void, Never>?

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
            .onChange(of: isPressed) { _, pressed in
                stopRepeating()
                guard pressed else { return }
                step()
                repeating = Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    while !Task.isCancelled {
                        step()
                        try? await Task.sleep(for: .milliseconds(100))
                    }
                }
            }
            .onDisappear(perform: stopRepeating)
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, step)
    }

    private func stopRepeating() {
        repeating?.cancel()
        repeating = nil
    }
}
