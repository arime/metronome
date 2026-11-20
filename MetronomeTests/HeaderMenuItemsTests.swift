import Testing
@testable import Metronome

@Suite struct HeaderMenuItemsTests {
    @Test func nothingLoadedOffersOnlySaveAsNewSongAndSettings() {
        #expect(HeaderMenuItems(hasSong: false, isEdited: false).groups == [[.saveAsNewSong], [.settings]])
    }

    @Test func aLoadedSongOffersEverythingButSaving() {
        #expect(HeaderMenuItems(hasSong: true, isEdited: false).groups
            == [[.editSong, .saveAsNewSong, .addToSetlist], [.unload], [.settings]])
    }

    @Test func anEditedSongPutsSaveChangesAndRevertFirst() {
        #expect(HeaderMenuItems(hasSong: true, isEdited: true).groups
            == [[.saveChanges, .revert], [.editSong, .saveAsNewSong, .addToSetlist], [.unload], [.settings]])
    }

    @Test func editedWithoutASongIsTreatedAsNothingLoaded() {
        #expect(HeaderMenuItems(hasSong: false, isEdited: true).groups == [[.saveAsNewSong], [.settings]])
    }

    @Test func aSetlistSongOffersStageModeBeforeSettings() {
        #expect(HeaderMenuItems(hasSong: true, isEdited: false, hasSetlist: true).groups
            == [[.editSong, .saveAsNewSong, .addToSetlist], [.unload], [.stageMode], [.settings]])
    }

    @Test func anEditedSetlistSongKeepsSaveFirst() {
        #expect(HeaderMenuItems(hasSong: true, isEdited: true, hasSetlist: true).groups
            == [[.saveChanges, .revert], [.editSong, .saveAsNewSong, .addToSetlist], [.unload], [.stageMode],
                [.settings]])
    }

    @Test func nothingLoadedNeverOffersStageMode() {
        #expect(HeaderMenuItems(hasSong: false, isEdited: false, hasSetlist: true).groups
            == [[.saveAsNewSong], [.settings]])
    }

    @Test func theButtonSaysWhenThereAreUnsavedChanges() {
        #expect(HeaderMenuItems.accessibilityLabel(hasBadge: false) == "More")
        #expect(HeaderMenuItems.accessibilityLabel(hasBadge: true) == "More, unsaved changes")
    }
}
