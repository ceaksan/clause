# ADR-002: Short note refs and private decision memos

**Date:** 2026-11-08
**Status:** Accepted
**Spec:** [2026-11-07-clause-herdr-board-design](../superpowers/specs/2026-11-07-clause-herdr-board-design.md)

## Context

The board (ADR-001) shows agent decisions, but the user had no short handle to name one
when asking an agent about it; note IDs are UUIDs. The user also wanted to jot private
thoughts on a decision before answering it, and found the row layout hard to read.

## Decision

- Every note gets `seq`, a board-wide number that only grows. Its `ref` is a type prefix
  plus that number: `N-3`, `T-4`, `W-8`, `D-12`. The prefix follows the current type, so a
  note turned into a decision keeps its number (`N-12` becomes `D-12`).
- The counter is persisted. `board.json` becomes `{ "nextSeq": n, "notes": [...] }`. A
  legacy array file still loads; notes without `seq` are numbered by age.
  Numbers are never reused, even after delete, prune or restart.
- `add_note` and `list_notes` return `ref`. `edit_note` and `delete_note` accept a UUID or a
  ref (`D-12`, `d12`, `12`). A ref resolves to a note ID first; pane scoping is then
  enforced by the existing scoped edit/delete, so a ref from another pane gets `notFound`.
- Decisions can carry a `memo`, a private note of up to 1000 characters, set, edited and
  deleted from the UI only. It is persisted with the note and removed with it. It is not
  in `list_notes` and `edit_note` ignores a `memo` param.
- Row redesign: a status glyph column replaces the text badges, the ref (click to copy) and
  the post date sit in a muted meta line, open decisions get an amber tint, decided ones
  fade, workspace headers show their open count.

## Consequences

### Positive
- "What is D-12?" works with any agent that posted it; the user copies refs in one click.
- Memos keep pre-decision thinking next to the decision without leaking into agent context.

### Negative
- Refs are unique per board, not per machine history: deleting `board.json` restarts at 1.
- Memo has no undo; delete is immediate.

### Alternatives Considered
- Per-type counters (`D-1`, `N-1`): a type change would need a new number and break refs.
- Workspace-prefixed refs (`audit-3`): breaks when the label changes, falls back to IDs.
- Random short codes: unique without a counter but hard to say and remember.
- Memo visible to agents: rejected; the user wanted a private scratch space.

## Files Changed

| File | Change |
|------|--------|
| `ClauseShared/Models/Note.swift` | `seq`, `memo`, `ref`, `NoteType.refPrefix`, `Note.seq(fromRef:)` |
| `ClauseShared/IPC/SocketConstants.swift` | `maxMemoLength` |
| `ClauseApp/Store/NoteStore.swift` | Persisted counter, `noteId(forRef:)`, `setMemo`, snapshot object with legacy load |
| `ClauseApp/Server/SocketServer.swift` | `ref` in add/list results, id param accepts refs |
| `ClauseApp/Views/NoteRowView.swift` | Redesigned row, copy ref, date stamp, memo view and editor |
| `ClauseApp/Views/ContentView.swift` | Workspace/pane hierarchy, open counts, Copy ID menu item |
| `ClauseMCP/main.swift` | Tool descriptions mention refs |
| `ClauseSharedTests/ModelsTests.swift`, `ClauseAppTests/*` | Ref, counter, memo privacy, stamp tests |
