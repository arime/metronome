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
    /// True while going deeper (a tab to its setlist, a setlist to Add songs); false going back.
    @State private var goesDeeper = true
    /// False for a switch between the tabs, which changes in place with no slide.
    @State private var slides = false
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
                    .transition(slide)
            case .setlists:
                SetlistsTab(
                    showSongs: { switchTab(to: .songs) },
                    open: { id in
                        model.selectFilter(id)
                        go(to: .setlist)
                    },
                    newSetlist: { startCreating(with: nil) }
                )
                .transition(slide)
            case .setlist:
                if let id = model.selectedSetlistID {
                    songList(setlistID: id)
                        .transition(slide)
                }
            case .adding:
                if let id = model.selectedSetlistID {
                    AddSongsView(setlistID: id) { go(to: .setlist) }
                        .transition(slide)
                }
            }
        }
        .padding(.top, 36)
        // Each level slides over the one before, as in a navigation stack.
        .clipped()
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
                // ‹ from a setlist slides back; the tab switch on the Songs tab does not.
                if setlistID == nil { switchTab(to: .setlists) } else { go(to: .setlists) }
            },
            addSongs: {
                namingID = nil
                go(to: .adding)
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
        go(to: .setlist)
    }

    private static func depth(of mode: Mode) -> Int {
        switch mode {
        case .songs, .setlists: 0
        case .setlist: 1
        case .adding: 2
        }
    }

    /// A deeper level comes in from the right and a shallower one from the left; the level
    /// left behind goes the other way.
    private var slide: AnyTransition {
        guard slides else { return .identity }
        return .asymmetric(
            insertion: .move(edge: goesDeeper ? .trailing : .leading),
            removal: .move(edge: goesDeeper ? .leading : .trailing)
        )
    }

    /// Changes level with a slide. The direction is set first and the level changed a moment
    /// later, so the view going away has already been drawn with the direction it leaves in.
    private func go(to target: Mode) {
        goesDeeper = Self.depth(of: target) > Self.depth(of: mode)
        slides = true
        Task { @MainActor in
            withAnimation(.snappy(duration: 0.3)) { mode = target }
        }
    }

    /// Switches between the Songs and Setlists tabs at once. Like go(to:), the views are
    /// first drawn without their slide, then the tab changes with every animation turned off.
    private func switchTab(to target: Mode) {
        slides = false
        Task { @MainActor in
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { mode = target }
        }
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

/// A centred title, and a line of explanation only where the title and button do not say it,
/// for a list that has nothing in it yet.
struct EmptyListMessage<Extra: View>: View {
    let title: String
    let text: String?
    @ViewBuilder let extra: Extra

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.dialWhite)
            if let text {
                Text(text)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
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
    /// At least this wide, with the text centred; nil for the text's own width.
    var minWidth: CGFloat?
    let action: () -> Void

    /// The tab headers' New song and New setlist share this width, so the tab switch beside
    /// them stays the same width on both tabs.
    static let tabHeaderWidth: CGFloat = 124

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
            .frame(minWidth: minWidth)
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
    /// What is typed in the Songs tab's search field. It starts empty each time.
    @State private var query = ""
    /// The list scrolls to the loaded song once, when it first appears, not each time a
    /// search brings it back.
    @State private var hasScrolledToLoaded = false

    private var setlist: Setlist? {
        setlistID.flatMap(model.library.setlist(id:))
    }

    private var songs: [Song] {
        setlist.map { model.library.songs(inSetlist: $0.id) } ?? model.library.sortedSongs
    }

    /// The songs in the list: on the Songs tab those matching the search, in a setlist all of them.
    private var shownSongs: [Song] {
        setlist == nil ? songs.filter { $0.matches(search: query) } : songs
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
                    PillButton(text: "New song", symbol: "plus", minWidth: PillButton.tabHeaderWidth) {
                        isNewSongShown = true
                    }
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
                controls
                if shownSongs.isEmpty {
                    EmptyListMessage(title: "No matches", text: nil) { EmptyView() }
                } else {
                    list
                }
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

    /// The line between the Songs tab's header and its list: the search field, and Unload
    /// at its right end while there is a song to unload. A setlist has no such line.
    @ViewBuilder
    private var controls: some View {
        if setlist == nil {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    SearchField(text: $query)
                    if model.loadedSong != nil {
                        UnloadSongButton(settings: model.settings) {
                            model.unloadSong()
                            close()
                        }
                    }
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

    private var list: some View {
        ScrollViewReader { proxy in
            List {
                // The numbers are a setlist's, which is never filtered, so an index here is
                // also the song's place in the setlist.
                ForEach(Array(shownSongs.enumerated()), id: \.element.id) { index, song in
                    SongRow(
                        song: song,
                        number: setlist == nil ? nil : index + 1,
                        isLoaded: model.marksLoaded(song.id, inSetlist: setlist?.id),
                        load: {
                            model.loadSong(song.id, from: setlist?.id)
                            close()
                        },
                        menu: { rowMenu(for: song) }
                    )
                    .sheetRow()
                    // On the Songs tab the swipe is a shortcut to the two most common items of
                    // the row's menu. A setlist has none: its list is in edit mode, so that the
                    // handles drag at once, and such a list takes no swipes.
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if setlist == nil {
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
            .scrollDismissesKeyboard(.immediately)
            // The library opens where the user is: with the marked row in view. Without an
            // anchor the list moves only as far as it must, so a row that is already on
            // screen leaves the list at its top.
            .onAppear {
                guard !hasScrolledToLoaded else { return }
                hasScrolledToLoaded = true
                if let marked = shownSongs.first(where: { model.marksLoaded($0.id, inSetlist: setlist?.id) }) {
                    proxy.scrollTo(marked.id)
                }
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
                    text: nil
                ) {
                    PillButton(text: "New song", symbol: "plus", size: .large) { isNewSongShown = true }
                }
            } else {
                // Adding is the only thing to do here, so its button is the amber one.
                EmptyListMessage(
                    title: "No songs in this setlist",
                    text: nil
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

/// The Songs tab's search, filling the line above the list. Typing narrows the list to the
/// songs whose names contain the text.
private struct SearchField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .accessibilityHidden(true)
            TextField("Search songs", text: $text, prompt: Text("Search").foregroundStyle(Theme.muted))
                .font(.system(size: 15))
                .foregroundStyle(Theme.dialWhite)
                .tint(Theme.amber)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .focused($isFocused)
                .onSubmit { isFocused = false }
                .accessibilityLabel("Search songs")
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

/// The grey pill above the Songs tab's list, shown only while a song is loaded. Tapping it
/// unloads the song and keeps the settings.
private struct UnloadSongButton: View {
    let settings: MetronomeSettings
    let unload: () -> Void

    var body: some View {
        PillButton(text: "Unload", symbol: "eject.fill", look: .neutral, action: unload)
            .accessibilityLabel("Unload song")
            .accessibilityHint(
                "Unloads the current song and keeps \(settings.bpm) beats per minute, \(settings.timeSignature.rawValue)"
            )
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

/// The side margin of the sheet's lists, the same as the header's and the controls line's.
private let sheetRowMargin: CGFloat = 20

extension EnvironmentValues {
    /// The width of the sheet list a row is in; 0 until it has been measured.
    @Entry var sheetListWidth: CGFloat = 0
}

/// See sheetRow().
private struct SheetRow: ViewModifier {
    @Environment(\.sheetListWidth) private var listWidth

    func body(content: Content) -> some View {
        let listWidth = listWidth
        return content
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: sheetRowMargin, bottom: 0, trailing: sheetRowMargin))
            .listRowSeparatorTint(Theme.line)
            // Separators span the row instead of starting at the row's text.
            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            // And end at the margin, in line with the ⋯ buttons and the line above the list.
            // Left to the system they end at the list's own layout margin, which is 16 pt on
            // narrower phones. The row's own width is no measure: in a setlist the drag handle
            // stands outside it. The guide counts from the row's leading edge, at the margin.
            .alignmentGuide(.listRowSeparatorTrailing) { dimensions in
                listWidth > 0 ? listWidth - 2 * sheetRowMargin : dimensions.width
            }
    }
}

/// See sheetList().
private struct SheetList: ViewModifier {
    @State private var width: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.sheetListWidth, width)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                width = newWidth
            }
    }
}

extension View {
    /// A row inside one of the sheet's lists: no system background, the sheet's own margins.
    func sheetRow() -> some View {
        modifier(SheetRow())
    }

    /// Invisible and out of reach, but still taking its space.
    func hiddenInPlace(_ isHidden: Bool) -> some View {
        opacity(isHidden ? 0 : 1)
            .allowsHitTesting(!isHidden)
            .accessibilityHidden(isHidden)
    }

    /// A plain list on the sheet's own background. It passes its width to its rows' separators.
    func sheetList() -> some View {
        modifier(SheetList())
    }

    /// A binding that is true while an optional has a value, and clears it when set to false.
    func isPresented<Value>(_ value: Binding<Value?>) -> Binding<Bool> {
        Binding(get: { value.wrappedValue != nil }, set: { if !$0 { value.wrappedValue = nil } })
    }
}
