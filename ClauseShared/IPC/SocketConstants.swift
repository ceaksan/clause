import Foundation

public enum ClauseConstants {
    public static let protocolVersion = "2"
    public static let socketDirectoryName = ".clause"
    public static let socketFileName = "clause.sock"
    public static let boardFileName = "board.json"
    public static let decidedRetentionPerPane = 5
    public static let herdrTimeoutSeconds: TimeInterval = 2
    public static let maxNoteLength = 4096
    public static let maxMemoLength = 1000
    public static let requestTimeoutSeconds: TimeInterval = 30

    public static var baseDirectory: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(socketDirectoryName, isDirectory: true)
    }

    public static var socketPath: String {
        baseDirectory.appendingPathComponent(socketFileName).path
    }

    public static var boardFile: URL {
        baseDirectory.appendingPathComponent(boardFileName)
    }
}
