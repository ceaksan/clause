import Testing
import Foundation
@testable import ClauseShared

/// Minimal line-based IPC server: answers every request with `["server": generation]`.
private final class FakeServer: @unchecked Sendable {
    private let path: String
    private let generation: Int
    private var listenFd: Int32 = -1
    private var clientFds: [Int32] = []
    private var accepted = 0
    var acceptedConnections: Int { lock.withLock { accepted } }
    private let lock = NSLock()

    init(path: String, generation: Int) throws {
        self.path = path
        self.generation = generation
        unlink(path)
        listenFd = socket(AF_UNIX, SOCK_STREAM, 0)
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let bytes = path.utf8CString
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: bytes.count) { dest in
                for i in 0..<bytes.count { dest[i] = bytes[i] }
            }
        }
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(listenFd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bound == 0, listen(listenFd, 4) == 0 else {
            throw NSError(domain: "FakeServer", code: Int(errno))
        }
        let thread = Thread { [self] in acceptLoop() }
        thread.start()
    }

    private func acceptLoop() {
        while true {
            let client = accept(listenFd, nil, nil)
            guard client >= 0 else { return }
            lock.withLock { clientFds.append(client); accepted += 1 }
            Thread { [self] in serve(client) }.start()
        }
    }

    private func serve(_ client: Int32) {
        var pending = Data()
        var buf = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = read(client, &buf, buf.count)
            guard count > 0 else { return }
            pending.append(contentsOf: buf[..<count])
            while let newline = pending.firstIndex(of: UInt8(ascii: "\n")) {
                let line = pending[pending.startIndex..<newline]
                pending = Data(pending[pending.index(after: newline)...])
                guard let request = try? JSONDecoder().decode(IPCRequest.self, from: Data(line)) else { continue }
                var reply = try! JSONEncoder().encode(IPCResponse(result: ["server": .int(generation)], reqId: request.reqId))
                reply.append(UInt8(ascii: "\n"))
                _ = reply.withUnsafeBytes { write(client, $0.baseAddress!, $0.count) }
            }
        }
    }

    func stop() {
        lock.withLock {
            clientFds.forEach { shutdown($0, SHUT_RDWR); close($0) }
            clientFds.removeAll()
        }
        shutdown(listenFd, SHUT_RDWR)
        close(listenFd)
        unlink(path)
    }
}

private func tempSocketPath() -> String {
    "/tmp/clause-test-\(UUID().uuidString.prefix(8)).sock"
}

@Suite("SocketClient", .serialized)
struct SocketClientTests {
    init() { signal(SIGPIPE, SIG_IGN) }

    @Test("Reconnects when Clause.app restarts between calls")
    func reconnectsAfterServerRestart() async throws {
        let path = tempSocketPath()
        let first = try FakeServer(path: path, generation: 1)
        let client = SocketClient(socketPath: path, requestTimeout: 2, launchTimeout: 2)
        try await client.connect()
        let before = try await client.send(IPCRequest(action: "list_notes"))
        #expect(before.result?["server"] == .int(1))

        first.stop()
        try await Task.sleep(for: .milliseconds(200))
        let second = try FakeServer(path: path, generation: 2)
        defer { second.stop() }

        let after = try await client.send(IPCRequest(action: "list_notes"))
        #expect(after.result?["server"] == .int(2))
    }

    @Test("Immediate responses are never lost between write and wait")
    func rapidResponsesNotLost() async throws {
        let path = tempSocketPath()
        let server = try FakeServer(path: path, generation: 3)
        defer { server.stop() }
        let client = SocketClient(socketPath: path, requestTimeout: 1, launchTimeout: 1)
        var answered = 0
        for _ in 0..<300 {
            if (try? await client.send(IPCRequest(action: "list_notes")))?.result?["server"] == .int(3) { answered += 1 }
        }
        #expect(answered == 300)
    }

    @Test("Parallel calls while the app starts share one connection and all get answers")
    func parallelCallsShareOneConnection() async throws {
        let path = tempSocketPath()
        let started = Locked<FakeServer?>(nil)
        let launches = Locked(0)
        let client = SocketClient(
            socketPath: path,
            launchApp: {
                launches.set(launches.get() + 1)
                if started.get() == nil { started.set(try FakeServer(path: path, generation: 5)) }
            },
            requestTimeout: 2,
            launchTimeout: 2
        )
        defer { started.get()?.stop() }
        let answered = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    (try? await client.send(IPCRequest(action: "list_notes")))?.result?["server"] == .int(5)
                }
            }
            return await group.reduce(0) { $0 + ($1 ? 1 : 0) }
        }
        #expect(answered == 10)
        #expect(launches.get() == 1)
        #expect(started.get()?.acceptedConnections == 1)
    }

    @Test("First call connects lazily and launches the app when nothing listens")
    func lazyConnectLaunchesApp() async throws {
        let path = tempSocketPath()
        let started = Locked<FakeServer?>(nil)
        let client = SocketClient(
            socketPath: path,
            launchApp: { started.set(try FakeServer(path: path, generation: 7)) },
            requestTimeout: 2,
            launchTimeout: 2
        )
        defer { started.get()?.stop() }
        let response = try await client.send(IPCRequest(action: "list_notes"))
        #expect(response.result?["server"] == .int(7))
    }
}

private final class Locked<Value>: @unchecked Sendable {
    private var value: Value
    private let lock = NSLock()
    init(_ value: Value) { self.value = value }
    func get() -> Value { lock.withLock { value } }
    func set(_ newValue: Value) { lock.withLock { value = newValue } }
}
