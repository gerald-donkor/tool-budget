#!/usr/bin/env bash
# Prints a colored "Figma N/LIMIT" status-line segment from the counter's log.
# Use it as the whole status line, or call it from an existing status-line script:
#   bash ~/.claude/hooks/statusline-figma.sh
LIMIT=${FIGMA_MCP_LIMIT:-200}
WARN_AT=${FIGMA_MCP_WARN_AT:-150}
BLOCK_AT=${FIGMA_MCP_BLOCK_AT:-195}
log="$HOME/.claude/figma-mcp-usage.log"
n=0
[ -f "$log" ] && n=$(grep -c "^$(date -u +%F)" "$log")
if [ "$n" -ge "$BLOCK_AT" ]; then c='243;139;168'    # red - blocking
elif [ "$n" -ge "$WARN_AT" ]; then c='249;226;175'   # yellow - warning
else c='166;227;161'; fi                              # green
printf ' \033[38;2;%smFigma %s/%s\033[0m' "$c" "$n" "$LIMIT"
