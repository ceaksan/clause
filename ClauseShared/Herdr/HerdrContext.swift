import Foundation

public enum HerdrContext {
    public static let workspaceEnvKey = "HERDR_WORKSPACE_ID"
    public static let paneEnvKey = "HERDR_PANE_ID"

    public static func isHerdr(env: [String: String]) -> Bool {
        !(env[workspaceEnvKey] ?? "").isEmpty && !(env[paneEnvKey] ?? "").isEmpty
    }

    public static func baseContext(env: [String: String], cwd: String, pid: Int32) -> AgentContext {
        if isHerdr(env: env), let workspace = env[workspaceEnvKey], let pane = env[paneEnvKey] {
            return AgentContext(workspaceId: workspace, paneId: pane, pid: pid)
        }
        let directory = URL(fileURLWithPath: cwd).lastPathComponent
        return AgentContext(
            workspaceId: "local:\(directory)",
            paneId: "pid-\(pid)",
            workspaceLabel: directory,
            pid: pid
        )
    }

    public static func workspaceLabel(fromJSON data: Data) -> String? {
        nonEmpty(result(data)?["workspace"].flatMap { ($0 as? [String: Any])?["label"] })
    }

    public static func agentLabel(fromJSON data: Data) -> String? {
        guard let agent = result(data)?["agent"] as? [String: Any] else { return nil }
        return nonEmpty(agent["name"]) ?? nonEmpty(agent["display_agent"]) ?? nonEmpty(agent["agent"])
    }

    public static func resolve(_ base: AgentContext, env: [String: String], run: ([String]) -> Data?) -> AgentContext {
        guard isHerdr(env: env) else { return base }
        var context = base
        context.workspaceLabel = run(["workspace", "get", base.workspaceId]).flatMap(workspaceLabel(fromJSON:))
        context.agentLabel = run(["agent", "get", base.paneId]).flatMap(agentLabel(fromJSON:))
        return context
    }

    public static func run(executable: String, arguments: [String], timeout: TimeInterval) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice

        let output = OutputBuffer()
        let reader = stdout.fileHandleForReading
        reader.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
                output.finish()
            } else {
                output.append(chunk)
            }
        }

        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }
        do {
            try process.run()
        } catch {
            reader.readabilityHandler = nil
            return nil
        }

        let deadline = DispatchTime.now() + timeout
        guard exited.wait(timeout: deadline) == .success else {
            reader.readabilityHandler = nil
            process.terminate()
            return nil
        }
        let reachedEOF = output.eof.wait(timeout: deadline) == .success
        if !reachedEOF { reader.readabilityHandler = nil }
        guard process.terminationStatus == 0 else { return nil }
        return output.data
    }

    private final class OutputBuffer: @unchecked Sendable {
        private let lock = NSLock()
        private var buffer = Data()
        let eof = DispatchSemaphore(value: 0)

        var data: Data { lock.withLock { buffer } }
        func append(_ chunk: Data) { lock.withLock { buffer.append(chunk) } }
        func finish() { eof.signal() }
    }

    public static func runHerdr(_ arguments: [String]) -> Data? {
        run(executable: "/usr/bin/env", arguments: ["herdr"] + arguments, timeout: ClauseConstants.herdrTimeoutSeconds)
    }

    private static func result(_ data: Data) -> [String: Any]? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return object["result"] as? [String: Any]
    }

    private static func nonEmpty(_ value: Any?) -> String? {
        guard let string = value as? String, !string.isEmpty else { return nil }
        return string
    }
}
