import SwiftUI

/// Select mode's header (8.7): the title in the tab switch's place and Done in the menu
/// button's.
struct SelectHeader: View {
    /// `Select songs`, or the count such as `3 selected`.
    let title: String
    let done: () -> Void

    var body: some View {
        SheetHeader {
            SheetTitle(text: title)
                .accessibilityAddTraits(.isHeader)
        } trailing: {
            PillButton(text: "Done") {
                // The search field keeps its focus when the mode ends; Done puts the
                // keyboard away with it.
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
                )
                done()
            }
        }
        // As tall as the top-level header, a 40 pt row and 12 pt below it, so that the
        // controls line and the list stay in place as select mode begins and ends.
        .frame(minHeight: 40 + 12)
    }
}

/// The round tick at the end of a row that can be ticked: on the Add song screen and in
/// select mode. Filled amber when on, an empty grey ring when off.
struct SelectionTick: View {
    let isOn: Bool

    var body: some View {
        Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 26))
            .foregroundStyle(isOn ? Theme.amber : Theme.surfaceSelected)
            .frame(width: 28)
    }
}

/// The bar at the bottom of the sheet in select mode (8.7): Add to setlist and Delete for the
/// ticked songs, both dimmed while nothing is ticked.
struct SelectActionBar: View {
    let isEnabled: Bool
    /// Every setlist, most recently used first.
    let setlists: [Setlist]
    let add: (UUID) -> Void
    let newSetlist: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(setlists) { setlist in
                    Button(setlist.name) { add(setlist.id) }
                }
                if !setlists.isEmpty { Divider() }
                Button(action: newSetlist) {
                    Label("New setlist", systemImage: "plus")
                }
            } label: {
                pill("Add to setlist", color: Theme.dialWhite)
            }
            // The menu opens upwards from the bar, where the system would turn it upside
            // down; the setlists stay first and New setlist last.
            .menuOrder(.fixed)
            Button(action: delete) {
                pill("Delete", color: Theme.red)
            }
            .buttonStyle(.plain)
        }
        .opacity(isEnabled ? 1 : 0.4)
        .disabled(!isEnabled)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Theme.surface.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.line)
                .frame(height: 1)
        }
    }

    private func pill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(color)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Theme.surfaceRaised, in: Capsule())
            .contentShape(Capsule())
    }
}
