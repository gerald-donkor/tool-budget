---
name: tool-budget
description: Keeps expensive tools cheap. Use before any Claude in Chrome (mcp__claude-in-chrome__*) browser automation, before Figma MCP read calls (get_screenshot, get_metadata, get_design_context, use_figma), when the user asks about token cost, Figma MCP rate limits, remaining calls or AI credits, or when setting up or debugging the Figma MCP call counter hook and its status-line segment.
---

# Tool budget

Two kinds of cost add up fast in Claude Code: **tokens** (browser screenshots and page dumps) and **rate-limited calls** (the Figma MCP server). This skill sets when each tool is worth it, how to use it cheaply, and how to install a counter that warns and blocks before Figma's limit is hit.

## 0. Quality comes first

Saving tokens and calls must never lower the quality of the work. These rules remove **waste**: repeated reads, unbounded dumps, polling, using an expensive tool where a cheap one gives the same answer. They don't remove **rigour**.

- **Do every read and check the work needs.** Read the design context, inspect the nodes involved, and screenshot the result to compare it with the intent. Verifying a meaningful change is required, not optional.
- **Spend where it counts.** Premium, pixel-accurate output is the goal. Save on the tools around the work, never on the work itself.
- **Never trade quality for budget silently.** If the budget (the warning level, the block, a rate limit) would force a weaker result, stop and tell the user what's left, what the task still needs, and the options: continue later, use the override, or work from local sources. Let them decide.
- **Never present unverified work as done.** If a check couldn't be run, say so.

## 1. Claude in Chrome: last resort

Claude in Chrome drives the user's real, signed-in browser. It is slow, interrupts the user, needs the extension connected, and costs a lot of tokens.

**Use it only when all three are true:**

1. The task needs something that exists only in a live, signed-in browser session: account, billing or admin pages, or settings no connected tool or API exposes.
2. Nothing else answers it. Check first: local files, CLI tools, MCP servers (Figma, Paper, Railway, Neon, etc.), WebFetch or WebSearch for public pages, and Firecrawl skills for scraping or interacting with public sites.
3. The user asked for it, or agreed when offered. If it would merely be convenient, ask first in one line.

**Don't use it for:**

- Previewing or screenshotting local pages or a dev server. Use the `run` skill, a headless browser via Bash, or ask the user to look.
- Reading public pages or documentation. Use WebFetch, WebSearch or Firecrawl.
- Inspecting Figma or Paper files. Use their MCP tools.
- Reading or publishing artifacts. Use the Artifact tool.
- Routine "check it worked" passes after every edit.

**When it is used:** call `tabs_context_mcp` first, work in a new tab, and close it when done. If the extension isn't connected (`list_connected_browsers` returns `[]`), stop after one retry, tell the user, and give them the steps: the extension must be signed in to the same claude.ai account as Claude Code, and `/chrome` checks or reconnects. Don't loop. Never enter credentials, accept terms or submit forms without explicit confirmation in chat.

### What it costs

| Action | Approximate cost |
|---|---|
| Full-size screenshot | 1,000–1,500 tokens each |
| `read_page` with defaults | up to 50,000 characters, about 12,000 tokens |
| Loading the Chrome tools | a few thousand tokens |
| Reading one value from a dashboard | often 6–10 calls, 10,000–30,000 tokens |
| For comparison: one small MCP call such as Figma `whoami` | about 150 tokens |

Everything returned stays in the conversation context.

### Keeping it cheap

- Load every Chrome tool you expect to need in one `ToolSearch` call, not one call per tool.
- Navigate straight to the target URL (a known settings or billing page) instead of clicking through menus.
- Prefer text over images: use `find` to locate an element, or `get_page_text` to read values, before taking a screenshot.
- When a screenshot is needed, pass `scale: 0.5` (about a quarter of the tokens) or `zoom` on just the region that matters.
- Never call `read_page` unbounded. Pass `filter: "interactive"`, a small `depth`, a `ref_id` for one section, or a lower `max_chars`.
- Don't take a confirming screenshot after every routine click. Do check every result that matters, at the zoom or scale needed to judge it properly.
- Stop as soon as the answer is found, report it, and close the tab.

## 2. Figma MCP: rate-limited reads

The Figma MCP server limits tool calls that **read** Figma data. Limits from https://developers.figma.com/docs/figma-mcp-server/rate-limits-access/ (checked 2026-10-13; Figma may change them, so re-check when it matters):

| Plan | Seat | Limit |
|---|---|---|
| Starter | any | up to 20 calls/month |
| Professional | View or Collab | up to 20 calls/month |
| Professional | Full or Dev | up to 200 calls/day, 10/minute |
| Organization | Full or Dev | up to 200 calls/day, 15/minute |
| Enterprise | Full or Dev | up to 600 calls/day, 20/minute |

- Tools that write to Figma are exempt. The docs name `whoami`, `create_new_file` and `add_code_connect_map`.
- `whoami` (free) shows the user's plans and seats, so use it to work out which limit applies. It does not report usage, and nothing in Figma's API does. Without the counter below, the only signal is a rate-limit error.
- Limits follow the plan that owns the file. Work in files owned by the team with the highest limit, and create new files there.
- AI credit balances aren't exposed by the MCP server either. They're in Figma's admin or billing settings. Send the user there rather than opening Chrome.

**Spend read calls deliberately:**

- Start with `get_metadata` to find the right node, then call `get_screenshot` or `get_design_context` on that node only, not on whole pages.
- Don't re-read a node that hasn't changed in this session.
- Don't poll or loop on read tools. Do verify every meaningful change: screenshot the changed node and compare it with the design intent, and read its design context whenever accuracy depends on it.
- On a rate-limit error or a block from the counter, stop, tell the user which limit was hit, and don't retry. Offer to continue later, to use the override, or to work from local files. Never finish the task with lower-quality or unverified work because the budget ran out.

## 3. The Figma call counter

`scripts/` contains a Claude Code hook that counts Figma calls locally, since Figma won't.

| File | Role |
|---|---|
| `scripts/figma-mcp-counter.sh` | `PreToolUse` hook on `mcp__figma__.*`. Logs each rate-limited call to `~/.claude/figma-mcp-usage.log`, counted per UTC day. Exempt tools aren't logged. |
| `scripts/statusline-figma.sh` | Prints a `Figma N/200` status-line segment: green, yellow from the warning level, red from the blocking level. |
| `scripts/install.sh` | One-step setup for a new machine, safe to re-run: links this skill into `~/.claude/skills/tool-budget`, copies both scripts into `~/.claude/hooks/`, backs up `~/.claude/settings.json` and registers the hook if it's missing, sets the status line (or prints the line to add to an existing status-line script), and adds or refreshes the rules block in `~/.claude/CLAUDE.md`. |
| `scripts/claude-md-block.md` | The short rules block the installer puts in the global `~/.claude/CLAUDE.md`, between `tool-budget:start` and `tool-budget:end` markers, so every session in every project follows the rules even when this skill isn't loaded. Edit it here and re-run the installer. |

**Behaviour:**

- From 150 calls it warns: the user sees a message and Claude is told to mention the count and save calls.
- From 195 it blocks Figma calls without logging them. Don't work around the block. Tell the user, who can allow the rest of the day with `touch ~/.claude/figma-mcp-allow-today`.
- Change the levels with `FIGMA_MCP_LIMIT`, `FIGMA_MCP_WARN_AT` and `FIGMA_MCP_BLOCK_AT` in the `env` block of `~/.claude/settings.json`. For a 20/month seat this daily counter doesn't fit; tell the user instead of pretending it does.

**Install:** the skill itself installs with `npx skills add https://github.com/gerald-donkor/tool-budget --skill tool-budget` (add `-g` for every project; or a git clone). The `skills` CLI only copies files, so for the counter run `bash <skill-dir>/scripts/install.sh` (`~/.claude/skills/tool-budget/scripts/install.sh` for a global install, `.claude/skills/tool-budget/scripts/install.sh` in the project for a project install), then have the user open `/hooks` once or restart Claude Code. Hooks are loaded at session start, so a newly added hook won't fire in the session that added it.

**Verify without spending quota:**

1. Pipe-test with a throwaway home: `echo '{"tool_name":"mcp__figma__get_metadata"}' | HOME=/tmp/fake bash scripts/figma-mcp-counter.sh`, after creating `/tmp/fake/.claude`. Pre-fill that log with today's date to test the warning and block paths.
2. In a fresh session, call `whoami`. It's free, so it isn't logged; to prove the hook fires, temporarily prefix the hook command with a sentinel such as `echo fired >> /tmp/hook-check.txt;`, then remove it.

**Known limits:**

- It only counts calls made by Claude Code on this machine. Other apps, other machines and Figma's own AI features aren't counted, so treat the number as a minimum.
- Figma doesn't document when the day resets; the counter assumes midnight UTC. That's why it blocks at 195, not 200.
- `use_figma` and `generate_figma_design` can read and write, so they're counted to be safe. The count may run slightly high, never low.
- It can't tell which team owns a file, so calls to a file on a lower-limit plan are counted against the daily figure.

**Requirements:** bash, `jq`, `flock` (util-linux) and GNU `date`. On macOS, install `coreutils` and `util-linux`, or adapt the `date -r` and `flock` lines.
