import SwiftUI

/// − / Tap tempo / +, from margin to margin: the pill fills the space between the round buttons.
/// The round buttons are as tall as the row: 60 pt, or 48 pt on a small screen (6.8).
struct TempoControls: View {
    @Environment(MetronomeModel.self) private var model
    var height: CGFloat = 60

    var body: some View {
        HStack(spacing: 12) {
            StepButton(symbol: "minus", label: "Slower", size: height) { model.nudgeBPM(by: -1) }
            TapTempoPill(height: height)
            StepButton(symbol: "plus", label: "Faster", size: height) { model.nudgeBPM(by: 1) }
        }
    }
}

/// The outlined Tap tempo pill, with the hand icon. It fills the width it is given. While a
/// series is open, from a tap until it would start over two seconds later, the outline is
/// amber and the label changes.
struct TapTempoPill: View {
    @Environment(MetronomeModel.self) private var model
    let height: CGFloat
    @ScaledMetric(relativeTo: .subheadline) private var labelSize = 15.0
    @State private var series = TapTempoSeries()

    var body: some View {
        Button {
            let time = ProcessInfo.processInfo.systemUptime
            model.tapTempo(at: time)
            series.tapped()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "hand.tap")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.amber)
                TapTempoLabels(isTapping: series.isTapping, label: label)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay(
                Capsule().strokeBorder(
                    series.isTapping ? Theme.amber : Theme.line, lineWidth: series.isTapping ? 1.5 : 1
                )
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tap tempo")
        .endsTapTempoSeries($series)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: labelSize, weight: .semibold))
            .foregroundStyle(Theme.dialWhite)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

/// Whether a tap tempo series is open, for the controls that show it: from a tap until the series
/// would start over, two seconds later. Shared by the tempo controls' pill and Sync mode's pad.
struct TapTempoSeries: Equatable {
    /// Goes up by one per tap; restarts the wait for the end of the series.
    private(set) var tapCount = 0
    private(set) var isTapping = false

    mutating func tapped() {
        tapCount += 1
        isTapping = true
    }

    mutating func ended() {
        isTapping = false
    }
}

extension View {
    /// Closes the series two seconds after its last tap, as a new tap would start a new one then.
    func endsTapTempoSeries(_ series: Binding<TapTempoSeries>) -> some View {
        task(id: series.wrappedValue.tapCount) {
            guard series.wrappedValue.tapCount > 0 else { return }
            try? await Task.sleep(for: .seconds(TapTempo.seriesTimeout))
            if !Task.isCancelled { series.wrappedValue.ended() }
        }
    }
}

/// `Tap tempo`, or `Tap again` while a series is open. Both labels are laid out, so the control
/// keeps its size when they swap. They take no touches themselves: a touch on the invisible one
/// would otherwise be lost instead of reaching the control.
struct TapTempoLabels<Label: View>: View {
    let isTapping: Bool
    let label: (String) -> Label

    var body: some View {
        ZStack {
            label("Tap tempo").opacity(isTapping ? 0 : 1)
            label("Tap again").opacity(isTapping ? 1 : 0)
        }
        .allowsHitTesting(false)
    }
}

/// A round button that steps once on tap and repeats while held:
/// after 400 ms, ten steps per second.
struct StepButton: View {
    let symbol: String
    let label: String
    var size: CGFloat = 56
    var fill: Color = Theme.surface
    /// The symbol's size; 36 % of the button's when not given.
    var symbolSize: CGFloat?
    let step: () -> Void

    /// True while a finger is down. Gesture state goes back to false when the
    /// gesture is cancelled as well as when it ends, so a hold can never outlive the touch.
    @GestureState private var isPressed = false

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: symbolSize ?? size * 0.36, weight: .semibold))
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
