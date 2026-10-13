#!/usr/bin/env bash
# Installs the tool-budget skill into ~/.claude. Safe to re-run.
#   - links the skill into ~/.claude/skills/tool-budget (skipped if it was installed there,
#     e.g. with `npx skills add ... -g`)
#   - installs the Figma MCP counter hook and status-line segment into ~/.claude/hooks
#   - registers the hook in ~/.claude/settings.json (backed up first)
#   - adds the status-line segment (new status line, or prints the line to add)
#   - adds/refreshes a short rules block in ~/.claude/CLAUDE.md
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
skill_dir=$(dirname "$here")
claude="${CLAUDE_HOME:-$HOME/.claude}"
settings="$claude/settings.json"
hook_cmd="bash $claude/hooks/figma-mcp-counter.sh"
seg_cmd="bash $claude/hooks/statusline-figma.sh"

for bin in jq flock; do
  command -v "$bin" >/dev/null || { echo "$bin is required" >&2; exit 1; }
done

mkdir -p "$claude/hooks" "$claude/backups" "$claude/skills"

# 1. Skill link
link="$claude/skills/tool-budget"
if [ -e "$link" ] && [ "$(cd "$link" && pwd -P)" = "$(cd "$skill_dir" && pwd -P)" ]; then
  echo "Skill already installed at $link"
elif [ -L "$link" ] || [ ! -e "$link" ]; then
  ln -sfn "$skill_dir" "$link"
  echo "Linked skill: $link -> $skill_dir"
else
  echo "Skipped skill link: $link exists and is not a symlink"
fi

# 2. Scripts
install -m 755 "$here/figma-mcp-counter.sh" "$claude/hooks/figma-mcp-counter.sh"
install -m 755 "$here/statusline-figma.sh" "$claude/hooks/statusline-figma.sh"
echo "Installed scripts to $claude/hooks/"

# 3. Hook in settings.json
[ -f "$settings" ] || echo '{}' > "$settings"
cp "$settings" "$claude/backups/settings.json.$(date +%Y%m%d%H%M%S)"
tmp=$(mktemp)
jq --arg cmd "$hook_cmd" '
  if ([.hooks.PreToolUse[]? | select(.matcher == "mcp__figma__.*")] | length) > 0 then .
  else .hooks.PreToolUse = ((.hooks.PreToolUse // []) + [{
    matcher: "mcp__figma__.*",
    hooks: [{type: "command", command: $cmd, timeout: 5}]
  }]) end' "$settings" > "$tmp" && mv "$tmp" "$settings"
echo "Hook on mcp__figma__.* is registered in $settings"

# 4. Status line
if ! jq -e '.statusLine' "$settings" >/dev/null; then
  tmp=$(mktemp)
  jq --arg cmd "$seg_cmd" '.statusLine = {type: "command", command: $cmd}' "$settings" > "$tmp" && mv "$tmp" "$settings"
  echo "Set the status line to show the Figma count"
elif jq -r '.statusLine.command' "$settings" | grep -q "statusline-figma.sh"; then
  echo "Status line already shows the Figma count"
else
  script=$(jq -r '.statusLine.command' "$settings" | grep -o "[^ ]*\.sh" | head -1 || true)
  script=${script/#\~/$HOME}
  if [ -n "$script" ] && [ -f "$script" ] && grep -q "statusline-figma.sh" "$script"; then
    echo "Status line script already shows the Figma count"
  else
    echo "You already have a status line. To show the Figma count, add this to it:"
    echo "  $seg_cmd"
  fi
fi

# 5. Rules block in the global CLAUDE.md
md="$claude/CLAUDE.md"
touch "$md"
tmp=$(mktemp)
awk '/<!-- tool-budget:start -->/{skip=1} !skip{print} /<!-- tool-budget:end -->/{skip=0}' "$md" > "$tmp"
# drop trailing blank lines, then append the fresh block
sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$tmp" > "$tmp.2"
{ cat "$tmp.2"; [ -s "$tmp.2" ] && echo; cat "$here/claude-md-block.md"; } > "$md"
rm -f "$tmp" "$tmp.2"
echo "Refreshed the tool-budget rules block in $md"

echo
echo "Done. Open /hooks once or restart Claude Code so the hook loads."
