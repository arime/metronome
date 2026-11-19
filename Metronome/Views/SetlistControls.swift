import SwiftUI

/// A setlist's controls line, between its header and its songs (8.3): the search field and
/// the + that opens Add song, or the field alone in select mode.
struct SetlistControlsLine: View {
    @Binding var query: String
    let showsAdd: Bool
    let add: () -> Void

    var body: some View {
        ControlsLine(query: $query, searchName: "Search this setlist") {
            if showsAdd {
                AddButton(accessibilityName: "Add song", action: add)
            }
        }
    }
}
