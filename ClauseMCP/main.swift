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
        description: "Post a note to the user's Clause board. When you send a decision topic to another agent, add a one-line headline with type \"decision\" (status defaults to \"sent\"). Notes are scoped to your herdr pane. Returns the note id and a short ref such as D-17; the user refers to notes by ref.",
        inputSchema: schema([
            "text": .object(["type": .string("string"), "description": .string("Note text; for decisions a one-line headline")]),
            "type": .object(["type": .string("string"), "enum": noteTypes, "description": .string("Note type")]),
            "status": .object(["type": .string("string"), "enum": decisionStatuses, "description": .string("Decision status, decisions only")])
        ], required: ["text"])
    ),
    Tool(
        name: "list_notes",
        description: "List the notes this pane has posted to the Clause board. Each note has a ref such as D-17 and its post time (ts). When the user asks about a ref, look it up here.",
        inputSchema: schema([
            "type": .object(["type": .string("string"), "enum": noteTypes, "description": .string("Filter by note type")])
        ])
    ),
    Tool(
        name: "edit_note",
        description: "Edit one of your own Clause notes. Set status to \"decided\" when the answer to your decision topic comes back. Status is only valid on decisions.",
        inputSchema: schema([
            "id": .object(["type": .string("string"), "description": .string("Note UUID or ref such as D-17")]),
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
            "id": .object(["type": .string("string"), "description": .string("Note UUID or ref such as D-17")])
        ], required: ["id"])
    ),
    Tool(
        name: "clear_notes",
        description: "Clear all notes this pane has posted to the Clause board.",
        inputSchema: schema([:])
    )
]

// MARK: - Tool Call Handler

/// The Clause.app that ships with this binary: the bundle it is embedded in, or a sibling bundle.
/// Falls back to LaunchServices, which may pick any Clause.app (for example a Debug build).
func clauseAppBundle() -> String? {
    let binaryDir = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath().deletingLastPathComponent()
    let enclosing = binaryDir.deletingLastPathComponent().deletingLastPathComponent()
    if binaryDir.lastPathComponent == "MacOS", enclosing.pathExtension == "app" { return enclosing.path }
    let sibling = binaryDir.appendingPathComponent("Clause.app")
    return FileManager.default.fileExists(atPath: sibling.path) ? sibling.path : nil
}

let socketClient = SocketClient(
    socketPath: ClauseConstants.socketPath,
    launchApp: {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = clauseAppBundle().map { [$0] } ?? ["-a", "Clause"]
        try process.run()
    },
    log: log
)
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
    version: "0.2.1",
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
} catch {
    log("Initial connect failed, will retry on the first tool call: \(error)")
}

do {
    log("Starting MCP transport...")
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
