# Reddit Launch Post: r/ClaudeAI
# Draft: d2-reddit-launch

---

## Post

**Title:** I built Clause: a floating note panel for Claude Code sessions [macOS, open source]

---

Hey, I've been working on something small but useful for my own Claude Code workflow and figured I'd share it here.

**What it is:** Clause is a floating window that sits on your screen while you work in Claude Code. It's an MCP server, so Claude can read and write to it directly during your session.

**The problem it solves:** When you are deep in a Claude Code session, you accumulate a lot of scratch context. Decisions you made, warnings to not touch certain files, things to revisit later, half-formed TODOs. None of this has a natural home. It lives in your head, or buried in terminal scrollback, or in a random text file you will forget about.

**What Clause does:** It gives that context a visible, structured place. Notes are organized by type (note, todo, warning), Claude can add and read them natively through MCP tools, and everything disappears when the session ends. That last part is intentional. This is not a second brain or a task manager. It's a scratchpad for the session you are currently in.

**How it works:** There are two processes: clause-mcp (the CLI that Claude Code talks to via MCP) and Clause.app (the floating window). They communicate over a Unix domain socket. Claude gets six tools: set_session, add_note, list_notes, edit_note, delete_note, clear_notes. That's the whole surface area.

[GIF demo here]

**Status:** Milestone 1 is complete and I have been using it as my daily driver for a few weeks. Milestone 2 is in progress, adding hotkeys, multi-session tabs, and search.

It's open source, MIT licensed, Swift 6, macOS 14+.

Looking for feedback. What would you want from a tool like this?

GitHub: https://github.com/ceaksan/clause
Site: clause.ceaksan.com

---

## Anticipated Objection Responses (Not for posting)

**1. "Why not just use macOS Notes/Reminders?"**

The integration is the thing. Claude writes to Clause directly during your session via MCP, without you doing anything. Notes and Reminders are not MCP servers. You would have to manually copy context back and forth, which defeats the purpose.

**2. "Why not Todoist/Notion/Obsidian?"**

Those are persistent systems. Clause is intentionally ephemeral. Session ends, notes are gone. Different tool for a different job. Also, same integration point: Claude cannot natively read and write to those during a session without a lot of setup.

**3. "Just use a text file"**

You could. A text file does not sit in a floating window visible while you work, does not organize notes by type, and most importantly does not have an MCP interface so Claude would have to use file system tools to interact with it. Clause is just a better-suited primitive for this specific use case.

**4. "Why macOS only?"**

It's a native SwiftUI app. That is a macOS constraint for now. The MCP server part (clause-mcp) is cross-platform in theory, and the socket protocol is simple enough that a different UI could be built on top. PRs welcome.

**5. "Why not a VS Code extension?"**

Claude Code is a terminal tool. Most people using it are not necessarily in VS Code. A floating window that works regardless of your editor setup felt like the right fit. Also, a native app gives you better windowing behavior, stays on top, and does not depend on which editor you happen to have open.

**6. "This seems too simple"**

That is roughly the goal. It does one thing: gives your Claude Code session a shared, visible scratch context. Scope creep would make it worse, not better. If Milestone 2 features (hotkeys, multi-session, search) feel like the right additions, it is because they serve the same core use case.
