# Show HN: Clause, a floating MCP note companion for Claude Code (macOS, Swift)

**URL:** https://github.com/ceaksan/clause

---

## First Comment

During AI-assisted coding sessions I kept losing track of things that did not belong in the codebase itself: what I had already tried, what was next, a warning about a brittle assumption, a todo that was two layers of context away from where I was working. Markdown files in the project root work but feel wrong for ephemeral session context. I built Clause to give that scratch layer a proper home, one that is aware of the session, accessible to Claude Code without interrupting flow, and gone when the session is done.

Clause is two processes. `clause-mcp` is a CLI binary that Claude Code launches as an MCP server over stdio transport, following the standard MCP server lifecycle. It connects to `Clause.app`, a SwiftUI floating window, via a POSIX Unix domain socket at `~/.clause/clause.sock`. The app manages six MCP tools: `set_session`, `add_note`, `list_notes`, `edit_note`, `delete_note`, and `clear_notes`. Notes carry a type field (note, todo, warning) and are stored in memory with debounced JSON persistence to `~/.clause/sessions/{id}.json`. The implementation uses Swift 6 strict concurrency throughout: `Sendable` types, `@MainActor` for all UI state, and `Network.framework` `NWConnection` on the client side. MCP protocol handling is via `modelcontextprotocol/swift-sdk` 0.11.0.

Milestone 1 is complete and I run it daily. The two-process socket architecture turned out to be the right call: it separates the MCP server lifecycle (managed by Claude Code) from the app lifecycle (managed by the user), which means the window survives reconnects without losing session state. Milestone 2 is in progress: global hotkey (Cmd+Shift+N) to summon the window without switching focus, multi-session tabs for parallel workspaces, and note search. The repo is at github.com/ceaksan/clause, site at clause.ceaksan.com.

Happy to answer questions about the MCP protocol, the Swift implementation, or anything else.

---

## Anticipated Objection Responses (Not for posting)

**1. "Why not just use a text file / scratchpad?"**

A text file does not know which session it belongs to, cannot be written by the AI model without an extra tool setup, and has no structure for note types. The MCP interface is the key difference: Claude Code can add a warning or todo directly during a tool call, without the user manually switching to another window and typing.

**2. "Why macOS only?"**

The floating window is a SwiftUI app, so macOS is the natural target. The `clause-mcp` binary and socket protocol are platform-agnostic in principle. A Linux CLI-only mode without the GUI layer is feasible if there is demand for it, but the window is the whole point of the current design.

**3. "Why not a VS Code extension?"**

Claude Code is a terminal tool, not a VS Code extension. The target workflow is a terminal session plus a floating overlay, not an editor sidebar. A VS Code extension would not help someone working in Neovim, Zed, or a plain terminal.

**4. "This seems over-engineered for note-taking"**

The socket architecture and MCP layer are there to make the notes writable by the AI model, not just by the user. Without that, it is just a stickies app. The complexity budget is justified by the use case.

**5. "Why Swift and not TypeScript/Electron?"**

Native SwiftUI gives a floating window with proper macOS window management, focus behavior, and system integration at roughly zero runtime overhead. An Electron app would work but would be the wrong tool for a utility that needs to sit unobtrusively on screen all day. The `clause-mcp` binary is also a native executable with no Node.js runtime dependency in the user's PATH.

**6. "Why ephemeral? I want persistent notes."**

Persistence per session exists: notes are written to `~/.clause/sessions/{id}.json` and survive app restarts within a session. What is ephemeral is the assumption that old sessions are relevant to new ones. A different session ID starts clean. Long-lived notes that should outlast sessions belong in the codebase or a proper note-taking tool, not in scratch context.
