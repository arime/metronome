import Foundation
import Testing
@testable import Metronome

@Suite struct SyncStatusTextTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 16, minute: 0))! }

    private func text(_ status: SyncStatus?) -> SyncStatusText {
        SyncStatusText(status: status, now: now, calendar: calendar)
    }

    @Test func offHasNoRowAndTheGeneralLine() {
        let result = text(nil)
        #expect(result.row == nil)
        #expect(result.footer == SyncStatusText.generalFooter)
        #expect(result.footer == "Keeps your presets and setlists the same on every device signed in to your iCloud account. Your settings stay separate on each device.")
    }

    @Test func syncingIsMutedWithAMutedDimDot() {
        let result = text(.syncing)
        #expect(result.row == .init(dot: .mutedDim, text: "Syncing…", textTone: .muted, detail: nil))
        #expect(result.footer == SyncStatusText.generalFooter)
    }

    @Test func upToDateWithoutATimeHasNoDetail() {
        let result = text(.upToDate(lastSynced: nil))
        #expect(result.row == .init(dot: .green, text: "Up to date", textTone: .dialWhite, detail: nil))
        #expect(result.footer == SyncStatusText.generalFooter)
    }

    @Test func upToDateTodayShowsTheTime() {
        let earlier = calendar.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 14, minute: 32))!
        let expected = "Last synced \(earlier.formatted(Date.FormatStyle(date: .omitted, time: .shortened)))"
        #expect(text(.upToDate(lastSynced: earlier)).row?.detail == expected)
    }

    @Test func upToDateOnAnotherDayShowsTheDate() {
        let earlier = calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 23, minute: 59))!
        let expected = "Last synced \(earlier.formatted(Date.FormatStyle().day().month(.abbreviated)))"
        #expect(text(.upToDate(lastSynced: earlier)).row?.detail == expected)
    }

    @Test func notSignedInIsAmber() {
        let result = text(.notSignedIn)
        #expect(result.row == .init(dot: .amber, text: "Not signed in to iCloud", textTone: .amber, detail: nil))
        #expect(result.footer == "Sign in to iCloud in the Settings app to sync. Until then your presets and setlists stay on this iPhone.")
    }

    @Test func fullIsAmber() {
        let result = text(.full)
        #expect(result.row == .init(dot: .amber, text: "iCloud storage is full", textTone: .amber, detail: nil))
        #expect(result.footer == "Delete presets or setlists you no longer need to make room. Until then some changes stay on this iPhone.")
    }

    @Test func needsUpdateIsAmber() {
        let result = text(.needsUpdate)
        #expect(result.row == .init(dot: .amber, text: "Update the app to keep syncing", textTone: .amber, detail: nil))
        #expect(result.footer == "Another of your devices has a newer version of the app. Until this one is updated, your presets and setlists stay on this iPhone.")
    }
}
