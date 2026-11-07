import Foundation
import ClauseShared
import MCP
import Logging

#if canImport(Darwin)
import Darwin
#endif

// MARK: - Debug Logging

func log(_ msg: String) {
    FileHandle.standardError.write(Data("[clause-mcp] \(msg)\n".utf8))
}

// MARK: - Socket Client (POSIX)

final class SocketClient: @unchecked Sendable {
    private var fd: Int32 = -1
    private var buffer = Data()
    private var pendingRequests: [String: CheckedContinuation<IPCResponse, Error>] = [:]
    private var readSource: DispatchSourceRead?
    private let queue = DispatchQueue(label: "clause.socket")

    func connect() async throws {
        let socketPath = ClauseConstants.socketPath
        log("Connecting to socket: \(socketPath)")

        do {
            try posixConnect(path: socketPath)
            log("Socket connected")
        } catch {
            log("Direct connect failed: \(error), launching Clause.app")
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", "Clause"]
            try process.run()

            var interval: TimeInterval = 0.1
            let maxInterval: TimeInterval = 1.0
            let multiplier: Double = 1.5
            let deadline = Date().addingTimeInterval(10)

            while Date() < deadline {
                try await Task.sleep(for: .milliseconds(Int(interval * 1000)))
                do {
                    try posixConnect(path: socketPath)
                    log("Socket connected after retry")
                    return
                } catch {
                    interval = min(interval * multiplier, maxInterval)
                }
            }
            throw NSError(domain: "Clause", code: 1, userInfo: [NSLocalizedDescriptionKey: "Timeout waiting for Clause.app"])
        }
    }

    private func posixConnect(path: String) throws {
        let sockFd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard sockFd >= 0 else {
            throw NSError(domain: "Clause", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create socket"])
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = path.utf8CString
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
            Darwin.close(sockFd)
            throw NSError(domain: "Clause", code: 1, userInfo: [NSLocalizedDescriptionKey: "Socket path too long"])
        }
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: pathBytes.count) { dest in
                for i in 0..<pathBytes.count { dest[i] = pathBytes[i] }
            }
        }

        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                Darwin.connect(sockFd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else {
            Darwin.close(sockFd)
            throw NSError(domain: "Clause", code: 1, userInfo: [NSLocalizedDescriptionKey: "Connect failed: errno \(errno)"])
        }

        // Set non-blocking for reads
        let flags = fcntl(sockFd, F_GETFL)
        _ = fcntl(sockFd, F_SETFL, flags | O_NONBLOCK)

        self.fd = sockFd
        startReceiving()
    }

    func send(_ request: IPCRequest) async throws -> IPCResponse {
        guard fd >= 0 else {
            throw NSError(domain: "Clause", code: 2, userInfo: [NSLocalizedDescriptionKey: "Not connected"])
        }

        var data = try JSONEncoder().encode(request)
        data.append(UInt8(ascii: "\n"))

        // Write synchronously (small messages)
        let written = data.withUnsafeBytes { ptr in
            Darwin.write(fd, ptr.baseAddress!, ptr.count)
        }
        guard written == data.count else {
            throw NSError(domain: "Clause", code: 2, userInfo: [NSLocalizedDescriptionKey: "Write failed"])
        }

        return try await withCheckedThrowingContinuation { continuation in
            queue.sync {
                pendingRequests[request.reqId] = continuation
            }

            Task {
                try await Task.sleep(for: .seconds(ClauseConstants.requestTimeoutSeconds))
                let pending = self.queue.sync {
                    self.pendingRequests.removeValue(forKey: request.reqId)
                }
                pending?.resume(throwing: NSError(domain: "Clause", code: 3, userInfo: [NSLocalizedDescriptionKey: "Request timeout"]))
            }
        }
    }

    private func startReceiving() {
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in
            self?.readAvailable()
        }
        source.setCancelHandler { [weak self] in
            if let fd = self?.fd, fd >= 0 {
                Darwin.close(fd)
                self?.fd = -1
            }
        }
        source.resume()
        readSource = source
    }

    private func readAvailable() {
        var buf = [UInt8](repeating: 0, count: 65536)
        let bytesRead = read(fd, &buf, buf.count)
        guard bytesRead > 0 else { return }

        buffer.append(Data(buf[..<bytesRead]))
        processBuffer()
    }

    private func processBuffer() {
        let newline = UInt8(ascii: "\n")
        while let index = buffer.firstIndex(of: newline) {
            let messageData = buffer[buffer.startIndex..<index]
            buffer = Data(buffer[buffer.index(after: index)...])

            if let response = try? JSONDecoder().decode(IPCResponse.self, from: Data(messageData)) {
                let continuation = pendingRequests.removeValue(forKey: response.reqId)
                continuation?.resume(returning: response)
            }
        }
    }

    func disconnect() {
        readSource?.cancel()
        readSource = nil
    }
}

// MARK: - Tool Definitions

let noteTypes: Value = .array([.string("note"), .string("todo"), .string("warning"), .string("decision")])
let decisionStatuses: Value = .array([.string("sent"), .string("decided")])

func schema(_ properties: [String: Value], required: [String] = []) -> Value {
    var object: [String: Value] = ["type": .string("object"), "properties": .object(properties)]
    if !required.isEmpty { object["required"] = .array(required.map { .string($0) }) }
    return .object(object)
}

let tools: [Tool] = [
    Tool(
        name: "add_note",
        description: "Post a note to the user's Clause board. When you send a decision topic to another agent, add a one-line headline with type \"decision\" (status defaults to \"sent\"). Notes are scoped to your herdr pane.",
        inputSchema: schema([
            "text": .object(["type": .string("string"), "description": .string("Note text; for decisions a one-line headline")]),
            "type": .object(["type": .string("string"), "enum": noteTypes, "description": .string("Note type")]),
            "status": .object(["type": .string("string"), "enum": decisionStatuses, "description": .string("Decision status, decisions only")])
        ], required: ["text"])
    ),
    Tool(
        name: "list_notes",
        description: "List the notes this pane has posted to the Clause board.",
        inputSchema: schema([
            "type": .object(["type": .string("string"), "enum": noteTypes, "description": .string("Filter by note type")])
        ])
    ),
    Tool(
        name: "edit_note",
        description: "Edit one of your own Clause notes. Set status to \"decided\" when the answer to your decision topic comes back. Status is only valid on decisions.",
        inputSchema: schema([
            "id": .object(["type": .string("string"), "description": .string("Note UUID to edit")]),
            "text": .object(["type": .string("string"), "description": .string("New text content")]),
            "type": .object(["type": .string("string"), "enum": noteTypes]),
            "completed": .object(["type": .string("boolean"), "description": .string("Todo completion status")]),
            "status": .object(["type": .string("string"), "enum": decisionStatuses, "description": .string("Decision status, decisions only")])
        ], required: ["id"])
    ),
    Tool(
        name: "delete_note",
        description: "Delete one of this pane's Clause notes.",
        inputSchema: schema([
            "id": .object(["type": .string("string"), "description": .string("Note UUID to delete")])
        ], required: ["id"])
    ),
    Tool(
        name: "clear_notes",
        description: "Clear all notes this pane has posted to the Clause board.",
        inputSchema: schema([:])
    )
]

// MARK: - Tool Call Handler

let socketClient = SocketClient()
let environment = ProcessInfo.processInfo.environment
let baseContext = HerdrContext.baseContext(
    env: environment,
    cwd: FileManager.default.currentDirectoryPath,
    pid: getpid()
)

func handleToolCall(name: String, arguments: [String: Value]?) async throws -> String {
    log("handleToolCall: \(name)")
    var params: [String: IPCValue] = [:]

    if let args = arguments {
        for (key, value) in args {
            if let s = value.stringValue { params[key] = .string(s) }
            else if let b = value.boolValue { params[key] = .bool(b) }
            else if let i = value.intValue { params[key] = .int(i) }
        }
    }

    let context = name == "add_note"
        ? HerdrContext.resolve(baseContext, env: environment, run: HerdrContext.runHerdr)
        : baseContext
    let request = IPCRequest(action: name, params: params, context: context, version: ClauseConstants.protocolVersion)
    let response = try await socketClient.send(request)

    if let error = response.error {
        throw NSError(domain: "Clause", code: error.code, userInfo: [NSLocalizedDescriptionKey: error.message])
    }

    let resultData = try JSONEncoder().encode(response.result)
    return String(data: resultData, encoding: .utf8) ?? "{}"
}

// MARK: - Main

signal(SIGPIPE, SIG_IGN)

log("Starting clause-mcp")

let server = Server(
    name: "clause",
    version: "0.2.0",
    capabilities: .init(tools: .init())
)

await server.withMethodHandler(ListTools.self) { _ in
    log("ListTools called")
    return ListTools.Result(tools: tools)
}

await server.withMethodHandler(CallTool.self) { params in
    do {
        let result = try await handleToolCall(name: params.name, arguments: params.arguments)
        return CallTool.Result(content: [.text(text: result, annotations: nil, _meta: nil)])
    } catch {
        return CallTool.Result(content: [.text(text: "Error: \(error.localizedDescription)", annotations: nil, _meta: nil)], isError: true)
    }
}

log("Handlers registered, connecting to socket...")

do {
    try await socketClient.connect()
    log("Socket connected, starting MCP transport...")
    let logger = Logger(label: "clause.stdio")
    let transport = StdioTransport(logger: logger)
    log("Starting server...")
    try await server.start(transport: transport)
    log("Server started, waiting...")
    await server.waitUntilCompleted()
    log("Server completed")
} catch {
    log("FATAL: \(error)")
    FileHandle.standardError.write(Data("Clause MCP error: \(error)\n".utf8))
    exit(1)
}
