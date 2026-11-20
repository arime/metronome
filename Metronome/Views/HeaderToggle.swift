import SwiftUI

/// One of the header's two toggles, the Sound button and the Backing tracks switch: whether it
/// is on, its icon, whether it is dimmed, and what VoiceOver reads. Both look and read alike.
struct HeaderToggle: Equatable {
    enum Icon: Equatable {
        case speakerWithWaves, speakerWithCross, note, noteWithSlash
    }

    let label: String
    let isOn: Bool
    /// Dimmed to 40 % and taking no touches.
    let isDimmed: Bool
    var icon: Icon
    var accessibilityValue: String { isOn ? "on" : "off" }

    /// On while the click sounds. It works stopped and playing, so it is never dimmed.
    static func sound(isMuted: Bool) -> HeaderToggle {
        HeaderToggle(
            label: "Click sound", isOn: !isMuted, isDimmed: false,
            icon: isMuted ? .speakerWithCross : .speakerWithWaves
        )
    }

    /// Works only while stopped; dimmed while playing.
    static func backingTracks(isOn: Bool, isPlaying: Bool) -> HeaderToggle {
        HeaderToggle(
            label: "Backing tracks", isOn: isOn, isDimmed: isPlaying,
            icon: isOn ? .note : .noteWithSlash
        )
    }
}

/// The lines of the toggles' icons, from the board's paths in a 24 unit grid, scaled to the
/// rect they are drawn in.
struct HeaderToggleIconShape: Shape {
    enum Part {
        case speaker, waves, cross, note, slash
    }

    let part: Part

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch part {
        case .speaker:
            // M11 5 6 9H2v6h4l5 4V5z
            path.addLines([
                CGPoint(x: 11, y: 5), CGPoint(x: 6, y: 9), CGPoint(x: 2, y: 9),
                CGPoint(x: 2, y: 15), CGPoint(x: 6, y: 15), CGPoint(x: 11, y: 19),
            ])
            path.closeSubpath()
        case .waves:
            // M15.5 8.5a5 5 0 0 1 0 7 and M19 5a10 10 0 0 1 0 14: arcs bulging right, each
            // from its chord's upper end to its lower end.
            Self.addArc(to: &path, chordX: 15.5, halfChord: 3.5, radius: 5)
            Self.addArc(to: &path, chordX: 19, halfChord: 7, radius: 10)
        case .cross:
            // M16 9l6 6M22 9l-6 6
            path.move(to: CGPoint(x: 16, y: 9))
            path.addLine(to: CGPoint(x: 22, y: 15))
            path.move(to: CGPoint(x: 22, y: 9))
            path.addLine(to: CGPoint(x: 16, y: 15))
        case .note:
            // M9 18V5l11-2v13, with circles of radius 3 at (6, 18) and (17, 16).
            path.move(to: CGPoint(x: 9, y: 18))
            path.addLine(to: CGPoint(x: 9, y: 5))
            path.addLine(to: CGPoint(x: 20, y: 3))
            path.addLine(to: CGPoint(x: 20, y: 16))
            path.addEllipse(in: CGRect(x: 3, y: 15, width: 6, height: 6))
            path.addEllipse(in: CGRect(x: 14, y: 13, width: 6, height: 6))
        case .slash:
            // M3 3l18 18
            path.move(to: CGPoint(x: 3, y: 3))
            path.addLine(to: CGPoint(x: 21, y: 21))
        }
        let scale = min(rect.width, rect.height) / 24
        return path.applying(
            CGAffineTransform(translationX: rect.minX, y: rect.minY).scaledBy(x: scale, y: scale)
        )
    }

    /// A circular arc through the chord's ends at x = chordX, y = 12 ∓ halfChord, its centre
    /// to the left of the chord.
    private static func addArc(to path: inout Path, chordX: Double, halfChord: Double, radius: Double) {
        let centre = CGPoint(x: chordX - (radius * radius - halfChord * halfChord).squareRoot(), y: 12)
        let half = asin(halfChord / radius)
        path.move(to: CGPoint(x: chordX, y: 12 - halfChord))
        path.addRelativeArc(center: centre, radius: radius, startAngle: .radians(-half), delta: .radians(2 * half))
    }
}

/// A toggle's icon: 20 pt, drawn with 1.5 pt lines (1.8 grid units).
struct HeaderToggleIcon: View {
    let icon: HeaderToggle.Icon
    let colour: Color
    /// The button's fill, which cuts the gap in the note around the slash.
    let fill: Color

    private static let size: CGFloat = 20
    private static func units(_ grid: CGFloat) -> CGFloat { grid * size / 24 }
    private static let line = StrokeStyle(lineWidth: units(1.8), lineCap: .round, lineJoin: .round)

    var body: some View {
        ZStack {
            switch icon {
            case .speakerWithWaves:
                stroke(.speaker)
                stroke(.waves)
            case .speakerWithCross:
                stroke(.speaker)
                stroke(.cross)
            case .note:
                stroke(.note)
            case .noteWithSlash:
                stroke(.note)
                HeaderToggleIconShape(part: .slash)
                    .stroke(fill, style: StrokeStyle(lineWidth: Self.units(5), lineCap: .round))
                stroke(.slash)
            }
        }
        .frame(width: Self.size, height: Self.size)
    }

    private func stroke(_ part: HeaderToggleIconShape.Part) -> some View {
        HeaderToggleIconShape(part: part).stroke(colour, style: Self.line)
    }
}

/// A header toggle: a 40 pt circle, surface selected with a dial-white icon when on, surface with
/// a muted icon when off. Never amber, so the menu button's badge stays the header's only amber.
struct HeaderToggleButton: View {
    let toggle: HeaderToggle
    let action: () -> Void

    var body: some View {
        let fill = toggle.isOn ? Theme.surfaceSelected : Theme.surface
        Button(action: action) {
            HeaderToggleIcon(icon: toggle.icon, colour: toggle.isOn ? Theme.dialWhite : Theme.muted, fill: fill)
                .frame(width: 40, height: 40)
                .background(fill, in: Circle())
                // Drawn at 40 pt; the touch area reaches 2 pt further for a 44 pt target.
                .contentShape(Circle().inset(by: -2))
        }
        .buttonStyle(.plain)
        // Dimmed as one picture, so the slash's gap stays cut and the note does not show
        // through it.
        .compositingGroup()
        .opacity(toggle.isDimmed ? 0.4 : 1)
        .allowsHitTesting(!toggle.isDimmed)
        .disabled(toggle.isDimmed)
        .accessibilityLabel(toggle.label)
        .accessibilityValue(toggle.accessibilityValue)
    }
}
