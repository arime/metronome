import SwiftUI

/// The Setlists tab: every setlist, most recently used first. Tapping one opens it.
struct SetlistsTab: View {
    @Environment(MetronomeModel.self) private var model
    let showSongs: () -> Void
    let open: (UUID) -> Void
    let newSetlist: () -> Void

    /// The setlist a swipe asked to delete, while the confirmation is shown.
    @State private var deleting: Setlist?

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader {
                LibraryTabs(selected: .setlists) { tab in
                    if tab == .songs { showSongs() }
                }
            } trailing: {
                // While there are no setlists the button is in the middle instead. Its place
                // stays, so the tabs keep their width.
                PillButton(
                    text: "New setlist", symbol: "plus", look: .outlined,
                    minWidth: PillButton.tabHeaderWidth, action: newSetlist
                )
                    .hiddenInPlace(model.library.setlists.isEmpty)
            }
            if model.library.setlists.isEmpty {
                EmptyListMessage(
                    title: "No setlists yet",
                    text: nil
                ) {
                    PillButton(text: "New setlist", symbol: "plus", size: .large, action: newSetlist)
                }
            } else {
                List {
                    ForEach(model.library.setlistsByRecency) { setlist in
                        row(setlist)
                    }
                }
                .sheetList()
            }
        }
        // As with Delete setlist in a setlist's menu, deleting is confirmed first.
        .alert("Delete “\(deleting?.name ?? "")”?", isPresented: isPresented($deleting), presenting: deleting) { setlist in
            Button("Delete", role: .destructive) { model.deleteSetlist(setlist.id) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Its songs stay in the library.")
        }
    }

    /// The setlist the loaded song came from is amber, so the user sees where they are.
    private func row(_ setlist: Setlist) -> some View {
        let holdsLoaded = model.loadedSongID != nil && model.loadedFromSetlistID == setlist.id
        let count = setlist.songIDs.count
        return Button {
            open(setlist.id)
        } label: {
            HStack(spacing: 12) {
                Text(setlist.name)
                    .font(.system(size: 17, weight: holdsLoaded ? .bold : .semibold))
                    .foregroundStyle(holdsLoaded ? Theme.amber : Theme.dialWhite)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("\(count)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.muted)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.mutedDim)
            }
            .frame(height: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(setlist.name), \(count == 1 ? "1 song" : "\(count) songs")"
                + (holdsLoaded ? ", has the loaded song" : "")
        )
        .accessibilityAddTraits(.isButton)
        .sheetRow()
        // A shortcut to Delete setlist in the setlist's own menu.
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Delete") { deleting = setlist }
                .tint(Theme.red)
        }
    }
}

/// A full-width row that does something: amber by default, red for deleting.
struct ActionRow: View {
    let text: String
    let symbol: String
    var color = Theme.amber
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .bold))
                Text(text)
                    .font(.system(size: 17, weight: .semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(color)
            .frame(height: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
    }
}

/// The header of a setlist's view: back to the setlists, the name, and the setlist's menu.
/// The name is a field that looks like a title. Rename setlist in the menu makes it
/// editable in place; while the name is being typed, Done takes the menu's place.
struct SetlistHeader: View {
    @Environment(MetronomeModel.self) private var model
    let setlistID: UUID
    /// True for a setlist that was just created: the name field starts empty and focused.
    let focusesName: Bool
    /// True for a setlist just made with New setlist. While it is still Untitled the field
    /// stays empty and shows the grey placeholder, so the setlist does not look named.
    let isNew: Bool
    let back: () -> Void
    let duplicate: () -> Void
    let delete: () -> Void

    @State private var name = ""
    @FocusState private var isNameFocused: Bool

    var body: some View {
        SheetHeader {
            HStack(spacing: 2) {
                BackButton(action: back)
                nameField
                    .frame(height: 44)
            }
        } trailing: {
            if isNameFocused {
                PillButton(text: "Done") { isNameFocused = false }
            } else {
                Menu {
                    Button {
                        isNameFocused = true
                    } label: {
                        Label("Rename setlist", systemImage: "pencil")
                    }
                    Button(action: duplicate) {
                        Label("Duplicate setlist", systemImage: "plus.square.on.square")
                    }
                    Button(role: .destructive, action: delete) {
                        Label("Delete setlist", systemImage: "trash")
                    }
                } label: {
                    MoreButtonLabel(size: 36)
                }
                .accessibilityLabel("More for this setlist")
            }
        }
        .onAppear {
            name = shownName
            isNameFocused = focusesName
        }
        .onChange(of: name) { _, newName in
            if newName.count > Library.maxNameLength { name = String(newName.prefix(Library.maxNameLength)) }
        }
        // The name is saved once typing ends (Done, Return, or leaving the view), not on
        // every letter, so a name typed and then erased leaves the setlist as it was.
        .onChange(of: isNameFocused) { _, isFocused in
            if !isFocused { saveName() }
        }
        .onDisappear {
            if isNameFocused { saveName() }
        }
    }

    /// An empty name is not accepted: the setlist keeps the name it had, Untitled for a new
    /// one, and the field shows it again.
    private func saveName() {
        model.renameSetlist(setlistID, to: name)
        name = shownName
    }

    /// The setlist's name as the field shows it: empty for a new setlist still Untitled.
    private var shownName: String {
        let current = model.library.setlist(id: setlistID)?.name ?? ""
        return isNew && current == Library.defaultSetlistName ? "" : current
    }

    /// The name. It takes touches only while it is being renamed, so a tap on the title does
    /// nothing by surprise; Rename setlist in the menu is the way in.
    private var nameField: some View {
        TextField("Setlist name", text: $name, prompt: Text(Library.defaultSetlistName).foregroundStyle(Theme.mutedDim))
            .font(.system(size: 26, weight: .heavy))
            .foregroundStyle(Theme.dialWhite)
            .tint(Theme.amber)
            .submitLabel(.done)
            .focused($isNameFocused)
            .allowsHitTesting(isNameFocused)
            .accessibilityLabel("Setlist name")
    }
}

/// Ticks the library's songs in or out of a setlist, and creates new ones on the spot.
struct AddSongsView: View {
    @Environment(MetronomeModel.self) private var model
    let setlistID: UUID
    let done: () -> Void

    @State private var isNewSongShown = false

    private var setlistName: String { model.library.setlist(id: setlistID)?.name ?? "setlist" }
    private var members: [UUID] { model.library.setlist(id: setlistID)?.songIDs ?? [] }
    private var songs: [Song] { model.library.sortedSongs }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader {
                VStack(alignment: .leading, spacing: 2) {
                    SectionLabel(text: "ADD TO")
                    SheetTitle(text: setlistName)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Add to \(setlistName)")
                .accessibilityAddTraits(.isHeader)
            } trailing: {
                // Grey while the library is empty, so New song is the one amber button.
                PillButton(text: "Done", look: songs.isEmpty ? .neutral : .filled, action: done)
            }
            if songs.isEmpty {
                EmptyListMessage(
                    title: "No songs in library yet",
                    text: "Create one here, and it goes straight into \(setlistName)."
                ) {
                    PillButton(text: "New song", symbol: "plus", size: .large) { isNewSongShown = true }
                }
            } else {
                list
            }
        }
        .sheet(isPresented: $isNewSongShown) {
            SongSheet(purpose: .library(setlistID: setlistID))
                .environment(model)
        }
    }

    private var list: some View {
        List {
            ForEach(songs) { song in
                let isIncluded = members.contains(song.id)
                Button {
                    if isIncluded {
                        // No Undo here: ticking it again puts it back, at the end.
                        _ = model.removeSong(song.id, fromSetlist: setlistID)
                    } else {
                        model.setSong(song.id, inSetlist: setlistID, included: true)
                    }
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(song.name)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Theme.dialWhite)
                                .lineLimit(1)
                            Text(song.detail)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.muted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: isIncluded ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 26))
                            .foregroundStyle(isIncluded ? Theme.amber : Theme.tileDot)
                            .frame(width: 28)
                    }
                    .frame(height: 62)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(song.spokenDescription)
                .accessibilityValue(isIncluded ? "in the setlist" : "not in the setlist")
                .accessibilityAddTraits(.isButton)
                .sheetRow()
            }
            // At the end, as Add song is in the setlist itself.
            ActionRow(text: "New song", symbol: "plus") { isNewSongShown = true }
                .sheetRow()
        }
        .sheetList()
    }
}
