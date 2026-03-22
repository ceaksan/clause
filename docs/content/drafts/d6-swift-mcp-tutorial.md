# Building an MCP Server in Swift

> SEO targets: "Swift MCP server", "MCP protocol Swift", "build MCP server", "Model Context Protocol". Validate with seo-research before publishing.

The Model Context Protocol (MCP) is becoming the standard way for AI assistants to interact with external tools. Most MCP servers today are written in TypeScript or Python, but Swift is a compelling alternative, especially if you are building a macOS companion app. Strong typing, structured concurrency, and native platform access make it a natural fit.

I built [Clause](https://github.com/ceaksan/clause), a macOS companion app for Claude Code sessions. It is a floating SwiftUI window paired with an MCP server that lets Claude add notes, todos, and warnings to a visible scratchpad. The entire system communicates over a Unix domain socket, with no network access and no external dependencies beyond Apple's platform frameworks.

This tutorial walks through the real code from Clause. You will learn how to register MCP tools, handle tool calls, bridge an MCP server to a native app over IPC, and wire everything into a reactive SwiftUI interface.

## MCP Protocol Primer

MCP defines a standardized way for AI models to discover and invoke tools. If you have used function calling in the OpenAI or Anthropic APIs, MCP formalizes that pattern into a protocol with transport, discovery, and execution layers.

The core concepts:

**Tools** are functions that the AI model can call. Each tool has a name, a description, and a JSON Schema defining its input parameters. The model decides when to call a tool based on the description and current conversation context.

**Transport** is how the MCP client (Claude Code, in our case) communicates with the MCP server. The most common transport is stdio: the client spawns the server as a child process and communicates over stdin/stdout using JSON-RPC 2.0. This is the transport Clause uses.

**Server lifecycle** follows a simple pattern: the client starts the server process, sends an `initialize` request, discovers available tools via `tools/list`, then invokes tools via `tools/call` throughout the session. When the session ends, the process exits.

The official Swift SDK from the MCP project ([modelcontextprotocol/swift-sdk](https://github.com/modelcontextprotocol/swift-sdk)) handles the JSON-RPC layer, transport management, and protocol negotiation. You register your tools and handlers; the SDK handles everything else.

For full protocol details, see [modelcontextprotocol.io](https://modelcontextprotocol.io).

## Project Setup

Clause uses Xcode with [xcodegen](https://github.com/yonaskolb/XcodeGen) for project generation. The MCP server is a separate CLI tool target that depends on the official Swift SDK. Here is the relevant section from `project.yml`:

```yaml
packages:
  MCP:
    url: https://github.com/modelcontextprotocol/swift-sdk
    from: "0.11.0"

targets:
  ClauseMCP:
    type: tool
    platform: macOS
    sources:
      - ClauseMCP
    dependencies:
      - target: ClauseShared
      - package: MCP
    settings:
      base:
        PRODUCT_NAME: clause-mcp
```

If you prefer Swift Package Manager directly, add the dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/modelcontextprotocol/swift-sdk", from: "0.11.0")
]
```

The key architectural decision here is separating the MCP server (`ClauseMCP`) from the app (`ClauseApp`) into distinct targets. They share a static library (`ClauseShared`) for wire types and constants, but compile independently. The MCP server is a standalone command-line tool that Claude Code spawns as a child process.

## Implementing MCP Tools

The MCP server entry point lives in `ClauseMCP/main.swift`. Tool registration is straightforward: define an array of `Tool` objects, then register handlers for `ListTools` and `CallTool`.

Here are the tool definitions. Each tool has a name, description (which the model reads to decide when to call it), and a JSON Schema for its parameters:

```swift
import MCP

let tools: [Tool] = [
    Tool(
        name: "add_note",
        description: "Add a note to the Clause companion window",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "text": .object([
                    "type": .string("string"),
                    "description": .string("Note text content")
                ]),
                "type": .object([
                    "type": .string("string"),
                    "enum": .array([.string("note"), .string("todo"), .string("warning")]),
                    "description": .string("Note type")
                ])
            ]),
            "required": .array([.string("text")])
        ])
    ),
    // ... edit_note, delete_note, list_notes, clear_notes, set_session
]
```

The server initialization and handler registration uses the SDK's `Server` class:

```swift
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
```

The `handleToolCall` function translates MCP tool arguments into IPC messages and sends them to the running Clause app over a Unix socket:

```swift
func handleToolCall(name: String, arguments: [String: Value]?) async throws -> String {
    var params: [String: IPCValue] = [:]

    if let args = arguments {
        for (key, value) in args {
            if let s = value.stringValue { params[key] = .string(s) }
            else if let b = value.boolValue { params[key] = .bool(b) }
            else if let i = value.intValue { params[key] = .int(i) }
        }
    }

    let request = IPCRequest(action: name, params: params)
    let response = try await socketClient.send(request)

    if let error = response.error {
        throw NSError(domain: "Clause", code: error.code,
                      userInfo: [NSLocalizedDescriptionKey: error.message])
    }

    let resultData = try JSONEncoder().encode(response.result)
    return String(data: resultData, encoding: .utf8) ?? "{}"
}
```

Finally, the server starts the stdio transport and waits:

```swift
let transport = StdioTransport(logger: Logger(label: "clause.stdio"))
try await server.start(transport: transport)
await server.waitUntilCompleted()
```

That is the complete MCP server. The SDK handles JSON-RPC framing, protocol negotiation, and message routing. Your code only needs to define tools and implement handlers.

## IPC: Unix Domain Sockets

Clause has a two-process architecture. The MCP server (CLI tool) runs as a child process of Claude Code. The SwiftUI app runs independently as a floating window. They communicate over a Unix domain socket at `~/.clause/clause.sock`.

The shared constants live in `ClauseShared/IPC/SocketConstants.swift`:

```swift
public enum ClauseConstants {
    public static let protocolVersion = "1"
    public static let socketDirectoryName = ".clause"
    public static let socketFileName = "clause.sock"
    public static let requestTimeoutSeconds: TimeInterval = 30

    public static var socketPath: String {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(socketDirectoryName, isDirectory: true)
            .appendingPathComponent(socketFileName).path
    }
}
```

The IPC message types are simple Codable structs, also in `ClauseShared`:

```swift
public struct IPCRequest: Codable, Sendable {
    public let action: String
    public let params: [String: IPCValue]
    public let reqId: String
}

public struct IPCResponse: Codable, Sendable {
    public let result: [String: IPCValue]?
    public let error: IPCError?
    public let reqId: String
}
```

Why POSIX sockets? Apple's `NWListener` (Network.framework) does not support `AF_UNIX` server binding on macOS. So the app side uses raw POSIX socket calls for the server, while the MCP CLI side uses POSIX as well for the client connection. The server in `SocketServer.swift` creates, binds, and listens on the socket using standard C APIs:

```swift
serverFd = socket(AF_UNIX, SOCK_STREAM, 0)

var addr = sockaddr_un()
addr.sun_family = sa_family_t(AF_UNIX)
// ... copy socket path into addr.sun_path ...

bind(serverFd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
listen(serverFd, 5)

// Non-blocking + GCD dispatch source for accept
let flags = fcntl(serverFd, F_GETFL)
_ = fcntl(serverFd, F_SETFL, flags | O_NONBLOCK)

let source = DispatchSource.makeReadSource(fileDescriptor: serverFd, queue: .main)
source.setEventHandler { [weak self] in self?.acceptConnection() }
source.resume()
```

Messages are newline-delimited JSON. Each side reads into a buffer, splits on `\n`, and decodes complete messages. The `reqId` field in every request/response pairs them together, allowing the async client to match responses to pending continuations.

## SwiftUI Integration

The real payoff of building an MCP server in Swift is native UI integration. Clause's `NoteStore` is an `@Observable` class running on `@MainActor`, which means MCP tool calls from Claude directly update the SwiftUI view hierarchy:

```swift
@MainActor
@Observable
final class NoteStore {
    private(set) var notes: [Note] = []
    private(set) var session: Session?

    @discardableResult
    func addNote(text: String, source: Note.Source, type: Note.NoteType = .note) -> Note {
        let note = Note(text: text, source: source, type: type)
        notes.insert(note, at: 0)
        scheduleSave()
        return note
    }

    func listNotes(type: Note.NoteType? = nil, source: Note.Source? = nil) -> [Note] {
        notes.filter { note in
            (type == nil || note.type == type) &&
            (source == nil || note.source == source)
        }
    }

    // ... editNote, deleteNote, clearNotes
}
```

When the `SocketServer` receives an `add_note` IPC request, it calls `noteStore.addNote(source: .claude)`. Because `NoteStore` is `@Observable` and its methods run on `@MainActor`, SwiftUI automatically picks up the change and re-renders the note list. No manual notification, no delegate callbacks, no Combine publishers. The observation system handles it.

The `Note` model itself is a simple value type shared between both processes:

```swift
public struct Note: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public var source: Source
    public var type: NoteType
    public var text: String
    public var completed: Bool

    public enum Source: String, Codable, Sendable { case claude, user }
    public enum NoteType: String, Codable, Sendable { case note, todo, warning }
}
```

Persistence is handled with debounced JSON snapshots. Every mutation schedules a save after 500ms of idle time, plus a periodic 10-second flush as a safety net. Session data is written to `~/.clause/sessions/{id}.json`. This keeps things simple and fast, avoiding any database dependency for what is fundamentally an ephemeral scratchpad.

## Testing

Clause uses the Swift Testing framework (`@Test` macros, `#expect` assertions). For an MCP server, the key areas to test are:

**Model round-trips.** Verify that `Note` and `Session` encode and decode correctly through JSON. These types cross process boundaries, so serialization correctness is critical.

**NoteStore CRUD.** Test that `addNote`, `editNote`, `deleteNote`, `clearNotes`, and `listNotes` (with filters) behave correctly. Since `NoteStore` is `@MainActor`, tests need to run in an async context.

**IPC message handling.** Test that `SocketServer.handleRequest` correctly routes actions, validates parameters, and returns proper error responses for invalid inputs. This is where you catch issues like missing required fields or unknown action names.

**Socket communication** is harder to unit test and is better covered by integration tests that spin up both the server and a test client.

## Conclusion

Building an MCP server in Swift gives you type safety, structured concurrency, and direct access to the Apple platform ecosystem. The official [swift-sdk](https://github.com/modelcontextprotocol/swift-sdk) handles the protocol plumbing, so you can focus on what your tools actually do.

Clause is open source at [github.com/ceaksan/clause](https://github.com/ceaksan/clause), with more details at [clause.ceaksan.com](https://clause.ceaksan.com). If you are building macOS tooling for AI workflows, take a look at the code, try it with your own Claude Code sessions, or use it as a starting point for your own Swift MCP server.

The MCP ecosystem is still young. Most servers are TypeScript or Python. A well-built Swift MCP server with native macOS integration is a real differentiator, and there is plenty of room to explore what is possible when your AI tools have first-class access to the platform.
