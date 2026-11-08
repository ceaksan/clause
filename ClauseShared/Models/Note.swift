import Foundation

public enum DecisionStatus: String, Codable, Sendable {
    case sent, decided
}

public struct Note: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public var source: Source
    public var type: NoteType
    public var text: String
    public var completed: Bool
    public var workspaceId: String?
    public var workspaceLabel: String?
    public var paneId: String?
    public var agentLabel: String?
    public var status: DecisionStatus?
    public var decidedAt: Date?

    public enum Source: String, Codable, Sendable {
        case claude, user
    }

    public enum NoteType: String, Codable, Sendable {
        case note, todo, warning, decision
    }

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        text: String,
        source: Source,
        type: NoteType = .note,
        completed: Bool = false,
        status: DecisionStatus? = nil,
        context: AgentContext? = nil,
        decidedAt: Date? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.text = String(text.prefix(4096))
        self.source = source
        self.type = type
        self.completed = completed
        self.workspaceId = context?.workspaceId
        self.workspaceLabel = context?.workspaceLabel
        self.paneId = context?.paneId
        self.agentLabel = context?.agentLabel
        self.status = status
        self.decidedAt = decidedAt
        normalize()
    }

    public mutating func normalize() {
        if type != .todo { completed = false }
        guard type == .decision else {
            status = nil
            decidedAt = nil
            return
        }
        switch status ?? .sent {
        case .sent:
            status = .sent
            decidedAt = nil
        case .decided:
            if decidedAt == nil { decidedAt = Date() }
        }
    }

    public func belongs(to context: AgentContext) -> Bool {
        workspaceId == context.workspaceId && paneId == context.paneId
    }
}
