import SwiftUI

/// The library: a tall sheet over the metronome that lists songs, either all of
/// them or one setlist's, and leads to the setlist screens.
struct LibrarySheet: View {
    @Environment(MetronomeModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    /// A song to start a new setlist with: the library then opens inside that setlist, ready
    /// for naming, as New setlist in a song's menu does.
    let newSetlistWith: UUID?

    init(newSetlistWith: UUID? = nil) {
        self.newSetlistWith = newSetlistWith
    }

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
    /// True once the setlist asked for with newSetlistWith has been made, so it is made only
    /// once: the library appears again when a sheet over it closes.
    @State private var madeNewSetlist = false
    /// What is typed in the Setlists tab's search field. It is kept here, so that it stays
    /// while a setlist is open, and is emptied when the tab is switched.
    @State private var setlistQuery = ""

    var body: some View {
        VStack(spacing: 0) {
            switch mode {
            case .songs:
                songList(setlistID: nil)
                    .transition(slide)
            case .setlists:
                SetlistsTab(
                    query: $setlistQuery,
                    showSongs: {
                        setlistQuery = ""
                        switchTab(to: .songs)
                    },
                    open: { id in
                        model.selectFilter(id)
                        go(to: .setlist)
                    },
                    newSetlist: {
                        // So that the new setlist is listed when the user comes back.
                        setlistQuery = ""
                        startCreating(with: [])
                    }
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
                UndoBar(text: removal.text) {
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
        // Asked to start a setlist with a song, it opens inside the new setlist instead,
        // with no slide, as the sheet is only just appearing.
        .onAppear {
            if let songID = newSetlistWith {
                guard !madeNewSetlist else { return }
                madeNewSetlist = true
                let id = model.createSetlist()
                model.setSong(songID, inSetlist: id, included: true)
                namingID = id
                creatingID = id
                mode = .setlist
            } else if model.loadedFromSetlistID != nil {
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
            newSetlist: { songIDs in startCreating(with: songIDs) },
            removed: { removal = $0 },
            orderChanged: { removal = nil },
            selectStarted: {
                removal = nil
                // A new setlist's name has been asked for by then; the header coming back
                // after select mode does not ask again.
                namingID = nil
            },
            close: { dismiss() }
        )
        // A duplicate takes the setlist's place, with its own rows.
        .id(setlistID)
    }

    /// Makes a setlist holding the given songs, in that order, and opens it for naming.
    private func startCreating(with songIDs: [UUID]) {
        let id = model.createSetlist()
        if !songIDs.isEmpty { model.addSongs(songIDs, toSetlist: id) }
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
                .background(isSelected ? Theme.surfaceSelected : Color.clear, in: Capsule())
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

/// The round ⋯ button at the end of a row or in a header; it opens a menu. Drawn 40 pt, it
/// takes touches over 44 pt.
struct MoreButtonLabel: View {
    var body: some View {
        Image(systemName: "ellipsis")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Theme.dialWhite)
            .frame(width: 40, height: 40)
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

/// A pill button: filled amber, or grey for a quieter second button.
struct PillButton: View {
    enum Look { case filled, neutral }
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
        case .neutral: Theme.dialWhite
        }
    }

    private var fill: Color {
        switch look {
        case .filled: Theme.amber
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
            // A regular pill is drawn 36 pt tall; the touch area is 44 pt.
            .contentShape(Capsule().inset(by: size == .large ? 0 : -4))
        }
        .buttonStyle(.plain)
    }
}

/// The list of songs: all of them in the chosen order on the Songs tab, or one setlist's in
/// its own order.
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
    /// Makes a setlist that starts with the given songs and opens it for naming.
    let newSetlist: ([UUID]) -> Void
    let removed: (MetronomeModel.SetlistRemoval) -> Void
    /// The setlist's order changed, so an earlier removal can no longer be put back in place.
    let orderChanged: () -> Void
    /// Select mode began; it takes away an Undo bar that is shown (8.7).
    let selectStarted: () -> Void
    let close: () -> Void

    @State private var isNewSongShown = false
    /// The song open in the Edit song sheet.
    @State private var editingSong: Song?
    @State private var deleting: Song?
    @State private var isDeleteSetlistShown = false
    /// What is typed in the search field, the Songs tab's or the setlist's. It starts empty
    /// each time the list is shown.
    @State private var query = ""
    /// The list scrolls to the loaded song once, when it first appears, not each time a
    /// search brings it back.
    @State private var hasScrolledToLoaded = false
    /// The Songs tab's order as it was when the list appeared or an order was chosen, so
    /// that a song played meanwhile keeps its place (8.6). Nil until then.
    @State private var keptOrder: [UUID]?
    /// The ticked songs while the Songs tab or the setlist is in select mode (8.7, 8.8); nil
    /// when it is not.
    @State private var selection: SongSelection?
    /// True while the confirmation for deleting several ticked songs is shown.
    @State private var isDeletingSelection = false
    /// The ticked songs and the number of setlists holding them, taken when Delete was
    /// tapped. The confirmation reads these, not the live state, which its own Delete
    /// changes while it is still fading out.
    @State private var selectionDeletion = SelectionDeletion()

    private struct SelectionDeletion {
        var ids: Set<UUID> = []
        var setlistCount = 0
    }
    #if DEBUG
    /// True once the librarySelect screenshot scene has ticked its songs.
    private static var hasTickedSceneSongs = false
    /// True once the setlistSearch scene has typed its search or the setlistSelect scene has
    /// ticked its songs.
    private static var hasSetUpSetlistScene = false
    #endif

    private var setlist: Setlist? {
        setlistID.flatMap(model.library.setlist(id:))
    }

    private var songs: [Song] {
        if let setlist { return model.library.songs(inSetlist: setlist.id) }
        let live = model.orderedSongs
        return keptOrder.map { Library.songs(live, keptIn: $0) } ?? live
    }

    /// The songs the search finds, in a setlist each with its number in the whole setlist.
    private var rows: [(number: Int?, song: Song)] {
        if setlist != nil {
            return SetlistSearch.rows(songs, matching: query).map { ($0.number, $0.song) }
        }
        return songs.filter { $0.matches(search: query) }.map { (nil, $0) }
    }

    /// The songs select mode can tick: every song in the library on the Songs tab, the
    /// setlist's songs in a setlist.
    private var memberIDs: [UUID] {
        setlist?.songIDs ?? model.library.songs.map(\.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let selection {
                // In a setlist it takes the place of the ‹, the name and the menu button.
                SelectHeader(title: selection.title) { self.selection = nil }
            } else if let setlist {
                // Inside a setlist everything is done in place: renaming in the header,
                // reordering by dragging a row, removing with the row's swipe, its menu or in
                // select mode, and adding with the + in the controls line.
                SetlistHeader(
                    setlistID: setlist.id,
                    focusesName: focusesName,
                    isNew: isNew,
                    back: showSetlists,
                    select: setlistSelect,
                    addSongs: addSongs,
                    duplicate: { model.duplicateSetlist(setlist.id) },
                    delete: { isDeleteSetlistShown = true }
                )
            } else {
                // The top level: the tabs take the title's place.
                LibraryTabHeader(selected: .songs) { tab in
                    if tab == .setlists { showSetlists() }
                } menu: {
                    SongsTabMenu(
                        isEmpty: songs.isEmpty,
                        select: startSelecting,
                        newSong: { isNewSongShown = true }
                    )
                }
            }
            if songs.isEmpty {
                emptyState
            } else {
                controls
                if rows.isEmpty {
                    EmptyListMessage(title: "No matches", text: nil) { EmptyView() }
                } else {
                    list
                }
            }
        }
        // Over the list, which scrolls its last row clear of the bar.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let selection {
                SelectActionBar(
                    isEnabled: selection.count > 0,
                    // A setlist's own name is not offered for its songs.
                    setlists: model.library.setlistsByRecency.filter { $0.id != setlist?.id },
                    add: { addSelection(toSetlist: $0) },
                    newSetlist: newSetlistFromSelection,
                    second: secondAction
                )
            }
        }
        // The Songs tab's order is taken as the list appears and when another is chosen.
        .onAppear(perform: keepOrder)
        .onChange(of: model.songOrder) { keepOrder() }
        // A ticked song that leaves the list elsewhere drops out of the ticks: one deleted
        // from the library on the Songs tab, one taken out of the setlist in a setlist. With
        // no songs left select mode ends.
        .onChange(of: memberIDs) { _, ids in
            guard selection != nil else { return }
            if ids.isEmpty {
                selection = nil
            } else {
                selection?.keep(only: Set(ids))
            }
        }
        // The ticks never outlive the list: the library always opens with select mode off.
        .onDisappear { selection = nil }
        #if DEBUG
        .onAppear {
            // Once per launch, so that the library opens with select mode off after that.
            guard ScreenshotScene.current == .librarySelect, setlist == nil,
                  !Self.hasTickedSceneSongs
            else { return }
            Self.hasTickedSceneSongs = true
            var ticked = SongSelection()
            songs.prefix(3).forEach { ticked.toggle($0.id) }
            selection = ticked
        }
        #endif
        .sheet(isPresented: $isNewSongShown) {
            SongSheet(purpose: .library(setlistID: setlist?.id))
                .environment(model)
        }
        .sheet(item: $editingSong) { song in
            SongSheet(purpose: .edit(song))
                .environment(model)
        }
        .alert("Delete “\(deleting?.name ?? "")”?", isPresented: isPresented($deleting), presenting: deleting) { song in
            Button("Delete", role: .destructive) {
                model.deleteSong(song.id)
                // Asked from select mode with one song ticked, the delete ends it.
                selection = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: { song in
            if let message = deleteMessage(for: song) {
                Text(message)
            }
        }
        .alert(SongsDeletion.title(count: selectionDeletion.ids.count), isPresented: $isDeletingSelection) {
            Button("Delete", role: .destructive) {
                // A song deleted meanwhile on another device is skipped by deleteSongs.
                model.deleteSongs(selectionDeletion.ids)
                selection = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let message = SongsDeletion.message(setlistCount: selectionDeletion.setlistCount) {
                Text(message)
            }
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

    private func deleteMessage(for song: Song) -> String? {
        let count = model.library.setlistCount(containing: song.id)
        switch count {
        case 0: return nil
        case 1: return "It will also be removed from 1 setlist."
        default: return "It will also be removed from \(count) setlists."
        }
    }

    /// The action bar's pill beside Add to setlist: Delete on the Songs tab, Remove in a
    /// setlist (8.8).
    private var secondAction: SelectActionBar.SecondAction {
        if setlist == nil {
            SelectActionBar.SecondAction(title: "Delete", color: Theme.red, action: deleteSelection)
        } else {
            SelectActionBar.SecondAction(title: "Remove", color: Theme.dialWhite, action: removeSelection)
        }
    }

    /// Select in the setlist's menu; an empty setlist has none (8.3).
    private var setlistSelect: (() -> Void)? {
        songs.isEmpty ? nil : { startSelecting() }
    }

    /// Select mode begins with nothing ticked, on the Songs tab or in a setlist.
    private func startSelecting() {
        selection = SongSelection()
        selectStarted()
    }

    /// Adds the ticked songs not yet in the setlist to its end, in the order of the list shown
    /// (the Songs tab's or this setlist's) with the search left aside, and ends select mode.
    /// The library stays where it is.
    private func addSelection(toSetlist setlistID: UUID) {
        guard let selection else { return }
        model.addSongs(selection.ordered(in: songs), toSetlist: setlistID)
        self.selection = nil
    }

    /// Takes the ticked songs out of this setlist, ends select mode and offers Undo for them
    /// all (8.8).
    private func removeSelection() {
        guard let selection, let setlist else { return }
        let ids = selection.ordered(in: songs)
        let setlistID = setlist.id
        self.selection = nil
        if let removal = model.removeSongs(ids, fromSetlist: setlistID) { removed(removal) }
    }

    /// Makes a setlist of the ticked songs, in the order of the list shown, ends select mode
    /// and opens the setlist for naming.
    private func newSetlistFromSelection() {
        guard let selection else { return }
        let ids = selection.ordered(in: songs)
        self.selection = nil
        newSetlist(ids)
    }

    /// With one song ticked the confirmation is the row menu's own (8.7).
    private func deleteSelection() {
        guard let selection else { return }
        if selection.count == 1, let id = selection.ids.first {
            deleting = model.library.song(id: id)
        } else {
            selectionDeletion = SelectionDeletion(
                ids: selection.ids,
                setlistCount: model.library.setlistCount(containingAnyOf: selection.ids)
            )
            isDeletingSelection = true
        }
    }

    private func keepOrder() {
        guard setlist == nil else { return }
        keptOrder = model.orderedSongs.map(\.id)
    }

    /// The line between the header and the list: the search field and the +, or in select
    /// mode the search field alone. In a setlist the + opens Add song.
    @ViewBuilder
    private var controls: some View {
        if setlist != nil {
            SetlistControlsLine(query: $query, showsAdd: selection == nil, add: addSongs)
        } else {
            ControlsLine(query: $query, searchName: "Search songs") {
                if selection == nil {
                    AddButton(accessibilityName: "New song") { isNewSongShown = true }
                }
            }
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(rows, id: \.song.id) { row in
                    let song = row.song
                    SongRow(
                        song: song,
                        number: row.number,
                        isLoaded: model.marksLoaded(song.id, inSetlist: setlist?.id),
                        isTicked: selection?.contains(song.id),
                        tap: {
                            if selection != nil {
                                selection?.toggle(song.id)
                            } else {
                                model.loadSong(song.id, from: setlist?.id)
                                close()
                            }
                        },
                        menu: { rowMenu(for: song) }
                    )
                    .sheetRow()
                    // The swipe is a shortcut to items of the row's menu: Delete and Edit on the
                    // Songs tab, Remove from setlist in a setlist (8.3). Select mode has none.
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if selection == nil {
                            if let setlist {
                                Button("Remove") { remove(song, from: setlist) }
                                    .tint(Theme.surfaceSelected)
                            } else {
                                Button("Delete") { deleting = song }
                                    .tint(Theme.red)
                                Button("Edit") { editingSong = song }
                                    .tint(Theme.surfaceSelected)
                            }
                        }
                    }
                }
                // Only a setlist has an order of its own to change. Its rows are moved by
                // holding one until it lifts and dragging it.
                .onMove(perform: moveAction)
            }
            .sheetList()
            .scrollDismissesKeyboard(.immediately)
            // The library opens where the user is: with the marked row in view. Without an
            // anchor the list moves only as far as it must, so a row that is already on
            // screen leaves the list at its top.
            .onAppear {
                guard !hasScrolledToLoaded else { return }
                hasScrolledToLoaded = true
                #if DEBUG
                // In place of the scroll, which would go to a row that the search then hides.
                if setsUpSetlistScene() { return }
                #endif
                if let marked = rows.first(where: { model.marksLoaded($0.song.id, inSetlist: setlist?.id) }) {
                    proxy.scrollTo(marked.song.id)
                }
            }
        }
    }

    #if DEBUG
    /// Types `li` in the setlist's search for the setlistSearch screenshot scene, or ticks
    /// Copper Sky, Waltz for June and Slow Burn for the setlistSelect scene. Once per launch,
    /// so that the setlist opens with an empty field and select mode off after that. True
    /// when it did.
    private func setsUpSetlistScene() -> Bool {
        guard setlist != nil, !Self.hasSetUpSetlistScene else { return false }
        switch ScreenshotScene.current {
        case .setlistSearch?:
            query = "li"
        case .setlistSelect?:
            var ticked = SongSelection()
            songs.filter { ["Copper Sky", "Waltz for June", "Slow Burn"].contains($0.name) }
                .forEach { ticked.toggle($0.id) }
            selection = ticked
        default:
            return false
        }
        Self.hasSetUpSetlistScene = true
        return true
    }
    #endif

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
                newSetlist([song.id])
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

    /// Only a setlist's whole list can be reordered: while the search has text it shows part
    /// of it. Nor can select mode's.
    private var isReorderable: Bool {
        setlist != nil && SetlistSearch.allowsReorder(query: query, isSelecting: selection != nil)
    }

    /// move(from:to:) takes offsets into the whole setlist, so never those of a filtered list.
    /// Without it the rows do not lift on a long press.
    private var moveAction: ((IndexSet, Int) -> Void)? {
        isReorderable ? { move(from: $0, to: $1) } : nil
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
                // Making one is the only thing to do, so the large button stands here, and
                // there is no controls line.
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
