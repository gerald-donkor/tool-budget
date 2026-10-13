# tool-budget

Keeps Claude Code's browser automation and Figma MCP calls cheap, with a Figma call counter and status-bar count.

Two kinds of tool use get expensive in [Claude Code](https://claude.com/claude-code):

- **Tokens.** Browser automation with Claude in Chrome is powerful but costly. Every screenshot and page dump stays in the conversation.
- **Rate-limited calls.** The Figma MCP server caps how many read calls you can make, and gives you no way to see how many are left.

This skill gives Claude clear rules for when these tools are worth using and how to use them cheaply. It also installs a small hook that counts your Figma MCP calls, warns you before you run out, and shows the count in your status bar.

## Table of contents

- [Background](#background)
- [Install](#install)
- [Usage](#usage)
- [Configuration](#configuration)
- [Updating](#updating)
- [Uninstalling](#uninstalling)
- [Documentation](#documentation)
- [Maintainers](#maintainers)
- [Contributing](#contributing)
- [License](#license)

## Background

The setup has four parts:

| Part | What it does |
|---|---|
| **Skill** ([`SKILL.md`](SKILL.md)) | Full guidance Claude loads before browser automation or heavy Figma work: when to use each tool, what it costs, and how to keep it cheap. |
| **Global rules block** | A short summary of the rules in `~/.claude/CLAUDE.md`, so every session in every project follows them even when the skill isn't loaded. |
| **Figma call counter** | A `PreToolUse` hook that logs each rate-limited Figma MCP call, warns at 150 per day and blocks at 195. |
| **Status-bar count** | Shows `Figma N/200` in Claude Code's status bar: green, then yellow from 150, red from 195. |

Figma doesn't report how many MCP calls you have left, so the counter keeps its own tally. It only sees calls made by Claude Code on the same machine, so treat the number as a minimum. See [known limits](docs/how-it-works.md#known-limits).

## Install

### Dependencies

- [Claude Code](https://claude.com/claude-code), with hooks enabled (the default)
- `bash`
- [`jq`](https://jqlang.org/), for reading hook input and editing `settings.json`
- `flock` from `util-linux`, so parallel Figma calls are counted correctly
- GNU `date`, for its `-u` and `-r` options

These are standard on most Linux distributions. On macOS, install `jq`, `coreutils` and `util-linux` (for example with Homebrew) and put GNU `date` and `flock` on your `PATH`.

The Figma MCP server and the Claude in Chrome extension are optional. The rules apply to whichever tools you have; the counter only acts when Figma tools are called.

### Steps

```bash
git clone https://github.com/gerald-donkor/tool-budget.git ~/Projects/tool-budget
bash ~/Projects/tool-budget/scripts/install.sh
```

Then, in Claude Code, open `/hooks` once or restart Claude Code. Hooks are read when a session starts, so a newly added hook doesn't run in a session that was already open.

The installer:

- links the skill into `~/.claude/skills/`;
- copies the hook and status-line scripts into `~/.claude/hooks/`;
- backs up `~/.claude/settings.json`, then registers the hook;
- sets up the status-bar count;
- adds the rules block to `~/.claude/CLAUDE.md`.

It's safe to re-run and keeps your other settings. Keep the repo where you cloned it, because the skill is a link to it; if you move it, re-run the installer. For each step in detail, see [what the installer does](docs/how-it-works.md#what-the-installer-does).

### Check the install

1. In a new Claude Code session, the skill list includes `tool-budget`.
2. The status bar shows `Figma 0/200`, or today's count.
3. After a counted Figma call, such as `get_metadata`, the log has a new line:

   ```bash
   tail ~/.claude/figma-mcp-usage.log
   ```

To test the counter without using any Figma quota, see [testing without using Figma quota](docs/how-it-works.md#testing-without-using-figma-quota).

## Usage

Once installed, there's nothing to run. In practice:

- **Claude avoids the browser** unless a task really needs a signed-in page, such as billing or admin settings. It asks first if the browser would only be a convenience.
- **Claude reads Figma carefully.** It finds the right part of a file first, reads only that part, and never polls.
- **The status bar shows your Figma count** at all times.
- **At 150 calls** you see a warning, and Claude mentions it.
- **At 195 calls** Figma calls are refused with a message. Claude stops and tells you rather than retrying.

To use the last few calls of the day anyway, run:

```bash
touch ~/.claude/figma-mcp-allow-today
```

This lasts until midnight UTC.

### Adding the count to an existing status line

If you already had a status line, the installer prints this line instead of editing your script. Add it where you want the count to appear:

```bash
[ -f "$HOME/.claude/hooks/statusline-figma.sh" ] && bash "$HOME/.claude/hooks/statusline-figma.sh"
```

## Configuration

The defaults suit a Figma Professional or Organization Full seat (200 calls a day). To change them, set these in the `env` block of `~/.claude/settings.json`:

| Variable | Default | Meaning |
|---|---|---|
| `FIGMA_MCP_LIMIT` | `200` | The daily limit, shown in messages and the status bar. |
| `FIGMA_MCP_WARN_AT` | `150` | The count at which warnings start. |
| `FIGMA_MCP_BLOCK_AT` | `195` | The count at which calls are blocked. |

For example, for an Enterprise Full seat (600 a day):

```json
{
  "env": {
    "FIGMA_MCP_LIMIT": "600",
    "FIGMA_MCP_WARN_AT": "500",
    "FIGMA_MCP_BLOCK_AT": "590"
  }
}
```

Keep the block level a little under the real limit, because Figma's reset time isn't documented. Starter plans and View or Collab seats get 20 calls a month, which a daily counter doesn't fit; see the [Figma limits](docs/reference.md#figma-mcp-limits).

To change the rules themselves, edit [`SKILL.md`](SKILL.md) or [`scripts/claude-md-block.md`](scripts/claude-md-block.md) and re-run the installer.

## Updating

```bash
cd ~/Projects/tool-budget
git pull
bash scripts/install.sh
```

Changes to `SKILL.md` take effect straight away, because the skill is a link to the repo. Re-running the installer copies the latest scripts and refreshes the rules block.

## Uninstalling

There's no uninstall script. Remove the pieces by hand:

```bash
# Skill link
rm ~/.claude/skills/tool-budget

# Hook registration (backs up settings first)
cp ~/.claude/settings.json ~/.claude/settings.json.bak
tmp=$(mktemp)
jq '.hooks.PreToolUse |= map(select(.matcher != "mcp__figma__.*"))
    | if .hooks.PreToolUse == [] then del(.hooks.PreToolUse) else . end' \
  ~/.claude/settings.json > "$tmp" && mv "$tmp" ~/.claude/settings.json

# Scripts, log and override
rm -f ~/.claude/hooks/figma-mcp-counter.sh ~/.claude/hooks/statusline-figma.sh
rm -f ~/.claude/figma-mcp-usage.log ~/.claude/figma-mcp-usage.log.lock ~/.claude/figma-mcp-allow-today

# Rules block in the global CLAUDE.md
sed -i '/<!-- tool-budget:start -->/,/<!-- tool-budget:end -->/d' ~/.claude/CLAUDE.md
```

Then:

- **Status line.** If the installer set the count as your whole status line, remove the `statusLine` entry from `settings.json`. If you added the line to your own script, delete it.
- **Reload.** Open `/hooks` or restart Claude Code.

## Documentation

| Page | Covers |
|---|---|
| [How it works](docs/how-it-works.md) | Each part in detail, what the installer changes, testing without quota, and known limits. |
| [Reference](docs/reference.md) | Figma MCP limits by plan and seat, and approximate Claude in Chrome token costs. |
| [Troubleshooting](docs/troubleshooting.md) | What to check when the counter, the status bar, the skill or Chrome don't work. |
| [`SKILL.md`](SKILL.md) | The guidance Claude itself reads. |

## Maintainers

[@gerald-donkor](https://github.com/gerald-donkor)

## Contributing

Questions and bug reports are welcome as [issues](https://github.com/gerald-donkor/tool-budget/issues).

When changing the scripts:

- Test them against a throwaway home folder (`HOME=/tmp/fake`) before running them on your own setup. See [testing without using Figma quota](docs/how-it-works.md#testing-without-using-figma-quota).
- Keep `scripts/install.sh` safe to re-run.
- Update `SKILL.md` and the docs to match.

## License

No license has been chosen yet. Until one is added, all rights are reserved by the maintainer.
