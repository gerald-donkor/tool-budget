# tool-budget

A Claude Code skill that keeps expensive tools cheap:

- **Claude in Chrome:** when browser automation is worth it, and how to cut its token cost.
- **Figma MCP:** the rate limits by plan, and how to spend read calls carefully.
- **A Figma call counter:** a `PreToolUse` hook that counts Figma MCP calls per day, warns at 150, blocks at 195, and shows `Figma N/200` in the status line.

## Install

```bash
git clone <this-repo> ~/Projects/tool-budget
bash ~/Projects/tool-budget/scripts/install.sh
```

The installer links the skill, installs the hook and status-line segment, and adds a short rules block to `~/.claude/CLAUDE.md`. It backs up `settings.json` first and is safe to re-run. Then open `/hooks` once in Claude Code, or restart it, so the hook loads.

Requirements: bash, `jq`, `flock` (util-linux) and GNU `date`.

See [SKILL.md](SKILL.md) for the full guidance, configuration and known limits.
