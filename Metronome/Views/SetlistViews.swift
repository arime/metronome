import SwiftUI

/// The Setlists tab: every setlist, most recently used first. Tapping one opens it.
struct SetlistsTab: View {
    @Environment(MetronomeModel.self) private var model
    let showPresets: () -> Void
    let open: (UUID) -> Void
    let newSetlist: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader {
                LibraryTabs(selected: .setlists) { tab in
                    if tab == .presets { showPresets() }
                }
            } trailing: {
                PillButton(text: "New setlist", symbol: "plus", look: .outlined, action: newSetlist)
            }
            if model.library.setlists.isEmpty {
                EmptyListMessage(
                    title: "No setlists yet",
                    text: "A setlist is an ordered selection of presets, for a gig or a practice routine. Make one with New setlist."
                ) { EmptyView() }
            } else {
                List {
                    ForEach(model.library.setlistsByRecency) { setlist in
                        row(setlist)
                    }
                }
                .sheetList()
            }
        }
    }

    /// The setlist the loaded preset came from is amber, so the user sees where they are.
    private func row(_ setlist: Setlist) -> some View {
        let holdsLoaded = model.loadedPresetID != nil && model.loadedFromSetlistID == setlist.id
        let count = setlist.presetIDs.count
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
            "\(setlist.name), \(count == 1 ? "1 preset" : "\(count) presets")"
                + (holdsLoaded ? ", has the loaded preset" : "")
        )
        .accessibilityAddTraits(.isButton)
        .sheetRow()
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
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 24)
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

/// Creating or editing a setlist: its name, which presets it has and their order.
/// Duplicating and deleting belong to the setlist's own view, not to its editor.
struct SetlistEditor: View {
    @Environment(MetronomeModel.self) private var model
    let setlistID: UUID
    /// True while the setlist is being created: Cancel is offered beside Done.
    let isNew: Bool
    /// True for a setlist that was just created: the name field starts empty and focused.
    let focusName: Bool
    let addPresets: () -> Void
    let removed: (MetronomeModel.SetlistRemoval) -> Void
    /// The order changed, so an earlier removal can no longer be put back in place.
    let orderChanged: () -> Void
    /// Drops the setlist being created.
    let cancel: () -> Void
    let done: () -> Void

    @State private var name = ""
    @FocusState private var isNameFocused: Bool

    private var setlist: Setlist? { model.library.setlist(id: setlistID) }
    private var presets: [Preset] { model.library.presets(inSetlist: setlistID) }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader {
                HStack(spacing: 4) {
                    nameField
                    // The name looks like a title, so a pen says that it can be changed.
                    // It is hidden while the name is being typed, and while creating,
                    // where the field starts out ready for typing.
                    if !isNew, !isNameFocused {
                        Button {
                            isNameFocused = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Theme.muted)
                                .frame(width: 36, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Rename setlist")
                    }
                }
                // As tall with the pen as without, so the rows do not move when it hides.
                .frame(height: 44)
            } trailing: {
                HStack(spacing: 14) {
                    if isNew {
                        Button(action: cancel) {
                            Text("Cancel")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.dialWhite)
                                .frame(height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    PillButton(text: "Done", action: done)
                }
            }
            List {
                ForEach(presets) { preset in
                    HStack(spacing: 12) {
                        Button {
                            if let removal = model.removePreset(preset.id, fromSetlist: setlistID) { removed(removal) }
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(Theme.red, in: Circle())
                                .contentShape(Rectangle().inset(by: -10))
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Remove \(preset.name) from the setlist")
                        VStack(alignment: .leading, spacing: 3) {
                            Text(preset.name)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Theme.dialWhite)
                                .lineLimit(1)
                            Text(preset.detail)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.muted)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(preset.spokenDescription)
                        Spacer(minLength: 0)
                    }
                    .frame(height: 62)
                    .sheetRow()
                }
                .onMove { source, destination in
                    var order = presets.map(\.id)
                    order.move(fromOffsets: source, toOffset: destination)
                    model.reorderSetlist(setlistID, to: order)
                    orderChanged()
                }
                ActionRow(text: "Add preset", symbol: "plus", action: addPresets)
                    .sheetRow()
                    .moveDisabled(true)
            }
            .sheetList()
            // Always in edit mode, so every preset row shows its drag handle.
            .environment(\.editMode, .constant(.active))
        }
        .onAppear {
            let current = setlist?.name ?? ""
            name = focusName && current == Library.defaultSetlistName ? "" : current
            isNameFocused = focusName
        }
        .onChange(of: name) { _, newName in
            if newName.count > Library.maxNameLength { name = String(newName.prefix(Library.maxNameLength)) }
            // An empty name is not accepted; the setlist keeps the one it had.
            model.renameSetlist(setlistID, to: newName)
        }
    }

    /// The name, as wide as its text so that the pen sits right after it. A hidden copy of
    /// the text gives the width, and shrinks with the space when the name is long.
    private var nameField: some View {
        Text((name.isEmpty ? Library.defaultSetlistName : name) + " ")
            .font(.system(size: 26, weight: .heavy))
            .lineLimit(1)
            .hidden()
            .overlay(alignment: .leading) {
                TextField("Setlist name", text: $name, prompt: Text(Library.defaultSetlistName).foregroundStyle(Theme.mutedDim))
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(Theme.dialWhite)
                    .tint(Theme.amber)
                    .submitLabel(.done)
                    .focused($isNameFocused)
                    .accessibilityLabel("Setlist name")
            }
    }
}

/// Ticks the library's presets in or out of a setlist, and creates new ones on the spot.
struct AddPresetsView: View {
    @Environment(MetronomeModel.self) private var model
    let setlistID: UUID
    let removed: (MetronomeModel.SetlistRemoval) -> Void
    let done: () -> Void

    @State private var isNewPresetShown = false

    private var members: [UUID] { model.library.setlist(id: setlistID)?.presetIDs ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader {
                SheetTitle(text: "Add to \(model.library.setlist(id: setlistID)?.name ?? "setlist")")
            } trailing: {
                PillButton(text: "Done", action: done)
            }
            List {
                ActionRow(text: "New preset", symbol: "plus") { isNewPresetShown = true }
                    .sheetRow()
                ForEach(model.library.sortedPresets) { preset in
                    let isIncluded = members.contains(preset.id)
                    Button {
                        if isIncluded {
                            // Unticking loses the preset's place in the order, so it can be undone.
                            if let removal = model.removePreset(preset.id, fromSetlist: setlistID) { removed(removal) }
                        } else {
                            model.setPreset(preset.id, inSetlist: setlistID, included: true)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: isIncluded ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundStyle(isIncluded ? Theme.amber : Theme.mutedDim)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(preset.name)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(Theme.dialWhite)
                                    .lineLimit(1)
                                Text(preset.detail)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.muted)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(height: 62)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(preset.spokenDescription)
                    .accessibilityValue(isIncluded ? "in the setlist" : "not in the setlist")
                    .accessibilityAddTraits(.isButton)
                    .sheetRow()
                }
            }
            .sheetList()
        }
        .sheet(isPresented: $isNewPresetShown) {
            NewPresetSheet(purpose: .library(setlistID: setlistID))
                .environment(model)
        }
    }
}
