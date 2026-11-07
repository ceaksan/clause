import Testing
import Foundation
@testable import ClauseShared
@testable import Clause

@MainActor
private struct Harness {
    let store = NoteStore(snapshotURL: nil)
    let server: SocketServer

    init() { server = SocketServer(noteStore: store) }

    func call(
        _ action: String,
        _ params: [String: IPCValue] = [:],
        ws: String = "w1",
        pane: String,
        version: String? = ClauseConstants.protocolVersion,
        withContext: Bool = true
    ) -> IPCResponse {
        let context = withContext ? AgentContext(workspaceId: ws, paneId: pane, pid: 1) : nil
        return server.handleRequest(IPCRequest(action: action, params: params, context: context, version: version))
    }

    func add(_ text: String, type: String = "note", status: String? = nil, ws: String = "w1", pane: String) -> String {
        var params: [String: IPCValue] = ["text": .string(text), "type": .string(type)]
        if let status { params["status"] = .string(status) }
        return call("add_note", params, ws: ws, pane: pane).result?["id"]?.stringValue ?? ""
    }

    func listedTexts(ws: String = "w1", pane: String) throws -> [String] {
        let json = try #require(call("list_notes", ws: ws, pane: pane).result?["notes"]?.stringValue)
        let rows = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: Any]])
        return rows.compactMap { $0["text"] as? String }
    }
}

@Suite("SocketServer entry point")
@MainActor
struct SocketServerTests {
    @Test("Cross-pane edit rejected at entry point")
    func crossPaneEditRejected() {
        let h = Harness()
        let id = h.add("theirs", pane: "p2")
        let response = h.call("edit_note", ["id": .string(id), "text": .string("hijack")], pane: "p1")
        #expect(response.error?.code == ErrorCode.notFound.rawValue)
        #expect(h.store.notes.first?.text == "theirs")
    }

    @Test("Cross-pane delete rejected at entry point")
    func crossPaneDeleteRejected() {
        let h = Harness()
        let id = h.add("theirs", pane: "p2")
        let response = h.call("delete_note", ["id": .string(id)], pane: "p1")
        #expect(response.error?.code == ErrorCode.notFound.rawValue)
        #expect(h.store.notes.count == 1)
    }

    @Test("clear_notes leaves other panes and user notes")
    func clearScopedAtEntry() {
        let h = Harness()
        _ = h.add("mine-p1", pane: "p1")
        _ = h.add("other-p2", pane: "p2")
        h.store.addNote(text: "user", source: .user)
        let response = h.call("clear_notes", pane: "p1")
        #expect(response.result?["cleared"] == .int(1))
        #expect(h.store.notes.map(\.text).sorted() == ["other-p2", "user"])
    }

    @Test("list_notes returns only the caller's notes")
    func listScopedAtEntry() throws {
        let h = Harness()
        _ = h.add("mine", pane: "p1")
        _ = h.add("theirs", pane: "p2")
        h.store.addNote(text: "user", source: .user)
        #expect(try h.listedTexts(pane: "p1") == ["mine"])
    }

    @Test("Same pane ID in another workspace cannot edit")
    func otherWorkspaceSamePane() {
        let h = Harness()
        let id = h.add("w1 note", ws: "w1", pane: "p1")
        let response = h.call("edit_note", ["id": .string(id), "text": .string("x")], ws: "w2", pane: "p1")
        #expect(response.error?.code == ErrorCode.notFound.rawValue)
    }

    @Test("Sixth decided decision prunes through edit_note")
    func retentionThroughEditNote() throws {
        let h = Harness()
        var ids: [String] = []
        for i in 0..<6 {
            let id = h.add("d\(i)", type: "decision", pane: "p1")
            ids.append(id)
            let response = h.call("edit_note", ["id": .string(id), "status": .string("decided")], pane: "p1")
            #expect(response.error == nil)
        }
        let texts = try h.listedTexts(pane: "p1")
        #expect(texts.count == 5)
        #expect(!texts.contains("d0"))
    }

    @Test("list_notes reports decision status")
    func listReportsStatus() throws {
        let h = Harness()
        _ = h.add("d", type: "decision", pane: "p1")
        let json = try #require(h.call("list_notes", ["type": .string("decision")], pane: "p1").result?["notes"]?.stringValue)
        let rows = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: Any]])
        #expect(rows.first?["status"] as? String == "sent")
        #expect(rows.first?["type"] as? String == "decision")
    }

    @Test("Status on a non-decision is rejected")
    func statusOnNonDecisionRejected() {
        let h = Harness()
        let add = h.call("add_note", ["text": .string("x"), "type": .string("note"), "status": .string("decided")], pane: "p1")
        #expect(add.error?.code == ErrorCode.invalidParams.rawValue)
        #expect(h.store.notes.isEmpty)
        let todo = h.add("t", type: "todo", pane: "p1")
        let edit = h.call("edit_note", ["id": .string(todo), "status": .string("decided")], pane: "p1")
        #expect(edit.error?.code == ErrorCode.invalidParams.rawValue)
    }

    @Test("Status allowed when edit converts to decision")
    func statusWithConversionAllowed() {
        let h = Harness()
        let id = h.add("t", type: "todo", pane: "p1")
        let edit = h.call("edit_note", ["id": .string(id), "type": .string("decision"), "status": .string("decided")], pane: "p1")
        #expect(edit.error == nil)
        #expect(h.store.notes.first?.status == .decided)
    }

    @Test("Unknown status or type rejected")
    func invalidStatusRejected() {
        let h = Harness()
        let badStatus = h.call("add_note", ["text": .string("x"), "type": .string("decision"), "status": .string("done")], pane: "p1")
        #expect(badStatus.error?.code == ErrorCode.invalidParams.rawValue)
        let badType = h.call("add_note", ["text": .string("x"), "type": .string("idea")], pane: "p1")
        #expect(badType.error?.code == ErrorCode.invalidParams.rawValue)
        #expect(h.store.notes.isEmpty)
    }

    @Test("Wrong or missing version rejected")
    func wrongVersionRejected() {
        let h = Harness()
        #expect(h.call("list_notes", pane: "p1", version: "1").error?.code == ErrorCode.versionMismatch.rawValue)
        #expect(h.call("list_notes", pane: "p1", version: nil).error?.code == ErrorCode.versionMismatch.rawValue)
    }

    @Test("Missing context rejected")
    func missingContextRejected() {
        let h = Harness()
        let response = h.call("add_note", ["text": .string("x")], pane: "p1", withContext: false)
        #expect(response.error?.code == ErrorCode.invalidParams.rawValue)
        #expect(h.store.notes.isEmpty)
    }

    @Test("set_session is gone")
    func setSessionRemoved() {
        let h = Harness()
        let response = h.call("set_session", ["id": .string("s"), "directory": .string("/tmp")], pane: "p1")
        #expect(response.error?.code == ErrorCode.invalidParams.rawValue)
    }
}
