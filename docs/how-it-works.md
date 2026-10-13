# How tool-budget works

This page explains each part of the setup in detail. For installation and everyday use, see the [README](../README.md).

## Contents

- [The skill](#the-skill)
- [The global rules block](#the-global-rules-block)
- [The Figma call counter](#the-figma-call-counter)
- [The status-line segment](#the-status-line-segment)
- [What the installer does](#what-the-installer-does)
- [Testing without using Figma quota](#testing-without-using-figma-quota)
- [Known limits](#known-limits)

## The skill

[`SKILL.md`](../SKILL.md) is what Claude reads when the skill is triggered. Its description makes Claude load it:

- before Claude in Chrome automation;
- before Figma MCP read calls;
- when you ask about token cost, rate limits, remaining calls or AI credits;
- when setting up or debugging the counter.

It starts with one principle that overrides the rest: **quality comes first**. The rules remove waste (repeated reads, unbounded dumps, polling, expensive tools where cheap ones give the same answer), never the reads and checks the work needs. If a budget or limit would force a weaker or unverified result, Claude stops and asks you instead of quietly cutting corners.

It then has three parts:

1. **Claude in Chrome as a last resort.** Use it only when all three hold:
   - the task needs a live, signed-in page (billing, admin, account settings);
   - nothing else can answer it;
   - you asked for it or agreed when offered.

   The skill lists what to use instead (WebFetch, Firecrawl, MCP tools, a headless browser), what each browser action costs in tokens, and seven concrete ways to keep a session cheap. If the extension isn't connected, Claude stops after one retry and tells you how to fix it rather than looping.
2. **Figma MCP limits.** The limits by plan and seat, which tools are free, and how to spend read calls: find the node first, then read only that node, never poll, and stop on a limit.
3. **The counter.** How it behaves, how to install and verify it, and its limits.

## The global rules block

Skills load on demand. To make the essential rules apply all the time, the installer adds a short block to your global `~/.claude/CLAUDE.md`, which Claude Code reads at the start of every session in every project:

```markdown
<!-- tool-budget:start -->
## Tool budget (from the tool-budget skill)
...
<!-- tool-budget:end -->
```

The source is [`scripts/claude-md-block.md`](../scripts/claude-md-block.md). Edit it there and re-run the installer, rather than editing `~/.claude/CLAUDE.md` directly; the installer replaces everything between the markers.

Project instructions, such as a repo's `CLAUDE.md` or `AGENTS.md`, can add project-specific details on top, like which Figma team owns a project's files.

## The Figma call counter

[`scripts/figma-mcp-counter.sh`](../scripts/figma-mcp-counter.sh) runs before every tool whose name matches `mcp__figma__.*`. Claude Code passes it the tool call as JSON on standard input.

For each call it:

1. **Skips free tools.** `whoami`, `create_new_file` and `add_code_connect_map` are exempt from Figma's limit, so they aren't counted.
2. **Takes a lock** (`~/.claude/figma-mcp-usage.log.lock`), so calls made at the same time are counted correctly.
3. **Counts today's calls**: lines in the log that start with today's UTC date.
4. **Blocks at the block level.** At 195 or more, unless you've allowed it for today, it returns a `deny` decision. Claude sees the reason and you see a message. Blocked calls aren't logged.
5. **Logs the call** otherwise.
6. **Warns at the warning level.** From 150, it shows you a message and adds a note to Claude's context asking it to mention the count and save calls. The call still goes ahead.

### The log

`~/.claude/figma-mcp-usage.log` has one line per counted call: a UTC timestamp and the tool name, separated by a tab.

```
2026-10-13T10:24:38Z	get_metadata
```

It's never trimmed. Each line is tiny and the file gives you a history. Delete it whenever you like; the count simply restarts.

### Allowing the rest of the day

```bash
touch ~/.claude/figma-mcp-allow-today
```

The hook only honours this file if it was touched today (UTC), so the override ends by itself at the next reset.

## The status-line segment

[`scripts/statusline-figma.sh`](../scripts/statusline-figma.sh) prints one coloured segment, such as ` Figma 37/200`, from today's lines in the log:

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

## What the installer does

[`scripts/install.sh`](../scripts/install.sh) is safe to run more than once. Each step checks before changing anything:

1. **Checks requirements.** Stops with a message if `jq` or `flock` is missing.
2. **Links the skill** to `~/.claude/skills/tool-budget`. If the skill is already installed there (for example with `npx skills add … -g`), it says so and moves on. If something else that isn't a symlink exists there, it leaves it alone and says so.
3. **Copies the scripts** `figma-mcp-counter.sh` and `statusline-figma.sh` into `~/.claude/hooks/`, overwriting older copies.
4. **Backs up `~/.claude/settings.json`** to `~/.claude/backups/settings.json.<timestamp>`, creating an empty settings file first if there isn't one.
5. **Registers the hook** under `hooks.PreToolUse` with the matcher `mcp__figma__.*`, only if no hook with that matcher exists. Your other hooks and settings are kept.
6. **Sets up the status line:**
   - No status line yet: it sets the Figma segment as your status line.
   - Your status line already includes the segment: it does nothing.
   - You have a different status line: it prints the one line to add to your script. It never edits your script.
7. **Adds or refreshes the rules block** in `~/.claude/CLAUDE.md`. It removes any previous block between the `tool-budget` markers and appends the current one, leaving the rest of the file untouched.

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

## Testing without using Figma quota

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

## Known limits

- **Only local calls are counted.** The counter sees only calls made by Claude Code on this machine. Other tools (Cursor, other machines, Figma's own AI features) share the same limit but aren't counted, so treat the number as a minimum.
- **The reset time is assumed.** Figma doesn't document when the daily limit resets. The counter assumes midnight UTC, which is why it blocks a little before the real limit.
- **Some tools may not count.** `use_figma` and `generate_figma_design` can both read and write. Figma's docs say tools that write are exempt but only name three, so the counter includes these two to be safe. Your count may run slightly high, never low.
- **There's one count for all teams.** The counter can't tell which team owns a file, so calls to files on a lower-limit plan are added to the same daily figure.
- **It counts calls, not tokens.** It doesn't measure Chrome's token use; the skill's rules handle that.
- **The figures will go out of date.** Figma's limits were checked on 2026-10-13, and the token costs are approximate. See the [reference](reference.md).
