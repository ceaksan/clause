# Clause Milestone 1: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Working CLI MCP server + SwiftUI floating window with bidirectional note communication via Unix domain socket.

**Architecture:** Two-process model. CLI binary (clause-mcp) handles MCP stdio transport and proxies tool calls over Unix domain socket to the SwiftUI app (Clause.app). App manages in-memory NoteStore, persists to JSON, displays notes in a floating NSPanel. Xcode project with 3 targets: ClauseShared (static lib), ClauseMCP (CLI), ClauseApp (macOS app).

**Tech Stack:** Swift 6, SwiftUI, AppKit (NSPanel), Network.framework (NWListener/NWConnection), modelcontextprotocol/swift-sdk, Xcode 16+

**Spec:** `docs/superpowers/specs/2026-03-21-clause-design.md`

**Milestone 1 Scope:** All 6 MCP tools, socket IPC, floating window with note list and input bar. No hotkey, no session cleanup, no accessibility permissions.

---

## File Structure

```
Clause/
├── Clause.xcodeproj
├── ClauseShared/
│   ├── Models/
│   │   ├── Note.swift              # Note struct (Identifiable, Codable, Equatable)
│   │   └── Session.swift           # Session struct (Codable)
│   └── IPC/
│       ├── MessageTypes.swift      # IPCRequest, IPCResponse, IPCError, ErrorCode enum
│       └── SocketConstants.swift   # Socket path, protocol version constants
├── ClauseMCP/
│   └── main.swift                  # MCP server entry point: stdio transport + socket client
├── ClauseApp/
│   ├── ClauseApp.swift             # @main App entry, NSPanel setup
│   ├── AppDelegate.swift           # NSApplicationDelegate, lifecycle management
│   ├── Store/
│   │   └── NoteStore.swift         # @MainActor @Observable, in-memory + JSON persistence
│   ├── Server/
│   │   └── SocketServer.swift      # NWListener, connection handling, request routing
│   ├── Views/
│   │   ├── ContentView.swift       # Main view: note list + input bar + state indicators
│   │   ├── NoteRowView.swift       # Single note row: type badge, source, text, checkbox
│   │   └── InputBar.swift          # Text input + N/T/W type selector
│   └── Window/
│       └── FloatingPanel.swift     # NSPanel subclass, floating window configuration
├── ClauseSharedTests/
│   └── ModelsTests.swift           # Note, Session, MessageTypes tests
├── ClauseAppTests/
│   └── NoteStoreTests.swift        # NoteStore CRUD + persistence tests
├── CLAUDE.md                       # Project-specific Claude Code instructions
└── .gitignore
```

---

### Task 1: Xcode Project Scaffolding

**Files:**
- Create: `Clause.xcodeproj` (via Xcode CLI)
- Create: `CLAUDE.md`
- Create: `.gitignore`

- [ ] **Step 1: Initialize git repo**

```bash
cd ~/Documents/DNM_Projects/clause
git init
```

- [ ] **Step 2: Create .gitignore**

```gitignore
# Xcode
build/
DerivedData/
*.xcuserdata
*.xcworkspace/xcuserdata/

# Swift Package Manager
.build/
Packages/
Package.resolved

# macOS
.DS_Store
*.swp
*~

# Superpowers
.superpowers/
```

- [ ] **Step 3: Create CLAUDE.md**

```markdown
# Clause - Project Instructions

## Stack
- Swift 6, SwiftUI, AppKit, Network.framework
- Xcode 16+ with 3 targets: ClauseShared, ClauseMCP, ClauseApp
- modelcontextprotocol/swift-sdk for MCP protocol
- macOS 14+ (Sonoma) minimum deployment target

## Build
- Open Clause.xcodeproj in Xcode
- Or: xcodebuild -scheme ClauseApp -configuration Debug build
- Or: xcodebuild -scheme ClauseMCP -configuration Debug build

## Architecture
Two-process model: ClauseMCP (CLI, stdio MCP) <-> Unix socket <-> ClauseApp (SwiftUI window)
See docs/superpowers/specs/2026-03-21-clause-design.md for full spec.

## Conventions
- Swift Testing framework (@Test, #expect) for all tests
- @Observable for state management (not ObservableObject)
- Structured concurrency (async/await, actors)
- All UI state mutations on @MainActor
```

- [ ] **Step 4: Create Xcode project with 3 targets**

This must be done in Xcode or via `xcodebuild` scaffolding. Open Xcode:
1. File > New > Project > macOS > App
2. Product Name: `Clause`, Bundle ID: `com.ceaksan.clause`
3. Language: Swift, Interface: SwiftUI
4. Minimum deployment: macOS 14.0
5. Save to `~/Documents/DNM_Projects/clause/`

Then add targets:
1. File > New > Target > macOS > Framework > Name: `ClauseShared`
2. File > New > Target > macOS > Command Line Tool > Name: `ClauseMCP`
3. Link `ClauseShared` to both `ClauseApp` and `ClauseMCP` targets (Build Phases > Link Binary)

Add SPM dependencies (File > Add Package Dependencies):
1. `https://github.com/modelcontextprotocol/swift-sdk` (from: 0.11.0)
2. Add `MCP` library to `ClauseMCP` target

- [ ] **Step 5: Create directory structure**

```bash
cd ~/Documents/DNM_Projects/clause
mkdir -p ClauseShared/Models ClauseShared/IPC
mkdir -p ClauseMCP
mkdir -p ClauseApp/Store ClauseApp/Server ClauseApp/Views ClauseApp/Window
mkdir -p ClauseSharedTests ClauseAppTests
```

- [ ] **Step 6: Verify build**

```bash
cd ~/Documents/DNM_Projects/clause
xcodebuild -scheme Clause -configuration Debug build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: scaffold Xcode project with 3 targets"
```

---

### Task 2: Shared Models (ClauseShared)

**Files:**
- Create: `ClauseShared/Models/Note.swift`
- Create: `ClauseShared/Models/Session.swift`
- Create: `ClauseShared/IPC/SocketConstants.swift`
- Create: `ClauseShared/IPC/MessageTypes.swift`
- Test: `ClauseSharedTests/ModelsTests.swift`

- [ ] **Step 1: Write tests for Note model**

```swift
// ClauseSharedTests/ModelsTests.swift
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
        let note = Note(text: "Test", source: .user, type: .todo)
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -scheme ClauseShared -destination 'platform=macOS' 2>&1 | grep -E "(Test|error|FAIL)"
```
Expected: Compilation errors (types not defined yet)

- [ ] **Step 3: Implement Note model**

```swift
// ClauseShared/Models/Note.swift
import Foundation

public struct Note: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public var source: Source
    public var type: NoteType
    public var text: String
    public var completed: Bool

    public enum Source: String, Codable, Sendable {
        case claude, user
    }

    public enum NoteType: String, Codable, Sendable {
        case note, todo, warning
    }

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        text: String,
        source: Source,
        type: NoteType = .note,
        completed: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.text = String(text.prefix(4096))
        self.source = source
        self.type = type
        self.completed = completed
    }
}
```

- [ ] **Step 4: Implement Session model**

```swift
// ClauseShared/Models/Session.swift
import Foundation

public struct Session: Codable, Sendable {
    public let id: String
    public let directory: String
    public let protocolVersion: String
    public let pid: Int32
    public let startedAt: Date

    public init(id: String, directory: String, protocolVersion: String = "1", pid: Int32, startedAt: Date = Date()) {
        self.id = id
        self.directory = directory
        self.protocolVersion = protocolVersion
        self.pid = pid
        self.startedAt = startedAt
    }
}
```

- [ ] **Step 5: Implement SocketConstants**

```swift
// ClauseShared/IPC/SocketConstants.swift
import Foundation

public enum ClauseConstants {
    public static let protocolVersion = "1"
    public static let socketDirectoryName = ".clause"
    public static let socketFileName = "clause.sock"
    public static let sessionsDirectoryName = "sessions"
    public static let maxNoteLength = 4096
    public static let requestTimeoutSeconds: TimeInterval = 30

    public static var baseDirectory: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(socketDirectoryName, isDirectory: true)
    }

    public static var socketPath: String {
        baseDirectory.appendingPathComponent(socketFileName).path
    }

    public static var sessionsDirectory: URL {
        baseDirectory.appendingPathComponent(sessionsDirectoryName, isDirectory: true)
    }
}
```

- [ ] **Step 6: Implement MessageTypes**

```swift
// ClauseShared/IPC/MessageTypes.swift
import Foundation

public enum ErrorCode: Int, Codable, Sendable {
    case notFound = -1
    case invalidParams = -2
    case sessionNotSet = -3
    case internalError = -4
    case versionMismatch = -5
}

public struct IPCRequest: Codable, Sendable {
    public let action: String
    public let params: [String: IPCValue]
    public let reqId: String

    public init(action: String, params: [String: IPCValue] = [:], reqId: String = UUID().uuidString) {
        self.action = action
        self.params = params
        self.reqId = reqId
    }
}

public struct IPCResponse: Codable, Sendable {
    public let result: [String: IPCValue]?
    public let error: IPCError?
    public let reqId: String
    public let shutdown: ShutdownInfo?

    public init(result: [String: IPCValue], reqId: String) {
        self.result = result
        self.error = nil
        self.reqId = reqId
        self.shutdown = nil
    }

    public init(error: IPCError, reqId: String) {
        self.result = nil
        self.error = error
        self.reqId = reqId
        self.shutdown = nil
    }

    public init(shutdown: ShutdownInfo) {
        self.result = nil
        self.error = nil
        self.reqId = ""
        self.shutdown = shutdown
    }
}

public struct IPCError: Codable, Sendable {
    public let code: Int
    public let message: String

    public init(code: ErrorCode, message: String) {
        self.code = code.rawValue
        self.message = message
    }
}

public struct ShutdownInfo: Codable, Sendable {
    public let reason: String

    public init(reason: String) {
        self.reason = reason
    }
}

public enum IPCValue: Codable, Sendable, Equatable {
    case string(String)
    case int(Int)
    case bool(Bool)
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) { self = .string(str) }
        else if let int = try? container.decode(Int.self) { self = .int(int) }
        else if let bool = try? container.decode(Bool.self) { self = .bool(bool) }
        else if container.decodeNil() { self = .null }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type") }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        case .bool(let b): try container.encode(b)
        case .null: try container.encodeNil()
        }
    }

    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    public var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }
}
```

- [ ] **Step 7: Run tests**

```bash
xcodebuild test -scheme ClauseShared -destination 'platform=macOS' 2>&1 | grep -E "(Test|PASS|FAIL)"
```
Expected: All tests PASS

- [ ] **Step 8: Commit**

```bash
git add ClauseShared/ ClauseSharedTests/
git commit -m "feat: add shared models (Note, Session, IPC message types)"
```

---

### Task 3: NoteStore (ClauseApp)

**Files:**
- Create: `ClauseApp/Store/NoteStore.swift`
- Test: `ClauseAppTests/NoteStoreTests.swift`

- [ ] **Step 1: Write NoteStore tests**

```swift
// ClauseAppTests/NoteStoreTests.swift
import Testing
import Foundation
@testable import ClauseShared
@testable import Clause

@Suite("NoteStore")
struct NoteStoreTests {
    @Test("Add note increases count")
    @MainActor func addNote() {
        let store = NoteStore()
        store.addNote(text: "Hello", source: .claude, type: .note)
        #expect(store.notes.count == 1)
        #expect(store.notes.first?.text == "Hello")
        #expect(store.notes.first?.source == .claude)
    }

    @Test("Edit note updates text")
    @MainActor func editNote() {
        let store = NoteStore()
        store.addNote(text: "Original", source: .user, type: .note)
        let id = store.notes.first!.id
        let result = store.editNote(id: id, text: "Updated", type: nil, completed: nil)
        #expect(result == true)
        #expect(store.notes.first?.text == "Updated")
    }

    @Test("Delete note removes it")
    @MainActor func deleteNote() {
        let store = NoteStore()
        store.addNote(text: "To delete", source: .claude, type: .note)
        let id = store.notes.first!.id
        let result = store.deleteNote(id: id)
        #expect(result == true)
        #expect(store.notes.isEmpty)
    }

    @Test("Clear removes all notes")
    @MainActor func clearNotes() {
        let store = NoteStore()
        store.addNote(text: "One", source: .claude, type: .note)
        store.addNote(text: "Two", source: .user, type: .todo)
        let count = store.clearNotes()
        #expect(count == 2)
        #expect(store.notes.isEmpty)
    }

    @Test("List notes with filter")
    @MainActor func listFiltered() {
        let store = NoteStore()
        store.addNote(text: "Note 1", source: .claude, type: .note)
        store.addNote(text: "Todo 1", source: .user, type: .todo)
        store.addNote(text: "Note 2", source: .claude, type: .note)
        let notes = store.listNotes(type: .note, source: nil)
        #expect(notes.count == 2)
        let todos = store.listNotes(type: .todo, source: .user)
        #expect(todos.count == 1)
    }

    @Test("Toggle completed on todo")
    @MainActor func toggleCompleted() {
        let store = NoteStore()
        store.addNote(text: "Task", source: .claude, type: .todo)
        let id = store.notes.first!.id
        _ = store.editNote(id: id, text: nil, type: nil, completed: true)
        #expect(store.notes.first?.completed == true)
    }

    @Test("Edit nonexistent note returns false")
    @MainActor func editMissing() {
        let store = NoteStore()
        let result = store.editNote(id: UUID(), text: "nope", type: nil, completed: nil)
        #expect(result == false)
    }

    @Test("Note text truncated at 4096 chars")
    @MainActor func textTruncation() {
        let store = NoteStore()
        let longText = String(repeating: "a", count: 5000)
        store.addNote(text: longText, source: .user, type: .note)
        #expect(store.notes.first?.text.count == 4096)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -scheme Clause -destination 'platform=macOS' 2>&1 | grep -E "(error|FAIL)"
```
Expected: Compilation errors (NoteStore not defined)

- [ ] **Step 3: Implement NoteStore**

```swift
// ClauseApp/Store/NoteStore.swift
import Foundation
import SwiftUI
import ClauseShared

@MainActor
@Observable
final class NoteStore {
    private(set) var notes: [Note] = []
    private(set) var session: Session?
    private var saveTask: Task<Void, Never>?
    private var periodicSaveTask: Task<Void, Never>?

    var isSessionActive: Bool { session != nil }

    // MARK: - CRUD

    @discardableResult
    func addNote(text: String, source: Note.Source, type: Note.NoteType = .note) -> Note {
        let note = Note(text: text, source: source, type: type)
        notes.insert(note, at: 0)
        scheduleSave()
        return note
    }

    @discardableResult
    func editNote(id: UUID, text: String?, type: Note.NoteType?, completed: Bool?) -> Bool {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return false }
        if let text { notes[index].text = String(text.prefix(ClauseConstants.maxNoteLength)) }
        if let type { notes[index].type = type }
        if let completed { notes[index].completed = completed }
        scheduleSave()
        return true
    }

    @discardableResult
    func deleteNote(id: UUID) -> Bool {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return false }
        notes.remove(at: index)
        scheduleSave()
        return true
    }

    func clearNotes() -> Int {
        let count = notes.count
        notes.removeAll()
        scheduleSave()
        return count
    }

    func listNotes(type: Note.NoteType? = nil, source: Note.Source? = nil) -> [Note] {
        notes.filter { note in
            (type == nil || note.type == type) &&
            (source == nil || note.source == source)
        }
    }

    // MARK: - Session

    func setSession(_ session: Session) {
        if self.session != nil {
            flushSync()
        }
        self.session = session
        loadFromDisk()
        startPeriodicSave()
    }

    func endSession() {
        flushSync()
        periodicSaveTask?.cancel()
        periodicSaveTask = nil
        session = nil
    }

    // MARK: - Persistence

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.flushSync()
        }
    }

    private func startPeriodicSave() {
        periodicSaveTask?.cancel()
        periodicSaveTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { return }
                self?.flushSync()
            }
        }
    }

    func flushSync() {
        guard let session else { return }
        let url = ClauseConstants.sessionsDirectory
            .appendingPathComponent("\(session.id).json")
        do {
            try FileManager.default.createDirectory(
                at: ClauseConstants.sessionsDirectory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(notes)
            try data.write(to: url, options: .atomic)
        } catch {
            print("NoteStore save error: \(error)")
        }
    }

    private func loadFromDisk() {
        guard let session else { return }
        let url = ClauseConstants.sessionsDirectory
            .appendingPathComponent("\(session.id).json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            notes = []
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            notes = try decoder.decode([Note].self, from: data)
        } catch {
            print("NoteStore load error: \(error)")
            notes = []
        }
    }
}
```

- [ ] **Step 4: Run tests**

```bash
xcodebuild test -scheme Clause -destination 'platform=macOS' 2>&1 | grep -E "(Test|PASS|FAIL)"
```
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add ClauseApp/Store/ ClauseAppTests/
git commit -m "feat: add NoteStore with CRUD and JSON persistence"
```

---

### Task 4: Socket Server (ClauseApp)

**Files:**
- Create: `ClauseApp/Server/SocketServer.swift`

- [ ] **Step 1: Implement SocketServer**

```swift
// ClauseApp/Server/SocketServer.swift
import Foundation
import Network
import ClauseShared

@MainActor
final class SocketServer {
    private var listener: NWListener?
    private var connections: [UUID: NWConnection] = [:]
    private let noteStore: NoteStore
    private var buffer: [UUID: Data] = [:]

    init(noteStore: NoteStore) {
        self.noteStore = noteStore
    }

    func start() {
        setupDirectory()
        removeStaleSocket()

        let socketPath = ClauseConstants.socketPath

        do {
            let params = NWParameters()
            params.allowLocalEndpointReuse = true
            listener = try NWListener(using: params)
        } catch {
            print("Listener creation failed: \(error)")
            return
        }

        listener?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.handleListenerState(state)
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in
                self?.handleNewConnection(connection)
            }
        }

        listener?.start(queue: .main)
    }

    // NOTE: NWListener Unix domain socket binding requires verification during implementation.
    // If NWListener does not support UDS server-side directly, fall back to POSIX:
    // socket(AF_UNIX, SOCK_STREAM, 0) + bind() + listen() + DispatchSource.makeReadSource()
    // The iMCP project uses Network.framework for this, so it likely works on macOS 14+.

    func stop() {
        // Notify all connected CLIs
        let shutdown = IPCResponse(shutdown: ShutdownInfo(reason: "app_quit"))
        for (id, connection) in connections {
            sendResponse(shutdown, to: connection)
            connection.cancel()
        }
        connections.removeAll()
        buffer.removeAll()

        listener?.cancel()
        listener = nil
        removeStaleSocket()
    }

    // MARK: - Private

    private func setupDirectory() {
        try? FileManager.default.createDirectory(
            at: ClauseConstants.baseDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }

    private func removeStaleSocket() {
        let path = ClauseConstants.socketPath
        if FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            print("Socket server ready at \(ClauseConstants.socketPath)")
        case .failed(let error):
            print("Listener failed: \(error). Retrying in 1s...")
            Task {
                try? await Task.sleep(for: .seconds(1))
                self.start()
            }
        default:
            break
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        let connectionId = UUID()
        connections[connectionId] = connection
        buffer[connectionId] = Data()

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    print("CLI connected: \(connectionId)")
                case .failed, .cancelled:
                    self?.connections.removeValue(forKey: connectionId)
                    self?.buffer.removeValue(forKey: connectionId)
                    print("CLI disconnected: \(connectionId)")
                default:
                    break
                }
            }
        }

        connection.start(queue: .main)
        receiveData(from: connection, id: connectionId)
    }

    private func receiveData(from connection: NWConnection, id: UUID) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let self else { return }

                if let data, !data.isEmpty {
                    self.buffer[id, default: Data()].append(data)
                    self.processBuffer(connectionId: id)
                }

                if isComplete || error != nil {
                    self.connections.removeValue(forKey: id)
                    self.buffer.removeValue(forKey: id)
                    return
                }

                self.receiveData(from: connection, id: id)
            }
        }
    }

    private func processBuffer(connectionId: UUID) {
        guard var data = buffer[connectionId] else { return }
        let newline = UInt8(ascii: "\n")

        while let newlineIndex = data.firstIndex(of: newline) {
            let messageData = data[data.startIndex..<newlineIndex]
            data = data[data.index(after: newlineIndex)...]

            if let request = try? JSONDecoder().decode(IPCRequest.self, from: Data(messageData)) {
                let response = handleRequest(request)
                if let connection = connections[connectionId] {
                    sendResponse(response, to: connection)
                }
            }
        }

        buffer[connectionId] = Data(data)
    }

    private func handleRequest(_ request: IPCRequest) -> IPCResponse {
        switch request.action {
        case "set_session":
            return handleSetSession(request)
        case "add_note":
            return handleAddNote(request)
        case "list_notes":
            return handleListNotes(request)
        case "edit_note":
            return handleEditNote(request)
        case "delete_note":
            return handleDeleteNote(request)
        case "clear_notes":
            return handleClearNotes(request)
        default:
            return IPCResponse(error: IPCError(code: .invalidParams, message: "Unknown action: \(request.action)"), reqId: request.reqId)
        }
    }

    private func handleSetSession(_ request: IPCRequest) -> IPCResponse {
        guard let id = request.params["id"]?.stringValue,
              let directory = request.params["directory"]?.stringValue else {
            return IPCResponse(error: IPCError(code: .invalidParams, message: "Missing id or directory"), reqId: request.reqId)
        }

        let version = request.params["version"]?.stringValue ?? ClauseConstants.protocolVersion
        if version != ClauseConstants.protocolVersion {
            return IPCResponse(error: IPCError(code: .versionMismatch, message: "Expected protocol version \(ClauseConstants.protocolVersion), got \(version)"), reqId: request.reqId)
        }

        let pid: Int32 = if case .int(let p) = request.params["pid"] { Int32(p) } else { 0 }
        let session = Session(id: id, directory: directory, protocolVersion: version, pid: pid)
        noteStore.setSession(session)
        return IPCResponse(result: ["ok": .bool(true)], reqId: request.reqId)
    }

    private func handleAddNote(_ request: IPCRequest) -> IPCResponse {
        guard noteStore.isSessionActive else {
            return IPCResponse(error: IPCError(code: .sessionNotSet, message: "No active session"), reqId: request.reqId)
        }
        guard let text = request.params["text"]?.stringValue else {
            return IPCResponse(error: IPCError(code: .invalidParams, message: "Missing text"), reqId: request.reqId)
        }
        let typeStr = request.params["type"]?.stringValue ?? "note"
        let type = Note.NoteType(rawValue: typeStr) ?? .note

        let note = noteStore.addNote(text: text, source: .claude, type: type)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let ts = ISO8601DateFormatter().string(from: note.timestamp)
        return IPCResponse(result: ["id": .string(note.id.uuidString), "ts": .string(ts)], reqId: request.reqId)
    }

    private func handleListNotes(_ request: IPCRequest) -> IPCResponse {
        guard noteStore.isSessionActive else {
            return IPCResponse(error: IPCError(code: .sessionNotSet, message: "No active session"), reqId: request.reqId)
        }
        let typeFilter = request.params["type"]?.stringValue.flatMap { Note.NoteType(rawValue: $0) }
        let sourceFilter = request.params["source"]?.stringValue.flatMap { Note.Source(rawValue: $0) }
        let notes = noteStore.listNotes(type: typeFilter, source: sourceFilter)

        let formatter = ISO8601DateFormatter()
        let noteDicts: [[String: IPCValue]] = notes.map { note in
            [
                "id": .string(note.id.uuidString),
                "ts": .string(formatter.string(from: note.timestamp)),
                "source": .string(note.source.rawValue),
                "type": .string(note.type.rawValue),
                "text": .string(note.text),
                "completed": .bool(note.completed)
            ]
        }

        // Encode as JSON array string in result
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(noteDicts), let json = String(data: data, encoding: .utf8) {
            return IPCResponse(result: ["notes": .string(json)], reqId: request.reqId)
        }
        return IPCResponse(result: ["notes": .string("[]")], reqId: request.reqId)
    }

    private func handleEditNote(_ request: IPCRequest) -> IPCResponse {
        guard noteStore.isSessionActive else {
            return IPCResponse(error: IPCError(code: .sessionNotSet, message: "No active session"), reqId: request.reqId)
        }
        guard let idStr = request.params["id"]?.stringValue, let id = UUID(uuidString: idStr) else {
            return IPCResponse(error: IPCError(code: .invalidParams, message: "Missing or invalid id"), reqId: request.reqId)
        }
        let text = request.params["text"]?.stringValue
        let type = request.params["type"]?.stringValue.flatMap { Note.NoteType(rawValue: $0) }
        let completed = request.params["completed"]?.boolValue

        if noteStore.editNote(id: id, text: text, type: type, completed: completed) {
            return IPCResponse(result: ["ok": .bool(true)], reqId: request.reqId)
        }
        return IPCResponse(error: IPCError(code: .notFound, message: "Note not found"), reqId: request.reqId)
    }

    private func handleDeleteNote(_ request: IPCRequest) -> IPCResponse {
        guard noteStore.isSessionActive else {
            return IPCResponse(error: IPCError(code: .sessionNotSet, message: "No active session"), reqId: request.reqId)
        }
        guard let idStr = request.params["id"]?.stringValue, let id = UUID(uuidString: idStr) else {
            return IPCResponse(error: IPCError(code: .invalidParams, message: "Missing or invalid id"), reqId: request.reqId)
        }
        if noteStore.deleteNote(id: id) {
            return IPCResponse(result: ["ok": .bool(true)], reqId: request.reqId)
        }
        return IPCResponse(error: IPCError(code: .notFound, message: "Note not found"), reqId: request.reqId)
    }

    private func handleClearNotes(_ request: IPCRequest) -> IPCResponse {
        guard noteStore.isSessionActive else {
            return IPCResponse(error: IPCError(code: .sessionNotSet, message: "No active session"), reqId: request.reqId)
        }
        let count = noteStore.clearNotes()
        return IPCResponse(result: ["cleared": .int(count)], reqId: request.reqId)
    }

    private func sendResponse(_ response: IPCResponse, to connection: NWConnection) {
        guard let data = try? JSONEncoder().encode(response) else { return }
        var message = data
        message.append(UInt8(ascii: "\n"))
        connection.send(content: message, completion: .contentProcessed { error in
            if let error {
                print("Send error: \(error)")
            }
        })
    }
}
```

- [ ] **Step 2: Verify build**

```bash
xcodebuild -scheme Clause -configuration Debug build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ClauseApp/Server/
git commit -m "feat: add SocketServer with IPC request handling"
```

---

### Task 5: SwiftUI Views (ClauseApp)

**Files:**
- Create: `ClauseApp/Views/NoteRowView.swift`
- Create: `ClauseApp/Views/InputBar.swift`
- Create: `ClauseApp/Views/ContentView.swift`
- Create: `ClauseApp/Window/FloatingPanel.swift`

- [ ] **Step 1: Implement FloatingPanel**

```swift
// ClauseApp/Window/FloatingPanel.swift
import AppKit

final class FloatingPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        backgroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.95)
        minSize = NSSize(width: 280, height: 300)
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }

    override func close() {
        orderOut(nil)
    }
}
```

- [ ] **Step 2: Implement NoteRowView**

```swift
// ClauseApp/Views/NoteRowView.swift
import SwiftUI
import ClauseShared

struct NoteRowView: View {
    let note: Note
    var onToggleCompleted: (() -> Void)?

    private var accentColor: Color {
        switch note.type {
        case .note: Color(red: 0.39, green: 0.4, blue: 0.95)    // #6366f1
        case .todo: Color(red: 0.98, green: 0.57, blue: 0.24)   // #fb923c
        case .warning: Color(red: 0.97, green: 0.44, blue: 0.44) // #f87171
        }
    }

    private var badgeText: String {
        switch note.type {
        case .note: "NOTE"
        case .todo: "TODO"
        case .warning: "WARNING"
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 3)
                .opacity(note.completed ? 0.4 : 1)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if note.type == .todo {
                        Button(action: { onToggleCompleted?() }) {
                            Image(systemName: note.completed ? "checkmark.square.fill" : "square")
                                .font(.system(size: 12))
                                .foregroundStyle(accentColor)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(badgeText)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(white: 0.17))
                            .cornerRadius(3)
                    }

                    Text(note.source == .claude ? "C" : "U")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color(white: 0.33))

                    Spacer()

                    Text(note.timestamp, format: .dateTime.hour().minute())
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color(white: 0.27))
                }

                Text(note.text)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.83))
                    .strikethrough(note.completed)
                    .lineLimit(5)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(Color(white: 0.12))
        .cornerRadius(6)
        .opacity(note.completed ? 0.5 : 1)
    }
}
```

- [ ] **Step 3: Implement InputBar**

```swift
// ClauseApp/Views/InputBar.swift
import SwiftUI
import ClauseShared

struct InputBar: View {
    @Binding var text: String
    @Binding var selectedType: Note.NoteType
    var onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("Add a note...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(white: 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(white: 0.2), lineWidth: 1)
                )
                .cornerRadius(6)
                .onSubmit { onSubmit() }

            HStack(spacing: 4) {
                typeButton("N", type: .note)
                typeButton("T", type: .todo)
                typeButton("W", type: .warning)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func typeButton(_ label: String, type: Note.NoteType) -> some View {
        Button(action: { selectedType = type }) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(selectedType == type ? Color.white : Color(white: 0.53))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(selectedType == type ? Color(white: 0.25) : Color(white: 0.17))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 4: Implement ContentView**

```swift
// ClauseApp/Views/ContentView.swift
import SwiftUI
import ClauseShared

struct ContentView: View {
    @Environment(NoteStore.self) private var noteStore
    @State private var inputText = ""
    @State private var selectedType: Note.NoteType = .note

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            titleBar

            Divider().background(Color(white: 0.17))

            // Content
            if noteStore.isSessionActive {
                noteList
            } else {
                standbyView
            }

            Divider().background(Color(white: 0.17))

            // Input
            if noteStore.isSessionActive {
                InputBar(text: $inputText, selectedType: $selectedType) {
                    submitNote()
                }
            }
        }
        .background(Color(red: 0.1, green: 0.1, blue: 0.1))
        .frame(minWidth: 280, minHeight: 300)
    }

    private var titleBar: some View {
        HStack {
            Text(noteStore.session?.directory ?? "Clause")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color(white: 0.53))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            HStack(spacing: 6) {
                Text("\(noteStore.notes.count) notes")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(white: 0.33))
                Circle()
                    .fill(noteStore.isSessionActive ? Color.green : Color(white: 0.33))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(white: 0.07))
    }

    private var noteList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(noteStore.notes) { note in
                    NoteRowView(note: note) {
                        _ = noteStore.editNote(id: note.id, text: nil, type: nil, completed: !note.completed)
                    }
                }
            }
            .padding(8)
        }
    }

    private var standbyView: some View {
        VStack {
            Spacer()
            Text("Waiting for session...")
                .font(.system(size: 13))
                .foregroundStyle(Color(white: 0.33))
            Spacer()
        }
    }

    private func submitNote() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        noteStore.addNote(text: trimmed, source: .user, type: selectedType)
        inputText = ""
    }
}
```

- [ ] **Step 5: Verify build**

```bash
xcodebuild -scheme Clause -configuration Debug build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add ClauseApp/Views/ ClauseApp/Window/
git commit -m "feat: add SwiftUI views and floating panel"
```

---

### Task 6: App Entry Point and Wiring (ClauseApp)

**Files:**
- Modify: `ClauseApp/ClauseApp.swift`
- Create: `ClauseApp/AppDelegate.swift`

- [ ] **Step 1: Implement AppDelegate**

```swift
// ClauseApp/AppDelegate.swift
import AppKit
import ClauseShared

final class AppDelegate: NSObject, NSApplicationDelegate {
    var socketServer: SocketServer?
    var noteStore: NoteStore?
    var panel: FloatingPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Socket server is started from ClauseApp.swift
    }

    func applicationWillTerminate(_ notification: Notification) {
        noteStore?.flushSync()
        socketServer?.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
```

- [ ] **Step 2: Update ClauseApp.swift**

```swift
// ClauseApp/ClauseApp.swift
import SwiftUI
import ClauseShared

@main
struct ClauseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var noteStore = NoteStore()
    @State private var socketServer: SocketServer?

    var body: some Scene {
        Window("Clause", id: "main") {
            ContentView()
                .environment(noteStore)
                .onAppear {
                    setupSocketServer()
                    configureWindow()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 320, height: 480)
    }

    private func setupSocketServer() {
        let server = SocketServer(noteStore: noteStore)
        server.start()
        socketServer = server
        appDelegate.socketServer = server
        appDelegate.noteStore = noteStore
    }

    private func configureWindow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = NSApp.windows.first {
                window.level = .floating
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                window.isMovableByWindowBackground = true
                window.backgroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.95)
                window.minSize = NSSize(width: 280, height: 300)
            }
        }
    }
}
```

- [ ] **Step 3: Verify build and run**

```bash
xcodebuild -scheme Clause -configuration Debug build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add ClauseApp/ClauseApp.swift ClauseApp/AppDelegate.swift
git commit -m "feat: wire app entry point with socket server and NoteStore"
```

---

### Task 7: MCP CLI Server (ClauseMCP)

**Files:**
- Create: `ClauseMCP/main.swift`

This task requires the `modelcontextprotocol/swift-sdk` package. The CLI reads MCP JSON-RPC from stdin, translates tool calls to IPC requests, sends them over the Unix socket to the app, and writes responses to stdout.

- [ ] **Step 1: Implement MCP CLI entry point**

```swift
// ClauseMCP/main.swift
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

        // Try connecting, launch app if needed
        do {
            try await tryConnect(path: socketPath)
        } catch {
            // Launch app
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", "Clause"]
            try process.run()

            // Poll with exponential backoff
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

            // Timeout
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

// MARK: - MCP Tool Handlers

let socketClient = SocketClient()

func handleToolCall(name: String, arguments: [String: Any]?) async throws -> String {
    var params: [String: IPCValue] = [:]

    if let args = arguments {
        for (key, value) in args {
            if let s = value as? String { params[key] = .string(s) }
            else if let b = value as? Bool { params[key] = .bool(b) }
            else if let i = value as? Int { params[key] = .int(i) }
        }
    }

    // For set_session, inject version and pid
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

@main
struct ClauseMCPServer {
    static func main() async throws {
        // Connect to Clause.app
        try await socketClient.connect()

        // TODO: Initialize MCP server with swift-sdk stdio transport
        // Register tools: set_session, add_note, list_notes, edit_note, delete_note, clear_notes
        // Start reading from stdin
        // This will be refined once swift-sdk API is explored

        // For now, keep the process alive
        await withCheckedContinuation { (_: CheckedContinuation<Void, Never>) in
            // Block forever, waiting for stdin EOF
        }
    }
}
```

**Note:** The MCP server integration with swift-sdk will need refinement based on the actual API. During implementation, read the swift-sdk source to understand `Server`, `StdioTransport`, and tool registration APIs. The socket client and tool handler logic above is the core. Adapt the entry point to match the SDK's patterns.

- [ ] **Step 2: Verify build**

```bash
xcodebuild -scheme ClauseMCP -configuration Debug build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED (may need adjustments for swift-sdk API)

- [ ] **Step 3: Commit**

```bash
git add ClauseMCP/
git commit -m "feat: add MCP CLI server with socket client"
```

---

### Task 8: Integration Test

- [ ] **Step 1: Build both targets**

```bash
xcodebuild -scheme Clause -configuration Debug build 2>&1 | tail -3
xcodebuild -scheme ClauseMCP -configuration Debug build 2>&1 | tail -3
```
Expected: Both BUILD SUCCEEDED

- [ ] **Step 2: Manual integration test**

1. Run the app: `open ~/Documents/DNM_Projects/clause/build/Debug/Clause.app`
2. Verify: floating window appears with "Waiting for session..."
3. In a terminal, test socket connection:
```bash
echo '{"action":"set_session","params":{"id":"test-1","directory":"/tmp","version":"1","pid":"0"},"reqId":"1"}\n' | nc -U ~/.clause/clause.sock
```
4. Verify: window shows session directory, connection dot turns green
5. Send a note:
```bash
echo '{"action":"add_note","params":{"text":"Hello from CLI","type":"note"},"reqId":"2"}\n' | nc -U ~/.clause/clause.sock
```
6. Verify: note appears in window

- [ ] **Step 3: Run all unit tests**

```bash
xcodebuild test -scheme Clause -destination 'platform=macOS' 2>&1 | grep -E "(Test Suite|Passed|Failed)"
```
Expected: All tests pass

- [ ] **Step 4: Commit and tag milestone**

```bash
git add -A
git commit -m "feat: milestone 1 complete - CLI MCP server + floating window"
git tag v0.1.0-milestone1
```

---

## Execution Notes

### Swift MCP SDK Integration (Task 7)

The `modelcontextprotocol/swift-sdk` API may differ from what's shown above. During implementation:

1. Read the swift-sdk README and source to understand `Server`, `StdioTransport`, and `Tool` registration APIs
2. The core pattern is: create a `Server`, register tools with their schemas, start stdio transport
3. Each tool handler calls `handleToolCall()` which proxies to the socket client
4. The CLI's `@main` entry point may conflict with swift-sdk's server loop. Remove `@main` if the SDK provides its own entry point.

### NWListener Unix Socket Setup (Task 4)

iMCP uses Network.framework for Unix socket IPC on macOS. If `NWListener` does not support UDS server-side directly, fall back to POSIX sockets with `DispatchSource.makeReadSource()`. Verify during implementation by checking iMCP source code.

### Xcode Target Membership

Ensure all files are added to the correct Xcode targets:
- `ClauseShared/` files: ClauseShared target only
- `ClauseApp/` files: Clause (app) target only
- `ClauseMCP/` files: ClauseMCP target only
- Test files: their respective test targets