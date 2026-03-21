import Foundation
import ClauseShared

#if canImport(Darwin)
import Darwin
#endif

@MainActor
final class SocketServer {
    private var serverFd: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    private var clientSources: [Int32: DispatchSourceRead] = [:]
    private var clientBuffers: [Int32: Data] = [:]
    private let noteStore: NoteStore

    init(noteStore: NoteStore) {
        self.noteStore = noteStore
    }

    func start() {
        setupDirectory()
        removeStaleSocket()

        let socketPath = ClauseConstants.socketPath

        // Create socket
        serverFd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverFd >= 0 else {
            print("Failed to create socket: \(errno)")
            return
        }

        // Bind
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketPath.utf8CString
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
            print("Socket path too long")
            Darwin.close(serverFd)
            serverFd = -1
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
            print("Failed to bind socket: \(errno)")
            Darwin.close(serverFd)
            serverFd = -1
            return
        }

        // Listen
        guard listen(serverFd, 5) == 0 else {
            print("Failed to listen: \(errno)")
            Darwin.close(serverFd)
            serverFd = -1
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
        for (fd, _) in clientSources {
            sendResponse(shutdown, to: fd)
            Darwin.close(fd)
        }
        clientSources.values.forEach { $0.cancel() }
        clientSources.removeAll()
        clientBuffers.removeAll()

        acceptSource?.cancel()
        acceptSource = nil

        if serverFd >= 0 {
            Darwin.close(serverFd)
            serverFd = -1
        }
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

        // Set non-blocking
        let flags = fcntl(clientFd, F_GETFL)
        _ = fcntl(clientFd, F_SETFL, flags | O_NONBLOCK)

        setupClientSource(fd: clientFd)
    }

    private func setupClientSource(fd: Int32) {
        clientBuffers[fd] = Data()

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .main)
        source.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.readFromClient(fd: fd)
            }
        }
        source.setCancelHandler {
            Darwin.close(fd)
        }
        source.resume()
        clientSources[fd] = source

        print("CLI connected: fd=\(fd)")
    }

    private func readFromClient(fd: Int32) {
        var buf = [UInt8](repeating: 0, count: 65536)
        let bytesRead = read(fd, &buf, buf.count)

        if bytesRead <= 0 {
            // EOF or error
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

    private func sendResponse(_ response: IPCResponse, to fd: Int32) {
        guard let data = try? JSONEncoder().encode(response) else { return }
        var message = data
        message.append(UInt8(ascii: "\n"))
        message.withUnsafeBytes { ptr in
            _ = write(fd, ptr.baseAddress!, ptr.count)
        }
    }
}
