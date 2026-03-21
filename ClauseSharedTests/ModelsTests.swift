import Testing
import Foundation
@testable import ClauseShared

@Suite("Note Model")
struct NoteTests {
    @Test("Note initializes with correct defaults")
    func noteInit() {
        let note = Note(text: "Test note", source: .claude, type: .note)
        #expect(note.text == "Test note")
        #expect(note.source == .claude)
        #expect(note.type == .note)
        #expect(note.completed == false)
        #expect(note.id != UUID())
    }

    @Test("Note encodes and decodes to JSON")
    func noteCodable() throws {
        let ts = Date(timeIntervalSince1970: 1_700_000_000)
        let note = Note(id: UUID(), timestamp: ts, text: "Test", source: .user, type: .todo)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(note)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Note.self, from: data)
        #expect(decoded == note)
    }

    @Test("Note types encode as expected strings")
    func noteTypeEncoding() throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(Note.NoteType.warning)
        let str = String(data: data, encoding: .utf8)
        #expect(str == "\"warning\"")
    }
}

@Suite("Session Model")
struct SessionTests {
    @Test("Session encodes and decodes")
    func sessionCodable() throws {
        let session = Session(id: "test-123", directory: "/tmp/project", protocolVersion: "1", pid: 12345)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(session)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Session.self, from: data)
        #expect(decoded.id == "test-123")
        #expect(decoded.directory == "/tmp/project")
        #expect(decoded.protocolVersion == "1")
        #expect(decoded.pid == 12345)
    }
}
