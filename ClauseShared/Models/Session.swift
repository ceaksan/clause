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
