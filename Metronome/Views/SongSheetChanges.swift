/// When the song sheet's save button is ready (specification 10): in Edit song when the name
/// is present and something differs from the saved song, in New song when there is a name.
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

    /// Spaces at the ends of the name do not count, as they are removed on saving.
    func canSave(name: String, settings: MetronomeSettings) -> Bool {
        guard let cleaned = Library.cleanName(name) else { return false }
        guard let savedSettings = self.settings else { return true }
        return cleaned != self.name || settings != savedSettings
    }
}
