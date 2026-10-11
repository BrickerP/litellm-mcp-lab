# litellm-mcp-lab

**Local learning lab: LiteLLM proxy + one MCP server + a budgeted virtual key.**

This is a **lab / notes repo**, not a production gateway. It documents a quality-first experiment drawn from OSS radar work: run a small OpenAI-compatible proxy locally, attach one MCP tool server, and practice spend control with LiteLLM virtual keys. Expect rough edges, pinned docs links that move, and configs that need tuning for your machine.

> **Honest scope**
> - ✅ Local docker-compose or `uv` install of LiteLLM proxy
> - ✅ One minimal stdio MCP example (`echo`)
> - ✅ Soft budget on a virtual key (spend tracking when Postgres is up)
> - ❌ Not multi-tenant, not HA, not a security review, not a hosted SaaS
> - ❌ No secrets in this repo — copy `.env.example` → `.env`

## Why this exists

Agent stacks rarely fail on the model call alone. They fail on **routing**, **tool surface area**, and **unbounded spend**. This lab isolates three pieces you can reason about separately:

| Piece | Role in the lab |
|---|---|
| **LiteLLM proxy** | OpenAI-compatible gateway; models behind one base URL |
| **MCP server** | One local tool process (stdio) for agent/tool wiring practice |
| **Virtual key + budget** | Soft spend ceiling so experiments do not become invoices |

Quality over hype: if a step is flaky or optional, the README says so.

## Prerequisites

- Docker + Compose **or** Python 3.11+ with [`uv`](https://github.com/astral-sh/uv)
- An upstream provider key (e.g. `OPENAI_API_KEY`) — you pay the provider; this lab only routes
- Optional: `jq` + `curl` for the virtual-key helper script

## Quick start (Docker Compose)

```bash
git clone https://github.com/BrickerP/litellm-mcp-lab.git
cd litellm-mcp-lab
cp .env.example .env
# Edit .env: set OPENAI_API_KEY and a long random LITELLM_MASTER_KEY

docker compose up -d
curl -s http://localhost:4000/health/liveliness
```

Proxy UI / OpenAI-compatible base URL: `http://localhost:4000`

Smoke chat (master key — prefer a virtual key once created):

```bash
curl -s http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o-mini",
    "messages": [{"role": "user", "content": "ping"}]
  }'
```

Tear down: `docker compose down` (add `-v` to wipe the lab Postgres volume).

## Quick start (`uv` — proxy only, no Postgres)

Useful when you want the proxy without Compose. Virtual-key / spend persistence is weaker without a DB; treat this path as “route + call”, not full budget practice.

```bash
cp .env.example .env   # set OPENAI_API_KEY + LITELLM_MASTER_KEY
uv sync
uv run litellm --config config/litellm_config.yaml --port 4000
```

## One MCP example

`mcp_servers/echo_mcp.py` is a tiny stdio MCP server with a single `echo` tool. Purpose: prove your MCP client can spawn and call a local server — nothing more.

```bash
uv sync
uv run python mcp_servers/echo_mcp.py
# Or wire it into Cursor / Claude Code / your agent as a stdio MCP server:
#   command: uv
#   args: ["run", "python", "mcp_servers/echo_mcp.py"]
#   cwd:  <path-to-this-repo>
```

**How this fits with LiteLLM:** LiteLLM is the **LLM gateway**; MCP is the **tool protocol**. They are complementary, not the same layer. Typical lab wiring:

1. Agent / IDE talks to LiteLLM (`base_url=http://localhost:4000/v1`) with a **budgeted virtual key**.
2. Same agent also connects to `echo_mcp` (and later real tools) over MCP stdio/SSE.
3. You observe cost on the gateway side and tool behavior on the MCP side separately.

Do not expect LiteLLM to “be” MCP out of the box in this scaffold — that glue belongs in your agent host.

## Budgeted virtual key

With Compose (Postgres attached), create a soft-budget key after the proxy is healthy:

```bash
export LITELLM_MASTER_KEY=...   # from .env
export LAB_VK_MAX_BUDGET=5.00   # USD soft ceiling
export LAB_VK_BUDGET_DURATION=30d
./scripts/create_lab_virtual_key.sh
```

Notes (lab honesty):

- Budgets are **soft / policy** controls inside LiteLLM — verify behavior against [current LiteLLM docs](https://docs.litellm.ai/docs/proxy/virtual_keys) for your image tag; APIs move.
- Default lab ceiling is **\$5 / 30d**. Raise only when you mean to.
- Store the returned key outside git. Rotate via `/key/delete` when done.
- Without Postgres, spend tracking and key persistence may be incomplete — prefer Compose for the budget experiment.

Client usage:

```bash
export LAB_VK=sk-...   # from /key/generate response
curl -s http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer $LAB_VK" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-4o-mini","messages":[{"role":"user","content":"budget check"}]}'
```

## Layout

```
compose.yml                 # LiteLLM + Postgres lab stack
config/litellm_config.yaml  # model list (no secrets)
mcp_servers/echo_mcp.py     # one stdio MCP smoke server
scripts/create_lab_virtual_key.sh
.env.example                # template only
pyproject.toml              # uv path (mcp + litellm[proxy])
```

## Cost & risk notes

- **You pay the upstream provider.** This repo does not subsidize tokens.
- Keep `LITELLM_MASTER_KEY` private; treat it like root on the proxy.
- Bind to localhost only in this lab (`compose.yml` publishes `4000` on the host — firewall accordingly if the host is shared).
- Pin the LiteLLM image tag for anything beyond a weekend experiment (`main-latest` drifts).
- MCP tools can have side effects. The included `echo` tool has none; replace carefully.

## What “done” looks like for this lab

1. Proxy healthy on `:4000`
2. Chat completion succeeds via a **virtual key** (not only the master key)
3. MCP client can call `echo` on the local server
4. You can point to a spend / key view (UI or API) showing the budgeted key

If any of those fail, prefer reading current upstream docs over inventing wrappers.

## References

- [LiteLLM proxy docs](https://docs.litellm.ai/docs/proxy/deploy)
- [LiteLLM virtual keys](https://docs.litellm.ai/docs/proxy/virtual_keys)
- [Model Context Protocol](https://modelcontextprotocol.io/)

## Author

Yupeng Lu — AI agent & backend engineer. Hire me: https://brickerp.github.io/hire/

MIT License.
