import Foundation

public struct AgentContext: Codable, Sendable, Equatable {
    public let workspaceId: String
    public let paneId: String
    public var workspaceLabel: String?
    public var agentLabel: String?
    public let pid: Int32

    public init(workspaceId: String, paneId: String, workspaceLabel: String? = nil, agentLabel: String? = nil, pid: Int32) {
        self.workspaceId = workspaceId
        self.paneId = paneId
        self.workspaceLabel = workspaceLabel
        self.agentLabel = agentLabel
        self.pid = pid
    }
}
