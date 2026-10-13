# Reference

Figures the skill relies on. Both tables go out of date; re-check them when they matter. Back to the [README](../README.md).

## Figma MCP limits

From [Figma's rate-limit docs](https://developers.figma.com/docs/figma-mcp-server/rate-limits-access/), checked 2026-10-13. Figma may change them.

| Plan | Seat | Limit |
|---|---|---|
| Starter | any | up to 20 calls/month |
| Professional | View or Collab | up to 20 calls/month |
| Professional | Full or Dev | up to 200 calls/day, 10/minute |
| Organization | Full or Dev | up to 200 calls/day, 15/minute |
| Enterprise | Full or Dev | up to 600 calls/day, 20/minute |

- The limits apply to tool calls that **read** Figma data.
- Free tools named in the docs: `whoami`, `create_new_file`, `add_code_connect_map`.
- Ask Claude to call `whoami` to see your plans and seats. It doesn't report usage, and nothing in Figma's API does.
- AI credit balances aren't exposed through the MCP server either; they're in Figma's admin or billing settings.

## Approximate Claude in Chrome costs

| Action | Approximate cost |
|---|---|
| Full-size screenshot | 1,000–1,500 tokens |
| Screenshot with `scale: 0.5` | about a quarter of that |
| `read_page` with defaults | up to 50,000 characters, about 12,000 tokens |
| Loading the Chrome tools | a few thousand tokens |
| Reading one value from a dashboard | often 6–10 calls, 10,000–30,000 tokens |
| For comparison: a small MCP call such as Figma `whoami` | about 150 tokens |

Everything a tool returns stays in the conversation context, so these costs add up over a session.
