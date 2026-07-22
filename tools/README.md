# Tools (Phase 3) — give the model real tools

The `tools` profile adds **mcpo**, a proxy that turns MCP tool servers into one OpenAPI server Open WebUI
can call. That lets the local model *do* things — query a database, read/write files, hit an API — instead
of only chatting. Off by default.

```
MCP tool servers ──► mcpo (:8000, OpenAPI) ──► Open WebUI ──► model
                     one container, many tools     http://toolserver:8000
```

## Turn it on
1. Copy the config: `cp tools/mcpo-config.example.json data/toolserver/mcpo-config.json`
   *(`data/` is gitignored — credentials in this file never get committed.)*
2. Edit `data/toolserver/mcpo-config.json` to define your tool servers (see below).
3. Enable the profile in `.env`: `COMPOSE_PROFILES=tools` (comma-add to others, e.g. `automation,tools`).
4. `docker compose up -d`
5. In Open WebUI: **Admin → Settings → Tools → add OpenAPI server** → URL `http://toolserver:8000`,
   Auth **None**. Tools now attach to any chat where you enable them. (Reach the docs from the host by
   temporarily publishing the port, or check container logs.)

## Defining tool servers
Each entry under `mcpServers` becomes a route `/<name>`. Two runtimes:

- **Python servers (`uvx …`)** run in the mcpo image out of the box — the safest choice here. The example
  ships `mcp-server-time` as a working proof; a `SELECT`-only database tool is the common useful one.
- **Node servers (`npx …`)** — e.g. the reference `@modelcontextprotocol/server-filesystem` and
  `@modelcontextprotocol/server-postgres` — are **not** runnable in the stock mcpo image (no Node). To use
  them either (a) build a Node-enabled mcpo image, or (b) run `mcpo` on the host (`uvx mcpo --config …`)
  where Node is installed, and point Open WebUI at `http://host.docker.internal:8000`.

```jsonc
{
  "mcpServers": {
    "time": { "command": "uvx", "args": ["mcp-server-time", "--local-timezone=Asia/Dubai"] }

    // Read-only database tool (host-run mcpo, or a Node-enabled image):
    // "sql": { "command": "npx", "args": ["-y", "@modelcontextprotocol/server-postgres",
    //          "postgresql://READONLY_USER:PASSWORD@HOST:5432/DB"] }
  }
}
```

## Model note
Tool-calling needs a capable model. On the mini-PC default (`llama3.2:3b`) tool use is unreliable — use a
7B+ instruct/coder model (e.g. `qwen2.5:7b` / `qwen2.5-coder:7b`) and, if Open WebUI's **native**
function-calling misbehaves, switch that preset's tool mode to **Default** (prompt-based).

## Warren's Power BI tool-calling
Live Power BI schema/DAX tool-calling (Microsoft's Power BI Modeling MCP against an open Desktop model)
is a **BI-dev / GPU-box** setup, documented separately in the personal-assistant monorepo
(`offline-ai/tools/`). It isn't part of this generic client stack because it needs Power BI Desktop's
Windows Analysis Services engine.
