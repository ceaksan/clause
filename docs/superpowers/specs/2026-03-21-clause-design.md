# Clause - Claude Code Session Companion

Minimal, ephemeral note-taking companion for Claude Code sessions. Floating SwiftUI window + MCP server, all Swift, two-process model. Bidirectional: Claude sends notes/todos via MCP tools, user captures content via global hotkey or app UI.

## System Architecture

### Two-Process Model

```
Claude Code ──stdio──> clause-mcp (CLI binary)
                            │
                     Unix domain socket
                     (~/.clause/clause.sock)
                            │
                      Clause.app (SwiftUI)
                      ┌─────────────┐
                      │ NoteStore   │  in-memory [Note] array
                      │ SocketServer│  NWListener on UDS
                      │ NSPanel     │  floating window
                      │ JSON file   │  debounced snapshot
                      └─────────────┘
```

### Why Two-Process

- Claude Code spawns MCP servers as child processes via stdio
- NSApplication.run() needs main thread for UI event loop
- Single-process is fragile (thread management, stdout contamination)
- CLI handles MCP protocol, app handles UI and state

### Deployment

- Single .app bundle containing both binaries
- CLI at: `Clause.app/Contents/MacOS/clause-mcp`
- App at: `Clause.app/Contents/MacOS/Clause`
- Claude Code config:
  ```json
  {"command": "/Applications/Clause.app/Contents/MacOS/clause-mcp"}
  ```

## Project Structure

Xcode project with two targets + shared static library (iMCP pattern).

```
Clause.xcodeproj
├── ClauseShared (static library target)
│   ├── Models/Note.swift
│   ├── Models/Session.swift
│   ├── IPC/SocketProtocol.swift
│   └── IPC/MessageTypes.swift
├── ClauseMCP (command line tool target)
│   └── main.swift
├── ClauseApp (macOS app target)
│   ├── App.swift
│   ├── Store/NoteStore.swift
│   ├── Server/SocketServer.swift
│   ├── Views/NoteListView.swift
│   ├── Views/NoteRowView.swift
│   ├── Views/InputBar.swift
│   └── Hotkey/HotkeyManager.swift
```

### Dependencies

- `modelcontextprotocol/swift-sdk` (MCP protocol, via SPM in Xcode)
- `sindresorhus/KeyboardShortcuts` (global hotkey, via SPM in Xcode)
- `Network.framework` (Unix domain socket)
- `SwiftUI` / `AppKit` (UI)

## Data Model

### Note

```swift
struct Note: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    var source: Source
    var type: NoteType
    var text: String
    var completed: Bool  // todo checkbox

    enum Source: String, Codable { case claude, user }
    enum NoteType: String, Codable { case note, todo, warning }
}
```

### Session

```swift
struct Session: Codable {
    let id: String
    let directory: String
    let protocolVersion: String  // "1"
    let pid: Int32
    let startedAt: Date
}
```

## MCP Tools

Six tools exposed via MCP protocol:

| Tool | Parameters | Return |
|---|---|---|
| `set_session` | `id: string, directory: string` | `{ok: true}` |
| `add_note` | `text: string, type?: "note"\|"todo"\|"warning"` | `{id, ts}` |
| `list_notes` | `type?: string, source?: string` | `[{id, ts, source, type, text, completed}]` |
| `edit_note` | `id: string, text?: string, type?: string, completed?: bool` | `{ok: true}` |
| `delete_note` | `id: string` | `{ok: true}` |
| `clear_notes` | - | `{cleared: count}` |

> `set_session`: The CLI internally injects `version` and `pid` fields into the IPC message. These are not MCP tool parameters visible to Claude.

## IPC Protocol

### Transport

- Unix domain socket at `~/.clause/clause.sock`
- Directory permissions: `0o700`
- App side: `NWListener` (server)
- CLI side: `NWConnection` (client)
- Framing: Newline-delimited JSON (`\n` terminated)

### Message Format

Request (CLI to App):
```json
{"action": "add_note", "params": {"text": "...", "type": "todo"}, "reqId": "uuid"}
```

Response (App to CLI):
```json
{"result": {"id": "uuid", "ts": "..."}, "reqId": "uuid"}
```

Error:
```json
{"error": {"code": -1, "message": "Not found"}, "reqId": "uuid"}
```

### Error Codes

| Code | Meaning | MCP Mapping |
|------|---------|-------------|
| -1 | Note not found (invalid ID) | -32602 (Invalid params) |
| -2 | Invalid parameters (missing/wrong type) | -32602 (Invalid params) |
| -3 | Session not set (tool called before set_session) | -32603 (Internal error) |
| -4 | Internal error (storage, unexpected) | -32603 (Internal error) |
| -5 | Version mismatch (protocol incompatible) | -32603 (Internal error) |

### Connection Policy

Single active session. When a new CLI connects with `set_session`:
1. Current session notes are flushed to JSON
2. Previous CLI connection receives a `{"shutdown": {"reason": "replaced"}}` message
3. Previous connection is closed
4. New session starts fresh (or loads from existing JSON if same session ID)

### Protocol Details

- `set_session` includes `version: "1"` and `pid` fields (injected by CLI, not MCP params)
- On version mismatch: app responds with error code -5 and message indicating expected version
- Request timeout: 30 seconds per request
- Buffering: Accumulate data until newline, then parse complete JSON line
- Path resolution: `NSHomeDirectory()` + `.clause/clause.sock` (never tilde)
- Date encoding: ISO 8601 format for both IPC messages and storage JSON
- Note text limit: 4096 characters max, truncated silently if exceeded
- Design scope: single-user-per-home-directory (socket permissions protect via 0o700)

## CLI Flow (clause-mcp)

1. Start: MCP handshake over stdin/stdout (initialize/initialized)
2. Try connecting to Unix socket
3. If connection fails: `open -a Clause.app`, poll socket with exponential backoff (100ms start, 1.5x multiplier, max 1s interval, 10s total timeout)
4. Connection established: send `set_session` with session ID, directory, protocol version, PID
5. Main loop: read MCP JSON-RPC from stdin, forward tool calls over socket, write response to stdout
6. On stdin EOF: close socket, exit
7. Error mapping: socket errors map to MCP JSON-RPC error codes (-32603 internal error)

## App Socket Server

1. App launch: create `~/.clause/` directory with `0o700` permissions
2. Unlink stale socket if exists
3. `NWListener` bind to `~/.clause/clause.sock`
4. Accept connections, read newline-delimited JSON with proper buffering
5. Parse action, execute CRUD on in-memory NoteStore
6. Write JSON response + `\n`
7. On listener failure: retry after 1s delay
8. On app terminate: send shutdown message to connected CLIs, flush notes, unlink socket

### Error Handling

- App crashes: CLI gets socket error, returns MCP error response
- CLI crashes: Socket connection closes, app continues, notes preserved
- Stale socket: App unlinks on startup, rebinds
- App graceful shutdown: Notifies connected CLIs with shutdown message before closing

## Storage

### In-Memory + JSON Snapshot

- Runtime: `@MainActor NoteStore` with `@Published var notes: [Note]`
- Persist: Debounced (500ms) atomic JSON write to `~/.clause/sessions/{session-id}.json`
- Atomic write: `Data.write(to:options:.atomic)` prevents corruption
- Load: On `set_session`, load from JSON file if exists
- Periodic save: Every 10 seconds as crash safety net
- Eager flush: On `applicationWillTerminate`, `didResignActiveNotification`, and CLI disconnect
- Accepted trade-off: crash between periodic saves may lose up to 10 seconds of notes (acceptable for ephemeral scratchpad)

### Session Cleanup

- On app launch: delete `~/.clause/sessions/*.json` files older than 7 days
- Manual: `clear_notes` MCP tool clears current session

## Window Design

### NSPanel Configuration

- Type: `NSPanel` with `.floating` level
- Default size: 320x480
- Min size: 280x300, resizable
- Collection behavior: `.canJoinAllSpaces`, `.fullScreenAuxiliary`
- Movable by window background
- Transparent title bar with hidden title visibility
- Toggle: floating by default, global hotkey toggles visibility

### Color System (Dark Theme, Ghostty-Compatible)

| Role | Value |
|---|---|
| Surface | #1a1a1a |
| Card | #1f1f1f |
| Border | #2a2a2a |
| Text primary | #d4d4d4 |
| Text secondary | #888888 |
| Text muted | #555555 |

### Type Accents

| Type | Color | Left Border |
|---|---|---|
| Note | #6366f1 (indigo) | 3px |
| Todo | #fb923c (orange) | 3px |
| Warning | #f87171 (red) | 3px |

### Typography

- SF Mono: paths, metadata, timestamps
- SF Pro: note content
- Scale: 9px (labels), 10px (metadata), 11px (secondary), 13px (body)

### Spacing

- Base grid: 4px
- Card padding: 10-12px
- List gap: 6px
- Section padding: 8px

### Note Row Layout

```
┌─────────────────────────────────┐
│▌ [TYPE BADGE] [SOURCE]  [TIME] │
│▌ Note text content here...     │
└─────────────────────────────────┘
```

- Left border: 3px colored by type
- Type badge: uppercase label (NOTE/TODO/WARNING) with type color
- Source: C (Claude) / U (User)
- Time: HH:mm format
- Todo: checkbox before source indicator, strikethrough when completed
- Completed todos: 50% opacity

### Input Bar

- Bottom-fixed, border-top separator
- Text input field with "Add a note..." placeholder
- Type selector buttons: N (note), T (todo), W (warning)
- Enter to submit, Esc to clear

### States

- **Active session**: Normal appearance, green connection dot in title bar
- **Standby** (app launched without CLI): "Waiting for session..." message
- **Disconnected**: Dimmed appearance, "Session ended" banner, read-only mode

## Global Hotkey

### API

Use `KeyboardShortcuts` package (sindresorhus) which wraps Carbon `RegisterEventHotKey`. This is preferred over `NSEvent.addGlobalMonitorForEvents` because:
- Can suppress events (prevent propagation to other apps)
- Works when app is frontmost AND when other apps are frontmost
- SwiftUI-friendly API
- Handles edge cases (key remapping, non-US keyboards)

### Default Shortcut

Cmd+Shift+N

### Behavior

- Window hidden: Show window + paste clipboard string to input + focus input
- Window visible: Hide window
- Clipboard handling: Check `NSPasteboard.general.string(forType: .string)`, ignore non-text content
- Input field: Set text (not append), select all so typing replaces

### Accessibility Permission

- Required for global hotkey functionality
- Check with `AXIsProcessTrustedWithOptions` on first hotkey registration
- Periodic check (every 5s) for permission revocation during runtime
- If revoked: disable hotkey, show subtle notification with "Grant Permission" button
- If denied on first prompt: hotkey unavailable, window accessible via Dock icon click or menu bar "Show Window" item
- Deep link to Settings: `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`

## App Lifecycle

### Launch (CLI-triggered or manual)

1. Create `~/.clause/` directory (0o700)
2. Unlink stale socket
3. NWListener bind
4. Clean up old session files (7 days)
5. Register global hotkey
6. Window starts hidden

### set_session Received

1. Save session info
2. Load previous notes from JSON if exists
3. Show window

### CLI Disconnect

1. Flush notes to JSON
2. Show "Session ended" state
3. Window stays open (user can review notes)
4. New CLI can connect (resets to active state)

### Window Close (Cmd+W)

- `orderOut(nil)` - hide, not close
- App doesn't quit
- Socket stays active
- Hotkey can reopen

### Window Hide (Esc)

- Same as Cmd+W

### App Quit (Cmd+Q)

1. Send shutdown message to connected CLIs
2. Flush notes to JSON
3. Unlink socket
4. Exit

### Multi-Screen

- On show: position on screen containing mouse cursor (`NSEvent.mouseLocation`)
- Listen for `NSApplication.didChangeScreenParametersNotification` to reposition if needed

## First Milestone

CLI MCP server + minimal floating window, bidirectional communication working:

1. Xcode project with 3 targets (ClauseShared, ClauseMCP, ClauseApp)
2. CLI: MCP handshake, socket client, all 6 MCP tools
3. App: Socket server, NoteStore, basic NoteListView
4. IPC: Unix domain socket, newline-delimited JSON, request/response
5. Window: NSPanel floating, dark theme, note list display
6. No hotkey, no session cleanup in first milestone

## Future Considerations

- Multiple session support (tabs or session switcher)
- Export session notes to markdown
- URL scheme (`clause:append?text=...`) for non-MCP contexts
- Distribution: DMG with drag-to-Applications, Homebrew tap
- Configurable auto-close timer after session ends

## Court Verdict

**Date:** 2026-03-22
**Jurors:** Claude (orchestrator), Gemini 2.5 Flash (security/performance), Kimi K2.5 (architecture/necessity)
**Verdict:** GO (conditional)
**Score:** 5.9/10

| Criterion | Claude | Gemini | Kimi | Avg |
|-----------|--------|--------|------|-----|
| Security | PASS | FAIL* | FAIL* | PASS (override) |
| Conflict | PASS | FAIL* | FAIL* | PASS (override) |
| Benefit | 7 | 2 | 3 | 4.0 |
| Necessity | 6 | 1 | 2 | 3.0 |
| Burden | 5 | 2 | 9 | 5.3 |
| Performance | 8 | 4 | 4 | 5.3 |
| Bottleneck | 8 | 1 | 8 | 5.7 |
| Currency | 7 | 7 | 3 | 5.7 |

*\* Overridden by orchestrator. See Dissenting Opinions.*

### Must-Meet Override Reasoning

**Security FAILs overridden to PASS:** Both jurors cited "any local process can connect to socket." This applies to ALL local IPC mechanisms on Unix (including XPC for non-sandboxed apps). 0o700 directory permissions are the standard mitigation. No new attack surface is introduced. Notes contain session scratchpad text, not credentials.

**Conflict FAILs overridden to PASS:** Gemini cited "conflicts with developer's expertise" which is not the Conflict criterion (it measures pattern/dependency/convention conflicts). Kimi cited race conditions in connection policy, which is valid engineering feedback but is an implementation concern, not a pattern conflict. Greenfield project has no existing patterns to conflict with.

### Dissenting Opinions

- **Gemini:** Developer expertise mismatch is the core risk. Swift/SwiftUI/macOS is outside primary stack. Time spent here is time not spent on revenue-generating products. Existing tools (Raycast, Obsidian) could solve this.
- **Kimi:** Architecture astronauting. Two-process model + custom IPC for a personal sticky note is overengineered. Suggested: single SwiftUI app with CoreData, or use Obsidian with a global hotkey instead.

### Rationale

The spec is technically sound and well-researched (iMCP pattern, model consensus on all major decisions). The real risk is not architecture but **developer burden**: building a Swift/macOS app outside primary expertise. The external jurors' concern about necessity is valid but discounts the MCP integration angle, which no existing tool provides. This is a personal productivity tool with learning value (Swift, macOS development), and the two-process model is inherently complex but proven.

**GO conditions:**
1. Time-box milestone 1 to 1 week. If socket IPC is not working by then, reassess.
2. Do not gold-plate. Ship the scratchpad, not a product.
3. Accept that this is a learning project with productivity upside, not a business asset.
