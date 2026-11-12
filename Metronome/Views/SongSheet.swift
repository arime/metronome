import SwiftUI

/// Creates or edits a song. A new song starts from the metronome's current settings;
/// an edited one from its own. The tempo, time signature and accents in the sheet can be
/// changed without touching the metronome.
struct SongSheet: View {
    enum Purpose {
        /// From Edit in a song row's menu: the song's name and settings are changed.
        case edit(Song)
        /// From the library: the song is created but not loaded. With a setlist,
        /// a switch offers to add it there.
        case library(setlistID: UUID?)
        /// From the title menu: the song is created and becomes the loaded one.
        case saveAsNew
    }

    @Environment(MetronomeModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let purpose: Purpose

    @State private var name = ""
    @State private var draft = MetronomeSettings()
    @State private var addToSetlist = true
    @State private var isPickerShown = false
    @State private var isTempoEntryShown = false
    /// The sheet's height. Starts near the usual height, then follows the content.
    @State private var sheetHeight: CGFloat = 560
    @FocusState private var isNameFocused: Bool

    private var setlist: Setlist? {
        if case .library(let id?) = purpose { return model.library.setlist(id: id) }
        return nil
    }

    private var editedSong: Song? {
        if case .edit(let song) = purpose { return song }
        return nil
    }

    private var canSave: Bool { Library.cleanName(name) != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(editedSong == nil ? "New song" : "Edit song")
                    .font(.system(size: 26, weight: .heavy))
                    .tracking(-0.52)
                    .foregroundStyle(Theme.dialWhite)
                TextField("Name", text: $name, prompt: Text("Name").foregroundStyle(Theme.mutedDim))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.dialWhite)
                    .tint(Theme.amber)
                    .submitLabel(.done)
                    .focused($isNameFocused)
                    .padding(.horizontal, 18)
                    .frame(height: 56)
                    .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .accessibilityLabel("Song name")
                tempo
                signature
                VStack(alignment: .leading, spacing: 14) {
                    SectionLabel(text: "ACCENTS")
                    accents
                }
                if let setlist {
                    Toggle(isOn: $addToSetlist) {
                        Text("Add to \(setlist.name)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.dialWhite)
                            .lineLimit(1)
                    }
                    .tint(Theme.amber)
                }
                Button(action: save) {
                    Text(editedSong == nil ? "Save song" : "Save changes")
                        .font(.system(size: 18, weight: .heavy))
                        // Until there is a name it is grey with muted text: still readable,
                        // but plainly not ready. Dimmed amber made the text almost vanish.
                        .foregroundStyle(canSave ? Theme.ink : Theme.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(canSave ? Theme.amber : Theme.surfaceRaised, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
            }
            .padding(.horizontal, Theme.sideMargin)
            .padding(.top, 36)
            .padding(.bottom, 24)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height.rounded(.up)
            } action: { height in
                sheetHeight = height
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollBounceBehavior(.basedOnSize)
        .background(Theme.surface)
        .preferredColorScheme(.dark)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        // A short sheet, as tall as its content; it scrolls if the keyboard leaves too little room.
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(Theme.surface)
        .onAppear {
            if let editedSong {
                // Editing starts from the song itself. The keyboard waits for a tap on
                // the name, as the change is more often to the tempo or accents.
                name = editedSong.name
                draft = editedSong.settings
            } else {
                draft = model.settings
                isNameFocused = true
            }
        }
        .onChange(of: name) { _, newName in
            if newName.count > Library.maxNameLength { name = String(newName.prefix(Library.maxNameLength)) }
        }
        .sheet(isPresented: $isPickerShown) {
            TimeSignaturePicker(selected: draft.timeSignature) { chosen in
                draft.setTimeSignature(chosen)
                isPickerShown = false
            }
        }
        .sheet(isPresented: $isTempoEntryShown) {
            TempoEntrySheet(current: draft.bpm) { draft.setBPM($0) }
                .environment(model)
        }
    }

    private var tempo: some View {
        HStack(spacing: 12) {
            StepButton(symbol: "minus", label: "Slower", size: 48, fill: Theme.surfaceRaised) {
                draft.setBPM(draft.bpm - 1)
            }
            Spacer(minLength: 0)
            // Tapping the number types a tempo, as on the dial.
            Button {
                isNameFocused = false
                isTempoEntryShown = true
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(draft.bpm)")
                        .font(.system(size: 44, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(Theme.dialWhite)
                    Text("BPM")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(Theme.muted)
                }
                .padding(.horizontal, 12)
                .frame(height: 56)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Tempo")
            .accessibilityValue("\(draft.bpm) beats per minute")
            .accessibilityHint("Type a tempo")
            .accessibilityAddTraits(.isButton)
            Spacer(minLength: 0)
            StepButton(symbol: "plus", label: "Faster", size: 48, fill: Theme.surfaceRaised) {
                draft.setBPM(draft.bpm + 1)
            }
        }
    }

    private var signature: some View {
        Button {
            isNameFocused = false
            isPickerShown = true
        } label: {
            HStack(spacing: 12) {
                Text("Time signature")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.dialWhite)
                Spacer(minLength: 0)
                Text(draft.timeSignature.rawValue)
                    .font(.system(size: 24, weight: .heavy))
                    .tracking(-0.48)
                    .foregroundStyle(Theme.amber)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 16, height: 16)
            }
            .padding(.leading, 20)
            .padding(.trailing, 18)
            .frame(height: 60)
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Time signature")
        .accessibilityValue(draft.timeSignature.rawValue)
        .accessibilityAddTraits(.isButton)
    }

    private var accents: some View {
        let rows = AccentTiles.rows(forBeats: draft.timeSignature.beatsPerBar)
        let isCompact = rows.count > 1
        return VStack(spacing: AccentTiles.rowGap) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: AccentTiles.tileGap) {
                    ForEach(row, id: \.self) { beat in
                        BeatTile(
                            beat: beat,
                            isAccented: draft.accents.contains(beat),
                            isSounding: false,
                            soundsAccented: false,
                            isCompact: isCompact,
                            height: isCompact ? AccentTiles.twoRowTileHeight : 56,
                            idleFill: Theme.surfaceRaised
                        ) {
                            draft.toggleAccent(beat: beat)
                        }
                    }
                }
            }
        }
    }

    private func save() {
        switch purpose {
        case .edit(let song):
            model.editSong(song.id, name: name, settings: draft)
        case .saveAsNew:
            model.saveAsNewSong(name: name, settings: draft)
        case .library:
            model.createSong(name: name, settings: draft, addingTo: addToSetlist ? setlist?.id : nil)
        }
        dismiss()
    }
}
