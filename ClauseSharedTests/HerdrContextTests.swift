import Testing
import Foundation
@testable import ClauseShared

private let herdrEnv = ["HERDR_WORKSPACE_ID": "w7", "HERDR_PANE_ID": "p3"]
private let workspaceJSON = Data(#"{"id":"x","result":{"type":"workspace_info","workspace":{"label":"audit","workspace_id":"w7"}}}"#.utf8)

@Suite("HerdrContext")
struct HerdrContextTests {
    @Test("Inside herdr uses env IDs")
    func contextInsideHerdr() {
        let ctx = HerdrContext.baseContext(env: herdrEnv, cwd: "/Users/x/proj", pid: 42)
        #expect(ctx.workspaceId == "w7")
        #expect(ctx.paneId == "p3")
        #expect(ctx.workspaceLabel == nil)
        #expect(ctx.agentLabel == nil)
        #expect(ctx.pid == 42)
    }

    @Test("Outside herdr falls back to a local workspace per directory")
    func contextOutsideHerdr() {
        let ctx = HerdrContext.baseContext(env: [:], cwd: "/Users/x/proj", pid: 42)
        #expect(ctx.workspaceId == "local:proj")
        #expect(HerdrContext.baseContext(env: [:], cwd: "/Users/x/other", pid: 42).workspaceId == "local:other")
        #expect(ctx.paneId == "pid-42")
        #expect(ctx.workspaceLabel == "proj")
    }

    @Test("Empty env values are not herdr")
    func emptyEnvIsNotHerdr() {
        #expect(!HerdrContext.isHerdr(env: ["HERDR_WORKSPACE_ID": "", "HERDR_PANE_ID": "p3"]))
        #expect(!HerdrContext.isHerdr(env: ["HERDR_WORKSPACE_ID": "w7"]))
        #expect(HerdrContext.isHerdr(env: herdrEnv))
    }

    @Test("Workspace label parsed")
    func workspaceLabelParsed() {
        #expect(HerdrContext.workspaceLabel(fromJSON: workspaceJSON) == "audit")
        let empty = Data(#"{"result":{"workspace":{"label":""}}}"#.utf8)
        #expect(HerdrContext.workspaceLabel(fromJSON: empty) == nil)
    }

    @Test("Agent label prefers name, then display_agent, then agent")
    func agentLabelPreference() {
        let named = Data(#"{"result":{"type":"agent_info","agent":{"name":"reviewer","display_agent":"Claude","agent":"claude"}}}"#.utf8)
        #expect(HerdrContext.agentLabel(fromJSON: named) == "reviewer")
        let unnamed = Data(#"{"result":{"agent":{"name":null,"display_agent":"Claude","agent":"claude"}}}"#.utf8)
        #expect(HerdrContext.agentLabel(fromJSON: unnamed) == "Claude")
        let kindOnly = Data(#"{"result":{"agent":{"name":"","agent":"codex"}}}"#.utf8)
        #expect(HerdrContext.agentLabel(fromJSON: kindOnly) == "codex")
    }

    @Test("Error JSON and garbage give nil")
    func labelsFromErrorJSON() {
        let error = Data(#"{"id":"x","error":{"code":"not_found","message":"no such pane"}}"#.utf8)
        #expect(HerdrContext.workspaceLabel(fromJSON: error) == nil)
        #expect(HerdrContext.agentLabel(fromJSON: error) == nil)
        #expect(HerdrContext.workspaceLabel(fromJSON: Data("nope".utf8)) == nil)
        #expect(HerdrContext.agentLabel(fromJSON: Data()) == nil)
    }

    @Test("Resolve skips herdr calls outside herdr")
    func resolveOutsideHerdr() {
        let base = HerdrContext.baseContext(env: [:], cwd: "/tmp/proj", pid: 1)
        var calls: [[String]] = []
        let resolved = HerdrContext.resolve(base, env: [:]) { args in
            calls.append(args)
            return workspaceJSON
        }
        #expect(calls.isEmpty)
        #expect(resolved == base)
    }

    @Test("Resolve fills labels; failed lookup leaves nil")
    func resolveInsideHerdr() {
        let base = HerdrContext.baseContext(env: herdrEnv, cwd: "/tmp", pid: 1)
        var calls: [[String]] = []
        let resolved = HerdrContext.resolve(base, env: herdrEnv) { args in
            calls.append(args)
            return args.first == "workspace" ? workspaceJSON : nil
        }
        #expect(calls == [["workspace", "get", "w7"], ["agent", "get", "p3"]])
        #expect(resolved.workspaceLabel == "audit")
        #expect(resolved.agentLabel == nil)
        #expect(resolved.paneId == "p3")
    }

    @Test("Runner returns stdout on success")
    func runnerSuccess() {
        let out = HerdrContext.run(executable: "/bin/echo", arguments: ["hi"], timeout: 2)
        #expect(out.flatMap { String(data: $0, encoding: .utf8) } == "hi\n")
    }

    @Test("Runner returns nil for a missing executable")
    func runnerMissingExecutable() {
        #expect(HerdrContext.run(executable: "/nonexistent/herdr", arguments: [], timeout: 2) == nil)
    }

    @Test("Runner returns nil on non-zero exit")
    func runnerNonZeroExit() {
        #expect(HerdrContext.run(executable: "/usr/bin/false", arguments: [], timeout: 2) == nil)
    }

    @Test("Runner is bounded when a child keeps stdout open after exit")
    func runnerChildHoldsPipe() {
        let start = Date()
        _ = HerdrContext.run(executable: "/bin/sh", arguments: ["-c", "sleep 5 & echo hi"], timeout: 0.5)
        #expect(Date().timeIntervalSince(start) < 1.5)
    }

    @Test("Runner gives up after the timeout")
    func runnerTimeout() {
        let start = Date()
        let out = HerdrContext.run(executable: "/bin/sleep", arguments: ["5"], timeout: 0.5)
        #expect(out == nil)
        #expect(Date().timeIntervalSince(start) < 1.5)
    }
}
