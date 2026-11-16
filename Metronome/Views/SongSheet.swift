import SwiftUI
import UniformTypeIdentifiers

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
    /// What saving does to the backing track; the row shows the result.
    @State private var trackEdit = TrackEdit.keep
    /// The edited song has a track whose file is not on this device. Read once, when the sheet opens.
    @State private var isSavedTrackMissing = false
    @State private var isFilePickerShown = false
    /// The file being copied and read; while set the row is dimmed and the save button waits.
    @State private var pickToRead: URL?
    @State private var isUnplayableShown = false
    @State private var isTrackNotStoredShown = false
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

    /// Edit song also needs something changed; New song only a name. Never while a picked file is read.
    private var canSave: Bool {
        !isReadingPick
            && (editedSong.map(SongSheetChanges.init(editing:)) ?? .newSong)
                .canSave(name: name, settings: draft, track: trackEdit)
    }

    private var isReadingPick: Bool {
        pickToRead != nil
    }

    private var trackState: TrackRowState {
        TrackRowState(saved: editedSong?.track, isSavedMissing: isSavedTrackMissing, edit: trackEdit)
    }

    /// The file picked in this sheet, while there is one; its copy is the sheet's to delete.
    private var pickedTrack: PickedTrack? {
        if case .attach(let picked) = trackEdit { return picked }
        return nil
    }

    /// Changes the track edit, deleting the copy of a pick it no longer holds.
    private func setTrackEdit(_ edit: TrackEdit) {
        if let old = pickedTrack, edit != trackEdit { PickedFileReader.discard(old) }
        trackEdit = edit
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(editedSong == nil ? "New song" : "Edit song")
                    .font(.system(size: 26, weight: .heavy))
                    .tracking(-0.52)
                    .foregroundStyle(Theme.dialWhite)
                TextField("Name", text: $name, prompt: Text("Name").foregroundStyle(Theme.muted))
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
                // No heading, as on the metronome screen: the tiles say what they are.
                accents
                backingTrack
                if let setlist {
                    Toggle(isOn: $addToSetlist) {
                        Text("Add to \(setlist.name)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.dialWhite)
                            .lineLimit(1)
                    }
                    .tint(Theme.amber)
                }
                HStack(spacing: 10) {
                    CancelPill(height: 60) { dismiss() }
                        .frame(width: 116)
                    // Not ready until there is a name, and in Edit song until something changed.
                    CommitPill(
                        title: editedSong == nil ? "Save song" : "Save changes",
                        font: .system(size: 18, weight: .heavy),
                        height: 60,
                        isReady: canSave,
                        action: save
                    )
                }
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
                isSavedTrackMissing = editedSong.track != nil && !model.hasTrackFile(for: editedSong)
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
        .fileImporter(isPresented: $isFilePickerShown, allowedContentTypes: [.audio]) { result in
            switch result {
            case .success(let url):
                pickToRead = url
            case .failure(let error):
                // Closing the picker is not a failure to read a file.
                if (error as? CocoaError)?.code != .userCancelled { isUnplayableShown = true }
            }
        }
        // Copies and reads the picked file away from the main actor, as a long, mostly silent file
        // is read to its end. Closing the sheet cancels this; a copy that arrives then is deleted.
        .task(id: pickToRead) {
            guard let url = pickToRead else { return }
            let result = await Task.detached(priority: .userInitiated) {
                Result { try PickedFileReader.read(url) }
            }.value
            if Task.isCancelled {
                if case .success(let picked) = result { PickedFileReader.discard(picked) }
                return
            }
            switch result {
            case .success(let picked): setTrackEdit(.attach(picked))
            case .failure: isUnplayableShown = true
            }
            pickToRead = nil
        }
        // A pick that was not saved is not needed any more; after a save the model has its own copy.
        .onDisappear {
            if let pickedTrack { PickedFileReader.discard(pickedTrack) }
        }
        .alert("This file can't be played", isPresented: $isUnplayableShown) {
            Button("OK", role: .cancel) {}
        }
        .alert("The track couldn't be saved", isPresented: $isTrackNotStoredShown) {
            Button("OK", role: .cancel) {}
        }
    }

    /// Attaches, replaces or removes the track (spec 10.3). The text opens the Files picker in
    /// every state; × is a separate target that only removes.
    private var backingTrack: some View {
        let state = trackState
        return HStack(spacing: 0) {
            Button {
                isNameFocused = false
                isFilePickerShown = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "music.note")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.muted)
                    Group {
                        switch state {
                        case .none:
                            Text("Add backing track").foregroundStyle(Theme.dialWhite)
                        case .file(let fileName):
                            Text(fileName).foregroundStyle(Theme.dialWhite)
                        case .missing:
                            Text("Track missing").foregroundStyle(Theme.amber)
                        }
                    }
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    Spacer(minLength: 0)
                }
                .padding(.leading, 16)
                // Without ×, the text keeps clear of the row's right end.
                .padding(.trailing, state == .none ? 16 : 0)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(trackLabel(for: state))
            .accessibilityAddTraits(.isButton)
            if state != .none {
                Button(action: removeTrack) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.muted)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove backing track")
            }
        }
        .frame(height: 60)
        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .opacity(isReadingPick ? 0.4 : 1)
        .allowsHitTesting(!isReadingPick)
    }

    private func trackLabel(for state: TrackRowState) -> String {
        switch state {
        case .none: "Add backing track"
        case .file(let fileName): "Backing track, \(fileName)"
        case .missing: "Track missing"
        }
    }

    /// Back to no track. A file picked for a song that had none just goes away, so saving
    /// never asks to remove a track that is not there.
    private func removeTrack() {
        setTrackEdit(editedSong?.track == nil ? .keep : .remove)
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
        // The visible heading is gone; VoiceOver still names the group.
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Accents")
    }

    /// When the picked file cannot be stored nothing is saved: the sheet stays open with
    /// everything entered, the pick included, and says so (10.3).
    private func save() {
        let picked = pickedTrack
        let saved = switch purpose {
        case .edit(let song):
            model.editSong(song.id, name: name, settings: draft, track: trackEdit)
        case .saveAsNew:
            model.saveAsNewSong(name: name, settings: draft, track: picked) != nil
        case .library:
            model.createSong(name: name, settings: draft, addingTo: addToSetlist ? setlist?.id : nil, track: picked) != nil
        }
        guard saved else {
            isTrackNotStoredShown = true
            return
        }
        // The model has copied the picked file into its own store; the sheet's copy goes.
        if let picked { PickedFileReader.discard(picked) }
        dismiss()
    }
}
