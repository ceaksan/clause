import Testing
import Foundation
@testable import ClauseShared
@testable import Clause

/// Real socket path: SocketClient (as used by clause-mcp) -> Unix socket -> SocketServer -> NoteStore.
@Suite("Socket end to end", .serialized)
@MainActor
struct SocketEndToEndTests {
    private func makeServer() -> (SocketServer, NoteStore, String) {
        let path = "/tmp/clause-e2e-\(UUID().uuidString.prefix(8)).sock"
        let store = NoteStore(snapshotURL: nil)
        let server = SocketServer(noteStore: store, socketPath: path)
        server.start()
        return (server, store, path)
    }

    private func request(_ action: String, _ params: [String: IPCValue] = [:]) -> IPCRequest {
        IPCRequest(
            action: action,
            params: params,
            context: AgentContext(workspaceId: "w1", paneId: "p1", pid: 1),
            version: ClauseConstants.protocolVersion
        )
    }

    @Test("A list_notes response far larger than the socket buffer arrives whole")
    func largeResponseArrivesWhole() async throws {
        let (server, _, path) = makeServer()
        defer { server.stop() }
        #expect(server.startError == nil)
        let client = SocketClient(socketPath: path, requestTimeout: 5, launchTimeout: 1)
        let text = String(repeating: "x", count: 4000)
        for _ in 0..<60 {
            let added = try await client.send(request("add_note", ["text": .string(text)]))
            #expect(added.error == nil)
        }
        let listed = try await client.send(request("list_notes"))
        let json = try #require(listed.result?["notes"]?.stringValue)
        #expect(json.utf8.count > 200_000)
        let rows = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: Any]])
        #expect(rows.count == 60)
    }

    @Test("A client that disconnects mid-response does not take the app down")
    func clientGoneDuringWrite() async throws {
        let (server, store, path) = makeServer()
        defer { server.stop() }
        let text = String(repeating: "y", count: 4000)
        for _ in 0..<60 {
            store.addNote(text: text, source: .claude, context: AgentContext(workspaceId: "w1", paneId: "p1", pid: 1))
        }
        try sendAndHangUp(path: path, request("list_notes"))
        try await Task.sleep(for: .milliseconds(500))
        let survivor = SocketClient(socketPath: path, requestTimeout: 5, launchTimeout: 1)
        let response = try await survivor.send(request("clear_notes"))
        #expect(response.result?["cleared"] == .int(60))
    }

    /// Writes one request and closes without reading, so the server writes to a closed peer.
    private func sendAndHangUp(path: String, _ request: IPCRequest) throws {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let bytes = path.utf8CString
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: bytes.count) { dest in
                for i in 0..<bytes.count { dest[i] = bytes[i] }
            }
        }
        let connected = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        try #require(connected == 0)
        var line = try JSONEncoder().encode(request)
        line.append(UInt8(ascii: "\n"))
        _ = line.withUnsafeBytes { write(fd, $0.baseAddress!, $0.count) }
        close(fd)
    }

    @Test("A socket that cannot be bound is reported, not just printed")
    func startErrorVisible() {
        let store = NoteStore(snapshotURL: nil)
        let server = SocketServer(noteStore: store, socketPath: "/dev/null/clause.sock")
        server.start()
        #expect(server.startError != nil)
    }
}
