import Foundation

public struct Note: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public var source: Source
    public var type: NoteType
    public var text: String
    public var completed: Bool

    public enum Source: String, Codable, Sendable {
        case claude, user
    }

    public enum NoteType: String, Codable, Sendable {
        case note, todo, warning
    }

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        text: String,
        source: Source,
        type: NoteType = .note,
        completed: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.text = String(text.prefix(4096))
        self.source = source
        self.type = type
        self.completed = completed
    }
}
