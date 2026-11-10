import SwiftUI

/// "Show": chooses what the library lists, all presets or one setlist, and creates setlists.
struct FilterListView: View {
    @Environment(MetronomeModel.self) private var model
    let done: () -> Void
    let newSetlist: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader {
                SheetTitle(text: "Show")
            } trailing: {
                PillButton(text: "New setlist", symbol: "plus", look: .outlined) {
                    model.createSetlist()
                    newSetlist()
                }
            }
            List {
                row(name: "All presets", count: model.library.presets.count, isSelected: model.selectedSetlistID == nil) {
                    model.selectFilter(nil)
                    done()
                }
                ForEach(model.library.setlistsByRecency) { setlist in
                    row(name: setlist.name, count: setlist.presetIDs.count, isSelected: model.selectedSetlistID == setlist.id) {
                        model.selectFilter(setlist.id)
                        done()
                    }
                }
            }
            .sheetList()
        }
    }

    private func row(name: String, count: Int, isSelected: Bool, choose: @escaping () -> Void) -> some View {
        Button(action: choose) {
            HStack(spacing: 12) {
                Text(name)
                    .font(.system(size: 17, weight: isSelected ? .bold : .semibold))
                    .foregroundStyle(isSelected ? Theme.amber : Theme.dialWhite)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("\(count)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.muted)
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.amber)
                    .opacity(isSelected ? 1 : 0)
                    .frame(width: 18)
            }
            .frame(height: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(count == 1 ? "1 preset" : "\(count) presets")")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
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

/// Editing a setlist: its name, which presets it has and their order, and copying or deleting it.
struct SetlistEditor: View {
    @Environment(MetronomeModel.self) private var model
    let setlistID: UUID
    /// True for a setlist that was just created: the name field starts empty and focused.
    let focusName: Bool
    let addPresets: () -> Void
    let done: () -> Void

    @State private var name = ""
    @State private var isDeleteShown = false
    @FocusState private var isNameFocused: Bool

    private var setlist: Setlist? { model.library.setlist(id: setlistID) }
    private var presets: [Preset] { model.library.presets(inSetlist: setlistID) }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader {
                TextField("Setlist name", text: $name, prompt: Text(Library.defaultSetlistName).foregroundStyle(Theme.mutedDim))
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(Theme.dialWhite)
                    .tint(Theme.amber)
                    .submitLabel(.done)
                    .focused($isNameFocused)
                    .accessibilityLabel("Setlist name")
            } trailing: {
                PillButton(text: "Done", action: done)
            }
            List {
                ForEach(presets) { preset in
                    HStack(spacing: 12) {
                        Button {
                            model.setPreset(preset.id, inSetlist: setlistID, included: false)
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
                }
                Group {
                    ActionRow(text: "Add preset", symbol: "plus", action: addPresets)
                    ActionRow(text: "Duplicate setlist", symbol: "plus.square.on.square") {
                        model.duplicateSetlist(setlistID)
                    }
                    ActionRow(text: "Delete setlist", symbol: "trash", color: Theme.red) {
                        isDeleteShown = true
                    }
                }
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
        .alert("Delete “\(setlist?.name ?? "")”?", isPresented: $isDeleteShown) {
            Button("Delete", role: .destructive) { model.deleteSetlist(setlistID) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its presets stay in the library.")
        }
    }
}

/// Ticks the library's presets in or out of a setlist, and creates new ones on the spot.
struct AddPresetsView: View {
    @Environment(MetronomeModel.self) private var model
    let setlistID: UUID
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
                        model.setPreset(preset.id, inSetlist: setlistID, included: !isIncluded)
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
