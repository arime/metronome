import SwiftUI

/// The library's top-level header: the tab switch filling the row, and the tab's menu
/// button 12 pt after it (8.1).
struct LibraryTabHeader<MenuButton: View>: View {
    let selected: LibraryTabs.Tab
    let select: (LibraryTabs.Tab) -> Void
    @ViewBuilder let menu: MenuButton

    var body: some View {
        HStack(spacing: 12) {
            LibraryTabs(selected: selected, select: select)
                .frame(maxWidth: .infinity)
            menu
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
}

/// The line between a tab's header and its list: the search field, 10 pt, and the +, then
/// 12 pt of space and a divider (8.2, 9.1).
struct ControlsLine<Trailing: View>: View {
    @Binding var query: String
    /// What VoiceOver calls the field.
    let searchName: String
    /// The + in its 40 pt slot, or nothing.
    @ViewBuilder let trailing: Trailing

    var body: some View {
        VStack(spacing: 0) {
            // 8 pt to the +'s slot, which is 2 pt wider on each side than the +: 10 pt to
            // the + itself.
            HStack(spacing: 8) {
                SearchField(text: $query, accessibilityName: searchName)
                trailing
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            Rectangle()
                .fill(Theme.line)
                .frame(height: 1)
                .padding(.horizontal, 20)
        }
    }
}

/// A tab's search, taking the rest of the controls line. Typing narrows the list to the
/// songs or setlists whose names contain the text.
struct SearchField: View {
    @Binding var text: String
    /// `Search songs` or `Search setlists`.
    let accessibilityName: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .accessibilityHidden(true)
            TextField(accessibilityName, text: $text, prompt: Text("Search").foregroundStyle(Theme.muted))
                .font(.system(size: 15))
                .foregroundStyle(Theme.dialWhite)
                .tint(Theme.amber)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .focused($isFocused)
                .onSubmit { isFocused = false }
                .accessibilityLabel(accessibilityName)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.muted)
                        .frame(width: 36, height: 36)
                        // Drawn in a 36 pt square; the touch area is 44 pt.
                        .contentShape(Rectangle().inset(by: -4))
                }
                .buttonStyle(.plain)
                // The symbol sits at the field's end, where the padding would push it in.
                .padding(.trailing, -10)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .frame(height: 36)
        .background(Theme.surfaceRaised, in: Capsule())
    }
}

/// The amber + at the end of the controls line: New song or New setlist. It is centred in
/// a 40 pt slot at the margin, so that it stands under the header's ⋯ and on the axis of
/// the rows' ⋯ buttons, which are 40 pt at the same margin.
struct AddButton: View {
    /// `New song` or `New setlist`.
    let accessibilityName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 36, height: 36)
                .background(Theme.amber, in: Circle())
                // Drawn 36 pt; the touch area is 44 pt.
                .contentShape(Circle().inset(by: -4))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityName)
        .frame(width: 40)
    }
}

/// An order a tab's menu offers under Sort by.
protocol MenuOrder: CaseIterable, Hashable where AllCases: RandomAccessCollection {
    var title: String { get }
}

extension SongOrder: MenuOrder {}
extension SetlistOrder: MenuOrder {}

/// The Sort by group of a tab's menu, with a tick on the current order.
struct SortMenuSection<Order: MenuOrder>: View {
    @Binding var order: Order

    var body: some View {
        // Toggles, not an inline picker: a picker in a menu draws no heading. A toggle in a
        // menu is an item with the system's tick, which VoiceOver reads as selected.
        Section("Sort by") {
            ForEach(Order.allCases, id: \.self) { candidate in
                Toggle(candidate.title, isOn: Binding(
                    get: { order == candidate },
                    set: { if $0 { order = candidate } }
                ))
            }
        }
    }
}

/// The Songs tab's menu (8.6): Select, New song and Sort by, or New song alone while the
/// library is empty.
struct SongsTabMenu: View {
    @Environment(MetronomeModel.self) private var model
    let isEmpty: Bool
    let select: () -> Void
    let newSong: () -> Void

    var body: some View {
        @Bindable var model = model
        Menu {
            if !isEmpty {
                Button(action: select) {
                    Label("Select", systemImage: "checkmark.circle")
                }
            }
            Button(action: newSong) {
                Label("New song", systemImage: "plus")
            }
            if !isEmpty {
                SortMenuSection(order: $model.songOrder)
            }
        } label: {
            MoreButtonLabel()
        }
        .accessibilityLabel("More for songs")
    }
}

/// The Setlists tab's menu (8.6): New setlist and Sort by, or New setlist alone while there
/// are no setlists.
struct SetlistsTabMenu: View {
    @Environment(MetronomeModel.self) private var model
    let isEmpty: Bool
    let newSetlist: () -> Void

    var body: some View {
        @Bindable var model = model
        Menu {
            Button(action: newSetlist) {
                Label("New setlist", systemImage: "plus")
            }
            if !isEmpty {
                SortMenuSection(order: $model.setlistOrder)
            }
        } label: {
            MoreButtonLabel()
        }
        .accessibilityLabel("More for setlists")
    }
}
