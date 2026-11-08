# Clause for herdr: multi-workspace observer board

**Date:** 2026-11-07
**Status:** Approved by user 2026-11-07; the workspace clear items were confirmed 2026-11-08.
**Supersedes:** the single-session model of [2026-03-21-clause-design.md](2026-03-21-clause-design.md)
**ADR:** [ADR-001](../../adr/ADR-001-herdr-multi-workspace-board.md)

## Problem

The user now runs several coding agents in parallel inside herdr. Agents pass decision
topics to each other directly (herdr `agent prompt`). While the user looks at something
else, those topics scroll away in terminals they are not watching. The user needs one
place to glance at: which workspace and pane is discussing what, what was sent for a
decision, what got decided, so they can ask the right agent for details.

Clause today cannot do this. `NoteStore` holds one global `session` and one `notes`
list (`ClauseApp/Store/NoteStore.swift:8-9`); a second agent calling `set_session`
replaces the first agent's view. `Note.Source` only knows `claude` and `user`.

## Goals

- Multiple agents, in multiple herdr workspaces, write to one board at the same time.
- Each entry carries its herdr context (workspace, pane) without the agent supplying it.
- A `decision` entry type with two states: `sent` (decision sent) and `decided`
  (decision made).
- The panel groups entries by workspace, then pane, and shows human-readable names
  next to the IDs.
- Decided entries do not accumulate: each pane keeps its 5 most recent decided entries.

## Non-goals

- Agents do not read the board to coordinate. Agent-to-agent communication stays in
  herdr. Clause is a one-way "for your information" board for the user.
- No task management, owners, assignees, from/to fields or leases.
- No long-term persistence or history. Durable items live in vault Active Tasks and ADRs.
- No herdr plugin pane. The floating Swift window stays the UI.
- No authentication between processes. The socket lives in a 0700 directory owned by
  the user; any process running as the user can claim any context. Scoping (below)
  prevents mistakes, not a hostile local process.

## Design

### Identity: `AgentContext`

`clause-mcp` is spawned by an agent running in a herdr pane, so it inherits
`HERDR_WORKSPACE_ID` and `HERDR_PANE_ID`. It builds an `AgentContext` and attaches it to
every IPC request. Agents never pass identity themselves.

```
AgentContext {
  workspaceId: String      // HERDR_WORKSPACE_ID, or "local" outside herdr
  paneId: String           // HERDR_PANE_ID, or "pid-<pid>" outside herdr
  workspaceLabel: String?  // herdr workspace label
  agentLabel: String?      // herdr agent name or display_agent
  pid: Int32
}
```

The scope key is the pair `(workspaceId, paneId)`, never `paneId` alone. herdr does not
document whether pane IDs are unique across workspaces, sessions or server restarts;
this has not been verified. A pane ID reused after a herdr restart inside the same
workspace ID would see the previous occupant's notes. That is accepted for an
ephemeral board.

Label resolution happens in `clause-mcp` when it adds a note, so renames show up on
the next entry:

- `herdr workspace get <workspaceId>` → `result.workspace.label`
- `herdr agent get <paneId>` → `result.agent.name`, else `result.agent.display_agent`,
  else `result.agent.agent`
- Each call has a 2 second timeout, run one after the other, so a hung herdr delays
  `add_note` by at most about 4 seconds. This is accepted. Any failure (missing binary,
  non-zero exit, timeout, unparseable output) leaves the label `nil`; the panel then
  shows the ID only.
- Outside herdr (env vars missing or empty) the workspace label is the basename of the
  current working directory and no herdr call is made.

### Protocol

- `IPCRequest` gets an optional `context: AgentContext?` and `version: String?`.
- `protocolVersion` becomes `"2"`. The app rejects agent requests whose version differs,
  with `versionMismatch`. This replaces the handshake that lived in `set_session`.
- `set_session` is removed from the tool list and from the server. The `sessionNotSet`
  error code is removed.
- Agent requests without a context are rejected with `invalidParams`.

### Model

`Note` gains:

| Field            | Type              | Notes                               |
| ---------------- | ----------------- | ----------------------------------- |
| `workspaceId`    | `String?`         | `nil` for notes the user types      |
| `workspaceLabel` | `String?`         |                                     |
| `paneId`         | `String?`         | `nil` for user notes                |
| `agentLabel`     | `String?`         |                                     |
| `status`         | `DecisionStatus?` | `sent` or `decided`, decisions only |
| `decidedAt`      | `Date?`           | set when status becomes `decided`   |

`NoteType` gains `decision`. New fields decode as optional, so an old snapshot still loads.

`Session` is deleted; `AgentContext` replaces it.

### Type and status invariants

These hold after every store write, whoever makes it:

1. A note of type `decision` always has a status. Creating or converting to `decision`
   without a status gives `sent`.
2. A note of any other type has `status == nil` and `decidedAt == nil`. Converting a
   decision to another type clears both.
3. `decidedAt != nil` exactly when `status == decided`. Becoming `decided` sets it to now
   (an already decided note keeps its time); becoming `sent` clears it.
4. At the IPC boundary, a `status` on a request whose resulting type is not `decision` is
   rejected with `invalidParams`, so agent mistakes are visible. An unknown `type` or
   `status` string is also `invalidParams`.

### Store rules

- One flat `notes` array, newest first. Grouping is computed for the UI.
- Scope: agent requests only see and change notes whose `(workspaceId, paneId)` matches
  their context. `list_notes`, `edit_note`, `delete_note` and `clear_notes` are all
  scoped. A pane cannot touch another pane's notes or the user's notes, and an agent's
  tool output only ever contains notes its own pane wrote.
- Retention: after any write that leaves a pane with more than 5 `decided` decisions,
  the oldest by `decidedAt` are removed. `sent` decisions, other note types and user
  notes are not pruned.
- Status updates: the pane that wrote the decision marks it `decided` when it gets the
  answer back. The deciding agent does not know the entry ID and does not update it.
- The UI may change any note (the user owns the board).
- The UI can clear a whole workspace's entries, since closed workspaces are
  not detected automatically.

### Persistence

One debounced snapshot at `~/.clause/board.json` (500 ms debounce, plus the existing
10 s periodic flush and flush on quit), loaded at app start. The old
`~/.clause/sessions/` directory is left alone and no longer read.

### MCP tools

| Tool          | Change                                                                       |
| ------------- | ---------------------------------------------------------------------------- |
| `set_session` | Removed                                                                      |
| `add_note`    | `type` enum adds `decision`; new optional `status` (`sent`/`decided`)        |
| `edit_note`   | `type` enum adds `decision`; new optional `status`; only the caller's notes  |
| `list_notes`  | `type` enum adds `decision`; `source` filter removed; only the caller's notes |
| `delete_note` | Only the caller's notes                                                      |
| `clear_notes` | Only the caller's notes                                                      |

Tool descriptions tell agents: write a one-line headline when you send a decision topic
to another agent, mark it `decided` when the answer comes back.

### UI

- Title bar: "Clause", count of open (`sent`) decisions, pin toggle.
- The input bar is always visible; user notes are not gated on a session any more.
- Sections, top to bottom:
  1. **You**: notes the user typed.
  2. One section per workspace, ordered by latest activity. Header:
     `workspaceLabel · workspaceId` (ID only if no label), plus a clear
     button that removes that workspace's entries.
  3. Inside a workspace, one block per pane. Header: `agentLabel · paneId`.
     Rows: open decisions first, then other notes, then decided decisions (max 5).
- Decision row: badge `SENT` (amber) or `DECIDED` (green), headline text.
- Empty state: "No notes yet".

### Agent rule (outside this repo, tracked separately)

The board is only useful if agents write to it. Agent instruction files (CLAUDE.md,
AGENTS.md) need one rule: when you send a decision topic to another agent, add a Clause
`decision` note with a one-line headline; mark it `decided` when the answer arrives.
This rollout is a separate follow-up, not part of this implementation.

## Testing

Swift Testing, as in the existing suites. Every scoping and retention guarantee is tested
at the socket entry point (`SocketServer.handleRequest`), not only in the store.

- `ClauseSharedTests`: model round-trips, old JSON decoding, context building, label
  parsing, and the real herdr process runner against a missing executable, a non-zero
  exit and a process that outlives the timeout.
- `ClauseAppTests` (store): invariants 1-3, scoping, retention, grouping, snapshot.
- `ClauseAppTests` (server): cross-pane edit, delete and clear; user notes survive an
  agent `clear_notes`; the sixth decided decision prunes through `edit_note`; invariant 4;
  wrong version and missing context rejected.

## Risks

- Agents forget to write. Mitigated only by the agent rule; out of scope here.
- Label lookup spawns two `herdr` processes per `add_note`, worst case about 4 s.
- herdr API shapes may change across versions. Parsing is lenient: missing keys give
  `nil` labels, never an error.
- Pane ID uniqueness is unverified (see Identity).
