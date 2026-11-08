import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Line-based IPC client for the Clause.app socket.
/// Connects lazily, launches the app when nothing listens, and reconnects when the app
/// restarts. A request is retried only when it could not be written; once written it is
/// never resent, so a note is not posted twice.
public final class SocketClient: @unchecked Sendable {
    private let socketPath: String
    private let launchApp: (@Sendable () throws -> Void)?
    private let requestTimeout: TimeInterval
    private let launchTimeout: TimeInterval
    private let log: @Sendable (String) -> Void

    private let queue = DispatchQueue(label: "clause.socket")
    private var fd: Int32 = -1
    private var buffer = Data()
    private var pendingRequests: [String: CheckedContinuation<IPCResponse, Error>] = [:]
    private var readSource: DispatchSourceRead?
    private var connecting: Task<Void, Error>?

    public init(
        socketPath: String,
        launchApp: (@Sendable () throws -> Void)? = nil,
        requestTimeout: TimeInterval = ClauseConstants.requestTimeoutSeconds,
        launchTimeout: TimeInterval = 10,
        log: @escaping @Sendable (String) -> Void = { _ in }
    ) {
        self.socketPath = socketPath
        self.launchApp = launchApp
        self.requestTimeout = requestTimeout
        self.launchTimeout = launchTimeout
        self.log = log
    }

    public var isConnected: Bool { queue.sync { fd >= 0 } }

    /// Parallel callers share one connection attempt, so a second attempt can never
    /// replace a live connection and strand the responses on it.
    public func connect() async throws {
        let attempt: Task<Void, Error>? = queue.sync {
            if fd >= 0 { return nil }
            if let connecting { return connecting }
            let task = Task { try await self.establish() }
            connecting = task
            return task
        }
        guard let attempt else { return }
        defer { queue.sync { if connecting == attempt { connecting = nil } } }
        try await attempt.value
    }

    private func establish() async throws {
        log("Connecting to socket: \(socketPath)")
        do {
            try posixConnect()
            log("Socket connected")
            return
        } catch {
            log("Direct connect failed: \(error), launching Clause.app")
        }
        try launchApp?()

        var interval: TimeInterval = 0.1
        let deadline = Date().addingTimeInterval(launchTimeout)
        while Date() < deadline {
            try await Task.sleep(for: .milliseconds(Int(interval * 1000)))
            if (try? posixConnect()) != nil {
                log("Socket connected after retry")
                return
            }
            interval = min(interval * 1.5, 1.0)
        }
        throw Self.error(1, "Timeout waiting for Clause.app")
    }

    public func send(_ request: IPCRequest) async throws -> IPCResponse {
        try await connect()
        var line = try JSONEncoder().encode(request)
        line.append(UInt8(ascii: "\n"))
        do {
            return try await exchange(request.reqId, line)
        } catch is NotWritten {
            log("Write failed, reconnecting")
            drop(reason: "write failed")
            try await connect()
            do {
                return try await exchange(request.reqId, line)
            } catch is NotWritten {
                drop(reason: "write failed")
                throw Self.error(2, "Write failed")
            }
        }
    }

    public func disconnect() {
        drop(reason: "disconnected")
    }

    // MARK: - Private

    private struct NotWritten: Error {}

    /// Registers the waiter and writes in one step on `queue`, where responses are read,
    /// so a response can never arrive before its waiter exists.
    private func exchange(_ reqId: String, _ line: Data) async throws -> IPCResponse {
        try await withCheckedThrowingContinuation { continuation in
            let written: Bool = queue.sync {
                guard fd >= 0 else { return false }
                pendingRequests[reqId] = continuation
                guard SocketIO.writeAll(fd, line, timeout: 2) else {
                    pendingRequests.removeValue(forKey: reqId)
                    return false
                }
                return true
            }
            guard written else {
                continuation.resume(throwing: NotWritten())
                return
            }
            Task {
                try? await Task.sleep(for: .seconds(self.requestTimeout))
                let pending = self.queue.sync { self.pendingRequests.removeValue(forKey: reqId) }
                pending?.resume(throwing: Self.error(3, "Request timeout"))
            }
        }
    }

    private func posixConnect() throws {
        let sockFd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard sockFd >= 0 else { throw Self.error(1, "Failed to create socket") }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketPath.utf8CString
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
            Darwin.close(sockFd)
            throw Self.error(1, "Socket path too long")
        }
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: pathBytes.count) { dest in
                for i in 0..<pathBytes.count { dest[i] = pathBytes[i] }
            }
        }
        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(sockFd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else {
            let code = errno
            Darwin.close(sockFd)
            throw Self.error(1, "Connect failed: errno \(code)")
        }

        SocketIO.disableSigPipe(sockFd)
        let flags = fcntl(sockFd, F_GETFL)
        _ = fcntl(sockFd, F_SETFL, flags | O_NONBLOCK)

        queue.sync {
            fd = sockFd
            buffer = Data()
            let source = DispatchSource.makeReadSource(fileDescriptor: sockFd, queue: queue)
            source.setEventHandler { [weak self] in self?.readAvailable(sockFd) }
            source.setCancelHandler { Darwin.close(sockFd) }
            source.resume()
            readSource = source
        }
    }

    /// Runs on `queue`.
    private func readAvailable(_ sockFd: Int32) {
        guard sockFd == fd else { return }
        var buf = [UInt8](repeating: 0, count: 65536)
        let bytesRead = read(sockFd, &buf, buf.count)
        if bytesRead > 0 {
            buffer.append(contentsOf: buf[..<bytesRead])
            processBuffer()
        } else if bytesRead == 0 || (errno != EAGAIN && errno != EWOULDBLOCK) {
            log("Socket closed by Clause.app")
            dropLocked(reason: "Clause.app closed the connection")
        }
    }

    /// Runs on `queue`.
    private func processBuffer() {
        let newline = UInt8(ascii: "\n")
        while let index = buffer.firstIndex(of: newline) {
            let messageData = buffer[buffer.startIndex..<index]
            buffer = Data(buffer[buffer.index(after: index)...])
            if let response = try? JSONDecoder().decode(IPCResponse.self, from: Data(messageData)) {
                pendingRequests.removeValue(forKey: response.reqId)?.resume(returning: response)
            }
        }
    }

    private func drop(reason: String) {
        queue.sync { dropLocked(reason: reason) }
    }

    /// Runs on `queue`. In-flight requests fail; they may have reached the app, so they are not resent.
    private func dropLocked(reason: String) {
        readSource?.cancel()
        readSource = nil
        fd = -1
        buffer = Data()
        let pending = pendingRequests
        pendingRequests.removeAll()
        pending.values.forEach { $0.resume(throwing: Self.error(2, "Connection lost: \(reason)")) }
    }

    private static func error(_ code: Int, _ message: String) -> NSError {
        NSError(domain: "Clause", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
