# tool-budget

A [Claude Code](https://claude.com/claude-code) skill that keeps two expensive kinds of tool use under control:

- **Tokens.** Browser automation with Claude in Chrome is powerful but costly. Every screenshot and page dump stays in the conversation.
- **Rate-limited calls.** The Figma MCP server caps how many read calls you can make, and gives you no way to see how many are left.

The skill gives Claude clear rules for when these tools are worth using and how to use them cheaply. It also installs a small hook that counts your Figma MCP calls, warns you before you run out, and shows the count in your status bar.

---

## Contents

- [What you get](#what-you-get)
- [Requirements](#requirements)
- [Install](#install)
- [Check that it works](#check-that-it-works)
- [How it works](#how-it-works)
  - [The skill](#the-skill)
  - [The global rules block](#the-global-rules-block)
  - [The Figma call counter](#the-figma-call-counter)
  - [The status-line segment](#the-status-line-segment)
- [Configuration](#configuration)
- [Day-to-day use](#day-to-day-use)
- [Updating](#updating)
- [Uninstalling](#uninstalling)
- [Troubleshooting](#troubleshooting)
- [Known limits](#known-limits)
- [Reference](#reference)
- [Repository layout](#repository-layout)

---

## What you get

| Piece | What it does | Where it ends up |
|---|---|---|
| **Skill** (`SKILL.md`) | Full guidance Claude loads before browser automation or heavy Figma work: when to use each tool, what it costs, and how to keep it cheap. | `~/.claude/skills/tool-budget` (a symlink to this repo) |
| **Global rules block** | A short summary of the rules, so every session in every project follows them even when the skill isn't loaded. | `~/.claude/CLAUDE.md`, between marker comments |
| **Figma call counter** | A `PreToolUse` hook that logs each rate-limited Figma MCP call, warns at 150 per day and blocks at 195. | `~/.claude/hooks/figma-mcp-counter.sh`, registered in `~/.claude/settings.json` |
| **Status-line segment** | Shows `Figma N/200` in Claude Code's status bar: green, then yellow from 150, red from 195. | `~/.claude/hooks/statusline-figma.sh` |

---

## Requirements

- **Claude Code**, with hooks enabled (they are by default).
- **bash**
- **jq**, for reading hook input and editing `settings.json`.
- **flock** (part of `util-linux`), so parallel Figma calls don't corrupt the count.
- **GNU `date`**, for the `-u` and `-r` options the scripts use.

These are standard on most Linux distributions. On **macOS**, install `jq`, `coreutils` and `util-linux` (for example with Homebrew) and make sure GNU `date` and `flock` are on your `PATH`, or adapt the `date -r` and `flock` lines in the scripts.

The Figma MCP server and the Claude in Chrome extension are optional. The rules still apply to whichever tools you have; the counter only does anything when Figma tools are called.

---

## Install

```bash
git clone https://github.com/gerald-donkor/tool-budget.git ~/Projects/tool-budget
bash ~/Projects/tool-budget/scripts/install.sh
```

You can clone it anywhere. The installer links the skill to wherever the repo lives, so **keep the folder where you cloned it**; moving it breaks the link. Re-run the installer after a move.

Then, in Claude Code, **open `/hooks` once or restart Claude Code**. Hooks are read when a session starts, so a newly added hook doesn't run in a session that was already open.

### What the installer does

`scripts/install.sh` is safe to run more than once. Each step checks before changing anything:

1. **Checks requirements.** Stops with a message if `jq` or `flock` is missing.
2. **Links the skill** to `~/.claude/skills/tool-budget`. If something that isn't a symlink already exists there, it leaves it alone and says so.
3. **Copies the scripts** `figma-mcp-counter.sh` and `statusline-figma.sh` into `~/.claude/hooks/`, overwriting older copies.
4. **Backs up `~/.claude/settings.json`** to `~/.claude/backups/settings.json.<timestamp>`, creating an empty settings file first if there isn't one.
5. **Registers the hook** under `hooks.PreToolUse` with the matcher `mcp__figma__.*`, only if no hook with that matcher exists. Your other hooks and settings are kept.
6. **Sets up the status line:**
   - No status line yet: it sets the Figma segment as your status line.
   - Your status line already includes the segment: it does nothing.
   - You have a different status line: it prints the one line to add to your status-line script (see [The status-line segment](#the-status-line-segment)). It never edits your script.
7. **Adds or refreshes the rules block** in `~/.claude/CLAUDE.md`. It removes any previous block between the `tool-budget` markers and appends the current one, leaving the rest of the file untouched.

---

## Check that it works

1. **The skill is listed.** In a new Claude Code session, the skill list should include `tool-budget`.
2. **The status bar shows the count.** You should see `Figma 0/200` (or today's count).
3. **The counter runs.** After a counted Figma call (for example `get_metadata`), check the log:

   ```bash
   tail ~/.claude/figma-mcp-usage.log
   ```

   Each line is a UTC timestamp and a tool name, separated by a tab:

   ```
   2026-10-13T10:24:38Z	get_metadata
   ```

### Testing without using any Figma quota

Run the hook by hand against a throwaway home folder:

```bash
mkdir -p /tmp/fake/.claude
echo '{"tool_name":"mcp__figma__get_metadata"}' | HOME=/tmp/fake bash scripts/figma-mcp-counter.sh
cat /tmp/fake/.claude/figma-mcp-usage.log
```

To test the warning and the block, fill that log with today's date first:

```bash
for i in $(seq 1 193); do printf '%s\tx\n' "$(date -u +%FT%TZ)" >> /tmp/fake/.claude/figma-mcp-usage.log; done
echo '{"tool_name":"mcp__figma__get_screenshot"}' | HOME=/tmp/fake bash scripts/figma-mcp-counter.sh   # call 195: warning
echo '{"tool_name":"mcp__figma__get_screenshot"}' | HOME=/tmp/fake bash scripts/figma-mcp-counter.sh   # blocked
rm -rf /tmp/fake
```

To confirm Claude Code actually runs the hook, ask Claude to call Figma's `whoami`. It's free, so it isn't logged. Temporarily put `echo fired >> /tmp/hook-check.txt; ` in front of the hook command in `settings.json`, make the call, check the file, then remove the prefix.

---

## How it works

### The skill

`SKILL.md` is what Claude reads when the skill is triggered. Its description makes Claude load it before Claude in Chrome automation, before Figma MCP read calls, when you ask about token cost, rate limits, remaining calls or AI credits, and when setting up or debugging the counter.

It has three parts:

1. **Claude in Chrome as a last resort.** Use it only when all three hold:
   - the task needs a live, signed-in page (billing, admin, account settings);
   - nothing else can answer it;
   - you asked for it or agreed when offered.

   The skill lists what to use instead (WebFetch, Firecrawl, MCP tools, a headless browser), what each browser action costs in tokens, and seven concrete ways to keep a session cheap. If the extension isn't connected, Claude stops after one retry and tells you how to fix it rather than looping.
2. **Figma MCP limits.** The limits by plan and seat, which tools are free, and how to spend read calls: find the node first, then read only that node, never poll, and stop on a limit.
3. **The counter.** How it behaves, how to install and verify it, and its limits.

### The global rules block

Skills load on demand. To make the essential rules apply all the time, the installer adds a short block to your global `~/.claude/CLAUDE.md`, which Claude Code reads at the start of every session in every project:

```markdown
<!-- tool-budget:start -->
## Tool budget (from the tool-budget skill)
...
<!-- tool-budget:end -->
```

The source is `scripts/claude-md-block.md`. Edit it there and re-run the installer, rather than editing `~/.claude/CLAUDE.md` directly; the installer replaces everything between the markers.

Project instructions, such as a repo's `CLAUDE.md` or `AGENTS.md`, can add project-specific details on top, like which Figma team owns a project's files.

### The Figma call counter

`figma-mcp-counter.sh` runs before every tool whose name matches `mcp__figma__.*`. Claude Code passes it the tool call as JSON on standard input.

For each call it:

1. **Skips free tools.** `whoami`, `create_new_file` and `add_code_connect_map` are exempt from Figma's limit, so they aren't counted.
2. **Takes a lock** (`~/.claude/figma-mcp-usage.log.lock`), so calls made at the same time are counted correctly.
3. **Counts today's calls**: lines in the log that start with today's UTC date.
4. **Blocks at the block level.** At 195 or more, unless you've allowed it for today, it returns a `deny` decision. Claude sees the reason and you see a message. Blocked calls aren't logged.
5. **Logs the call** otherwise, as a timestamp and tool name.
6. **Warns at the warning level.** From 150, it shows you a message and adds a note to Claude's context asking it to mention the count and save calls. The call still goes ahead.

**Allowing the rest of the day.** If you want to use the last few calls:

```bash
touch ~/.claude/figma-mcp-allow-today
```

The hook only honours this file if it was touched today (UTC), so the override ends by itself at the next reset.

**The log** is never trimmed. It grows by one short line per call, which is tiny, and it gives you a history. Delete it whenever you like; the count simply restarts.

### The status-line segment

`statusline-figma.sh` prints one coloured segment, such as ` Figma 37/200`, from today's lines in the log:

| Count | Colour |
|---|---|
| Below the warning level | green |
| From the warning level (150) | yellow |
| From the block level (195) | red |

If you have no status line, the installer uses this segment as your whole status line. If you already have a status-line script, add this line where you want the segment to appear:

```bash
[ -f "$HOME/.claude/hooks/statusline-figma.sh" ] && bash "$HOME/.claude/hooks/statusline-figma.sh"
```

The `[ -f … ]` check keeps your status line working on machines where the skill isn't installed.

---

## Configuration

Set these environment variables to change the numbers. The easiest place is the `env` block of `~/.claude/settings.json`, so they apply to the hook and the status line:

```json
{
  "env": {
    "FIGMA_MCP_LIMIT": "600",
    "FIGMA_MCP_WARN_AT": "500",
    "FIGMA_MCP_BLOCK_AT": "590"
  }
}
```

| Variable | Default | Meaning |
|---|---|---|
| `FIGMA_MCP_LIMIT` | `200` | The daily limit, shown in messages and the status bar. |
| `FIGMA_MCP_WARN_AT` | `150` | The count at which warnings start. |
| `FIGMA_MCP_BLOCK_AT` | `195` | The count at which calls are blocked. |

Pick values from the [Figma limits](#figma-mcp-limits) for your plan and seat. Keep the block level a little under the real limit, since Figma's reset time isn't documented.

**Monthly limits.** Starter plans and View or Collab seats get 20 calls a month. The counter counts per day, so it doesn't fit those seats well. On such a seat, rely on the skill's rules and count manually, or adapt the script to count by month (`date -u +%Y-%m`).

---

## Day-to-day use

You don't need to do anything. In practice:

- **Claude avoids the browser** unless a task really needs a signed-in page, and asks first if it would only be a convenience.
- **Claude reads Figma carefully**: it finds the right part of a file first, then reads only that part.
- **The status bar shows your Figma count** at all times.
- **At 150 calls** you'll see a warning, and Claude will mention it.
- **At 195 calls** Figma calls are refused with a message. Claude stops and tells you rather than retrying. Wait for the next UTC day, or run `touch ~/.claude/figma-mcp-allow-today` to use the rest.

---

## Updating

```bash
cd ~/Projects/tool-budget
git pull
bash scripts/install.sh
```

Re-running the installer copies the latest scripts and refreshes the rules block. Changes to `SKILL.md` take effect straight away, because the skill folder is a link to the repo.

If you change things yourself, edit the files in this repo, not the installed copies in `~/.claude/hooks/` or the block in `~/.claude/CLAUDE.md`. Re-run the installer, then commit and push.

---

## Uninstalling

There's no uninstall script. Remove the pieces by hand:

```bash
# 1. Skill link
rm ~/.claude/skills/tool-budget

# 2. Hook registration (backs up settings first)
cp ~/.claude/settings.json ~/.claude/settings.json.bak
tmp=$(mktemp)
jq '.hooks.PreToolUse |= map(select(.matcher != "mcp__figma__.*"))
    | if .hooks.PreToolUse == [] then del(.hooks.PreToolUse) else . end' \
  ~/.claude/settings.json > "$tmp" && mv "$tmp" ~/.claude/settings.json

# 3. Scripts, log and override
rm -f ~/.claude/hooks/figma-mcp-counter.sh ~/.claude/hooks/statusline-figma.sh
rm -f ~/.claude/figma-mcp-usage.log ~/.claude/figma-mcp-usage.log.lock ~/.claude/figma-mcp-allow-today

# 4. Rules block in the global CLAUDE.md
sed -i '/<!-- tool-budget:start -->/,/<!-- tool-budget:end -->/d' ~/.claude/CLAUDE.md
```

Then:

- **Status line.** If the installer set the segment as your whole status line, remove the `statusLine` entry from `settings.json`. If you added the segment line to your own script, delete it. Its `[ -f … ]` check means it does nothing once the script is gone.
- **Reload.** Open `/hooks` or restart Claude Code.

---

## Troubleshooting

**The counter doesn't log anything.**
- Open `/hooks` once or restart Claude Code. Hooks added during a session don't run until then.
- Check the hook is registered:
  ```bash
  jq '.hooks.PreToolUse[] | select(.matcher == "mcp__figma__.*")' ~/.claude/settings.json
  ```
- Check that `settings.json` is valid JSON with `jq . ~/.claude/settings.json`. An invalid file means Claude Code ignores all of it.
- Free tools (`whoami`, `create_new_file`, `add_code_connect_map`) are never logged. Test with a counted tool.
- Check that `jq` and `flock` are on the `PATH` Claude Code uses.

**The status bar doesn't show `Figma N/200`.**
- If you already had a status line, the installer only printed the line to add. Add it to your status-line script.
- Run the segment by hand to see its output: `bash ~/.claude/hooks/statusline-figma.sh`.

**Figma calls are blocked and I still need them.** Run `touch ~/.claude/figma-mcp-allow-today`. It lasts until midnight UTC.

**Figma says I'm rate-limited but the counter is low.** Calls from other apps, other machines or Figma's own AI features use the same limit but aren't counted here. See [Known limits](#known-limits).

**The skill doesn't appear.** Check the link with `ls -l ~/.claude/skills/tool-budget`. It should point to this repo. If you moved the repo, re-run the installer.

**Claude in Chrome won't connect.** The skill's guidance:
- Make sure the extension is installed, turned on, and signed in to the same claude.ai account as Claude Code.
- Run `/chrome` in Claude Code to check or reconnect.
- If you just installed the extension, restart Chrome.

---

## Known limits

- **Only local calls are counted.** The counter sees only calls made by Claude Code on this machine. Other tools (Cursor, other machines, Figma's own AI features) share the same limit but aren't counted, so treat the number as a minimum.
- **The reset time is assumed.** Figma doesn't document when the daily limit resets. The counter assumes midnight UTC, which is why it blocks a little before the real limit.
- **Some tools may not count.** `use_figma` and `generate_figma_design` can both read and write. Figma's docs say tools that write are exempt but only name three, so the counter includes these two to be safe. Your count may run slightly high, never low.
- **There's one count for all teams.** The counter can't tell which team owns a file, so calls to files on a lower-limit plan are added to the same daily figure.
- **It counts calls, not tokens.** It doesn't measure Chrome's token use; the skill's rules handle that.
- **The figures will go out of date.** Figma's limits were checked on 2026-10-13, and the token costs are approximate. Re-check Figma's page when it matters.

---

## Reference

### Figma MCP limits

From [Figma's rate-limit docs](https://developers.figma.com/docs/figma-mcp-server/rate-limits-access/), checked 2026-10-13. Figma may change them.

| Plan | Seat | Limit |
|---|---|---|
| Starter | any | up to 20 calls/month |
| Professional | View or Collab | up to 20 calls/month |
| Professional | Full or Dev | up to 200 calls/day, 10/minute |
| Organization | Full or Dev | up to 200 calls/day, 15/minute |
| Enterprise | Full or Dev | up to 600 calls/day, 20/minute |

Free tools named in the docs: `whoami`, `create_new_file`, `add_code_connect_map`. Ask Claude to call `whoami` to see your plans and seats; it doesn't report usage.

### Approximate Claude in Chrome costs

| Action | Approximate cost |
|---|---|
| Full-size screenshot | 1,000–1,500 tokens |
| Screenshot with `scale: 0.5` | about a quarter of that |
| `read_page` with defaults | up to 50,000 characters, about 12,000 tokens |
| Loading the Chrome tools | a few thousand tokens |
| Reading one value from a dashboard | often 6–10 calls, 10,000–30,000 tokens |
| For comparison: a small MCP call such as Figma `whoami` | about 150 tokens |

### Files the setup creates or changes

| Path | Created by | Purpose |
|---|---|---|
| `~/.claude/skills/tool-budget` | installer | Link to this repo |
| `~/.claude/hooks/figma-mcp-counter.sh` | installer | The hook |
| `~/.claude/hooks/statusline-figma.sh` | installer | The status-line segment |
| `~/.claude/settings.json` | installer (edited) | Hook registration, maybe the status line |
| `~/.claude/backups/settings.json.<timestamp>` | installer | Backup before each edit |
| `~/.claude/CLAUDE.md` | installer (edited) | The rules block |
| `~/.claude/figma-mcp-usage.log` | hook | One line per counted call |
| `~/.claude/figma-mcp-usage.log.lock` | hook | Lock file for concurrent calls |
| `~/.claude/figma-mcp-allow-today` | you | Today's override |

---

## Repository layout

```
tool-budget/
├── SKILL.md                     # The skill Claude reads
├── README.md                    # This file
└── scripts/
    ├── install.sh               # One-step, re-runnable setup
    ├── figma-mcp-counter.sh     # PreToolUse hook: count, warn, block
    ├── statusline-figma.sh      # "Figma N/200" status-line segment
    └── claude-md-block.md       # Rules block for ~/.claude/CLAUDE.md
```
