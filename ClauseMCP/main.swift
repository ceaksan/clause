import Foundation
import Network
import ClauseShared
import MCP

// MARK: - Socket Client

final class SocketClient: @unchecked Sendable {
    private var connection: NWConnection?
    private var buffer = Data()
    private var pendingRequests: [String: CheckedContinuation<IPCResponse, Error>] = [:]
    private let queue = DispatchQueue(label: "clause.socket")

    func connect() async throws {
        let socketPath = ClauseConstants.socketPath

        do {
            try await tryConnect(path: socketPath)
        } catch {
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
                    try await tryConnect(path: socketPath)
                    return
                } catch {
                    interval = min(interval * multiplier, maxInterval)
                }
            }
            throw NSError(domain: "Clause", code: 1, userInfo: [NSLocalizedDescriptionKey: "Timeout waiting for Clause.app"])
        }
    }

    private func tryConnect(path: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let endpoint = NWEndpoint.unix(path: path)
            let conn = NWConnection(to: endpoint, using: NWParameters())

            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    continuation.resume()
                case .failed(let error):
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }

            self.connection = conn
            conn.start(queue: self.queue)
            self.startReceiving()
        }
    }

    func send(_ request: IPCRequest) async throws -> IPCResponse {
        guard let connection else {
            throw NSError(domain: "Clause", code: 2, userInfo: [NSLocalizedDescriptionKey: "Not connected"])
        }

        var data = try JSONEncoder().encode(request)
        data.append(UInt8(ascii: "\n"))

        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[request.reqId] = continuation

            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    self.pendingRequests.removeValue(forKey: request.reqId)
                    continuation.resume(throwing: error)
                }
            })

            Task {
                try await Task.sleep(for: .seconds(ClauseConstants.requestTimeoutSeconds))
                if let pending = self.pendingRequests.removeValue(forKey: request.reqId) {
                    pending.resume(throwing: NSError(domain: "Clause", code: 3, userInfo: [NSLocalizedDescriptionKey: "Request timeout"]))
                }
            }
        }
    }

    private func startReceiving() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            if let data {
                self.buffer.append(data)
                self.processBuffer()
            }

            if !isComplete && error == nil {
                self.startReceiving()
            }
        }
    }

    private func processBuffer() {
        let newline = UInt8(ascii: "\n")
        while let index = buffer.firstIndex(of: newline) {
            let messageData = buffer[buffer.startIndex..<index]
            buffer = Data(buffer[buffer.index(after: index)...])

            if let response = try? JSONDecoder().decode(IPCResponse.self, from: Data(messageData)) {
                if let continuation = pendingRequests.removeValue(forKey: response.reqId) {
                    continuation.resume(returning: response)
                }
            }
        }
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
    }
}

// MARK: - Tool Definitions

let tools: [Tool] = [
    Tool(
        name: "set_session",
        description: "Set the active session for the Clause companion window",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "id": .object(["type": .string("string"), "description": .string("Session identifier")]),
                "directory": .object(["type": .string("string"), "description": .string("Working directory path")])
            ]),
            "required": .array([.string("id"), .string("directory")])
        ])
    ),
    Tool(
        name: "add_note",
        description: "Add a note to the Clause companion window",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "text": .object(["type": .string("string"), "description": .string("Note text content")]),
                "type": .object(["type": .string("string"), "enum": .array([.string("note"), .string("todo"), .string("warning")]), "description": .string("Note type")])
            ]),
            "required": .array([.string("text")])
        ])
    ),
    Tool(
        name: "list_notes",
        description: "List notes in the Clause companion window",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "type": .object(["type": .string("string"), "enum": .array([.string("note"), .string("todo"), .string("warning")]), "description": .string("Filter by note type")]),
                "source": .object(["type": .string("string"), "enum": .array([.string("claude"), .string("user")]), "description": .string("Filter by source")])
            ])
        ])
    ),
    Tool(
        name: "edit_note",
        description: "Edit an existing note in the Clause companion window",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "id": .object(["type": .string("string"), "description": .string("Note UUID to edit")]),
                "text": .object(["type": .string("string"), "description": .string("New text content")]),
                "type": .object(["type": .string("string"), "enum": .array([.string("note"), .string("todo"), .string("warning")])]),
                "completed": .object(["type": .string("boolean"), "description": .string("Todo completion status")])
            ]),
            "required": .array([.string("id")])
        ])
    ),
    Tool(
        name: "delete_note",
        description: "Delete a note from the Clause companion window",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "id": .object(["type": .string("string"), "description": .string("Note UUID to delete")])
            ]),
            "required": .array([.string("id")])
        ])
    ),
    Tool(
        name: "clear_notes",
        description: "Clear all notes from the Clause companion window",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    )
]

// MARK: - Tool Call Handler

let socketClient = SocketClient()

func handleToolCall(name: String, arguments: [String: Value]?) async throws -> String {
    var params: [String: IPCValue] = [:]

    if let args = arguments {
        for (key, value) in args {
            if let s = value.stringValue { params[key] = .string(s) }
            else if let b = value.boolValue { params[key] = .bool(b) }
            else if let i = value.intValue { params[key] = .int(i) }
        }
    }

    if name == "set_session" {
        params["version"] = .string(ClauseConstants.protocolVersion)
        params["pid"] = .int(Int(ProcessInfo.processInfo.processIdentifier))
    }

    let request = IPCRequest(action: name, params: params)
    let response = try await socketClient.send(request)

    if let error = response.error {
        throw NSError(domain: "Clause", code: error.code, userInfo: [NSLocalizedDescriptionKey: error.message])
    }

    let resultData = try JSONEncoder().encode(response.result)
    return String(data: resultData, encoding: .utf8) ?? "{}"
}

// MARK: - Main

let server = Server(
    name: "clause",
    version: "0.1.0",
    capabilities: .init(tools: .init())
)

await server.withMethodHandler(ListTools.self) { _ in
    ListTools.Result(tools: tools)
}

await server.withMethodHandler(CallTool.self) { params in
    do {
        let result = try await handleToolCall(name: params.name, arguments: params.arguments)
        return CallTool.Result(content: [.text(result)])
    } catch {
        return CallTool.Result(content: [.text("Error: \(error.localizedDescription)")], isError: true)
    }
}

do {
    try await socketClient.connect()
    let transport = StdioTransport()
    try await server.start(transport: transport)
    await server.waitUntilCompleted()
} catch {
    FileHandle.standardError.write(Data("Clause MCP error: \(error)\n".utf8))
    exit(1)
}
