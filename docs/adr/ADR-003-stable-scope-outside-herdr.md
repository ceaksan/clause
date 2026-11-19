# ADR-003: Workspace read scope outside herdr, ref lookup across panes

**Date:** 2026-11-19
**Status:** Accepted
**Amends:** [ADR-001](ADR-001-herdr-multi-workspace-board.md) (request scoping)

## Context

ADR-001 scopes every agent request to the caller's `(workspaceId, paneId)`. Outside herdr
the pane is `pid-<pid>`, the pid of the `clause-mcp` process. That pid changes whenever the
agent session restarts or the client runs `clause-mcp` once per call, so the agent loses its
own notes: `list_notes` no longer shows them and `edit_note` returns "Note not found".
Seen 2026-11-19 with D-55 and D-56, posted from an agent in an hc (herdr-core) terminal,
which exports `HC_*` and not `HERDR_*`; the user had to mark them decided by hand.

Inside herdr the same thing happens in a smaller way: once a pane is closed, a user who
hands its ref to an agent in another pane cannot have that note marked decided.

The fix has to hold for every user, not one terminal setup.

## Decision

Three access levels, checked in `Note`:

| Level | Rule | Used by |
|-------|------|---------|
| `belongs(to:)` | same workspace and same pane | `delete_note`, `clear_notes` |
| `isReadable(by:)` | `belongs`, or the caller is outside herdr (`local:` workspace) and in the same workspace | `list_notes`, `edit_note` by UUID |
| `sharesWorkspace(with:)` | same workspace | `list_notes` with `ref`, `edit_note` by ref |

- Outside herdr the folder (`local:<path>`) is the stable identity for reading and editing.
  The pid stays as the pane ID, so the board still groups one session's notes together and
  destructive calls stay limited to the session that posted.
- A ref is something the user hands to an agent, so lookup and edit by ref reach any pane in
  the caller's workspace, inside herdr too. `list_notes` gains an optional `ref` parameter
  that returns only that note. Edit by UUID inside herdr stays pane-scoped.
- No workspace boundary is crossed: a ref from another workspace is "not found".
- Protocol version stays 2: `ref` is an optional parameter and old clients never send it.

## Consequences

### Positive
- A restarted or one-shot agent outside herdr keeps listing and closing its decisions.
- The user can hand any ref in a workspace to any agent in that workspace to mark decided.
- No configuration, no terminal-specific environment variables.

### Negative
- Two agents in the same folder outside herdr see and can edit each other's notes. The board
  is single-user and scoping was never authentication (ADR-001), so this is accepted.
- After a restart outside herdr the old session's notes cannot be deleted or cleared by the
  new session; they age out through decided retention or are cleared from the panel.
- Each restart outside herdr still opens a new pane group on the board.

### Alternatives Considered
- Terminal ID chain (`HERDR_PANE_ID`, then `HC_TERMINAL_ID`, `TMUX_PANE`, `WEZTERM_PANE`,
  `TERM_SESSION_ID`, then pid): stable across restarts in one terminal, but it depends on the
  terminal. Ghostty exports no per-surface ID, and the list never ends. Kept as a possible
  later improvement for board grouping only.
- Agent session ID (`CLAUDE_CODE_SESSION_ID`): agent-specific, unverified for Codex, and a
  new session gets a new ID, so it does not fix the restart case.
- Ref edit only, no workspace read scope: fixes `edit_note` but `list_notes` without a ref
  still loses the session's own notes.

## Files Changed

| File | Change |
|------|--------|
| `ClauseShared/Models/Note.swift` | `isReadable(by:)`, `sharesWorkspace(with:)` next to `belongs(to:)` |
| `ClauseShared/Models/AgentContext.swift` | `isLocal` |
| `ClauseShared/Herdr/HerdrContext.swift` | `localWorkspacePrefix` constant |
| `ClauseApp/Store/NoteStore.swift` | List by read scope, `note(ref:caller:)`, `editableNote`, edit `byRef` |
| `ClauseApp/Server/SocketServer.swift` | `list_notes` `ref` param, ref-aware edit; delete stays pane-scoped |
| `ClauseMCP/main.swift` | `list_notes` `ref` schema, tool descriptions |
| `ClauseAppTests/SocketServerTests.swift` | `editByRef` inverted, `listByRef`, `localWorkspaceScope` |
| `ClauseSharedTests/HerdrContextTests.swift` | `localReadScope` |
