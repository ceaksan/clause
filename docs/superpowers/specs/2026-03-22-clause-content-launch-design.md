# Clause Beta Launch Content Strategy

**Date:** 2026-03-22
**Status:** Approved
**Phase:** Beta Launch (M1 complete, M2 in progress)
**Language:** English
**Channels:** Reddit, Hacker News, Twitter/X, LinkedIn (deferred), Blog (ceaksan.com), dev.to

## Context

Clause is a minimal, ephemeral note-taking companion for Claude Code sessions. macOS 14+ SwiftUI app with MCP server integration. Two-process architecture: `clause-mcp` (CLI/MCP) + `Clause.app` (floating window UI), connected via Unix domain socket.

The core problem Clause solves: during Claude Code sessions, you accumulate scratch context (decisions, warnings, TODOs, bookmarks) that has no persistent home. It exists in your head or scattered across terminal output. Clause gives this context a visible, structured place that both you and Claude can read/write.

Current state: Milestone 1 complete and working. Site live at clause.ceaksan.com. GitHub repo public. No launch content produced yet.

## Strategy: Pre-Launch + Staggered A + Sequential B

### Pre-Launch (Week -1)

Organic community engagement before launch. Build visibility in MCP/Claude Code spaces without promoting Clause. 3-5 days of genuine participation: answer questions, share useful things, comment on threads.

### Phase A: Staggered Launch (Week 0)

Each channel gets its own day. Entire 2-hour daily block dedicated to engagement on that channel. No multi-channel same-day posting.

### Phase B: Ecosystem Authority (Week +2 to +3)

Broader MCP ecosystem content. Tutorial first (more shareable, drives installs), comparison after (enriched by launch feedback). Clause appears organically.

Rationale for sequential: solo dev time constraint (~2 hrs/day), launch data feeds ecosystem content with real stories, different tempos (launch = hot/fast, ecosystem = cold/SEO).

## Pre-Launch Checklist

Before any content goes out:

- [ ] GitHub repo public and accessible
- [ ] clause.ceaksan.com live and working
- [ ] Reddit account has sufficient karma for r/ClaudeAI posting
- [ ] Twitter/X account active
- [ ] Hacker News account active (check posting eligibility)
- [ ] dev.to account created (needed for Week +2)
- [ ] Blog platform confirmed (ceaksan.com/blog or separate)
- [ ] 3-5 days of organic community engagement completed (Week -1)

## Competitive Landscape

No direct competitors in "floating session-scoped notepad for Claude Code" niche.

Note: star counts captured 2026-03-22, re-verify before publishing D7.

| Tool | Focus | Stars | GUI | Claude Code | Open Source |
|---|---|---|---|---|---|
| iMCP (mattt) | Apple system data access | ~1,300 | Menu bar | No (Desktop) | Yes |
| Macuse MCP | macOS automation + apps | ~20 | System app | No (Desktop) | No |
| claude-peers-mcp | Multi-session Claude comms | ~330 | No | Yes | Yes |
| **Clause** | Session-scoped notes | New | Floating window | Yes | Yes |

## Deliverables

### Week -1: Pre-Launch Community Engagement

#### P0. Organic Participation
- Spend 3-5 days engaging genuinely in r/ClaudeAI, relevant HN threads, MCP-related discussions
- Answer questions, share insights, comment on others' projects
- Zero mention of Clause. Goal: be a recognized name before you need attention
- Time: ~30 min/day

### Week 0: Staggered Launch

#### D0. Screenshot/GIF Asset (Hard Prerequisite)
- Create 5-10 second GIF showing: Claude Code terminal on left, Clause floating window on right, a note appearing in real-time.
- Tool: macOS screen recording (Cmd+Shift+5) then convert to GIF via `ffmpeg` or Gifox.
- Dimensions: 800-1200px wide, optimized for GitHub README (< 5MB).
- Also produce a static screenshot fallback (PNG) for platforms that don't autoplay GIFs.
- This blocks all other Week 0 deliverables.

#### D1. README Update
- Add GIF from D0 at top of README.
- Add "Why Clause?" section: 2-3 sentence problem/solution before technical docs.
- Tighten quick start: "30 seconds to running" feel.

#### D2. Reddit Launch Post (r/ClaudeAI) — Monday
- Format: "I built X" post with embedded GIF
- Length: 200-400 words
- Angle: Problem statement + demo + "looking for feedback"
- Tone: Casual, builder. "Hey, I've been working on..."
- Entire 2-hour block: post + engage with every comment
- Skip r/programming for now (strict self-promo rules, better entry via ecosystem content later)

#### D3. Hacker News "Show HN" — Wednesday
- Format: "Show HN: Clause, a floating MCP note companion for Claude Code sessions"
- Links to clause.ceaksan.com or GitHub repo
- Entire 2-hour block dedicated to HN comments
- HN comments are tough but high-value feedback. Engage thoughtfully.

#### D4. Twitter/X Launch Thread — Friday
- Tweet 1: Hook + GIF
- Tweet 2: Problem ("During Claude Code sessions, scratch context (decisions, warnings, TODOs) has no persistent home")
- Tweet 3: Solution ("Floating window that stays visible, talks to Claude via MCP")
- Tweet 4: Tech details (Swift 6, MCP protocol, open source)
- Tweet 5: CTA (repo link + "feedback welcome")
- By Friday, can reference Reddit/HN reactions for social proof

### Week +1: Build in Public

#### D5. Lessons Learned Thread (Twitter/X, 5-7 tweets)
- Content: Real launch data (stars, feedback, surprises, changes needed)
- Template prepared in advance, data filled post-launch
- Depends on actual launch results
- **Contingency:** If launch metrics are very low (< 10 stars, 0 engagement), pivot this to a "building in public" reflection on what you'd do differently. The thread still ships; the angle just changes.

### Week +2: Technical Authority (Reordered: tutorial before comparison)

#### D6. Building an MCP Server in Swift (~2000 words)
- Title candidates: "Building an MCP Server in Swift" / "Swift + MCP Protocol: A Practical Guide"
- Covers: MCP protocol intro, Swift MCP SDK usage, Unix domain socket IPC, SwiftUI + MCP integration
- Real code examples from Clause
- SEO targets: "Swift MCP server", "MCP protocol Swift", "build MCP server"
- **Pre-writing gate:** Run `seo-research` to validate keyword targets before writing. If no search volume exists, adjust title/angle to match actual demand.
- Distribution: Blog canonical first, dev.to 24-48 hours later, Reddit r/swift or r/programming + Twitter summary thread same day as dev.to.
- Rationale for going first: working code examples are more shareable, drive direct installs, and the comparison post can reference this tutorial.

### Week +3: Ecosystem Content

#### D7. macOS MCP Tools Comparison (~1500 words)
- Title candidates: "macOS MCP Tools in 2026: What's Out There" / "Giving Claude Access to Your Mac"
- Covers: iMCP, Macuse, claude-peers-mcp, Clause
- Comparison table: focus, GUI, session-scoped, Claude Code support, open source, language
- Tone: Neutral, informative. "These exist, they solve different problems."
- SEO targets: "MCP tools macOS", "Claude MCP server macOS"
- **Pre-writing gate:** Run `seo-research` to validate keyword targets before writing. If no search volume exists, adjust title/angle to match actual demand.
- Re-verify competitor star counts and features before publishing.
- Can now reference real user feedback from launch weeks ("after weeks of feedback, here's how Clause fits the landscape").
- Distribution: Blog canonical first, dev.to cross-post 24-48 hours later (canonical indexing window), Reddit r/ClaudeAI link same day as dev.to.
- Internal link to D6 (tutorial).

### Week +3/+4: LinkedIn (Deferred)

#### D8. LinkedIn Launch Post
- Deferred from Week 0. Low ROI at this stage without existing audience.
- By Week +3/+4, has real launch data, feedback, and story to tell.
- Format: Single post, professional tone
- Angle: "I launched an open source dev tool 3 weeks ago. Here's what happened."
- Richer story than a cold launch post. Includes metrics, surprises, lessons.
- CTA: repo link

## Content Flow

```
P0 (Community engagement) ─── Week -1: Pre-Launch
         │
D0 (GIF/screenshot) ─────── Hard prerequisite
         │
         ▼
D1 (README) ─────────┐
D2 (Reddit, Mon) ─────┤ Week 0: Staggered Launch
D3 (HN, Wed) ─────────┤ (one channel per day, full engagement)
D4 (Twitter, Fri) ────┘
         │
         ▼ (launch data feeds)
D5 (Lessons thread) ──── Week +1: Build in Public
         │
         ▼
D6 (Swift tutorial) ──── Week +2: Technical Authority
         │
         ▼ (internal link)
D7 (MCP comparison) ──── Week +3: Ecosystem
         │
         ▼
D8 (LinkedIn) ────────── Week +3/+4: Deferred Launch Story
```

## Tone & Voice

- **General:** Builder, pragmatic, no-hype. "I needed this, so I built it."
- **Reddit:** Casual, first-person.
- **Hacker News:** Technical, concise. Respect the audience's intelligence.
- **Twitter/X:** Concise, punchy. One idea per tweet.
- **LinkedIn:** Professional but not corporate. Solo entrepreneur angle. Data-driven.
- **Blog/dev.to:** Educational, authoritative. Real code, clear explanations.
- **Universal rule:** Do not oversell Clause. "Small tool that does one thing well."

## Content Intelligence Integration

All CI skills are **pre-writing gates**, not post-writing validation.

| Deliverable | Skill | Purpose | When |
|---|---|---|---|
| D2-D4 (launch posts) | content-quality | Validate angle, hook, CTA | Before final draft |
| D3, D4 (platform drafts) | engage | Platform-specific draft generation | During writing |
| D6, D7 (blog posts) | seo-research | Keyword validation (volume, difficulty) | Before writing starts |
| D7 (comparison) | radar | Tool evaluation data | Before writing starts |

## Dependencies

- P0 (pre-launch engagement): blocks Week 0 launch
- D0 (GIF): hard prerequisite, blocks D1-D4
- D1: blocks D2-D4 (README must be polished before directing traffic to repo)
- D2, D3, D4: staggered Mon/Wed/Fri, each depends on D1
- D5: depends on launch data (template prepared in advance)
- D6: depends on seo-research validation
- D7: depends on D6 (internal link), seo-research validation, and launch feedback data
- D8: depends on accumulated launch story (Week +3 minimum)

## Success Metrics (Beta Launch)

| Metric | Target | Signal |
|---|---|---|
| GitHub stars | 50+ first week | Community interest |
| Reddit post | 20+ upvotes on r/ClaudeAI | Problem resonance |
| HN post | Front page or 10+ points | Technical credibility |
| Twitter thread | 5K+ impressions | Reach |
| Blog organic traffic | Starts week 4+ | SEO working |
| GitHub issues/feedback | 3-5 quality items | **Primary goal** |

## Anticipated Objections

These will come up in Reddit/HN comments. Do NOT address proactively in content (it legitimizes false comparisons and puts Clause in a defensive position). Instead, have ready replies for when asked.

| Objection | Ready Reply |
|---|---|
| "Why not just use macOS Notes/Reminders?" | Clause is MCP-native: Claude reads and writes to it during the session. Apple Notes has no MCP integration. Also ephemeral by design, notes disappear when the session ends. Different tool for a different job. |
| "Why not Todoist/Notion/Obsidian?" | Same answer: no MCP protocol support, no two-way Claude interaction, not session-scoped. Clause is not a note-taking app. It is a session companion that happens to store notes. |
| "Just use a text file / scratchpad" | You can, but Claude cannot read or write to your text file mid-session. The MCP integration is the entire point. |
| "Why macOS only?" | Built with SwiftUI and native macOS APIs for the floating window behavior. Cross-platform would require a fundamentally different architecture. macOS first, evaluate demand for others. |
| "Why not a VS Code extension?" | Clause is editor-agnostic. It works alongside any terminal where Claude Code runs. No IDE dependency. |
| "This seems too simple / not enough features" | Intentional. One job, done well. Milestone 2 adds hotkeys, search, multi-session. Feedback drives what comes next. |

**Usage rules:**
- Never put these in README, landing page, or launch posts
- Use only as comment replies when the question is actually asked
- Keep replies short (2-3 sentences max), no defensiveness
- Tone: matter-of-fact, redirect to what Clause actually is

## Time Budget Estimate

| Deliverable | Estimated Hours |
|---|---|
| P0 (Pre-launch engagement) | ~2.5 (30 min/day x 5 days) |
| D0 (GIF) | 1-2 |
| D1 (README) | 1 |
| D2 (Reddit + engagement) | 2 |
| D3 (HN + engagement) | 2 |
| D4 (Twitter) | 1 |
| D5 (Lessons) | 1 |
| D6 (Swift tutorial) | 5-6 |
| D7 (Comparison) | 4-5 |
| D8 (LinkedIn) | 0.5 |
| **Total** | **~20-22 hrs across 5 weeks** |

At ~2 hrs/day: feasible. Week 0 is the most intensive (staggered but 3 launch days). Weeks +2 and +3 are content-heavy, limited room for M2 development during those weeks. Pre-launch week is low effort (30 min/day).
