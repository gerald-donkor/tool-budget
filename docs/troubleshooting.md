# Troubleshooting

Back to the [README](../README.md).

## The counter doesn't log anything

- Open `/hooks` once or restart Claude Code. Hooks added during a session don't run until then.
- Check the hook is registered:

  ```bash
  jq '.hooks.PreToolUse[] | select(.matcher == "mcp__figma__.*")' ~/.claude/settings.json
  ```

- Check that `settings.json` is valid JSON with `jq . ~/.claude/settings.json`. An invalid file means Claude Code ignores all of it.
- Free tools (`whoami`, `create_new_file`, `add_code_connect_map`) are never logged. Test with a counted tool, or follow [testing without using Figma quota](how-it-works.md#testing-without-using-figma-quota).
- Check that `jq` and `flock` are on the `PATH` Claude Code uses.

## The status bar doesn't show the Figma count

- If you already had a status line, the installer only printed the line to add. Add it to your status-line script; see [the status-line segment](how-it-works.md#the-status-line-segment).
- Run the segment by hand to see its output:

  ```bash
  bash ~/.claude/hooks/statusline-figma.sh
  ```

## Figma calls are blocked and I still need them

Run this. It lasts until midnight UTC:

```bash
touch ~/.claude/figma-mcp-allow-today
```

## Figma says I'm rate-limited but the counter is low

Calls from other apps, other machines or Figma's own AI features use the same limit but aren't counted here. See [known limits](how-it-works.md#known-limits).

## The skill doesn't appear in Claude Code

Check where it is installed:

```bash
ls -l ~/.claude/skills/tool-budget
```

- With a `skills` CLI install, it's a folder; `npx skills list -g` should list `tool-budget`. If you installed without `-g`, it's in the project's `.claude/skills/` instead and only appears in that project.
- With a git install, it should be a link to your clone. If you moved the repo, re-run `scripts/install.sh`.

## Claude in Chrome won't connect

- Make sure the extension is installed, turned on, and signed in to the same claude.ai account as Claude Code.
- Run `/chrome` in Claude Code to check or reconnect.
- If you just installed the extension, restart Chrome.
