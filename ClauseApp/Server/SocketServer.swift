import Foundation
import ClauseShared

#if canImport(Darwin)
import Darwin
#endif

@MainActor
@Observable
final class SocketServer {
    /// Set when the socket could not be opened; agents cannot reach the board until restart.
    private(set) var startError: String?
    private let socketPath: String
    private var serverFd: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    private var clientSources: [Int32: DispatchSourceRead] = [:]
    private var clientBuffers: [Int32: Data] = [:]
    /// One serial queue per client: writes leave the main actor, keep their order, and the
    /// fd is closed on the same queue, so it is never closed under a pending write.
    private var clientWriteQueues: [Int32: DispatchQueue] = [:]
    private let noteStore: NoteStore

    init(noteStore: NoteStore, socketPath: String = ClauseConstants.socketPath) {
        self.noteStore = noteStore
        self.socketPath = socketPath
    }

    func start() {
        setupDirectory()
        removeStaleSocket()
        startError = nil

        // Create socket
        serverFd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverFd >= 0 else {
            failStart("Failed to create socket (errno \(errno))")
            return
        }

        // Bind
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketPath.utf8CString
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
            failStart("Socket path too long")
            return
        }
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: pathBytes.count) { dest in
                for i in 0..<pathBytes.count {
                    dest[i] = pathBytes[i]
                }
            }
        }

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                bind(serverFd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else {
            failStart("Failed to bind \(socketPath) (errno \(errno))")
            return
        }

        // Listen
        guard listen(serverFd, 5) == 0 else {
            failStart("Failed to listen (errno \(errno))")
            return
        }

        // Set non-blocking
        let flags = fcntl(serverFd, F_GETFL)
        _ = fcntl(serverFd, F_SETFL, flags | O_NONBLOCK)

        // Accept connections via DispatchSource
        let source = DispatchSource.makeReadSource(fileDescriptor: serverFd, queue: .main)
        source.setEventHandler { [weak self] in
            self?.acceptConnection()
        }
        source.setCancelHandler { [weak self] in
            if let fd = self?.serverFd, fd >= 0 {
                Darwin.close(fd)
                self?.serverFd = -1
            }
        }
        source.resume()
        acceptSource = source

        print("Socket server ready at \(socketPath)")
    }

    func stop() {
        // Notify connected CLIs
        let shutdown = IPCResponse(shutdown: ShutdownInfo(reason: "app_quit"))
        for (fd, source) in clientSources {
            sendResponse(shutdown, to: fd)
            source.cancel()
        }
        clientSources.removeAll()
        clientBuffers.removeAll()
        clientWriteQueues.removeAll()

        acceptSource?.cancel()
        acceptSource = nil

        if serverFd >= 0 {
            Darwin.close(serverFd)
            serverFd = -1
        }
        removeStaleSocket()
    }

    // MARK: - Private

    private func failStart(_ message: String) {
        print(message)
        startError = message
        if serverFd >= 0 { Darwin.close(serverFd) }
        serverFd = -1
    }

    private func setupDirectory() {
        try? FileManager.default.createDirectory(
            at: URL(fileURLWithPath: socketPath).deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }

    private func removeStaleSocket() {
        let path = socketPath
        if FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    private func acceptConnection() {
        var clientAddr = sockaddr_un()
        var clientLen = socklen_t(MemoryLayout<sockaddr_un>.size)

        let fd = serverFd
        let clientFd = withUnsafeMutablePointer(to: &clientAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                accept(fd, sockPtr, &clientLen)
            }
        }

        guard clientFd >= 0 else { return }

        SocketIO.disableSigPipe(clientFd)
        let flags = fcntl(clientFd, F_GETFL)
        _ = fcntl(clientFd, F_SETFL, flags | O_NONBLOCK)

        setupClientSource(fd: clientFd)
    }

    private func setupClientSource(fd: Int32) {
        clientBuffers[fd] = Data()
        let writeQueue = DispatchQueue(label: "clause.client.\(fd)")
        clientWriteQueues[fd] = writeQueue

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .main)
        source.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.readFromClient(fd: fd)
            }
        }
        source.setCancelHandler {
            writeQueue.async { Darwin.close(fd) }
        }
        source.resume()
        clientSources[fd] = source

        print("CLI connected: fd=\(fd)")
    }

    private func readFromClient(fd: Int32) {
        var buf = [UInt8](repeating: 0, count: 65536)
        let bytesRead = read(fd, &buf, buf.count)

        if bytesRead == 0 {
            disconnectClient(fd: fd)
            return
        }
        if bytesRead < 0 {
            if errno == EAGAIN || errno == EWOULDBLOCK { return }
            disconnectClient(fd: fd)
            return
        }

        clientBuffers[fd, default: Data()].append(Data(buf[..<bytesRead]))
        processBuffer(fd: fd)
    }

    private func disconnectClient(fd: Int32) {
        clientSources[fd]?.cancel()
        clientSources.removeValue(forKey: fd)
        clientBuffers.removeValue(forKey: fd)
        clientWriteQueues.removeValue(forKey: fd)
        print("CLI disconnected: fd=\(fd)")
    }

    private func processBuffer(fd: Int32) {
        guard var data = clientBuffers[fd] else { return }
        let newline = UInt8(ascii: "\n")

        while let newlineIndex = data.firstIndex(of: newline) {
            let messageData = data[data.startIndex..<newlineIndex]
            data = data[data.index(after: newlineIndex)...]

            if let request = try? JSONDecoder().decode(IPCRequest.self, from: Data(messageData)) {
                let response = handleRequest(request)
                sendResponse(response, to: fd)
            }
        }

        clientBuffers[fd] = Data(data)
    }

    func handleRequest(_ request: IPCRequest) -> IPCResponse {
        guard request.version == ClauseConstants.protocolVersion else {
            let got = request.version ?? "none"
            return fail(.versionMismatch, "Expected protocol version \(ClauseConstants.protocolVersion), got \(got)", request)
        }
        guard let caller = request.context else {
            return fail(.invalidParams, "Missing agent context", request)
        }
        do {
            switch request.action {
            case "add_note":
                return try handleAddNote(request, caller: caller)
            case "list_notes":
                return try handleListNotes(request, caller: caller)
            case "edit_note":
                return try handleEditNote(request, caller: caller)
            case "delete_note":
                return try handleDeleteNote(request, caller: caller)
            case "clear_notes":
                let count = noteStore.clearNotes(caller: caller)
                return IPCResponse(result: ["cleared": .int(count)], reqId: request.reqId)
            default:
                return fail(.invalidParams, "Unknown action: \(request.action)", request)
            }
        } catch let error as ParamError {
            return fail(.invalidParams, error.message, request)
        } catch {
            return fail(.internalError, "\(error)", request)
        }
    }

    private struct ParamError: Error {
        let message: String
    }

    private func fail(_ code: ErrorCode, _ message: String, _ request: IPCRequest) -> IPCResponse {
        IPCResponse(error: IPCError(code: code, message: message), reqId: request.reqId)
    }

    private func stringParam(_ request: IPCRequest, _ key: String) throws -> String? {
        switch request.params[key] {
        case nil, .null?: return nil
        case .string(let raw)?: return raw
        default: throw ParamError(message: "\(key) must be a string")
        }
    }

    private func boolParam(_ request: IPCRequest, _ key: String) throws -> Bool? {
        switch request.params[key] {
        case nil, .null?: return nil
        case .bool(let value)?: return value
        default: throw ParamError(message: "\(key) must be a boolean")
        }
    }

    private func enumParam<T: RawRepresentable>(_ request: IPCRequest, _ key: String) throws -> T? where T.RawValue == String {
        guard let raw = try stringParam(request, key) else { return nil }
        guard let value = T(rawValue: raw) else { throw ParamError(message: "Invalid \(key): \(raw)") }
        return value
    }

    private func idParam(_ request: IPCRequest) throws -> UUID? {
        guard let raw = try stringParam(request, "id") else { throw ParamError(message: "Missing id") }
        if let id = UUID(uuidString: raw) { return id }
        guard Note.seq(fromRef: raw) != nil else { throw ParamError(message: "Invalid id: \(raw)") }
        return noteStore.noteId(forRef: raw)
    }

    private func requireDecisionForStatus(_ status: DecisionStatus?, type: Note.NoteType) throws {
        if status != nil && type != .decision {
            throw ParamError(message: "status is only valid on decision notes")
        }
    }

    private func handleAddNote(_ request: IPCRequest, caller: AgentContext) throws -> IPCResponse {
        guard let text = try stringParam(request, "text") else { throw ParamError(message: "Missing text") }
        let type: Note.NoteType = try enumParam(request, "type") ?? .note
        let status: DecisionStatus? = try enumParam(request, "status")
        try requireDecisionForStatus(status, type: type)

        guard let note = noteStore.addNoteDurably(text: text, source: .claude, type: type, status: status, context: caller) else {
            return fail(.internalError, "Board could not be saved, note not added: \(noteStore.saveError ?? "unknown error")", request)
        }
        let ts = ISO8601DateFormatter().string(from: note.timestamp)
        return IPCResponse(
            result: ["id": .string(note.id.uuidString), "ref": note.ref.map { .string($0) } ?? .null, "ts": .string(ts)],
            reqId: request.reqId
        )
    }

    private func handleListNotes(_ request: IPCRequest, caller: AgentContext) throws -> IPCResponse {
        let typeFilter: Note.NoteType? = try enumParam(request, "type")
        let notes = noteStore.listNotes(caller: caller, type: typeFilter)

        let formatter = ISO8601DateFormatter()
        let noteDicts: [[String: IPCValue]] = notes.map { note in
            [
                "id": .string(note.id.uuidString),
                "ref": note.ref.map { .string($0) } ?? .null,
                "ts": .string(formatter.string(from: note.timestamp)),
                "type": .string(note.type.rawValue),
                "status": note.status.map { .string($0.rawValue) } ?? .null,
                "text": .string(note.text),
                "completed": .bool(note.completed)
            ]
        }

        guard let data = try? JSONEncoder().encode(noteDicts), let json = String(data: data, encoding: .utf8) else {
            return IPCResponse(result: ["notes": .string("[]")], reqId: request.reqId)
        }
        return IPCResponse(result: ["notes": .string(json)], reqId: request.reqId)
    }

    private func handleEditNote(_ request: IPCRequest, caller: AgentContext) throws -> IPCResponse {
        guard let id = try idParam(request) else { return fail(.notFound, "Note not found", request) }
        let type: Note.NoteType? = try enumParam(request, "type")
        let status: DecisionStatus? = try enumParam(request, "status")
        let text = try stringParam(request, "text")
        let completed = try boolParam(request, "completed")
        guard let current = noteStore.listNotes(caller: caller).first(where: { $0.id == id }) else {
            return fail(.notFound, "Note not found", request)
        }
        try requireDecisionForStatus(status, type: type ?? current.type)

        noteStore.editNote(
            id: id,
            text: text,
            type: type,
            completed: completed,
            status: status,
            caller: caller
        )
        return IPCResponse(result: ["ok": .bool(true)], reqId: request.reqId)
    }

    private func handleDeleteNote(_ request: IPCRequest, caller: AgentContext) throws -> IPCResponse {
        guard let id = try idParam(request) else { return fail(.notFound, "Note not found", request) }
        guard noteStore.deleteNote(id: id, caller: caller) else {
            return fail(.notFound, "Note not found", request)
        }
        return IPCResponse(result: ["ok": .bool(true)], reqId: request.reqId)
    }

    private func sendResponse(_ response: IPCResponse, to fd: Int32) {
        guard let writeQueue = clientWriteQueues[fd],
              var message = try? JSONEncoder().encode(response) else { return }
        message.append(UInt8(ascii: "\n"))
        let line = message
        let source = clientSources[fd]
        writeQueue.async { [weak self] in
            guard !SocketIO.writeAll(fd, line) else { return }
            print("Write to CLI failed: fd=\(fd)")
            Task { @MainActor in
                guard let self, let source, self.clientSources[fd] === source else { return }
                self.disconnectClient(fd: fd)
            }
        }
    }
}
