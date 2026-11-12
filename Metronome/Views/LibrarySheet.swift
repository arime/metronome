import SwiftUI

/// The library: a tall sheet over the metronome that lists songs, either all of
/// them or one setlist's, and leads to the setlist screens.
struct LibrarySheet: View {
    @Environment(MetronomeModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    /// The top level has two tabs, all the songs and the list of setlists. A setlist opens
    /// from its tab, and is changed in its own view; adding songs opens from there.
    enum Mode {
        case songs, setlists, setlist, adding
    }

    @State private var mode = Mode.songs
    /// The setlist just made with New setlist, until its view has asked for a name once.
    @State private var namingID: UUID?
    /// The setlist just made with New setlist, until the user leaves it. Left Untitled and
    /// empty, with ‹ or by closing the library, it is not kept.
    @State private var creatingID: UUID?
    /// The last song taken out of a setlist, while it can still be put back.
    @State private var removal: MetronomeModel.SetlistRemoval?

    var body: some View {
        VStack(spacing: 0) {
            switch mode {
            case .songs:
                songList(setlistID: nil)
            case .setlists:
                SetlistsTab(
                    showSongs: { mode = .songs },
                    open: { id in
                        model.selectFilter(id)
                        mode = .setlist
                    },
                    newSetlist: { startCreating(with: nil) }
                )
            case .setlist:
                if let id = model.selectedSetlistID {
                    songList(setlistID: id)
                }
            case .adding:
                if let id = model.selectedSetlistID {
                    AddSongsView(setlistID: id) { mode = .setlist }
                }
            }
        }
        .padding(.top, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .bottom) {
            if let removal {
                UndoBar(text: "Removed \(removal.songName)") {
                    model.undo(removal)
                    self.removal = nil
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: removal)
        // The offer to undo goes away by itself.
        .task(id: removal) {
            guard removal != nil else { return }
            try? await Task.sleep(for: .seconds(6))
            if !Task.isCancelled { removal = nil }
        }
        // The library opens on all the songs, so a song can be picked at once. When the
        // loaded song came from a setlist it opens inside that setlist, where the user is.
        .onAppear {
            if model.loadedFromSetlistID != nil {
                model.showLoadedSetlist()
                mode = .setlist
            }
        }
        .onDisappear(perform: leaveNewSetlist)
        .background(Theme.surface)
        .preferredColorScheme(.dark)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(Theme.surface)
        .onChange(of: model.selectedSetlistID) { _, selected in
            // The setlist being shown or edited was deleted, here or on another device.
            if selected == nil, mode == .setlist || mode == .adding { mode = .setlists }
        }
    }

    private func songList(setlistID: UUID?) -> some View {
        SongListView(
            setlistID: setlistID,
            focusesName: setlistID != nil && setlistID == namingID,
            isNew: setlistID != nil && setlistID == creatingID,
            showSetlists: {
                namingID = nil
                leaveNewSetlist()
                mode = .setlists
            },
            addSongs: {
                namingID = nil
                mode = .adding
            },
            newSetlist: { songID in startCreating(with: songID) },
            removed: { removal = $0 },
            orderChanged: { removal = nil },
            close: { dismiss() }
        )
        // A duplicate takes the setlist's place, with its own rows.
        .id(setlistID)
    }

    /// Makes a setlist, optionally starting with one song, and opens it for naming.
    private func startCreating(with songID: UUID?) {
        let id = model.createSetlist()
        if let songID { model.setSong(songID, inSetlist: id, included: true) }
        namingID = id
        creatingID = id
        mode = .setlist
    }

    /// Leaving the setlist just made: it is dropped if it is still Untitled and empty. This
    /// waits a moment, so that a name being typed is saved first as the view goes away.
    private func leaveNewSetlist() {
        guard let id = creatingID else { return }
        creatingID = nil
        Task { @MainActor in model.discardSetlistIfUntouched(id) }
    }
}

/// The switch at the top of the library: all the songs, or the list of setlists.
struct LibraryTabs: View {
    enum Tab { case songs, setlists }

    let selected: Tab
    let select: (Tab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            tab("Songs", .songs)
            tab("Setlists", .setlists)
        }
        .padding(3)
        .background(Theme.surfaceRaised, in: Capsule())
    }

    private func tab(_ text: String, _ tab: Tab) -> some View {
        let isSelected = tab == selected
        return Button {
            select(tab)
        } label: {
            Text(text)
                .font(.system(size: 15, weight: isSelected ? .bold : .semibold))
                .foregroundStyle(isSelected ? Theme.dialWhite : Theme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(isSelected ? Theme.tileDot : Color.clear, in: Capsule())
                .contentShape(Rectangle().inset(by: -5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A centred title and a line of explanation, for a list that has nothing in it yet.
struct EmptyListMessage<Extra: View>: View {
    let title: String
    let text: String
    @ViewBuilder let extra: Extra

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.dialWhite)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            extra
                .padding(.top, 8)
        }
        .padding(.horizontal, 44)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 80)
    }
}

/// A plain ‹ that goes one level up.
struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.dialWhite)
                .frame(width: 28, height: 44, alignment: .leading)
                .contentShape(Rectangle().inset(by: -8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back to setlists")
    }
}

/// Offers to take back the removal that just happened, at the bottom of the sheet.
private struct UndoBar: View {
    let text: String
    let undo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.dialWhite)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button(action: undo) {
                Text("Undo")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.amber)
                    .frame(height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

/// The round ⋯ button at the end of a row or in a header; it opens a menu.
struct MoreButtonLabel: View {
    /// 40 pt at the end of a row; 36 pt beside a pill button in a header.
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: "ellipsis")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Theme.dialWhite)
            .frame(width: size, height: size)
            .background(Theme.surfaceRaised, in: Circle())
            .contentShape(Circle().inset(by: -2))
    }
}

/// The title row shared by the sheet's screens: a large title at the left and one button at the right.
struct SheetHeader<Title: View, Trailing: View>: View {
    @ViewBuilder let title: Title
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            title
            Spacer(minLength: 0)
            trailing
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
}

/// The large sheet title, optionally with a chevron when it opens something.
struct SheetTitle: View {
    let text: String
    var chevron: String?

    var body: some View {
        HStack(spacing: 8) {
            Text(text)
                .font(.system(size: 26, weight: .heavy))
                .tracking(-0.52)
                .foregroundStyle(Theme.dialWhite)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let chevron {
                Image(systemName: chevron)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.muted)
            }
        }
    }
}

/// A pill button: filled amber, outlined amber, or grey for a quieter second button.
struct PillButton: View {
    enum Look { case filled, outlined, neutral }
    /// Regular in headers; large in the middle of an empty screen.
    enum Size { case regular, large }

    let text: String
    var symbol: String?
    var look = Look.filled
    var size = Size.regular
    let action: () -> Void

    private var foreground: Color {
        switch look {
        case .filled: Theme.ink
        case .outlined: Theme.amber
        case .neutral: Theme.dialWhite
        }
    }

    private var fill: Color {
        switch look {
        case .filled: Theme.amber
        case .outlined: .clear
        case .neutral: Theme.surfaceRaised
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: size == .large ? 8 : 6) {
                if let symbol {
                    Image(systemName: symbol).font(.system(size: size == .large ? 14 : 12, weight: .heavy))
                }
                Text(text).font(.system(size: size == .large ? 16 : 14, weight: .bold))
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, size == .large ? 22 : 14)
            .frame(height: size == .large ? 48 : 36)
            .background(fill, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.amber, lineWidth: 1).opacity(look == .outlined ? 1 : 0))
            // A regular pill is drawn 36 pt tall; the touch area is 44 pt.
            .contentShape(Capsule().inset(by: size == .large ? 0 : -4))
        }
        .buttonStyle(.plain)
    }
}

/// The list of songs: all of them A–Z on the Songs tab, or one setlist's in its own order.
private struct SongListView: View {
    @Environment(MetronomeModel.self) private var model
    /// The setlist to show; nil for all the songs.
    let setlistID: UUID?
    /// True for a setlist just made with New setlist: its name is ready for typing.
    let focusesName: Bool
    /// True for a setlist just made with New setlist: until named it shows no title, only
    /// the grey Untitled placeholder.
    let isNew: Bool
    /// Goes to the Setlists tab: from the Songs tab, or back up from a setlist.
    let showSetlists: () -> Void
    let addSongs: () -> Void
    /// Makes a setlist that starts with the given song and opens it for naming.
    let newSetlist: (UUID) -> Void
    let removed: (MetronomeModel.SetlistRemoval) -> Void
    /// The setlist's order changed, so an earlier removal can no longer be put back in place.
    let orderChanged: () -> Void
    let close: () -> Void

    @State private var isNewSongShown = false
    /// The song open in the Edit song sheet.
    @State private var editingSong: Song?
    @State private var deleting: Song?
    @State private var isDeleteSetlistShown = false

    private var setlist: Setlist? {
        setlistID.flatMap(model.library.setlist(id:))
    }

    private var songs: [Song] {
        setlist.map { model.library.songs(inSetlist: $0.id) } ?? model.library.sortedSongs
    }

    var body: some View {
        VStack(spacing: 0) {
            if let setlist {
                // Inside a setlist everything is done in place: renaming in the header,
                // reordering with the handles, removing with a swipe or the row's menu, and
                // adding with the row at the end of the list.
                SetlistHeader(
                    setlistID: setlist.id,
                    focusesName: focusesName,
                    isNew: isNew,
                    back: showSetlists,
                    duplicate: { model.duplicateSetlist(setlist.id) },
                    delete: { isDeleteSetlistShown = true }
                )
            } else {
                // The top level: the tabs take the title's place.
                SheetHeader {
                    LibraryTabs(selected: .songs) { tab in
                        if tab == .setlists { showSetlists() }
                    }
                } trailing: {
                    // While the library is empty the button is in the middle instead. Its
                    // place stays, so the tabs keep their width.
                    PillButton(text: "New song", symbol: "plus") { isNewSongShown = true }
                        .hiddenInPlace(songs.isEmpty)
                }
            }
            // An empty setlist says so in the middle of the screen; a count of 0 adds nothing.
            if setlist != nil, !songs.isEmpty {
                SectionLabel(text: songs.count == 1 ? "1 SONG" : "\(songs.count) SONGS")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
            if songs.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .sheet(isPresented: $isNewSongShown) {
            SongSheet(purpose: .library(setlistID: setlist?.id))
                .environment(model)
        }
        .sheet(item: $editingSong) { song in
            SongSheet(purpose: .edit(song))
                .environment(model)
        }
        .alert("Delete “\(deleting?.name ?? "")”?", isPresented: isPresented($deleting), presenting: deleting) { song in
            Button("Delete", role: .destructive) { model.deleteSong(song.id) }
            Button("Cancel", role: .cancel) {}
        } message: { song in
            Text(deleteMessage(for: song))
        }
        .alert("Delete “\(setlist?.name ?? "")”?", isPresented: $isDeleteSetlistShown) {
            Button("Delete", role: .destructive) {
                if let setlist { model.deleteSetlist(setlist.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its songs stay in the library.")
        }
    }

    private func deleteMessage(for song: Song) -> String {
        let count = model.library.setlistCount(containing: song.id)
        switch count {
        case 0: return "It is not in any setlist."
        case 1: return "It will also be removed from 1 setlist."
        default: return "It will also be removed from \(count) setlists."
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            List {
                // Only the full library offers it, and only while there is a song to unload.
                if setlist == nil, model.loadedSong != nil {
                    NoSongRow(settings: model.settings) {
                        model.clearSong()
                        close()
                    }
                    .sheetRow()
                }
                ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                    SongRow(
                        song: song,
                        number: setlist == nil ? nil : index + 1,
                        isLoaded: song.id == model.loadedSongID,
                        load: {
                            model.loadSong(song.id, from: setlist?.id)
                            close()
                        },
                        menu: { rowMenu(for: song) }
                    )
                    .sheetRow()
                    // The swipe is a shortcut to the two most common items of the row's menu.
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if let setlist {
                            Button("Remove") { remove(song, from: setlist) }
                                .tint(Color(hex: 0x3A3A3F))
                        } else {
                            Button("Delete") { deleting = song }
                                .tint(Theme.red)
                            Button("Edit") { editingSong = song }
                                .tint(Color(hex: 0x3A3A3F))
                        }
                    }
                }
                // Only a setlist has an order of its own to change.
                .onMove(perform: moveAction)
                if setlist != nil {
                    ActionRow(text: "Add song", symbol: "plus", action: addSongs)
                        .sheetRow()
                        .moveDisabled(true)
                }
            }
            .sheetList()
            // A setlist's rows always show their drag handles; there is no separate edit mode.
            .environment(\.editMode, editMode)
            // The library opens where the user is: with the loaded song's row in view.
            // Without an anchor the list moves only as far as it must, so a row that is
            // already on screen leaves the list at its top.
            .onAppear {
                if let loaded = model.loadedSongID { proxy.scrollTo(loaded) }
            }
        }
    }

    /// Everything that can be done with a song, the same in every list.
    @ViewBuilder
    private func rowMenu(for song: Song) -> some View {
        Menu {
            ForEach(model.library.setlistsByRecency) { candidate in
                let isIncluded = candidate.songIDs.contains(song.id)
                Button {
                    if isIncluded {
                        remove(song, from: candidate)
                    } else {
                        model.setSong(song.id, inSetlist: candidate.id, included: true)
                    }
                } label: {
                    if isIncluded {
                        Label(candidate.name, systemImage: "checkmark")
                    } else {
                        Text(candidate.name)
                    }
                }
            }
            Divider()
            Button {
                newSetlist(song.id)
            } label: {
                Label("New setlist", systemImage: "plus")
            }
        } label: {
            Label("Add to setlist", systemImage: "text.badge.plus")
        }
        // Edit holds the name too, so there is no separate Rename.
        Button {
            editingSong = song
        } label: {
            Label("Edit", systemImage: "pencil")
        }
        if let setlist {
            Button {
                remove(song, from: setlist)
            } label: {
                // Without the setlist's name: with it the item wraps onto two lines.
                Label("Remove from setlist", systemImage: "minus.circle")
            }
        }
        Button(role: .destructive) {
            deleting = song
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func remove(_ song: Song, from setlist: Setlist) {
        if let removal = model.removeSong(song.id, fromSetlist: setlist.id) { removed(removal) }
    }

    private var editMode: Binding<EditMode> {
        .constant(setlist == nil ? .inactive : .active)
    }

    private var moveAction: ((IndexSet, Int) -> Void)? {
        setlist == nil ? nil : { move(from: $0, to: $1) }
    }

    private func move(from source: IndexSet, to destination: Int) {
        guard let setlist else { return }
        var order = songs.map(\.id)
        order.move(fromOffsets: source, toOffset: destination)
        model.reorderSetlist(setlist.id, to: order)
        orderChanged()
    }

    private var emptyState: some View {
        Group {
            if setlist == nil {
                // Making one is the only thing to do, so the button is here, not in the header.
                EmptyListMessage(
                    title: "No songs yet",
                    text: "A song is a tempo, time signature and accents saved under a name."
                ) {
                    PillButton(text: "New song", symbol: "plus", size: .large) { isNewSongShown = true }
                }
            } else {
                // Adding is the only thing to do here, so its button is the amber one.
                EmptyListMessage(
                    title: "No songs in this setlist",
                    text: "Add the songs you want to play, in the order you want them."
                ) {
                    PillButton(text: "Add song", symbol: "plus", size: .large, action: addSongs)
                }
            }
        }
    }
}

/// One song: name, tempo and time signature. Tapping it loads it; the ⋯ button at the
/// end opens the row's menu.
private struct SongRow<MenuContent: View>: View {
    let song: Song
    let number: Int?
    let isLoaded: Bool
    let load: () -> Void
    @ViewBuilder let menu: MenuContent

    var body: some View {
        HStack(spacing: 12) {
            Button(action: load) {
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
                        Text(song.detail + (isLoaded ? " · loaded" : ""))
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(song.spokenDescription + (isLoaded ? ", loaded" : ""))
            .accessibilityAddTraits(.isButton)
            Menu {
                menu
            } label: {
                MoreButtonLabel()
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("More for \(song.name)")
        }
        .frame(height: 62)
    }
}

/// The first row of the Songs tab, shown only while a song is loaded. Tapping it unloads
/// the song and keeps the settings. It has no menu button, so it does not pass for a song.
private struct NoSongRow: View {
    let settings: MetronomeSettings
    let choose: () -> Void

    var body: some View {
        Button(action: choose) {
            VStack(alignment: .leading, spacing: 3) {
                Text("No song")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.dialWhite)
                // What happens first, then what is kept; a narrow screen cuts the end.
                Text("Unload current song, keep \(settings.bpm) BPM · \(settings.timeSignature.rawValue)")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 62)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("No song")
        .accessibilityHint(
            "Unloads the current song and keeps \(settings.bpm) beats per minute, \(settings.timeSignature.rawValue)"
        )
        .accessibilityAddTraits(.isButton)
    }
}

extension Song {
    /// For example "120 BPM · 4/4".
    var detail: String {
        "\(settings.bpm) BPM · \(settings.timeSignature.rawValue)"
    }

    /// For example "Harbour Lights, 120 beats per minute, 4/4".
    var spokenDescription: String {
        "\(name), \(settings.bpm) beats per minute, \(settings.timeSignature.rawValue)"
    }
}

extension View {
    /// A row inside one of the sheet's lists: no system background, the sheet's own margins.
    func sheetRow() -> some View {
        listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
            .listRowSeparatorTint(Theme.line)
            // Separators span the row instead of starting at the row's text.
            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
    }

    /// Invisible and out of reach, but still taking its space.
    func hiddenInPlace(_ isHidden: Bool) -> some View {
        opacity(isHidden ? 0 : 1)
            .allowsHitTesting(!isHidden)
            .accessibilityHidden(isHidden)
    }

    /// A plain list on the sheet's own background.
    func sheetList() -> some View {
        listStyle(.plain)
            .scrollContentBackground(.hidden)
    }

    /// A binding that is true while an optional has a value, and clears it when set to false.
    func isPresented<Value>(_ value: Binding<Value?>) -> Binding<Bool> {
        Binding(get: { value.wrappedValue != nil }, set: { if !$0 { value.wrappedValue = nil } })
    }
}
