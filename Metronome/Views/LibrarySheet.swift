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

    var body: some View {
        VStack(spacing: 0) {
            switch mode {
            case .presets:
                PresetListView(
                    showFilters: { mode = .filters },
                    edit: { isNewSetlist = false; mode = .editing },
                    addPresets: { mode = .adding },
                    close: { dismiss() }
                )
            case .filters:
                FilterListView(
                    done: { mode = .presets },
                    newSetlist: { isNewSetlist = true; mode = .editing }
                )
            case .editing:
                if let id = model.selectedSetlistID {
                    SetlistEditor(
                        setlistID: id, focusName: isNewSetlist,
                        addPresets: { isNewSetlist = false; mode = .adding },
                        done: { mode = .presets }
                    )
                    // A duplicate takes the editor's place, with its own name.
                    .id(id)
                }
            case .adding:
                if let id = model.selectedSetlistID {
                    AddPresetsView(setlistID: id) { mode = .editing }
                }
            }
        }
        .padding(.top, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                PillButton(text: "New preset", symbol: "plus") { isNewPresetShown = true }
            }
            if setlist != nil {
                HStack {
                    SectionLabel(text: presets.count == 1 ? "1 PRESET" : "\(presets.count) PRESETS")
                    Spacer()
                    Button("Edit", action: edit)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.amber)
                        .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 6)
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
        List {
            ForEach(Array(presets.enumerated()), id: \.element.id) { index, preset in
                PresetRow(
                    preset: preset,
                    number: setlist == nil ? nil : index + 1,
                    isLoaded: preset.id == model.loadedPresetID,
                    load: {
                        model.loadPreset(preset.id, from: setlist?.id)
                        close()
                    },
                    play: {
                        model.loadPreset(preset.id, from: setlist?.id, start: true)
                        close()
                    }
                )
                .sheetRow()
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    // Renaming and deleting belong to the library; a setlist is changed in Edit.
                    if setlist == nil {
                        Button("Delete") { deleting = preset }
                            .tint(Theme.red)
                        Button("Rename") {
                            newName = preset.name
                            renaming = preset
                        }
                        .tint(Color(hex: 0x3A3A3F))
                    }
                }
            }
        }
        .sheetList()
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text(setlist == nil ? "No presets yet" : "No presets in this setlist")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.muted)
            if setlist == nil {
                PillButton(text: "New preset", symbol: "plus") { isNewPresetShown = true }
            } else {
                PillButton(text: "Add presets", symbol: "plus", action: addPresets)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 80)
    }
}

/// One preset: name, tempo and time signature, and a play button that loads and starts it.
private struct PresetRow: View {
    let preset: Preset
    let number: Int?
    let isLoaded: Bool
    let load: () -> Void
    let play: () -> Void

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
            Button(action: play) {
                Image(systemName: "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isLoaded ? Theme.ink : Theme.dialWhite)
                    .frame(width: 40, height: 40)
                    .background(isLoaded ? Theme.amber : Theme.surfaceRaised, in: Circle())
                    .contentShape(Circle().inset(by: -2))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Load and start")
        }
        .frame(height: 62)
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
