import SwiftUI

/// The library: a tall sheet over the metronome that lists presets, either all of
/// them or one setlist's, and leads to the setlist screens.
struct LibrarySheet: View {
    @Environment(MetronomeModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    /// The top level has two tabs, all the presets and the list of setlists. A setlist opens
    /// from its tab, and editing and adding open from the setlist.
    enum Mode {
        case presets, setlists, setlist, editing, adding
    }

    @State private var mode = Mode.presets
    /// True right after "New setlist", so the name field is ready for typing.
    @State private var focusesName = false
    /// The setlist being created, from New setlist until Done or Cancel.
    @State private var creatingID: UUID?
    /// Where Cancel goes back to: the screen New setlist was chosen on, and the setlist it showed.
    @State private var creatingReturnsTo = Mode.setlists
    @State private var setlistBeforeCreating: UUID?
    /// Where Done on the add screen goes back to: the screen it was opened from.
    @State private var addingReturnsTo = Mode.editing
    /// The last preset taken out of a setlist, while it can still be put back.
    @State private var removal: MetronomeModel.SetlistRemoval?

    var body: some View {
        VStack(spacing: 0) {
            switch mode {
            case .presets:
                presetList(setlistID: nil)
            case .setlists:
                SetlistsTab(
                    showPresets: { mode = .presets },
                    open: { id in
                        model.selectFilter(id)
                        mode = .setlist
                    },
                    newSetlist: { startCreating(with: nil) }
                )
            case .setlist:
                if let id = model.selectedSetlistID {
                    presetList(setlistID: id)
                }
            case .editing:
                if let id = model.selectedSetlistID {
                    SetlistEditor(
                        setlistID: id, isNew: creatingID == id, focusName: focusesName,
                        addPresets: { focusesName = false; addingReturnsTo = .editing; mode = .adding },
                        removed: { removal = $0 },
                        orderChanged: { removal = nil },
                        cancel: cancelCreating,
                        done: finishEditing
                    )
                }
            case .adding:
                if let id = model.selectedSetlistID {
                    AddPresetsView(setlistID: id, removed: { removal = $0 }) { mode = addingReturnsTo }
                }
            }
        }
        .padding(.top, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .bottom) {
            if let removal {
                UndoBar(text: "Removed \(removal.presetName)") {
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
        // The library opens on all the presets, so a song can be picked at once. When the
        // loaded preset came from a setlist it opens inside that setlist, where the user is.
        .onAppear {
            if model.loadedFromSetlistID != nil {
                model.showLoadedSetlist()
                mode = .setlist
            }
        }
        // Swiping the sheet away while a setlist is being created counts as Cancel.
        .onDisappear {
            if let creatingID { model.deleteSetlist(creatingID) }
            creatingID = nil
        }
        .background(Theme.surface)
        .preferredColorScheme(.dark)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(Theme.surface)
        .onChange(of: model.selectedSetlistID) { _, selected in
            // The setlist being shown or edited was deleted, here or on another device.
            if selected == nil, mode == .setlist || mode == .editing || mode == .adding { mode = .setlists }
        }
    }

    private func presetList(setlistID: UUID?) -> some View {
        PresetListView(
            setlistID: setlistID,
            showSetlists: { mode = .setlists },
            edit: { focusesName = false; mode = .editing },
            addPresets: { addingReturnsTo = .setlist; mode = .adding },
            newSetlist: { presetID in startCreating(with: presetID) },
            removed: { removal = $0 },
            close: { dismiss() }
        )
        // A duplicate takes the setlist's place, with its own rows.
        .id(setlistID)
    }

    /// Makes a setlist, optionally starting with one preset, and opens it for naming.
    private func startCreating(with presetID: UUID?) {
        creatingReturnsTo = mode
        setlistBeforeCreating = model.selectedSetlistID
        let id = model.createSetlist()
        if let presetID { model.setPreset(presetID, inSetlist: id, included: true) }
        creatingID = id
        focusesName = true
        mode = .editing
    }

    /// Done keeps the setlist, unless it is new and was left unnamed and empty.
    private func finishEditing() {
        if let creatingID {
            model.discardSetlistIfUntouched(creatingID)
            let wasKept = model.library.setlist(id: creatingID) != nil
            self.creatingID = nil
            if !wasKept {
                leaveCreating()
                return
            }
        }
        mode = .setlist
    }

    /// Cancel drops the setlist being created, whatever was put into it.
    private func cancelCreating() {
        if let creatingID { model.deleteSetlist(creatingID) }
        creatingID = nil
        leaveCreating()
    }

    /// Back to the screen New setlist was chosen on.
    private func leaveCreating() {
        if creatingReturnsTo == .setlist, let setlistBeforeCreating,
           model.library.setlist(id: setlistBeforeCreating) != nil {
            model.selectFilter(setlistBeforeCreating)
            mode = .setlist
        } else {
            mode = creatingReturnsTo == .presets ? .presets : .setlists
        }
    }
}

/// The switch at the top of the library: all the presets, or the list of setlists.
struct LibraryTabs: View {
    enum Tab { case presets, setlists }

    let selected: Tab
    let select: (Tab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            tab("Presets", .presets)
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

/// A pill button: filled amber, outlined amber, or filled dial white.
struct PillButton: View {
    enum Look { case filled, outlined }

    let text: String
    var symbol: String?
    var look = Look.filled
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol).font(.system(size: 12, weight: .heavy))
                }
                Text(text).font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(look == .filled ? Theme.ink : Theme.amber)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(look == .filled ? Theme.amber : Color.clear, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.amber, lineWidth: 1).opacity(look == .outlined ? 1 : 0))
            // Drawn 36 pt tall; the touch area is 44 pt.
            .contentShape(Capsule().inset(by: -4))
        }
        .buttonStyle(.plain)
    }
}

/// The list of presets: all of them A–Z on the Presets tab, or one setlist's in its own order.
private struct PresetListView: View {
    @Environment(MetronomeModel.self) private var model
    /// The setlist to show; nil for all the presets.
    let setlistID: UUID?
    /// Goes to the Setlists tab: from the Presets tab, or back up from a setlist.
    let showSetlists: () -> Void
    let edit: () -> Void
    let addPresets: () -> Void
    /// Makes a setlist that starts with the given preset and opens it for naming.
    let newSetlist: (UUID) -> Void
    let removed: (MetronomeModel.SetlistRemoval) -> Void
    let close: () -> Void

    @State private var isNewPresetShown = false
    @State private var renaming: Preset?
    @State private var newName = ""
    @State private var deleting: Preset?
    @State private var isDeleteSetlistShown = false

    private var setlist: Setlist? {
        setlistID.flatMap(model.library.setlist(id:))
    }

    private var presets: [Preset] {
        setlist.map { model.library.presets(inSetlist: $0.id) } ?? model.library.sortedPresets
    }

    var body: some View {
        VStack(spacing: 0) {
            if let setlist {
                // Inside a setlist: back to the list of setlists, the setlist's own menu, and
                // Edit, where presets are added, removed and reordered.
                SheetHeader {
                    HStack(spacing: 2) {
                        BackButton(action: showSetlists)
                        SheetTitle(text: setlist.name)
                    }
                } trailing: {
                    HStack(spacing: 8) {
                        Menu {
                            Button {
                                model.duplicateSetlist(setlist.id)
                            } label: {
                                Label("Duplicate setlist", systemImage: "plus.square.on.square")
                            }
                            Button(role: .destructive) {
                                isDeleteSetlistShown = true
                            } label: {
                                Label("Delete setlist", systemImage: "trash")
                            }
                        } label: {
                            MoreButtonLabel(size: 36)
                        }
                        .accessibilityLabel("More for this setlist")
                        PillButton(text: "Edit", symbol: "pencil", action: edit)
                    }
                }
            } else {
                // The top level: the tabs take the title's place.
                SheetHeader {
                    LibraryTabs(selected: .presets) { tab in
                        if tab == .setlists { showSetlists() }
                    }
                } trailing: {
                    PillButton(text: "New preset", symbol: "plus") { isNewPresetShown = true }
                }
            }
            // An empty setlist says so in the middle of the screen; a count of 0 adds nothing.
            if setlist != nil, !presets.isEmpty {
                SectionLabel(text: presets.count == 1 ? "1 PRESET" : "\(presets.count) PRESETS")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
            if presets.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .sheet(isPresented: $isNewPresetShown) {
            NewPresetSheet(purpose: .library(setlistID: setlist?.id))
                .environment(model)
        }
        .alert("Rename preset", isPresented: isPresented($renaming), presenting: renaming) { preset in
            TextField("Name", text: $newName)
            Button("Save") { model.renamePreset(preset.id, to: newName) }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete “\(deleting?.name ?? "")”?", isPresented: isPresented($deleting), presenting: deleting) { preset in
            Button("Delete", role: .destructive) { model.deletePreset(preset.id) }
            Button("Cancel", role: .cancel) {}
        } message: { preset in
            Text(deleteMessage(for: preset))
        }
        .alert("Delete “\(setlist?.name ?? "")”?", isPresented: $isDeleteSetlistShown) {
            Button("Delete", role: .destructive) {
                if let setlist { model.deleteSetlist(setlist.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its presets stay in the library.")
        }
    }

    private func deleteMessage(for preset: Preset) -> String {
        let count = model.library.setlistCount(containing: preset.id)
        switch count {
        case 0: return "It is not in any setlist."
        case 1: return "It will also be removed from 1 setlist."
        default: return "It will also be removed from \(count) setlists."
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            List {
                // Only the full library offers it, and only while there is a preset to unload.
                if setlist == nil, model.loadedPreset != nil {
                    NoPresetRow(settings: model.settings) {
                        model.clearPreset()
                        close()
                    }
                    .sheetRow()
                }
                ForEach(Array(presets.enumerated()), id: \.element.id) { index, preset in
                    PresetRow(
                        preset: preset,
                        number: setlist == nil ? nil : index + 1,
                        isLoaded: preset.id == model.loadedPresetID,
                        load: {
                            model.loadPreset(preset.id, from: setlist?.id)
                            close()
                        },
                        menu: { rowMenu(for: preset) }
                    )
                    .sheetRow()
                    // The swipe is a shortcut to the two most common items of the row's menu.
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if let setlist {
                            Button("Remove") { remove(preset, from: setlist) }
                                .tint(Color(hex: 0x3A3A3F))
                        } else {
                            Button("Delete") { deleting = preset }
                                .tint(Theme.red)
                            Button("Rename") { startRenaming(preset) }
                                .tint(Color(hex: 0x3A3A3F))
                        }
                    }
                }
            }
            .sheetList()
            // The library opens where the user is: with the loaded preset's row in view.
            // Without an anchor the list moves only as far as it must, so a row that is
            // already on screen leaves the list at its top.
            .onAppear {
                if let loaded = model.loadedPresetID { proxy.scrollTo(loaded) }
            }
        }
    }

    /// Everything that can be done with a preset, the same in every list.
    @ViewBuilder
    private func rowMenu(for preset: Preset) -> some View {
        Menu {
            ForEach(model.library.setlistsByRecency) { candidate in
                let isIncluded = candidate.presetIDs.contains(preset.id)
                Button {
                    if isIncluded {
                        remove(preset, from: candidate)
                    } else {
                        model.setPreset(preset.id, inSetlist: candidate.id, included: true)
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
                newSetlist(preset.id)
            } label: {
                Label("New setlist", systemImage: "plus")
            }
        } label: {
            Label("Add to setlist", systemImage: "text.badge.plus")
        }
        Button {
            startRenaming(preset)
        } label: {
            Label("Rename", systemImage: "pencil")
        }
        if let setlist {
            Button {
                remove(preset, from: setlist)
            } label: {
                // Without the setlist's name: with it the item wraps onto two lines.
                Label("Remove from setlist", systemImage: "minus.circle")
            }
        }
        Button(role: .destructive) {
            deleting = preset
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func startRenaming(_ preset: Preset) {
        newName = preset.name
        renaming = preset
    }

    private func remove(_ preset: Preset, from setlist: Setlist) {
        if let removal = model.removePreset(preset.id, fromSetlist: setlist.id) { removed(removal) }
    }

    private var emptyState: some View {
        Group {
            if setlist == nil {
                // The empty library needs no second button: New preset is in the header.
                EmptyListMessage(
                    title: "No presets yet",
                    text: "A preset is a tempo, time signature and accents saved under a name, usually one per song. Make one with New preset."
                ) { EmptyView() }
            } else {
                // An empty setlist gets a shortcut for filling it, past Edit.
                EmptyListMessage(
                    title: "No presets in this setlist",
                    text: "Add the presets you want to play, in the order you want them."
                ) {
                    PillButton(text: "Add preset", symbol: "plus", look: .outlined, action: addPresets)
                }
            }
        }
    }
}

/// One preset: name, tempo and time signature. Tapping it loads it; the ⋯ button at the
/// end opens the row's menu.
private struct PresetRow<MenuContent: View>: View {
    let preset: Preset
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
                        Text(preset.name)
                            .font(.system(size: 17, weight: isLoaded ? .bold : .semibold))
                            .foregroundStyle(isLoaded ? Theme.amber : Theme.dialWhite)
                            .lineLimit(1)
                        Text(preset.detail + (isLoaded ? " · loaded" : ""))
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
            .accessibilityLabel(preset.spokenDescription + (isLoaded ? ", loaded" : ""))
            .accessibilityAddTraits(.isButton)
            Menu {
                menu
            } label: {
                MoreButtonLabel()
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("More for \(preset.name)")
        }
        .frame(height: 62)
    }
}

/// The first row of the Presets tab, shown only while a preset is loaded. Tapping it unloads
/// the preset and keeps the settings. It has no menu button, so it does not pass for a preset.
private struct NoPresetRow: View {
    let settings: MetronomeSettings
    let choose: () -> Void

    var body: some View {
        Button(action: choose) {
            VStack(alignment: .leading, spacing: 3) {
                Text("No preset")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.dialWhite)
                // What happens first, then what is kept; a narrow screen cuts the end.
                Text("Unload current preset, keep \(settings.bpm) BPM · \(settings.timeSignature.rawValue)")
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
        .accessibilityLabel("No preset")
        .accessibilityHint(
            "Unloads the current preset and keeps \(settings.bpm) beats per minute, \(settings.timeSignature.rawValue)"
        )
        .accessibilityAddTraits(.isButton)
    }
}

extension Preset {
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
