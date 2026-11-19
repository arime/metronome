import SwiftUI

/// One song: name, tempo and time signature. Tapping it loads it; holding it opens its
/// menu, when it has one. In select mode a tick ends the row, tapping the row ticks or
/// unticks it, and holding it opens nothing.
struct SongRow<MenuContent: View>: View {
    let song: Song
    let number: Int?
    let isLoaded: Bool
    /// Whether the row is ticked in select mode; nil outside it.
    let isTicked: Bool?
    /// Loads the song, or in select mode ticks or unticks it.
    let tap: () -> Void
    /// The items of the menu a long press opens (8.4); nil for a row without one.
    let menu: MenuContent?

    var body: some View {
        // Always attached, so the row keeps one identity when select mode starts or ends;
        // with no items a long press shows nothing.
        content
            .contextMenu {
                if isTicked == nil, let menu {
                    menu
                }
            }
    }

    private var content: some View {
        HStack(spacing: 12) {
            if let number {
                Text("\(number)")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(isLoaded ? Theme.amber : Theme.mutedDim)
                    .frame(width: 24, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(song.name)
                    .font(.system(size: 17, weight: isLoaded ? .bold : .semibold))
                    .foregroundStyle(isLoaded ? Theme.amber : Theme.dialWhite)
                    .lineLimit(1)
                SongDetailLine(song: song, isLoaded: isLoaded)
            }
            Spacer(minLength: 0)
            // Inside the tapped area, so that the whole row takes the tap.
            if let isTicked {
                SelectionTick(isOn: isTicked)
            }
        }
        .frame(height: 62)
        .contentShape(Rectangle())
        .rowTap(tap)
        .accessibilityLabel(song.spokenDescription + (isLoaded ? ", loaded" : ""))
        .accessibilityAddTraits(isTicked == true ? .isSelected : [])
    }
}

/// A song row's second line: tempo and time signature, a music note when the song has a
/// backing track (whether or not its file is here), and `· loaded` on the loaded song's row.
/// The same on the Songs tab, in a setlist and on the Add song screen.
struct SongDetailLine: View {
    let song: Song
    var isLoaded = false

    var body: some View {
        HStack(spacing: 5) {
            if song.track == nil {
                Text(song.detail + (isLoaded ? " · loaded" : ""))
            } else {
                Text(song.detail)
                Image(systemName: "music.note")
                    .font(.system(size: 13))
                if isLoaded {
                    Text("· loaded")
                }
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(Theme.muted)
        .lineLimit(1)
    }
}

extension Song {
    /// For example "120 BPM · 4/4".
    var detail: String {
        "\(settings.bpm) BPM · \(settings.timeSignature.rawValue)"
    }

    /// For example "Harbour Lights, 120 beats per minute, 4/4", and ", backing track" when it has one.
    var spokenDescription: String {
        "\(name), \(settings.bpm) beats per minute, \(settings.timeSignature.rawValue)"
            + (track == nil ? "" : ", backing track")
    }
}

/// The side margin of the sheet's lists, the same as the header's and the controls line's.
private let sheetRowMargin: CGFloat = 20

/// See sheetRow().
private struct SheetRow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: sheetRowMargin, bottom: 0, trailing: sheetRowMargin))
            .listRowSeparatorTint(Theme.line)
            // Separators span the row instead of starting at the row's text.
            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            // And end at the margin, in line with the header's ⋯ and the line above the list.
            // Left to the system they end at the list's own layout margin, which is 16 pt on
            // narrower phones. The row spans from margin to margin.
            .alignmentGuide(.listRowSeparatorTrailing) { $0.width }
    }
}

/// See sheetList().
private struct SheetList: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
    }
}

extension View {
    /// A library row's own action, on a tap alone. A Button in a list row also fires when a
    /// drag or a swipe that no list gesture takes ends on it, so a held row that cannot be
    /// moved, or a swipe on a row with no swipe buttons on that side, would load, tick or
    /// open what the row shows. To VoiceOver the row stays one button that does the same.
    func rowTap(_ action: @escaping () -> Void) -> some View {
        onTapGesture(perform: action)
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default) { action() }
    }

    /// A row inside one of the sheet's lists: no system background, the sheet's own margins.
    func sheetRow() -> some View {
        modifier(SheetRow())
    }

    /// A plain list on the sheet's own background.
    func sheetList() -> some View {
        modifier(SheetList())
    }

    /// A binding that is true while an optional has a value, and clears it when set to false.
    func isPresented<Value>(_ value: Binding<Value?>) -> Binding<Bool> {
        Binding(get: { value.wrappedValue != nil }, set: { if !$0 { value.wrappedValue = nil } })
    }
}
