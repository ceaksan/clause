---
name: Clause # project.yml targets.Clause.settings.base.PRODUCT_NAME (Info.plist is generated, CFBundleName = PRODUCT_NAME)
company: ceaksan # decided by Ceair 2026-11-21
brand: Clause # decided by Ceair 2026-11-21
design_version: 1.0.0
product_version: 0.3.0 # project.yml settings.base.MARKETING_VERSION
source_commit: 54f3a11
updated: 2026-11-21
template: design/template.fig
status: implemented
schemes: [dark] # colors are hardcoded dark values; no light variant, no colorScheme handling
source:
  - ClauseApp/Views/NoteRowView.swift # status and type colors (static lets), row, memo
  - ClauseApp/Views/ContentView.swift # surfaces, title bar, board, groups, dialogs
  - ClauseApp/Views/InputBar.swift # input field and type buttons
  - ClauseApp/ClauseApp.swift # window size, level, window background
colors:
  # Literal SwiftUI/AppKit values from source; hex is the 8-bit rounding of each component.
  window-bg: { value: "NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.95)", hex: "#1A1A1AF2" }
  title-bar-bg: { value: "Color(white: 0.05)", hex: "#0D0D0D" }
  board-bg: { value: "Color(white: 0.075)", hex: "#131313" }
  memo-editor-bg: { value: "Color(white: 0.08)", hex: "#141414" }
  row-bg: { value: "Color(white: 0.1)", hex: "#1A1A1A" }
  input-bg: { value: "Color(white: 0.12)", hex: "#1F1F1F" }
  row-bg-hover: { value: "Color(white: 0.13)", hex: "#212121" }
  memo-bg: { value: "Color(white: 0.16)", hex: "#292929" }
  divider: { value: "Color(white: 0.17)", hex: "#2B2B2B" }
  type-button-bg: { value: "Color(white: 0.17)", hex: "#2B2B2B" }
  line: { value: "Color(white: 0.2)", hex: "#333333" } # input border, pane rail
  type-button-bg-selected: { value: "Color(white: 0.25)", hex: "#404040" }
  text-empty: { value: "Color(white: 0.33)", hex: "#545454" } # also unpinned pin icon
  text-counter: { value: "Color(white: 0.35)", hex: "#595959" }
  icon-trash-header: { value: "Color(white: 0.38)", hex: "#616161" }
  text-meta: { value: "Color(white: 0.4)", hex: "#666666" } # meta row, workspace subtitle, pane header, strikethrough
  text-closed: { value: "Color(white: 0.5)", hex: "#808080" } # completed or decided note text, memo icons
  type-button-fg: { value: "Color(white: 0.53)", hex: "#878787" }
  icon-action: { value: "Color(white: 0.55)", hex: "#8C8C8C" } # row actions, ref button
  text-pane: { value: "Color(white: 0.7)", hex: "#B3B3B3" }
  text-memo: { value: "Color(white: 0.72)", hex: "#B8B8B8" }
  text-title: { value: "Color(white: 0.75)", hex: "#BFBFBF" }
  ref-copied: { value: "Color(white: 0.8)", hex: "#CCCCCC" }
  icon-pinned: { value: "Color(white: 0.83)", hex: "#D4D4D4" }
  text-body: { value: "Color(white: 0.9)", hex: "#E6E6E6" } # note text, error bar text
  text-workspace: { value: "Color(white: 0.95)", hex: "#F2F2F2" }
  type-button-fg-selected: { value: "Color.white", hex: "#FFFFFF" }
  sent: { value: "Color(red: 0.98, green: 0.75, blue: 0.14)", hex: "#FABF24" } # open decision, open pill, memo accent
  decided: { value: "Color(red: 0.29, green: 0.78, blue: 0.47)", hex: "#4AC778" }
  note: { value: "Color(red: 0.51, green: 0.55, blue: 0.97)", hex: "#828CF7" }
  todo: { value: "Color(red: 0.98, green: 0.57, blue: 0.24)", hex: "#FA913D" }
  warning: { value: "Color(red: 0.97, green: 0.44, blue: 0.44)", hex: "#F77070" } # warning marker, error bar
  opacities: # applied to the colors above
    open-decision-fill: 0.07 # sent
    open-pill-fill: 0.14 # sent
    error-bar-fill: 0.18 # warning
    open-decision-stroke: 0.22 # sent
    memo-editor-stroke: 0.4 # sent
    memo-rail: 0.5 # sent
    todo-done-marker: 0.5 # todo
    decided-stamp: 0.6 # decided
    decided-marker: 0.75 # decided
    row-actions-idle: 0.35 # whole action group when not hovered
typography:
  family: "system (SF Pro), .system(size:)"
  mono: ".system(design: .monospaced)"
  title: { size: 12pt, weight: semibold } # "Clause" in title bar
  workspace: { size: 13pt, weight: bold }
  pane: { size: 11pt, weight: semibold }
  pane-id: { size: 10pt, design: monospaced }
  workspace-subtitle: { size: 10pt, design: monospaced }
  note-text: { size: 13pt, weight: regular, line-spacing: 4pt, line-limit: 6 }
  note-text-open-decision: { size: 13pt, weight: medium }
  meta: { size: 10pt, design: monospaced }
  memo: { size: 12pt, line-spacing: 3pt }
  memo-counter: { size: 9pt, design: monospaced }
  memo-buttons: 11pt
  input: 13pt
  type-button: { size: 10pt, weight: medium, design: monospaced }
  open-pill: { size: 10pt, weight: semibold }
  error-bar: 11pt
  empty: 13pt
  icon-row-action: 10pt
  icon-marker: 12pt # todo, decision; warning 11pt
  icon-pane: 9pt
  icon-ref-copy: 9pt
spacing:
  title-bar: { horizontal: 14pt, vertical: 10pt, gap: 8pt }
  error-bar: { horizontal: 14pt, vertical: 8pt, gap: 6pt }
  board: { horizontal: 10pt, vertical: 12pt, group-gap: 18pt }
  workspace-stack: 10pt # header to panes; 6pt in the "You" group
  workspace-header: { horizontal: 4pt, gap: 6pt }
  pane-stack: 4pt
  pane-indent: { rail-offset: 4pt, content: 10pt }
  row: { vertical: 8pt, horizontal: 10pt, marker-gap: 10pt, stack: 4pt }
  meta-gap: 6pt
  row-actions-gap: 8pt
  memo: { vertical: 5pt, horizontal: 8pt, top: 2pt }
  input-bar: { horizontal: 10pt, vertical: 8pt, gap: 8pt }
  input-field: { horizontal: 12pt, vertical: 8pt }
  type-button: { horizontal: 8pt, vertical: 4pt, gap: 4pt }
  open-pill: { horizontal: 6pt, vertical: 2pt }
rounded:
  row: 6pt
  input: 6pt
  memo: 4pt
  memo-editor: 4pt
  type-button: 4pt
  open-pill: capsule
components:
  window: { default: "320 x 480pt", min: "280 x 300pt", level: floating, title-bar: hidden }
  marker: { frame: "14 x 17pt" }
  note-dot: { size: "6 x 6pt" }
  pane-rail: { width: 1pt }
  memo-rail: { width: 2pt }
  memo-editor: { min-height: 44pt, max-height: 90pt, padding: 4pt, border: 1pt }
  input-field: { border: 1pt }
  open-decision-row: { border: 1pt }
motion:
  ref-copied-feedback: 1.2s # checkmark replaces copy icon, NoteRowView.swift:248
---

# Clause design

Clause is a floating macOS board that shows what coding agents decided, grouped by herdr workspace and pane. This file describes the shipped 0.3.0 window. The SwiftUI views are the source of truth: [ContentView](ClauseApp/Views/ContentView.swift), [NoteRowView](ClauseApp/Views/NoteRowView.swift), [InputBar](ClauseApp/Views/InputBar.swift), window setup in [ClauseApp.swift](ClauseApp/ClauseApp.swift). When this file and a view disagree, the view wins. The [editable OpenPencil template](design/template.fig) will hold every window state listed below.

## Overview

- **Product**: a scratch board next to the terminal. Agents post notes, todos, warnings and decision headlines through the `clause-mcp` MCP server; the user reads them, checks todos, marks decisions decided and adds private memos. See [README](README.md), [architecture.md](architecture.md) and ADRs [001](docs/adr/ADR-001-herdr-multi-workspace-board.md), [002](docs/adr/ADR-002-note-refs-and-private-memos.md), [003](docs/adr/ADR-003-stable-scope-outside-herdr.md).
- **Users**: a developer running parallel Claude Code or Codex sessions, usually inside herdr.
- **Platform**: macOS 14+, SwiftUI with AppKit window tweaks. `LSUIElement` is true (project.yml:49), so there is no Dock icon and no app menu.
- **Surfaces**: one window (`Window("Clause", id: "main")`), its two confirmation dialogs and the row context menu. No settings, no menu bar extra, no sheets.
- **Not part of the app**: `clause-mcp` has no UI. `docs/index.html` is a separate marketing page (clause.ceaksan.com) with its own CSS tokens and JetBrains Mono; it is out of scope here. `docs/clause-ui.svg` and `assets/demo*` are illustrations of the window, not sources (see Known gaps).

## Colors

The window is dark only. Every color is a literal in a view file; there is no asset catalog, no named color and no light variant. System controls inside the window (TextField, TextEditor, Cancel and Save buttons, confirmation dialogs, context menu) use system styling.

| Role | Tokens | Use |
| --- | --- | --- |
| Window | `window-bg` | NSWindow background at 95% alpha, behind the SwiftUI content. |
| Surfaces | `title-bar-bg`, `board-bg`, `row-bg`, `row-bg-hover`, `memo-bg`, `memo-editor-bg`, `input-bg` | Title bar is darkest, board below it, rows lighter, hovered rows lighter still. |
| Structure | `divider`, `line` | Dividers above and below the board; input border and the 1 pt pane rail. |
| Text ramp | `text-workspace` 0.95, `text-body` 0.9, `text-title` 0.75, `text-memo` 0.72, `text-pane` 0.7, `text-closed` 0.5, `text-meta` 0.4, `text-empty` 0.33 | Gray ramp by importance. Closed items (completed todo, decided decision) drop to 0.5. |
| Open decision | `sent` | Dotted circle marker, row tint (0.07) and stroke (0.22), "N open" pill, memo rail and editor stroke. |
| Decided | `decided` | Filled check marker at 0.75, "decided <time>" stamp at 0.6. |
| Note types | `note`, `todo`, `warning` | Note dot, todo checkbox (0.5 when done), warning triangle. |
| Error | `warning` | Error bar icon and fill at 0.18. The same red as warning notes. |

## Typography

System font at fixed point sizes, no Dynamic Type styles. Monospaced (`.system(design: .monospaced)`) for everything that is an identifier or a time: refs, timestamps, pane and workspace IDs, type buttons, memo counter. Headings stay small: workspace 13 pt bold is the largest heading, the app title is 12 pt semibold. Note text is 13 pt regular, medium for an open decision, capped at 6 lines with 4 pt line spacing.

## Layout

- **Window**: default 320 x 480 pt, minimum 280 x 300 pt (ClauseApp.swift:29, :48; ContentView.swift:49). Hidden title bar, movable by background, floating level, joins all Spaces and full screen (ClauseApp.swift:44-47).
- **Vertical structure** (ContentView.swift:14-47): title bar, optional error bar, divider, board or empty state, divider, input bar.
- **Title bar**: "Clause" left; right side the "N open" pill (only when there are open decisions) and the pin toggle.
- **Board**: a scroll view with a lazy stack, 18 pt between groups. Order: the "You" group (user notes, no workspace) first, then workspace groups sorted by latest activity (NoteStore.swift:161-187).
- **Workspace group**: header (name, monospaced subtitle, "N open" pill when more than one workspace exists, trash button), then pane groups.
- **Pane group**: indented 14 pt total with a 1 pt rail on the left; header with a terminal icon, agent label and pane ID; then rows.
- **Row order inside a pane** (NoteStore.swift:222-232): open decisions newest first, then notes, todos and warnings newest first, then decided decisions by decision time.
- **Density**: one column, fixed widths only from padding; text wraps.

## Elevation and depth

Flat. No shadows. Depth comes only from the gray ramp (title bar 0.05, board 0.075, rows 0.1 to 0.13, memo 0.16) and the 95% window alpha.

## Shapes

Rows and the input field use 6 pt rounded rectangles; memo, memo editor and type buttons 4 pt; the open pill is a capsule; the note marker is a 6 pt circle. Borders are 1 pt; the memo accent rail is 2 pt, the pane rail 1 pt.

## Motion

No animations are defined. The only timed change is the ref copy feedback: the copy icon becomes a checkmark for 1.2 s (NoteRowView.swift:245-252). Hover changes row background and action opacity instantly. No reduced motion handling exists because nothing animates.

## Components

- **Title bar** (ContentView.swift:76-99): app name, open pill, pin toggle (`pin.fill` at 0.83 when floating, `pin.slash` at 0.33 when not; help "Unpin from top" or "Pin to top").
- **Error bar** (ContentView.swift:17-32): `exclamationmark.triangle.fill` in `warning`, message text selectable, `warning` fill at 0.18. Shows `saveError` first, else the socket `startError`.
- **Open pill** (ContentView.swift:189-196): "\(count) open", 10 pt semibold `sent` text on a `sent` capsule at 0.14.
- **Workspace header** (ContentView.swift:130-158): title truncates in the middle, subtitle truncates at the head and has a help tooltip. Subtitle rules (ContentView.swift:236-242, tested in NoteRowViewTests.swift:23): `local:/path` shows the path with `~`; a herdr ID shows only when it differs from the label; plain `local` shows none. Trash button help "Clear this workspace". The "You" group has no subtitle, pill or trash.
- **Pane header** (ContentView.swift:160-187): `terminal` icon, label (or ID when unlabelled) at 11 pt semibold, the ID in monospace only when a label exists.
- **Note row** (NoteRowView.swift:62-101), states:
  - Note: `note` dot.
  - Todo: checkbox button `square` or `checkmark.square.fill`; completed text strikes through and drops to 0.5.
  - Warning: `exclamationmark.triangle.fill`.
  - Decision sent: `circle.dotted` bold in `sent`, medium text, tinted fill and stroke.
  - Decision decided: `checkmark.circle.fill` in `decided` at 0.75, text at 0.5, "decided <stamp>" in the meta row.
  - Hover: background 0.1 to 0.13, row actions from 0.35 to full opacity.
  - Marker tooltip and accessibility label: "Note", "Todo", "Done todo", "Warning", "Decision sent, waiting", "Decided" (NoteRowView.swift:53-60).
- **Meta row** (NoteRowView.swift:132-180): ref button (ref plus `doc.on.doc`, help "Copy <ref>"), timestamp stamp (help shows the full date), decided stamp, then actions: `square.and.pencil` "Add a private note" (decision without memo), status action (`checkmark.circle` "Mark decided" or `arrow.uturn.backward.circle` "Mark sent"), `trash` "Delete".
- **Timestamp stamp** (NoteRowView.swift:27-35, tested in NoteRowViewTests.swift:12): time only today, "Yesterday <time>", otherwise "<day> <abbreviated month> <time>".
- **Memo** (NoteRowView.swift:182-210): 12 pt text on `memo-bg` with a 2 pt `sent` rail at 0.5; `pencil` "Edit note" and `trash` "Delete note" at 0.35 until hover.
- **Memo editor** (NoteRowView.swift:212-238): TextEditor 44 to 90 pt high with a `sent` stroke at 0.4, counter "<count>/1000", Cancel (Escape) and Save (Command Return).
- **Input bar** (InputBar.swift): plain TextField "Add a note..." and three type buttons N, T, W. Selected button is white on 0.25, others 0.53 on 0.17. Decisions cannot be created from the panel.
- **Context menu** (ContentView.swift:217-233): "Copy ID <ref>", the status action label, "Delete private note" (decision with memo), divider, "Delete…" (destructive).
- **Confirmation dialogs** (ContentView.swift:50-73): system `confirmationDialog`, see Behavior rules.

## Behavior rules

- **Add**: Return in the input adds a user note of the selected type; empty or whitespace text is ignored; the field clears after adding (ContentView.swift:248-253). User notes have no workspace and land in the "You" group.
- **Todo toggle**: clicking the checkbox flips `completed` (ContentView.swift:212).
- **Decision status**: the row action or context menu toggles sent and decided (NoteRowView.swift:43-48, tested NoteRowViewTests.swift:35). Reverting to sent clears the decided time (NoteStoreTests.swift:73).
- **Retention**: each pane keeps its 5 most recent decided decisions; older ones are removed with their memo (`decidedRetentionPerPane`, NoteStore.swift:209-220, tested NoteStoreTests.swift:46). Open decisions are never pruned (NoteStoreTests.swift:64).
- **Memo**: private to the panel; agents never see or set it (SocketServerTests.swift:83). Trimmed, capped at 1000 characters, an empty save deletes it (NoteStore.swift:144-149, NoteStoreTests.swift:300). Only decisions offer "Add a private note".
- **Delete note**: always confirms. Title "Delete <ref>?", message "\"<first 80 chars>\" and its private memo are deleted. This cannot be undone.", buttons Delete (destructive) and Cancel (ContentView.swift:62-73). Deleting a memo alone does not confirm.
- **Clear workspace**: always confirms. Title "Clear <label or id>?", button "Clear <n> notes" (destructive), message "Notes and private memos in this workspace are deleted. This cannot be undone." (ContentView.swift:50-61). Only that workspace is removed (NoteStoreTests.swift:159).
- **Copy ref**: clicking the ref copies it to the pasteboard; refs are never reused (NoteStoreTests.swift:247).
- **Pin**: toggles the window level between floating and normal; the state is not persisted (`@State isFloating = true`, ContentView.swift:9, :255-260).
- **Close**: closing the window does not quit the app (AppDelegate.swift:18-20). On quit the board is flushed to disk (AppDelegate.swift:13-16).
- **Persistence**: board saved to `~/.clause/board.json`, debounced 500 ms plus a 10 s periodic flush (NoteStore.swift:250-268). Agent adds are written before the ref is returned (NoteStoreTests.swift:261). An unreadable board file is moved aside, not overwritten (NoteStoreTests.swift:202).
- **Errors**: a failed save shows "Board not saved: <reason>" in the error bar and clears after the next good save (NoteStore.swift:286, NoteStoreTests.swift:272). Socket start failures show "Failed to create socket (errno N)", "Socket path too long", "Failed to bind <path> (errno N)" or "Failed to listen (errno N)" (SocketServer.swift:36-68, tested SocketEndToEndTests.swift:175).
- **Empty**: no notes at all shows "No notes yet" centered (ContentView.swift:198-207). There is no per-group empty state.
- **Keyboard**: Return submits the input; in the memo editor Escape cancels and Command Return saves. No other shortcuts.
- **Scoping** (agents, not UI, but visible on the board): each pane sees and changes only its own notes; ref lookup and edit by ref reach the whole workspace (README, ADR-002, ADR-003).

## Screen inventory

One window, `ClauseApp/Views/ContentView.swift`. States to capture:

| ID | State | Source |
| --- | --- | --- |
| empty | No notes, "No notes yet" | ContentView.swift:198 |
| user-only | Only "You" group notes of each type | ContentView.swift:104-109 |
| single-workspace | One workspace, several panes, no workspace pill | ContentView.swift:111-123 |
| multi-workspace | Two or more workspaces with per-workspace "N open" pills | ContentView.swift:116 |
| row-types | Note, todo, done todo, warning, decision sent, decision decided | NoteRowView.swift:103-130 |
| row-hover | Hovered row with visible actions | NoteRowView.swift:93, :176 |
| memo | Decision with memo | NoteRowView.swift:182 |
| memo-editing | Memo editor with counter | NoteRowView.swift:212 |
| ref-copied | Checkmark after copying a ref | NoteRowView.swift:138 |
| context-menu | Row context menu for a decision with memo | ContentView.swift:217 |
| delete-confirm | Delete note dialog | ContentView.swift:62 |
| clear-confirm | Clear workspace dialog | ContentView.swift:50 |
| error-save | Error bar "Board not saved: ..." | ContentView.swift:17 |
| error-socket | Error bar with a socket start failure | ContentView.swift:17 |
| unpinned | Pin toggle in `pin.slash` state | ContentView.swift:89 |
| long-text | Six-line truncation, long workspace and path subtitle truncation | NoteRowView.swift:75, ContentView.swift:136, :142 |

Dark only; no light captures exist to make.

## Files and regeneration

- Views: `ClauseApp/Views/` (ContentView, NoteRowView, InputBar). Window: `ClauseApp/ClauseApp.swift`. State: `ClauseApp/Store/NoteStore.swift`. Limits and paths: `ClauseShared/IPC/SocketConstants.swift`.
- `ClauseApp/Window/FloatingPanel.swift` defines an NSPanel with the same background and minimum size, but nothing creates it; `AppDelegate.panel` is never assigned. The live window is the SwiftUI `Window` scene.
- Project: `project.yml` generates `Clause.xcodeproj` with xcodegen. Documented run commands (README, not run here):

```bash
brew install xcodegen && xcodegen generate
open Clause.xcodeproj
xcodebuild -scheme Clause -configuration Debug build
```

- `design/template.fig` will contain: the token collection (dark mode only), the components above, every state in the Screen inventory at 320 x 480 pt and at the 280 x 300 pt minimum, and a behavior page with the dialogs and context menu.

## Known gaps

- **Brand**: no brand is stated in the app. `ceaksan` is inferred from the README author, the `com.ceaksan` bundle prefix and the clause.ceaksan.com landing page. Needs confirmation.
- **No light mode**: colors are hardcoded dark values. System controls (TextField text, TextEditor text, Cancel and Save buttons, dialogs) still follow the system appearance; how they render on the dark surfaces in macOS light mode was not verified.
- **No app icon**: there is no Assets.xcassets and no AppIcon in the project.
- **Reopening a closed window**: the app keeps running after the window closes and has no Dock icon or menu; no code path to show the window again was found.
- **Dead code**: `FloatingPanel` is unused (see Files).
- **Illustration drift**: `docs/clause-ui.svg` uses slightly different values from the code (for example `sent` as rgb(245,190,60) vs code rgb(0.98, 0.75, 0.14) ≈ #FABF24, workspace title 11 vs 13 pt). The code wins.
- **Hex values** in the frontmatter are 8-bit roundings of float components; the float literals are authoritative.
- **Landing page** (`docs/index.html`) is not described; it has its own token set.
- **Accessibility**: only the marker and status action carry accessibility labels; VoiceOver behavior was not checked.
