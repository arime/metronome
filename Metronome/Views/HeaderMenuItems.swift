/// Which items the header menu shows, top to bottom, in groups separated by dividers (spec 7.6).
struct HeaderMenuItems: Equatable {
    enum Item: Equatable { case saveChanges, revert, editSong, saveAsNewSong, addToSetlist, unload, settings }

    let groups: [[Item]]

    /// Save as new song and Settings are always there; the rest need a loaded song,
    /// and Save changes and Revert also need it edited.
    init(hasSong: Bool, isEdited: Bool) {
        guard hasSong else {
            groups = [[.saveAsNewSong], [.settings]]
            return
        }
        let song: [[Item]] = [[.editSong, .saveAsNewSong, .addToSetlist], [.unload], [.settings]]
        groups = isEdited ? [[.saveChanges, .revert]] + song : song
    }

    /// "More", or "More, unsaved changes" while the badge shows.
    static func accessibilityLabel(hasBadge: Bool) -> String {
        hasBadge ? "More, unsaved changes" : "More"
    }
}
