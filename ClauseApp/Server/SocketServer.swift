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
            params.requiredLocalEndpoint = NWEndpoint.unix(path: socketPath)
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

    func stop() {
        let shutdown = IPCResponse(shutdown: ShutdownInfo(reason: "app_quit"))
        for (_, connection) in connections {
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
