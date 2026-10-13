#!/usr/bin/env bash
# PreToolUse hook for mcp__figma__* tools.
# Counts rate-limited Figma MCP calls per UTC day, warns from WARN_AT and blocks from BLOCK_AT.
# Log: ~/.claude/figma-mcp-usage.log
# Override for the rest of today: touch ~/.claude/figma-mcp-allow-today
# Configure with env vars (e.g. in the "env" block of ~/.claude/settings.json):
#   FIGMA_MCP_LIMIT (default 200), FIGMA_MCP_WARN_AT (150), FIGMA_MCP_BLOCK_AT (195)
LOG="$HOME/.claude/figma-mcp-usage.log"
OVERRIDE="$HOME/.claude/figma-mcp-allow-today"
LIMIT=${FIGMA_MCP_LIMIT:-200}
WARN_AT=${FIGMA_MCP_WARN_AT:-150}
BLOCK_AT=${FIGMA_MCP_BLOCK_AT:-195}

tool=$(jq -r '.tool_name // empty')
name=${tool#mcp__figma__}

# Exempt from Figma's rate limit (per Figma docs, checked 2026-10-13)
case "$name" in
  whoami|create_new_file|add_code_connect_map) exit 0 ;;
esac

today=$(date -u +%F)
exec 9>"$LOG.lock"
flock 9
used=$(grep -c "^$today" "$LOG" 2>/dev/null); used=${used:-0}

override=0
[ -f "$OVERRIDE" ] && [ "$(date -u -r "$OVERRIDE" +%F)" = "$today" ] && override=1

if [ "$used" -ge "$BLOCK_AT" ] && [ "$override" -eq 0 ]; then
  msg="Figma MCP: $used/$LIMIT rate-limited calls used today (UTC). Blocked at $BLOCK_AT to stay under Figma's limit. To allow the remaining calls today run: touch ~/.claude/figma-mcp-allow-today"
  jq -n --arg m "$msg" '{
    systemMessage: $m,
    hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $m}
  }'
  exit 0
fi

printf '%s\t%s\n' "$(date -u +%FT%TZ)" "$name" >> "$LOG"
used=$((used + 1))

if [ "$used" -ge "$WARN_AT" ]; then
  msg="Figma MCP: $used/$LIMIT rate-limited calls used today (UTC). Tell the user and spend remaining Figma read calls sparingly."
  jq -n --arg m "$msg" '{
    systemMessage: $m,
    hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $m}
  }'
fi
exit 0
