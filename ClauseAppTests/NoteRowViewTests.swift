import Testing
import Foundation
@testable import Clause

@Suite("NoteRowView")
struct NoteRowViewTests {
    private let calendar = Calendar(identifier: .gregorian)
    private let now = Date(timeIntervalSince1970: 1_794_200_000)

    @Test("Stamp names today and yesterday, dates older posts")
    func stampDay() {
        let today = NoteRowView.stamp(now.addingTimeInterval(-60), now: now, calendar: calendar)
        let yesterday = NoteRowView.stamp(now.addingTimeInterval(-86_400), now: now, calendar: calendar)
        let older = NoteRowView.stamp(now.addingTimeInterval(-3 * 86_400), now: now, calendar: calendar)
        #expect(today.hasPrefix("Today "))
        #expect(yesterday.hasPrefix("Yesterday "))
        #expect(!older.hasPrefix("Today") && !older.hasPrefix("Yesterday"))
        #expect(older.contains(now.addingTimeInterval(-3 * 86_400).formatted(.dateTime.day())))
    }
}
