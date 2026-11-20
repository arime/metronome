/// Which items the header menu shows, top to bottom, in groups separated by dividers (spec 7.6).
struct HeaderMenuItems: Equatable {
    enum Item: Equatable {
        case saveChanges, revert, editSong, saveAsNewSong, addToSetlist, unload, stageMode, settings
    }

    let groups: [[Item]]

    /// Save as new song and Settings are always there; the rest need a loaded song,
    /// Save changes and Revert also need it edited, and Stage mode needs it loaded from a
    /// setlist.
    init(hasSong: Bool, isEdited: Bool, hasSetlist: Bool = false) {
        guard hasSong else {
            groups = [[.saveAsNewSong], [.settings]]
            return
        }
        let stage: [[Item]] = hasSetlist ? [[.stageMode]] : []
        let song: [[Item]] = [[.editSong, .saveAsNewSong, .addToSetlist], [.unload]] + stage + [[.settings]]
        groups = isEdited ? [[.saveChanges, .revert]] + song : song
    }

    /// "More", or "More, unsaved changes" while the badge shows.
    static func accessibilityLabel(hasBadge: Bool) -> String {
        hasBadge ? "More, unsaved changes" : "More"
    }
}
