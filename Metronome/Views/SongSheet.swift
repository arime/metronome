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
    /// True while a picked file is copied and read; the row is dimmed and the save button waits.
    @State private var isReadingPick = false
    @State private var isUnplayableShown = false
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

    /// The track as saving would leave it.
    private enum TrackState: Equatable {
        case none, file(String), missing
    }

    private var trackState: TrackState {
        switch trackEdit {
        case .attach(let picked): .file(picked.fileName)
        case .remove: .none
        case .keep:
            if let track = editedSong?.track {
                isSavedTrackMissing ? .missing : .file(track.fileName)
            } else {
                .none
            }
        }
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
            case .success(let url): read(url)
            case .failure: isUnplayableShown = true
            }
        }
        .alert("This file can't be played", isPresented: $isUnplayableShown) {
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

    private func trackLabel(for state: TrackState) -> String {
        switch state {
        case .none: "Add backing track"
        case .file(let fileName): "Backing track, \(fileName)"
        case .missing: "Track missing"
        }
    }

    /// Back to no track. A file picked for a song that had none just goes away, so saving
    /// never asks to remove a track that is not there.
    private func removeTrack() {
        trackEdit = editedSong?.track == nil ? .keep : .remove
    }

    /// Copies and reads the picked file away from the main actor, as a long, mostly silent
    /// file is read to its end. A file that cannot be read leaves the row as it was.
    private func read(_ url: URL) {
        isReadingPick = true
        Task {
            do {
                trackEdit = .attach(try await Task.detached(priority: .userInitiated) {
                    try PickedFileReader.read(url)
                }.value)
            } catch {
                isUnplayableShown = true
            }
            isReadingPick = false
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
        // The visible heading is gone; VoiceOver still names the group.
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Accents")
    }

    private func save() {
        var picked: PickedTrack?
        if case .attach(let track) = trackEdit { picked = track }
        switch purpose {
        case .edit(let song):
            model.editSong(song.id, name: name, settings: draft, track: trackEdit)
        case .saveAsNew:
            model.saveAsNewSong(name: name, settings: draft, track: picked)
        case .library:
            model.createSong(name: name, settings: draft, addingTo: addToSetlist ? setlist?.id : nil, track: picked)
        }
        dismiss()
    }
}

/// Turns a file chosen in the Files picker into a `PickedTrack`: a copy in a new temporary
/// folder, under the file's own name, checked as audio and with its first sound found.
private enum PickedFileReader {
    static func read(_ picked: URL) throws -> PickedTrack {
        let manager = FileManager.default
        let folder = manager.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let copy = folder.appending(path: picked.lastPathComponent)
        do {
            // A file from the picker can be opened only while access is held; the copy is made then.
            let isAccessing = picked.startAccessingSecurityScopedResource()
            defer { if isAccessing { picked.stopAccessingSecurityScopedResource() } }
            try manager.createDirectory(at: folder, withIntermediateDirectories: true)
            try manager.copyItem(at: picked, to: copy)
        } catch {
            try? manager.removeItem(at: folder)
            throw error
        }
        do {
            _ = try TrackAudio.length(of: copy)
            let firstBeat = try TrackAudio.firstSound(in: copy)
            return PickedTrack(url: copy, fileName: picked.lastPathComponent, firstBeat: firstBeat)
        } catch {
            try? manager.removeItem(at: folder)
            throw error
        }
    }
}
