# Clause Beta Launch Content Plan

> **For agentic workers:** This is a content production plan, not a code implementation plan. Each task produces a content deliverable. Use `content-quality`, `engage`, `seo-research`, and `radar` skills as specified. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce and distribute all content for Clause beta launch across Reddit, HN, Twitter/X, blog, dev.to, and LinkedIn over 5 weeks.

**Spec:** `docs/superpowers/specs/2026-03-22-clause-content-launch-design.md`

**Key files for reference:**
- `README.md` — Current README (to be updated in Task 2)
- `docs/index.html` — Landing page at clause.ceaksan.com
- `ClauseApp/` — SwiftUI app source (for tutorial code examples)
- `ClauseMCP/main.swift` — MCP server entry point (for tutorial)
- `ClauseShared/` — Shared types (for tutorial)
- `architecture.md` — Technical architecture doc

**Metrics tracking:** All launch metrics logged in `docs/content/launch-metrics.md`. Create this file at start of Week 0. Format: date, channel, metric name, value, notable feedback. This data feeds D5 (lessons thread) and D8 (LinkedIn post).

---

## Task 0 (Pre-Launch): P0 — Community Engagement

**Output:** Engagement log in `docs/content/pre-launch-log.md`
**Timeline:** Week -1 (3-5 days before launch)
**Blocks:** All launch tasks

- [ ] **Step 1: Verify pre-launch checklist**
  - [ ] GitHub repo public and accessible
  - [ ] clause.ceaksan.com live and working
  - [ ] Reddit account has sufficient karma for r/ClaudeAI posting
  - [ ] Twitter/X account active
  - [ ] Hacker News account active (check posting eligibility)
  - [ ] dev.to account created (needed for Week +2)
  - [ ] Blog platform confirmed (ceaksan.com/blog or separate)

- [ ] **Step 2: Identify target threads**
  - Find 5-10 active threads in:
    - r/ClaudeAI (MCP-related, Claude Code tips, tool recommendations)
    - Hacker News (AI coding tools, MCP protocol, macOS dev tools)
    - Any active MCP Discord/community
  - List URLs in log file

- [ ] **Step 3: Engage daily (30 min/day, 3-5 days)**
  - Answer questions genuinely
  - Share useful insights from your MCP/Swift experience
  - Comment on others' projects
  - **Zero mention of Clause**
  - Log each interaction: date, platform, thread, what you contributed

- [ ] **Step 4: Verify readiness**
  - After 3-5 days, check: do you have at least some name recognition in these spaces?
  - All pre-launch checklist items checked?
  - If yes: proceed to Task 1 (D0)

---

## Task 1: D0 — Screenshot/GIF Asset

**Output:** `assets/demo.gif` + `assets/demo-static.png`
**Blocks:** All other tasks

- [ ] **Step 1: Prepare demo environment**
  - Build and run Clause.app from Xcode
  - Open a terminal with Claude Code running alongside
  - Ensure Clause floating window is visible and positioned right of terminal
  - Set window arrangement: terminal left ~60%, Clause right ~40%

- [ ] **Step 2: Record screen capture**
  - Use macOS screen recording (Cmd+Shift+5), select the region covering both windows
  - Demo scenario: Claude Code session starts, `set_session` is called, then 2-3 notes appear in Clause (one note, one todo, one warning) showing real-time IPC
  - Keep recording 5-10 seconds total
  - Save as .mov file

- [ ] **Step 3: Convert to GIF**
  ```bash
  # Convert mov to gif, 800px wide, 15fps, optimized
  ffmpeg -i assets/demo.mov -vf "fps=15,scale=800:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" -loop 0 assets/demo.gif
  ```
  - Verify file size < 5MB. If larger, reduce fps to 10 or trim duration.

- [ ] **Step 4: Create static screenshot fallback**
  - Take a PNG screenshot of the same arrangement at the moment 2-3 notes are visible
  - Save as `assets/demo-static.png`
  - Optimize: `sips -Z 1200 assets/demo-static.png`

- [ ] **Step 5: Verify assets**
  - Open both files, confirm they clearly show: terminal + floating Clause window + visible notes
  - Verify GIF plays smoothly and file size is acceptable

---

## Task 2: D1 — README Update

**Modify:** `README.md`
**Depends on:** Task 1 (GIF asset)

- [ ] **Step 1: Add GIF at top**
  - Replace `<!-- TODO: Add screenshot -->` with:
  ```markdown
  <p align="center">
    <img src="assets/demo.gif" alt="Clause demo — floating note panel alongside Claude Code" width="800">
  </p>
  ```

- [ ] **Step 2: Add "Why Clause?" section**
  - Insert after the GIF, before "What it does":
  ```markdown
  ## Why Clause?

  During Claude Code sessions, you accumulate scratch context — decisions made, warnings to remember, TODOs to track. This context lives in your head or gets buried in terminal output. Clause gives it a visible, structured home that both you and Claude can read and write to, in real time.
  ```

- [ ] **Step 3: Tighten quick start**
  - Update the Installation section to lead with the fastest path:
  ```markdown
  ## Quick Start

  ```bash
  git clone https://github.com/ceaksan/clause.git
  cd clause
  brew install xcodegen && xcodegen generate
  open Clause.xcodeproj
  # Build and run the Clause scheme, then configure Claude Code ↓
  ```
  ```
  - Keep the detailed installation and Claude Code configuration sections below

- [ ] **Step 4: Review full README**
  - Read the complete file end-to-end
  - Verify flow: GIF → Why → Quick Start → What it does → How it works → MCP Tools → ...
  - Ensure no broken links or formatting issues

- [ ] **Step 5: Commit**
  ```bash
  git add README.md assets/demo.gif assets/demo-static.png
  git commit -m "docs: add demo GIF and polish README for launch"
  ```

---

## Task 3: D2 — Reddit Launch Post (r/ClaudeAI)

**Output:** Draft in `docs/content/drafts/d2-reddit-launch.md`
**Depends on:** Task 2 (README polished, repo ready for traffic)
**Publish:** Monday of launch week

- [ ] **Step 1: Run content-quality validation**
  - Use `content-quality` skill to validate the angle: "I built a floating note companion for Claude Code sessions"
  - Check: hook strength, CTA clarity, audience fit for r/ClaudeAI

- [ ] **Step 2: Write draft**
  - Title: "I built Clause — a floating note panel for Claude Code sessions [macOS, open source]"
  - Body structure (200-400 words):
    1. Opening: What it is, one sentence
    2. Problem: Scratch context during sessions (decisions, TODOs, warnings) has no home
    3. Solution: Floating macOS window, MCP-native, Claude reads/writes to it
    4. How it works: 2-3 sentences on architecture (MCP server + SwiftUI + Unix socket)
    5. Demo: Embed GIF or link to it
    6. Status: M1 complete, daily driver, M2 in progress
    7. CTA: "Looking for feedback. What would you want from a tool like this?"
    8. Links: GitHub repo, clause.ceaksan.com
  - Tone: Casual, first-person, builder. No marketing speak.
  - Save to `docs/content/drafts/d2-reddit-launch.md`

- [ ] **Step 3: Review against anticipated objections**
  - Read the Anticipated Objections table in spec
  - Ensure the post does NOT proactively address them (no "unlike Obsidian..." comparisons)
  - Ensure the post naturally answers the most likely question ("why not just a text file?") by mentioning MCP integration
  - Pre-write Reddit-toned objection responses (casual, short) and keep in draft file as reference section

- [ ] **Step 4: Final review**
  - Word count check: 200-400 words
  - Read aloud for tone (casual, not salesy)
  - Verify all links work

- [ ] **Step 5: Publish (Monday)**
  - Post to r/ClaudeAI
  - Spend full 2-hour block engaging with comments
  - Log engagement metrics to `docs/content/launch-metrics.md` (upvotes, comments, notable feedback)

---

## Task 4: D3 — Hacker News "Show HN"

**Output:** Draft in `docs/content/drafts/d3-hn-show.md`
**Depends on:** Task 2
**Publish:** Wednesday of launch week

- [ ] **Step 1: Use engage skill for HN-specific draft**
  - Invoke `engage` skill with context: Clause launch, HN "Show HN" format, first comment draft
  - HN format: title + URL only, all substance goes in first comment

- [ ] **Step 2: Write/refine draft**
  - Title: "Show HN: Clause — A floating MCP note companion for Claude Code (macOS, Swift)"
  - URL: clause.ceaksan.com (or GitHub repo, whichever has better first impression)
  - HN "Show HN" has no body text beyond the title+URL. Prepare a first comment instead:
    - 3-4 paragraphs: what it does, why you built it, how it works technically, what's next
    - Technical depth appropriate for HN (mention Swift 6 strict concurrency, MCP protocol, Unix domain sockets, POSIX vs Network.framework)
    - End with: "Happy to answer questions about the MCP protocol, the Swift implementation, or anything else."
  - Save to `docs/content/drafts/d3-hn-show.md`

- [ ] **Step 3: Run content-quality validation**
  - Use `content-quality` skill on the first comment draft
  - Check: hook strength, technical credibility, CTA clarity for HN audience

- [ ] **Step 4: Review for HN tone**
  - No exclamation marks, no "excited to share", no emojis
  - Technical, concise, factual
  - No self-deprecation but also no hype

- [ ] **Step 5: Prepare anticipated objection responses**
  - Review spec's Anticipated Objections table
  - Pre-write short responses for HN tone (more technical than Reddit versions)
  - Keep in draft file as reference section (not posted, just ready)

- [ ] **Step 6: Publish (Wednesday)**
  - Submit to HN
  - Post first comment immediately
  - Spend full 2-hour block engaging with HN comments
  - Log metrics to `docs/content/launch-metrics.md` (points, comments, notable feedback)

---

## Task 5: D4 — Twitter/X Launch Thread

**Output:** Draft in `docs/content/drafts/d4-twitter-thread.md`
**Depends on:** Task 2 (README polished). Optionally enriched by Tasks 3-4 reactions (social proof).
**Publish:** Friday of launch week

- [ ] **Step 1: Use engage skill for platform-specific draft**
  - Invoke `engage` skill with context: Clause launch, Twitter/X thread format, 4-5 tweets
  - Input: spec summary, GIF asset reference, any Reddit/HN highlights from earlier in the week

- [ ] **Step 2: Write/refine thread**
  - Tweet 1: Hook + GIF. "I built a floating note panel for Claude Code sessions. Here's what it does ↓" + GIF
  - Tweet 2: Problem. "During Claude Code sessions, scratch context — decisions, warnings, TODOs — has no persistent home. It's in your head or buried in terminal scroll."
  - Tweet 3: Solution. "Clause is a floating macOS window connected to Claude via MCP. Both you and Claude can read/write notes in real time. Notes disappear when the session ends."
  - Tweet 4: Tech. "Built with Swift 6 + SwiftUI. Two-process architecture: MCP server (stdio) talks to floating window via Unix socket. Open source, MIT."
  - Tweet 5: CTA. "Repo: [link]. Site: clause.ceaksan.com. Looking for feedback — what would make this useful for your workflow?"
  - Optional Tweet 6: Social proof from Reddit/HN if available ("Posted this earlier this week, the feedback has been great — [interesting comment/insight]")
  - Save to `docs/content/drafts/d4-twitter-thread.md`

- [ ] **Step 3: Run content-quality check**
  - Use `content-quality` skill on the thread
  - Validate: hook strength (Tweet 1), clarity, CTA effectiveness

- [ ] **Step 4: Publish (Friday)**
  - Post thread
  - Engage with replies for 1-2 hours
  - Log metrics to `docs/content/launch-metrics.md` (impressions, likes, retweets, replies)

---

## Task 6: D5 — Lessons Learned Thread Template

**Output:** Template in `docs/content/drafts/d5-lessons-template.md`
**Depends on:** Tasks 3-5 (launch data needed to fill)
**Publish:** Week +1

- [ ] **Step 1: Create template**
  - 5-7 tweet thread structure with placeholders:
  - Tweet 1: "I launched Clause a week ago. Here's what happened ↓" + [METRIC: stars, forks, issues]
  - Tweet 2: "What surprised me: [SURPRISE_1]"
  - Tweet 3: "The feedback I didn't expect: [FEEDBACK_HIGHLIGHT]"
  - Tweet 4: "What I'd do differently: [LESSON]"
  - Tweet 5: "What's next based on feedback: [M2_PRIORITY_SHIFT]"
  - Tweet 6: "The numbers: [STATS_TABLE]"
  - Tweet 7: CTA + repo link
  - Save to `docs/content/drafts/d5-lessons-template.md`

- [ ] **Step 2: Add contingency variant**
  - In same file, add alternate angle for low-engagement scenario:
  - "I launched an open source dev tool last week to crickets. Here's what I learned about launching niche developer tools ↓"
  - Same structure but honest about low numbers, focused on process insights

- [ ] **Step 3: Fill and publish (Week +1)**
  - Fill template with actual data from `docs/content/launch-metrics.md`
  - Choose standard or contingency variant based on metrics
  - Run through `content-quality` before publishing
  - Post and engage

---

## Task 7: D6 — "Building an MCP Server in Swift" Blog Post

**Output:** Blog post draft in `docs/content/drafts/d6-swift-mcp-tutorial.md`
**Depends on:** SEO validation (pre-writing gate)
**Publish:** Week +2

- [ ] **Step 1: SEO keyword validation (pre-writing gate)**
  - Use `seo-research` skill to validate:
    - "Swift MCP server"
    - "MCP protocol Swift"
    - "build MCP server"
    - "Model Context Protocol tutorial"
  - If no search volume: adjust angle. Possible pivots:
    - "Building macOS developer tools with MCP"
    - "Swift + Claude Code integration"
  - Document validated keywords and chosen angle

- [ ] **Step 2: Outline**
  - Structure (~2000 words):
    1. **Intro** (~200w): What MCP is, why Swift, what we're building
    2. **MCP Protocol Primer** (~300w): Tools, resources, transports. Link to official docs.
    3. **Project Setup** (~200w): Swift Package Manager, modelcontextprotocol/swift-sdk dependency
    4. **Implementing MCP Tools** (~400w): Real code from `ClauseMCP/main.swift`. Tool registration, handler pattern.
    5. **IPC: Unix Domain Sockets** (~300w): Real code from `ClauseShared/IPC/`. Why POSIX on server, Network.framework on client.
    6. **SwiftUI Integration** (~300w): `@Observable` NoteStore, `@MainActor` threading. Real code from `ClauseApp/Store/NoteStore.swift`.
    7. **Testing** (~150w): Swift Testing framework, what to test in an MCP server
    8. **Conclusion** (~150w): Link to Clause repo, invite contribution
  - Save outline to draft file

- [ ] **Step 3: Write first draft**
  - Follow outline
  - Use real code snippets from Clause source (reference exact files)
  - Code blocks must be complete and runnable (not pseudo-code)
  - Tone: educational, practical, "here's how I did it"
  - Save to `docs/content/drafts/d6-swift-mcp-tutorial.md`

- [ ] **Step 4: Run content-quality check**
  - Use `content-quality` skill on full draft
  - Check: unique angle, technical accuracy, readability, SEO optimization

- [ ] **Step 5: Publish blog canonical**
  - Publish on ceaksan.com/blog (or confirmed blog platform)
  - Include canonical URL meta tag

- [ ] **Step 6: Cross-post to dev.to (24-48h later)**
  - Cross-post with canonical_url pointing to blog
  - Add dev.to-specific tags: swift, mcp, macos, opensource

- [ ] **Step 7: Distribute on social**
  - Reddit r/swift or r/programming (same day as dev.to)
  - Twitter summary thread (3-4 tweets highlighting key insights)
  - Use `engage` skill for platform-specific framing

---

## Task 8: D7 — "macOS MCP Tools Comparison" Blog Post

**Output:** Blog post draft in `docs/content/drafts/d7-mcp-comparison.md`
**Depends on:** Task 7 (internal link), SEO validation, launch feedback data
**Publish:** Week +3

- [ ] **Step 1: SEO keyword validation (pre-writing gate)**
  - Use `seo-research` skill to validate:
    - "MCP tools macOS"
    - "Claude MCP server macOS"
    - "macOS AI developer tools"
  - If no volume: adjust. Possible pivots:
    - "Claude Code extensions and companions"
    - "MCP ecosystem tools 2026"
  - Document validated keywords

- [ ] **Step 2: Re-verify competitor data**
  - Use `radar` skill to evaluate each tool fresh:
    - iMCP: current stars, last commit, features
    - Macuse MCP: current state, pricing if any
    - claude-peers-mcp: current stars, last commit, features
  - Note any changes since spec was written (2026-03-22)

- [ ] **Step 3: Outline**
  - Structure (~1500 words):
    1. **Intro** (~150w): MCP is expanding, macOS tools are emerging, here's the landscape
    2. **iMCP** (~250w): What, who (Mattt), strengths, limitations, ideal user
    3. **Macuse MCP** (~250w): What, closed-source angle, UI automation unique value, limitations
    4. **claude-peers-mcp** (~250w): What, inter-session problem, strengths, limitations
    5. **Clause** (~250w): What, session-scoped niche, strengths, limitations. Include real user feedback from launch.
    6. **Comparison Table** (~100w): Side-by-side on key dimensions
    7. **Which One Should You Use?** (~150w): Decision guide based on use case, not ranking
    8. **Conclusion** (~100w): Link to D6 tutorial, ecosystem is young and growing
  - Save outline

- [ ] **Step 4: Write first draft**
  - Tone: neutral, informative. "These tools solve different problems."
  - Do NOT rank or declare winners
  - Include real launch feedback where relevant ("users asked for X, which led to M2 priorities")
  - Internal link to D6 (Swift MCP tutorial) in Clause section and conclusion
  - Save to `docs/content/drafts/d7-mcp-comparison.md`

- [ ] **Step 5: Run content-quality check**
  - Use `content-quality` skill
  - Extra check: does it read as genuinely neutral? Would a reader feel it's fair?

- [ ] **Step 6: Publish blog canonical**
  - Publish on ceaksan.com/blog
  - Canonical URL meta tag

- [ ] **Step 7: Cross-post to dev.to (24-48h later)**
  - Cross-post with canonical_url
  - Tags: mcp, macos, claude, opensource

- [ ] **Step 8: Distribute on social**
  - Reddit r/ClaudeAI link (same day as dev.to)
  - Twitter summary (2-3 tweets, link to post)
  - Use `engage` skill for framing

---

## Task 9: D8 — LinkedIn Post (Deferred)

**Output:** Draft in `docs/content/drafts/d8-linkedin.md`
**Depends on:** 3+ weeks of launch data
**Publish:** Week +3/+4

- [ ] **Step 1: Gather launch story data**
  - Review `docs/content/launch-metrics.md` for all collected data
  - Compile: GitHub stars, issues, forks, notable feedback, surprises
  - What changed since launch (M2 priorities shifted?)
  - Best comment/feedback received
  - Any unexpected use cases

- [ ] **Step 2: Use engage skill for LinkedIn draft**
  - Invoke `engage` skill with context: LinkedIn post, "launched open source dev tool 3 weeks ago, here's what happened"
  - Professional but personal tone

- [ ] **Step 3: Write/refine post**
  - Structure:
    - Hook: "3 weeks ago I shipped an open source macOS app. Here's what I learned."
    - The why: Problem I was solving
    - The numbers: Real metrics (stars, issues, traffic)
    - The surprise: Something unexpected from launch
    - The lesson: One takeaway about building dev tools as a solo entrepreneur
    - CTA: Repo link, invite to try
  - Save to `docs/content/drafts/d8-linkedin.md`

- [ ] **Step 4: Run content-quality check**
  - Use `content-quality` skill
  - LinkedIn-specific: no hashtag spam, no "I'm humbled", professional not corporate

- [ ] **Step 5: Publish**
  - Post to LinkedIn
  - Engage with comments

---

## Execution Order

```
Task 0 (P0: Pre-launch engagement) ─── Week -1
    │
Task 1 (D0: GIF/screenshot) ─────── Weekend before launch
    │
Task 2 (D1: README update) ─────── Same session as Task 1
    │
    ├── Task 3 (D2: Reddit) ─────── Monday
    ├── Task 4 (D3: HN) ─────────── Wednesday
    └── Task 5 (D4: Twitter) ────── Friday
    │
Task 6 (D5: Lessons template) ──── Week +1
    │
Task 7 (D6: Swift tutorial) ────── Week +2
    │
Task 8 (D7: MCP comparison) ────── Week +3
    │
Task 9 (D8: LinkedIn) ──────────── Week +3/+4
```

Tasks 3, 4, 5 are staggered within Week 0 (Mon/Wed/Fri). Each gets a full 2-hour engagement block on its day.

Tasks 7 and 8 are the heaviest (5-6 hrs and 4-5 hrs respectively). Plan for reduced M2 development during those weeks.
