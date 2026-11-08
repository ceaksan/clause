import Testing
import Foundation
@testable import ClauseShared
@testable import Clause

private func ctx(_ ws: String, _ pane: String, label: String? = nil) -> AgentContext {
    AgentContext(workspaceId: ws, paneId: pane, workspaceLabel: label, agentLabel: "agent-\(pane)", pid: 1)
}

@MainActor
private func decide(_ store: NoteStore, _ note: Note, _ caller: AgentContext) {
    _ = store.editNote(id: note.id, status: .decided, caller: caller)
}

@Suite("NoteStore")
@MainActor
struct NoteStoreTests {
    @Test("Panes only list their own notes")
    func paneScopedList() {
        let store = NoteStore(snapshotURL: nil)
        store.addNote(text: "a", source: .claude, context: ctx("w1", "p1"))
        store.addNote(text: "b", source: .claude, context: ctx("w1", "p1"))
        store.addNote(text: "c", source: .claude, context: ctx("w1", "p2"))
        store.addNote(text: "mine", source: .user)
        #expect(store.listNotes(caller: ctx("w1", "p1")).count == 2)
        #expect(store.listNotes(caller: nil).count == 4)
    }

    @Test("Same pane ID in another workspace is a different scope")
    func samePaneIdOtherWorkspace() {
        let store = NoteStore(snapshotURL: nil)
        store.addNote(text: "a", source: .claude, context: ctx("w1", "p1"))
        store.addNote(text: "b", source: .claude, context: ctx("w2", "p1"))
        #expect(store.listNotes(caller: ctx("w1", "p1")).map(\.text) == ["a"])
    }

    @Test("Edit and delete of another pane's note fail")
    func crossPaneStoreRejected() {
        let store = NoteStore(snapshotURL: nil)
        let note = store.addNote(text: "theirs", source: .claude, context: ctx("w1", "p2"))
        #expect(store.editNote(id: note.id, text: "hijack", caller: ctx("w1", "p1")) == false)
        #expect(store.deleteNote(id: note.id, caller: ctx("w1", "p1")) == false)
        #expect(store.notes.first?.text == "theirs")
    }

    @Test("Sixth decided decision prunes the oldest")
    func decidedRetention() {
        let store = NoteStore(snapshotURL: nil)
        let p1 = ctx("w1", "p1")
        let p2 = ctx("w1", "p2")
        let other = store.addNote(text: "p2 decided", source: .claude, type: .decision, status: .decided, context: p2)
        var first: Note?
        for i in 0..<6 {
            let note = store.addNote(text: "d\(i)", source: .claude, type: .decision, context: p1)
            if i == 0 { first = note }
            decide(store, note, p1)
        }
        let decided = store.listNotes(caller: p1, type: .decision)
        #expect(decided.count == 5)
        #expect(!decided.contains { $0.id == first?.id })
        #expect(store.listNotes(caller: p2).map(\.id) == [other.id])
    }

    @Test("Sent decisions are never pruned")
    func sentNotPruned() {
        let store = NoteStore(snapshotURL: nil)
        let p1 = ctx("w1", "p1")
        for i in 0..<7 { store.addNote(text: "s\(i)", source: .claude, type: .decision, context: p1) }
        for i in 0..<5 { store.addNote(text: "d\(i)", source: .claude, type: .decision, status: .decided, context: p1) }
        #expect(store.listNotes(caller: p1).count == 12)
    }

    @Test("Reverting to sent clears decidedAt")
    func revertToSentClearsDecidedAt() {
        let store = NoteStore(snapshotURL: nil)
        let p1 = ctx("w1", "p1")
        let note = store.addNote(text: "d", source: .claude, type: .decision, status: .decided, context: p1)
        #expect(store.notes.first?.decidedAt != nil)
        _ = store.editNote(id: note.id, status: .sent, caller: p1)
        #expect(store.notes.first?.status == .sent)
        #expect(store.notes.first?.decidedAt == nil)
    }

    @Test("Converting a note to a decision makes it sent")
    func convertNoteToDecision() {
        let store = NoteStore(snapshotURL: nil)
        let p1 = ctx("w1", "p1")
        let note = store.addNote(text: "n", source: .claude, type: .note, context: p1)
        _ = store.editNote(id: note.id, type: .decision, caller: p1)
        #expect(store.notes.first?.status == .sent)
        #expect(store.openDecisionCount == 1)
    }

    @Test("Only todos stay completed after a type change")
    func completedClearedOffTodo() {
        let store = NoteStore(snapshotURL: nil)
        let p1 = ctx("w1", "p1")
        let todo = store.addNote(text: "t", source: .claude, type: .todo, context: p1)
        _ = store.editNote(id: todo.id, completed: true, caller: p1)
        _ = store.editNote(id: todo.id, type: .decision, caller: p1)
        #expect(store.notes.first?.completed == false)
        _ = store.editNote(id: todo.id, completed: true, caller: p1)
        #expect(store.notes.first?.completed == false)
    }

    @Test("Converting a decided decision to a note clears status")
    func convertDecisionToNote() {
        let store = NoteStore(snapshotURL: nil)
        let p1 = ctx("w1", "p1")
        let converted = store.addNote(text: "was decided", source: .claude, type: .decision, status: .decided, context: p1)
        _ = store.editNote(id: converted.id, type: .note, caller: p1)
        let note = store.notes.first { $0.id == converted.id }
        #expect(note?.status == nil)
        #expect(note?.decidedAt == nil)
        #expect(store.openDecisionCount == 0)
        for i in 0..<5 { store.addNote(text: "d\(i)", source: .claude, type: .decision, status: .decided, context: p1) }
        #expect(store.notes.contains { $0.id == converted.id })
    }

    @Test("Workspace groups ordered by latest activity")
    func groupOrdering() {
        let store = NoteStore(snapshotURL: nil)
        let w1 = ctx("w1", "p1")
        let decision = store.addNote(text: "d", source: .claude, type: .decision, context: w1)
        store.addNote(text: "n", source: .claude, context: ctx("w2", "p1"))
        #expect(store.workspaceGroups.map(\.id) == ["w2", "w1"])
        Thread.sleep(forTimeInterval: 0.01)
        decide(store, decision, w1)
        #expect(store.workspaceGroups.map(\.id) == ["w1", "w2"])
    }

    @Test("Group labels come from the newest labelled note")
    func groupLabels() {
        let store = NoteStore(snapshotURL: nil)
        store.addNote(text: "a", source: .claude, context: ctx("w1", "p1", label: "old"))
        store.addNote(text: "b", source: .claude, context: ctx("w1", "p1", label: "new"))
        store.addNote(text: "c", source: .claude, context: ctx("w1", "p1", label: nil))
        let group = store.workspaceGroups.first
        #expect(group?.label == "new")
        #expect(group?.panes.first?.label == "agent-p1")
    }

    @Test("Pane order: sent, notes, decided")
    func paneRowOrder() {
        let store = NoteStore(snapshotURL: nil)
        let p1 = ctx("w1", "p1")
        store.addNote(text: "decided", source: .claude, type: .decision, status: .decided, context: p1)
        store.addNote(text: "note", source: .claude, type: .note, context: p1)
        store.addNote(text: "sent", source: .claude, type: .decision, context: p1)
        store.addNote(text: "todo", source: .claude, type: .todo, context: p1)
        let texts = store.workspaceGroups.first?.panes.first?.notes.map(\.text)
        #expect(texts == ["sent", "todo", "note", "decided"])
    }

    @Test("clearWorkspace removes only that workspace")
    func clearWorkspaceScoped() {
        let store = NoteStore(snapshotURL: nil)
        store.addNote(text: "a", source: .claude, context: ctx("w1", "p1"))
        store.addNote(text: "b", source: .claude, context: ctx("w1", "p2"))
        store.addNote(text: "c", source: .claude, context: ctx("w2", "p1"))
        store.addNote(text: "mine", source: .user)
        #expect(store.clearWorkspace("w1") == 2)
        #expect(store.notes.map(\.text).sorted() == ["c", "mine"])
    }

    @Test("clearNotes removes only the caller's notes")
    func clearNotesScoped() {
        let store = NoteStore(snapshotURL: nil)
        store.addNote(text: "a", source: .claude, context: ctx("w1", "p1"))
        store.addNote(text: "b", source: .claude, context: ctx("w1", "p2"))
        store.addNote(text: "mine", source: .user)
        #expect(store.clearNotes(caller: ctx("w1", "p1")) == 1)
        #expect(store.notes.map(\.text).sorted() == ["b", "mine"])
    }

    @Test("User notes listed separately")
    func userNotesSeparate() {
        let store = NoteStore(snapshotURL: nil)
        store.addNote(text: "a", source: .claude, context: ctx("w1", "p1"))
        store.addNote(text: "mine", source: .user)
        #expect(store.userNotes.map(\.text) == ["mine"])
        #expect(store.workspaceGroups.count == 1)
    }

    @Test("Snapshot round-trips through the board file")
    func snapshotRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = dir.appendingPathComponent("board.json")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = NoteStore(snapshotURL: url)
        store.addNote(text: "d", source: .claude, type: .decision, status: .decided, context: ctx("w1", "p1"))
        store.addNote(text: "mine", source: .user)
        store.flushSync()
        let reloaded = NoteStore(snapshotURL: url)
        #expect(reloaded.notes == store.notes)
    }

    @Test("Unreadable board file is moved aside, not overwritten")
    func corruptBoardPreserved() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = dir.appendingPathComponent("board.json")
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)
        let store = NoteStore(snapshotURL: url)
        store.flushSync()
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        let corrupt = try #require(files.first { $0.hasPrefix("board.json.corrupt-") })
        #expect(try String(contentsOf: dir.appendingPathComponent(corrupt), encoding: .utf8) == "not json")
        #expect(store.notes.isEmpty)
    }

    @Test("Loaded notes are normalized and pruned")
    func loadNormalizesAndPrunes() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = dir.appendingPathComponent("board.json")
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var broken = Note(text: "no status", source: .claude, type: .decision, context: ctx("w1", "p2"))
        broken.status = nil
        var decided = (0..<6).map { i in
            Note(text: "d\(i)", source: .claude, type: .decision, status: .decided,
                 context: ctx("w1", "p1"), decidedAt: Date(timeIntervalSince1970: Double(1_700_000_000 + i)))
        }
        decided.append(broken)
        try JSONEncoder().encode(decided).write(to: url)
        let store = NoteStore(snapshotURL: url)
        #expect(store.listNotes(caller: ctx("w1", "p2")).first?.status == .sent)
        let kept = store.listNotes(caller: ctx("w1", "p1"))
        #expect(kept.count == 5)
        #expect(!kept.contains { $0.text == "d0" })
    }

    @Test("Refs are sequential across panes and user notes")
    func refsSequential() {
        let store = NoteStore(snapshotURL: nil)
        let a = store.addNote(text: "a", source: .claude, type: .decision, context: ctx("w1", "p1"))
        let b = store.addNote(text: "b", source: .claude, context: ctx("w2", "p1"))
        let c = store.addNote(text: "c", source: .user, type: .todo)
        #expect([a.ref, b.ref, c.ref] == ["D-1", "N-2", "T-3"])
    }

    @Test("Ref number is never reused after delete and reload")
    func refNotReused() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = dir.appendingPathComponent("board.json")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = NoteStore(snapshotURL: url)
        store.addNote(text: "a", source: .user)
        let last = store.addNote(text: "b", source: .user)
        _ = store.deleteNote(id: last.id)
        store.flushSync()
        let reloaded = NoteStore(snapshotURL: url)
        #expect(reloaded.addNote(text: "c", source: .user).seq == 3)
    }

    @Test("Legacy array board loads and gets refs in age order")
    func legacyBoardGetsRefs() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = dir.appendingPathComponent("board.json")
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let older = Note(timestamp: Date(timeIntervalSince1970: 1_700_000_000), text: "older", source: .user)
        let newer = Note(timestamp: Date(timeIntervalSince1970: 1_700_000_100), text: "newer", source: .user)
        try JSONEncoder().encode([newer, older]).write(to: url)
        let store = NoteStore(snapshotURL: url)
        #expect(store.notes.first { $0.text == "older" }?.seq == 1)
        #expect(store.notes.first { $0.text == "newer" }?.seq == 2)
        #expect(store.addNote(text: "next", source: .user).seq == 3)
    }

    @Test("Memo is set, trimmed, capped and cleared when empty")
    func memoLifecycle() {
        let store = NoteStore(snapshotURL: nil)
        let decision = store.addNote(text: "d", source: .claude, type: .decision, context: ctx("w1", "p1"))
        store.setMemo(id: decision.id, "  ask about rollback  ")
        #expect(store.notes.first?.memo == "ask about rollback")
        store.setMemo(id: decision.id, String(repeating: "x", count: 3000))
        #expect(store.notes.first?.memo?.count == ClauseConstants.maxMemoLength)
        store.setMemo(id: decision.id, "   ")
        #expect(store.notes.first?.memo == nil)
    }

    @Test("Agent edits leave the memo alone")
    func agentEditKeepsMemo() {
        let store = NoteStore(snapshotURL: nil)
        let p1 = ctx("w1", "p1")
        let decision = store.addNote(text: "d", source: .claude, type: .decision, context: p1)
        store.setMemo(id: decision.id, "mine")
        _ = store.editNote(id: decision.id, text: "d2", status: .decided, caller: p1)
        #expect(store.notes.first?.memo == "mine")
    }

    @Test("Note text truncated at 4096 chars")
    func textTruncation() {
        let store = NoteStore(snapshotURL: nil)
        store.addNote(text: String(repeating: "a", count: 5000), source: .user, type: .note)
        #expect(store.notes.first?.text.count == 4096)
    }
}
