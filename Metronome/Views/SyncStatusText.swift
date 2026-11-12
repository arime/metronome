import Foundation

/// What the iCloud card says about the sync status (specification 6.10): the status row, if any,
/// and the line below the card. A pure function of the status and the time, so it can be tested
/// without a view.
struct SyncStatusText: Equatable {
    /// The colours the card draws with, named by role so the view picks the actual colour.
    enum Tone: Equatable {
        case muted, mutedDim, dialWhite, amber, green
    }

    struct Row: Equatable {
        let dot: Tone
        let text: String
        let textTone: Tone
        let detail: String?
    }

    /// Nil while sync is off: the card has no status row then.
    let row: Row?
    let footer: String

    static let generalFooter = "Keeps your songs and setlists the same on every device signed in to your iCloud account. Your settings stay separate on each device."

    /// "Today" is decided with `calendar`; the time and date follow the phone's own formats.
    init(status: SyncStatus?, now: Date, calendar: Calendar) {
        switch status {
        case nil:
            row = nil
            footer = Self.generalFooter
        case .syncing:
            row = Row(dot: .mutedDim, text: "Syncing…", textTone: .muted, detail: nil)
            footer = Self.generalFooter
        case .upToDate(let lastSynced):
            let detail = lastSynced.map { date in
                if calendar.isDate(date, inSameDayAs: now) {
                    "Last synced \(date.formatted(Date.FormatStyle(date: .omitted, time: .shortened)))"
                } else {
                    "Last synced \(date.formatted(Date.FormatStyle().day().month(.abbreviated)))"
                }
            }
            row = Row(dot: .green, text: "Up to date", textTone: .dialWhite, detail: detail)
            footer = Self.generalFooter
        case .notSignedIn:
            row = Row(dot: .amber, text: "Not signed in to iCloud", textTone: .amber, detail: nil)
            footer = "Sign in to iCloud in the Settings app to sync. Until then your songs and setlists stay on this iPhone."
        case .full:
            row = Row(dot: .amber, text: "iCloud storage is full", textTone: .amber, detail: nil)
            footer = "Delete songs or setlists you no longer need to make room. Until then some changes stay on this iPhone."
        case .needsUpdate:
            row = Row(dot: .amber, text: "Update the app to keep syncing", textTone: .amber, detail: nil)
            footer = "Another of your devices has a newer version of the app. Until this one is updated, your songs and setlists stay on this iPhone."
        }
    }
}
