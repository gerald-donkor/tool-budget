<!-- tool-budget:start -->
## Tool budget (from the tool-budget skill)

- **Quality comes first.** These rules cut waste (repeated reads, unbounded dumps, polling, expensive tools where cheap ones do), never rigour. Do every read and verification premium work needs. If a budget or limit would force a weaker or unverified result, stop and ask the user; never trade quality away silently.
- **Claude in Chrome is a last resort.** Use it only when the task needs a live, signed-in page (billing, admin, account settings), nothing else can answer it, and the user asked or agreed. Don't use it for local previews, public pages, Figma/Paper files or artifacts. If the extension isn't connected, stop after one retry and tell the user. Keep sessions cheap: direct URLs, `find`/`get_page_text` before screenshots, `scale: 0.5`, bounded `read_page`, close the tab when done.
- **Figma MCP reads are rate-limited** (Pro/Org Full or Dev seat: 200/day; Starter or View/Collab seat: 20/month). `whoami`, `create_new_file` and `add_code_connect_map` are free. Use `get_metadata` first, then screenshot or read only the nodes needed; never poll, but always verify meaningful changes. On a rate-limit error or a counter block, stop and tell the user; don't retry or work around it.
- A local counter hook (`~/.claude/hooks/figma-mcp-counter.sh`) logs Figma calls, warns at 150 and blocks at 195 per UTC day; the status line shows `Figma N/200`. The user can allow the rest of a day with `touch ~/.claude/figma-mcp-allow-today`.
- Load the `tool-budget` skill for details before browser automation or heavy Figma work.
<!-- tool-budget:end -->
