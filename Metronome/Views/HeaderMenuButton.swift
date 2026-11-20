import SwiftUI

/// The round ⋯ button at the right of the header. It opens the header menu: everything that
/// is done to the loaded song as a whole, and Settings (specification 6.1, 7.6). An amber
/// badge sits on it while the loaded song has unsaved changes.
struct HeaderMenuButton: View {
    @Environment(MetronomeModel.self) private var model
    let openSettings: () -> Void
    /// Opens the library inside a new setlist holding the song with this ID.
    let newSetlist: (UUID) -> Void

    @State private var isSaveAsShown = false
    @State private var editingSong: Song?

    static let size: CGFloat = 40

    var body: some View {
        Menu {
            let items = HeaderMenuItems(
                hasSong: model.loadedSong != nil, isEdited: model.isEdited, hasSetlist: model.position != nil)
            ForEach(items.groups.indices, id: \.self) { index in
                Section {
                    ForEach(items.groups[index], id: \.self) { item($0) }
                }
            }
        } label: {
            label
        }
        .accessibilityLabel(HeaderMenuItems.accessibilityLabel(hasBadge: model.isSaveOffered))
        .sheet(isPresented: $isSaveAsShown) {
            SongSheet(purpose: .saveAsNew)
                .environment(model)
        }
        .sheet(item: $editingSong) { song in
            SongSheet(purpose: .edit(song))
                .environment(model)
        }
    }

    @ViewBuilder
    private func item(_ item: HeaderMenuItems.Item) -> some View {
        switch item {
        case .saveChanges:
            Button {
                model.saveChanges()
                // The badge going away cannot be heard, so the save is spoken.
                AccessibilityNotification.Announcement("Saved").post()
            } label: {
                Label("Save changes", systemImage: "square.and.arrow.down")
            }
        case .revert:
            Button {
                model.discardChanges()
            } label: {
                // A title with the saved values on a second line; on one line the
                // item wraps in the system menu.
                Text("Revert")
                if let saved = model.revertDescription {
                    Text(saved)
                }
                Image(systemName: "arrow.uturn.backward")
            }
        case .editSong:
            Button {
                editingSong = model.loadedSong
            } label: {
                Label("Edit song", systemImage: "pencil")
            }
        case .saveAsNewSong:
            Button {
                isSaveAsShown = true
            } label: {
                Label("Save as new song", systemImage: "plus.square.on.square")
            }
        case .addToSetlist:
            if let song = model.loadedSong {
                addToSetlistMenu(for: song)
            }
        case .unload:
            Button {
                model.unloadSong()
            } label: {
                Label("Unload", systemImage: "eject")
            }
        case .stageMode:
            if let setlistID = model.loadedFromSetlistID {
                Button {
                    model.enterStageMode(setlistID: setlistID)
                } label: {
                    Label("Stage mode", systemImage: "music.mic")
                }
                .disabled(model.isPlaying)
            }
        case .settings:
            Button(action: openSettings) {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }

    /// The row menu's second level (8.4), acting on the loaded song. Taking it out of a
    /// setlist shows no Undo bar, as there is no library sheet to show it in.
    private func addToSetlistMenu(for song: Song) -> some View {
        Menu {
            ForEach(model.library.setlistsByRecency) { candidate in
                let isIncluded = candidate.songIDs.contains(song.id)
                Button {
                    model.setSong(song.id, inSetlist: candidate.id, included: !isIncluded)
                } label: {
                    if isIncluded {
                        Label(candidate.name, systemImage: "checkmark")
                    } else {
                        Text(candidate.name)
                    }
                }
            }
            Divider()
            Button {
                newSetlist(song.id)
            } label: {
                Label("New setlist", systemImage: "plus")
            }
        } label: {
            Label("Add to setlist", systemImage: "text.badge.plus")
        }
    }

    private var label: some View {
        Image(systemName: "ellipsis")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Theme.dialWhite)
            .frame(width: Self.size, height: Self.size)
            .background(Theme.surface, in: Circle())
            .overlay(alignment: .topTrailing) {
                if model.isSaveOffered {
                    Circle()
                        .fill(Theme.amber)
                        .frame(width: 10, height: 10)
                        .frame(width: 14, height: 14)
                        .background(Theme.ink, in: Circle())
                        .offset(x: 1, y: -1)
                        // Fades in, but leaves at once, so that after Save changes or Revert
                        // only the menu's own closing animation is left on screen.
                        .transition(.asymmetric(insertion: .opacity, removal: .identity))
                }
            }
            .animation(.easeOut(duration: 0.15), value: model.isSaveOffered)
            // Drawn 40 pt; the touch area is 44 pt.
            .contentShape(Circle().inset(by: -2))
    }
}
