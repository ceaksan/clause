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
