/// When the song sheet's save button is ready (specification 10): in Edit song when the name
/// is present and something differs from the saved song or the track changed, in New song when there is a name.
/// A pure value, so the rule can be tested without a view.
struct SongSheetChanges: Equatable {
    /// The saved song's name and settings; nil for a new song, which has none yet.
    let name: String?
    let settings: MetronomeSettings?

    /// Edit song: compared with the song as it is saved.
    init(editing song: Song) {
        name = song.name
        settings = song.settings
    }

    private init() {
        name = nil
        settings = nil
    }

    /// New song: only a name is needed.
    static let newSong = SongSheetChanges()

    /// Spaces at the ends of the name do not count, as they are removed on saving. A track
    /// attached, replaced, removed or picked for a missing one counts as a change.
    func canSave(name: String, settings: MetronomeSettings, track: TrackEdit = .keep) -> Bool {
        guard let cleaned = Library.cleanName(name) else { return false }
        guard let savedSettings = self.settings else { return true }
        return cleaned != self.name || settings != savedSettings || track != .keep
    }
}

/// What the song sheet's Backing track row shows: the track as saving would leave it (spec 10.3).
enum TrackRowState: Equatable {
    case none, file(String), missing

    /// `saved` is the song's track before the sheet, nil for a new song; `isSavedMissing` when its
    /// file is not on this device. A picked file shows its own name, also one picked for a missing
    /// track, which takes that name on saving.
    init(saved: BackingTrack?, isSavedMissing: Bool, edit: TrackEdit) {
        switch edit {
        case .remove:
            self = .none
        case .attach(let picked):
            self = .file(picked.fileName)
        case .keep:
            if let saved {
                self = isSavedMissing ? .missing : .file(saved.fileName)
            } else {
                self = .none
            }
        }
    }
}
