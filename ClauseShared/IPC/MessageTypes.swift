import Foundation

public enum ErrorCode: Int, Codable, Sendable {
    case notFound = -1
    case invalidParams = -2
    case sessionNotSet = -3
    case internalError = -4
    case versionMismatch = -5
}

public struct IPCRequest: Codable, Sendable {
    public let action: String
    public let params: [String: IPCValue]
    public let reqId: String

    public init(action: String, params: [String: IPCValue] = [:], reqId: String = UUID().uuidString) {
        self.action = action
        self.params = params
        self.reqId = reqId
    }
}

public struct IPCResponse: Codable, Sendable {
    public let result: [String: IPCValue]?
    public let error: IPCError?
    public let reqId: String
    public let shutdown: ShutdownInfo?

    public init(result: [String: IPCValue], reqId: String) {
        self.result = result
        self.error = nil
        self.reqId = reqId
        self.shutdown = nil
    }

    public init(error: IPCError, reqId: String) {
        self.result = nil
        self.error = error
        self.reqId = reqId
        self.shutdown = nil
    }

    public init(shutdown: ShutdownInfo) {
        self.result = nil
        self.error = nil
        self.reqId = ""
        self.shutdown = shutdown
    }
}

public struct IPCError: Codable, Sendable {
    public let code: Int
    public let message: String

    public init(code: ErrorCode, message: String) {
        self.code = code.rawValue
        self.message = message
    }
}

public struct ShutdownInfo: Codable, Sendable {
    public let reason: String

    public init(reason: String) {
        self.reason = reason
    }
}

public enum IPCValue: Codable, Sendable, Equatable {
    case string(String)
    case int(Int)
    case bool(Bool)
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) { self = .string(str) }
        else if let int = try? container.decode(Int.self) { self = .int(int) }
        else if let bool = try? container.decode(Bool.self) { self = .bool(bool) }
        else if container.decodeNil() { self = .null }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type") }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        case .bool(let b): try container.encode(b)
        case .null: try container.encodeNil()
        }
    }

    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    public var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }
}
