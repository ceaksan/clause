# Clause

A minimal, ephemeral note-taking companion for Claude Code sessions.

<p align="center">
  <video src="assets/demo.mp4" autoplay loop muted playsinline width="800"></video>
</p>

## Why Clause?

During Claude Code sessions, you accumulate scratch context: decisions made, warnings to remember, TODOs to track. This context lives in your head or gets buried in terminal output. Clause gives it a visible, structured home that both you and Claude can read and write to, in real time.

## What it does

Clause is a floating scratchpad that lives alongside your terminal. Claude Code pushes notes, todos, and warnings to it during sessions via MCP tools. You can also add your own notes directly. Everything stays visible in a floating panel while you work, and disappears when the session ends.

## How it works

Clause uses a two-process architecture:

1. **`clause-mcp`** : CLI binary spawned by Claude Code as an MCP server (stdio transport)
2. **`Clause.app`** : SwiftUI floating window that manages and displays notes
3. Both processes communicate via Unix domain socket at `~/.clause/clause.sock`

Claude Code spawns `clause-mcp`, which connects to the running `Clause.app` instance. All MCP tool calls are forwarded over the socket in real time.

## MCP Tools

| Tool          | Description                               |
| ------------- | ----------------------------------------- |
| `set_session` | Set the current session name and context  |
| `add_note`    | Add a note, todo, or warning to the panel |
| `list_notes`  | List all notes in the current session     |
| `edit_note`   | Update an existing note by ID             |
| `delete_note` | Remove a note by ID                       |
| `clear_notes` | Clear all notes for the current session   |

## Requirements

- macOS 14+ (Sonoma)
- Xcode 16+
- Swift 6

## Quick Start

```bash
git clone https://github.com/ceaksan/clause.git
cd clause
brew install xcodegen && xcodegen generate
open Clause.xcodeproj
```

Build and run the **Clause** scheme in Xcode, then add `clause-mcp` to your Claude Code config:

```json
{
  "mcpServers": {
    "clause": {
      "command": "/path/to/Clause.app/Contents/MacOS/clause-mcp"
    }
  }
}
```

Replace `/path/to/Clause.app` with the actual path to the built app bundle.

## Building

```bash
xcodebuild -scheme Clause -configuration Debug build
xcodebuild -scheme ClauseMCP -configuration Debug build
```

## Testing

```bash
xcodebuild test -scheme Clause -destination 'platform=macOS'
xcodebuild test -scheme ClauseShared -destination 'platform=macOS'
```

## Architecture

See [architecture.md](architecture.md) for full technical details.

## Roadmap

- [x] Milestone 1: CLI MCP server + floating window + bidirectional IPC
- [ ] Milestone 2:
  - Global hotkey (Cmd+Shift+N) to capture clipboard content as a note
  - Multi-session tabs (each Claude Code session gets its own tab)
  - Session cleanup (auto-remove old JSON files)
  - Accessibility permission handling with fallback UI
  - Pin/unpin floating window (toggle already built)
  - Note search and filtering in the UI
  - `completed` filter for `list_notes` tool
- [ ] Milestone 3: Distribution (DMG, Homebrew cask, code signing)

## Tech Stack

Swift 6, SwiftUI, AppKit, Network.framework, [modelcontextprotocol/swift-sdk](https://github.com/modelcontextprotocol/swift-sdk)

## License

MIT
