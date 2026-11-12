import SwiftUI

/// The library: a tall sheet over the metronome that lists presets, either all of
/// them or one setlist's, and leads to the setlist screens.
struct LibrarySheet: View {
    @Environment(MetronomeModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    enum Mode {
        case presets, filters, editing, adding
    }

    @State private var mode = Mode.presets
    /// True right after "New setlist", so the name field is ready for typing.
    @State private var isNewSetlist = false
    /// The setlist made with "New setlist" in this visit; discarded if it is left untouched.
    @State private var newSetlistID: UUID?
    /// The list that was shown before "New setlist", to go back to if the new one is discarded.
    @State private var listBeforeNewSetlist: UUID?
    /// Where Done on the add screen goes back to: the screen it was opened from.
    @State private var addingReturnsTo = Mode.editing
    /// The last preset taken out of a setlist, while it can still be put back.
    @State private var removal: MetronomeModel.SetlistRemoval?

    var body: some View {
        VStack(spacing: 0) {
            switch mode {
            case .presets:
                PresetListView(
                    showFilters: { mode = .filters },
                    edit: { isNewSetlist = false; mode = .editing },
                    addPresets: { addingReturnsTo = .presets; mode = .adding },
                    newSetlist: { presetID in
                        listBeforeNewSetlist = model.selectedSetlistID
                        let id = model.createSetlist()
                        model.setPreset(presetID, inSetlist: id, included: true)
                        editNewSetlist(id)
                    },
                    removed: { removal = $0 },
                    close: { dismiss() }
                )
            case .filters:
                FilterListView(
                    done: { mode = .presets },
                    newSetlist: {
                        listBeforeNewSetlist = model.selectedSetlistID
                        editNewSetlist(model.createSetlist())
                    }
                )
            case .editing:
                if let id = model.selectedSetlistID {
                    SetlistEditor(
                        setlistID: id, focusName: isNewSetlist,
                        addPresets: { isNewSetlist = false; addingReturnsTo = .editing; mode = .adding },
                        removed: { removal = $0 },
                        orderChanged: { removal = nil },
                        done: finishEditing
                    )
                    // A duplicate takes the editor's place, with its own name.
                    .id(id)
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
        .onAppear { model.showLoadedSetlist() }
        .onDisappear(perform: discardUntouchedSetlist)
        .background(Theme.surface)
        .preferredColorScheme(.dark)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(Theme.surface)
        .onChange(of: model.selectedSetlistID) { _, selected in
            // The setlist being edited was deleted.
            if selected == nil, mode == .editing || mode == .adding { mode = .presets }
        }
    }

    private func editNewSetlist(_ id: UUID) {
        newSetlistID = id
        isNewSetlist = true
        mode = .editing
    }

    private func finishEditing() {
        discardUntouchedSetlist()
        mode = .presets
    }

    /// A setlist made in this visit and left unnamed and empty is not kept, and the
    /// library shows the list it showed before.
    private func discardUntouchedSetlist() {
        if let newSetlistID {
            model.discardSetlistIfUntouched(newSetlistID)
            if model.library.setlist(id: newSetlistID) == nil, let listBeforeNewSetlist {
                model.selectFilter(listBeforeNewSetlist)
            }
        }
        newSetlistID = nil
        listBeforeNewSetlist = nil
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

/// The list of presets: all of them A–Z, or the selected setlist's in its own order.
private struct PresetListView: View {
    @Environment(MetronomeModel.self) private var model
    let showFilters: () -> Void
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

    private var setlist: Setlist? {
        model.selectedSetlistID.flatMap(model.library.setlist(id:))
    }

    private var presets: [Preset] {
        setlist.map { model.library.presets(inSetlist: $0.id) } ?? model.library.sortedPresets
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader {
                Button(action: showFilters) {
                    SheetTitle(text: setlist?.name ?? "All presets", chevron: "chevron.down")
                }
                .buttonStyle(.plain)
                .accessibilityHint("Chooses all presets or a setlist")
            } trailing: {
                // The library's one button creates a preset. A setlist's opens Edit,
                // where presets are added, removed and reordered.
                if setlist == nil {
                    PillButton(text: "New preset", symbol: "plus") { isNewPresetShown = true }
                } else {
                    PillButton(text: "Edit", symbol: "pencil", action: edit)
                }
            }
            if setlist != nil {
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
                // Only the full library offers it; a setlist lists songs and nothing else.
                if setlist == nil {
                    NoPresetRow(isSelected: model.loadedPresetID == nil, settings: model.settings) {
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
        VStack(spacing: 16) {
            Text(setlist == nil ? "No presets in the library yet" : "No presets in this setlist")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.muted)
            // The empty library needs no second button: New preset is in the header.
            // An empty setlist gets a shortcut for filling it, past Edit.
            if setlist != nil {
                PillButton(text: "Add preset", symbol: "plus", look: .outlined, action: addPresets)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 80)
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

/// The first row of All presets. Tapping it unloads the preset and keeps the settings.
/// While nothing is loaded it is amber, shows the settings in use and has a tick.
private struct NoPresetRow: View {
    let isSelected: Bool
    let settings: MetronomeSettings
    let choose: () -> Void

    /// The same in both states: the settings the metronome keeps when the row is tapped.
    private var detail: String {
        "\(settings.bpm) BPM · \(settings.timeSignature.rawValue) · current settings"
    }

    var body: some View {
        Button(action: choose) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("No preset")
                        .font(.system(size: 17, weight: isSelected ? .bold : .semibold))
                        .foregroundStyle(isSelected ? Theme.amber : Theme.dialWhite)
                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                // The same 40 pt lane as the menu buttons below, so the rows line up.
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.amber)
                    .frame(width: 40, height: 40)
                    .opacity(isSelected ? 1 : 0)
            }
            .frame(height: 62)
            .contentShape(Rectangle())
            // The row changes state as the sheet closes; switching at once keeps the old
            // and new text from fading over each other during the slide.
            .transaction { $0.animation = nil }
        }
        .buttonStyle(.borderless)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("No preset, \(settings.bpm) beats per minute, \(settings.timeSignature.rawValue)")
        .accessibilityHint(isSelected ? "" : "Unloads the preset and keeps the current settings")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
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
