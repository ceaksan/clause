import Testing
import Foundation
@testable import ClauseShared

private func ctx(_ ws: String = "w1", _ pane: String = "p1") -> AgentContext {
    AgentContext(workspaceId: ws, paneId: pane, workspaceLabel: "audit", agentLabel: "reviewer", pid: 1)
}

private func roundTrip<T: Codable>(_ value: T) throws -> T {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(T.self, from: encoder.encode(value))
}

@Suite("Note Model")
struct NoteTests {
    @Test("Note initializes with correct defaults")
    func noteInit() {
        let note = Note(text: "Test note", source: .claude, type: .note)
        #expect(note.text == "Test note")
        #expect(note.source == .claude)
        #expect(note.type == .note)
        #expect(note.completed == false)
        #expect(note.status == nil)
        #expect(note.workspaceId == nil)
    }

    @Test("Note encodes and decodes to JSON")
    func noteCodable() throws {
        let ts = Date(timeIntervalSince1970: 1_700_000_000)
        let note = Note(id: UUID(), timestamp: ts, text: "Test", source: .user, type: .todo)
        #expect(try roundTrip(note) == note)
    }

    @Test("Note types encode as expected strings")
    func noteTypeEncoding() throws {
        let data = try JSONEncoder().encode(Note.NoteType.decision)
        #expect(String(data: data, encoding: .utf8) == "\"decision\"")
    }

    @Test("Decision defaults to sent and copies context")
    func decisionDefaults() {
        let note = Note(text: "Pick DB", source: .claude, type: .decision, context: ctx())
        #expect(note.status == .sent)
        #expect(note.workspaceId == "w1")
        #expect(note.paneId == "p1")
        #expect(note.workspaceLabel == "audit")
        #expect(note.agentLabel == "reviewer")
        #expect(note.decidedAt == nil)
    }

    @Test("Normalize clears status on non-decisions")
    func normalizeNonDecision() {
        let note = Note(text: "x", source: .claude, type: .note, status: .decided, decidedAt: Date())
        #expect(note.status == nil)
        #expect(note.decidedAt == nil)
    }

    @Test("Decided gets decidedAt, sent loses it")
    func normalizeDecidedAt() {
        var note = Note(text: "x", source: .claude, type: .decision, status: .decided)
        #expect(note.decidedAt != nil)
        note.status = .sent
        note.normalize()
        #expect(note.decidedAt == nil)
    }

    @Test("Already decided note keeps its decidedAt")
    func normalizeKeepsDecidedAt() {
        let past = Date(timeIntervalSince1970: 1_700_000_000)
        var note = Note(text: "x", source: .claude, type: .decision, status: .decided, decidedAt: past)
        note.normalize()
        #expect(note.decidedAt == past)
    }

    @Test("belongs(to:) needs both IDs")
    func belongsNeedsBothIDs() {
        let note = Note(text: "x", source: .claude, type: .note, context: ctx("w1", "p1"))
        #expect(note.belongs(to: ctx("w1", "p1")))
        #expect(!note.belongs(to: ctx("w2", "p1")))
        #expect(!note.belongs(to: ctx("w1", "p2")))
        let userNote = Note(text: "mine", source: .user)
        #expect(!userNote.belongs(to: ctx()))
    }

    @Test("Note with new fields round-trips")
    func noteRoundTrip() throws {
        let note = Note(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            text: "Pick DB", source: .claude, type: .decision, status: .decided,
            context: ctx(), decidedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
        #expect(try roundTrip(note) == note)
    }

    @Test("Old note JSON in the board file format decodes without new fields")
    func oldNoteJSONDecodes() throws {
        let json = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","timestamp":796384800,"source":"claude","type":"todo","text":"x","completed":false}"#
        let note = try JSONDecoder().decode(Note.self, from: Data(json.utf8))
        #expect(note.timestamp == Date(timeIntervalSinceReferenceDate: 796_384_800))
        #expect(note.type == .todo)
        #expect(note.workspaceId == nil)
        #expect(note.paneId == nil)
        #expect(note.status == nil)
        #expect(note.seq == nil)
        #expect(note.ref == nil)
    }

    @Test("Ref prefix follows the current type, number stays")
    func refFollowsType() {
        var note = Note(text: "x", source: .claude, type: .note)
        note.seq = 17
        #expect(note.ref == "N-17")
        note.type = .todo
        #expect(note.ref == "T-17")
        note.type = .warning
        #expect(note.ref == "W-17")
        note.type = .decision
        #expect(note.ref == "D-17")
    }

    @Test("Refs parse with or without prefix and dash")
    func refParsing() {
        #expect(Note.seq(fromRef: "D-17") == 17)
        #expect(Note.seq(fromRef: "d17") == 17)
        #expect(Note.seq(fromRef: "17") == 17)
        #expect(Note.seq(fromRef: " N-3 ") == 3)
        #expect(Note.seq(fromRef: "D-") == nil)
        #expect(Note.seq(fromRef: "X-1") == nil)
        #expect(Note.seq(fromRef: "D-0") == nil)
        #expect(Note.seq(fromRef: "6F9619FF-8B86-D011-B42D-00C04FC964FF") == nil)
    }
}

@Suite("Protocol")
struct ProtocolTests {
    @Test("AgentContext round-trips")
    func contextRoundTrip() throws {
        #expect(try roundTrip(ctx()) == ctx())
    }

    @Test("IPCRequest carries context and version")
    func requestContextRoundTrip() throws {
        let request = IPCRequest(action: "add_note", params: ["text": .string("x")], context: ctx(), version: "2")
        let decoded = try roundTrip(request)
        #expect(decoded.context == ctx())
        #expect(decoded.version == "2")
        #expect(decoded.params["text"] == .string("x"))
    }

    @Test("Protocol version is 2")
    func protocolVersion() {
        #expect(ClauseConstants.protocolVersion == "2")
        #expect(ClauseConstants.decidedRetentionPerPane == 5)
        #expect(ClauseConstants.boardFile.lastPathComponent == "board.json")
    }
}
