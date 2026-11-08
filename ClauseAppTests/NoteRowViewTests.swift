import Testing
import Foundation
@testable import Clause

@Suite("NoteRowView")
struct NoteRowViewTests {
    private let calendar = Calendar(identifier: .gregorian)
    private let now = Date(timeIntervalSince1970: 1_794_200_000)

    @Test("Stamp shows only the time today, names yesterday, dates older posts")
    func stampDay() {
        let today = NoteRowView.stamp(now.addingTimeInterval(-60), now: now, calendar: calendar)
        let yesterday = NoteRowView.stamp(now.addingTimeInterval(-86_400), now: now, calendar: calendar)
        let older = NoteRowView.stamp(now.addingTimeInterval(-3 * 86_400), now: now, calendar: calendar)
        #expect(today == now.addingTimeInterval(-60).formatted(.dateTime.hour().minute()))
        #expect(yesterday.hasPrefix("Yesterday "))
        #expect(!older.hasPrefix("Today") && !older.hasPrefix("Yesterday"))
        #expect(older.contains(now.addingTimeInterval(-3 * 86_400).formatted(.dateTime.day())))
    }

    @Test("Workspace subtitle hides local and duplicate IDs")
    func workspaceSubtitle() {
        func group(_ id: String, _ label: String?) -> NoteStore.WorkspaceGroup {
            NoteStore.WorkspaceGroup(id: id, label: label, panes: [])
        }
        #expect(ContentView.workspaceSubtitle(group("local:clause", "clause")) == nil)
        #expect(ContentView.workspaceSubtitle(group("local:/work/client-a/api", "api")) == "/work/client-a/api")
        #expect(ContentView.workspaceSubtitle(group("w7", "w7")) == nil)
        #expect(ContentView.workspaceSubtitle(group("w7", nil)) == nil)
        #expect(ContentView.workspaceSubtitle(group("w7", "audit")) == "w7")
    }
}
