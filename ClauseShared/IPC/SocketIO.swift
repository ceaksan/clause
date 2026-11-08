import Foundation
#if canImport(Darwin)
import Darwin
#endif

public enum SocketIO {
    /// Writes every byte to a non-blocking socket, waiting for buffer space up to `timeout`.
    /// Returns false when the peer is gone or the wait runs out; the caller drops the connection.
    public static func writeAll(_ fd: Int32, _ data: Data, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        return data.withUnsafeBytes { raw -> Bool in
            guard let base = raw.baseAddress else { return true }
            var offset = 0
            while offset < raw.count {
                let written = Darwin.write(fd, base + offset, raw.count - offset)
                if written > 0 {
                    offset += written
                    continue
                }
                guard written < 0, errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR else { return false }
                let remaining = deadline.timeIntervalSinceNow
                guard remaining > 0 else { return false }
                var pfd = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
                _ = poll(&pfd, 1, Int32(min(remaining, 1) * 1000))
            }
            return true
        }
    }

    /// A write to a closed peer returns EPIPE instead of killing the process.
    public static func disableSigPipe(_ fd: Int32) {
        var on: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
    }
}
