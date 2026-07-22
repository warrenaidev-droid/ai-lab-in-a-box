# Runbook — GPU laptop / offline-client profile

A deployment profile of the Lab for a **powerful laptop with an NVIDIA GPU**, used to do
**AI-assisted work for a client whose NDA forbids online / cloud AI**.

Everything runs on-device, so the client's data never leaves the machine — which is exactly
what a "no online AI" clause requires. This profile drops the always-on / remote-access pieces
(no Tailscale, no proxy, no n8n) and adds a GPU override plus an optional local **MCP tool**
bridge (e.g. a Power BI model) so the local model can call tools the way a cloud assistant would.

> **NDA reality check first.** "No online AI" is satisfied because nothing here transmits the
> client's data — Ollama runs the model locally and doesn't phone home. Two things to keep honest:
> 1. Using a *cloud* assistant (Claude, ChatGPT, Copilot, etc.) on the same client data would
>    breach the same clause. Use this local model for anything touching their data; keep cloud
>    tools for non-client scaffolding only.
> 2. Confirm the clause means "no cloud AI" and not "no AI processing at all" — a few NDAs are
>    written the stricter way, and then even a local model is off the table.

---

## Reference hardware (the box this was written for)

| | |
|---|---|
| Machine | Lenovo Legion 5 16IAX10 |
| CPU | Intel Core Ultra 9 275HX (24 cores) |
| RAM | 64 GB |
| GPU | NVIDIA GeForce RTX 5060 Laptop GPU — **8 GB VRAM** (+ Intel iGPU, unused) |
| OS | Windows 11 Pro + Docker Desktop (WSL2 backend) |

The 8 GB VRAM is the only real constraint — it decides how much runs on the fast GPU vs spills to
CPU/RAM. Ollama splits layers automatically, so bigger models still run, just slower. With 64 GB RAM
the footprint is otherwise a non-issue: a 14B model resident alongside Power BI Desktop, SSMS, and a
browser is comfortable.

---

## Pick a model (tuned for 8 GB VRAM)

For BI / DAX / SQL work you want a **coder** model — they're stronger at code *and* at the
tool-calling the MCP bridge relies on.

| Model | Fit on 8 GB VRAM | Speed | Use it for |
|---|---|---|---|
| **`qwen2.5-coder:7b`** | Fully in VRAM (~5 GB) | Fast (~30–50 tok/s) | Daily driver — DAX, SQL, interactive chat, single-step tools |
| **`qwen2.5-coder:14b`** | Partial offload (~9 GB) | Moderate (~10–20 tok/s) | Heavier reasoning + more reliable tool-calling |
| `qwen2.5-coder:32b` | Mostly CPU/RAM (~20 GB) | Slow (~3–5 tok/s) | Occasional deep tasks only |

Recommended: run **7b as the workhorse** and keep **14b** for the harder stuff (and for MCP tool
use). Set `DEFAULT_MODEL=qwen2.5-coder:14b` in `.env` and pull 7b as well.

> Expectation-setting: a local 14–32B model handles "draft this measure", "explain this
> relationship", and short tool-call chains well. Long, fully-autonomous multi-step modeling still
> favours a cloud assistant — but that's off-limits on this client's data anyway, so local + MCP is
> the best compliant option.

---

## Phase 1 — AI + web frontend (GPU)

1. **Put the Lab folder inside WSL2**, not under `/mnt/c/...` (bind-mount I/O across the Windows
   boundary is dramatically slow). Clone into e.g. `~/ai-projects/ai-lab-in-a-box`.

2. **Set the `.env`** for this profile:
   ```dotenv
   DEFAULT_MODEL=qwen2.5-coder:14b
   EMBED_MODEL=mxbai-embed-large
   COMPOSE_PROFILES=
   OLLAMA_KEEP_ALIVE=30m
   ENABLE_SIGNUP=true          # only for the first admin signup — flip to false after (see step 5)
   ```

3. **Start with the GPU override** (adds the RTX GPU + raises the memory limit):
   ```bash
   docker compose -f docker-compose.yml -f docker-compose.gpu.yml up -d
   ```
   To avoid typing `-f ...` every time, add this to `.env`:
   ```dotenv
   COMPOSE_FILE=docker-compose.yml:docker-compose.gpu.yml
   ```
   (On Windows use a `;` separator instead of `:` — `docker-compose.yml;docker-compose.gpu.yml`.)

4. **Pull the models** and confirm the GPU is doing the work:
   ```bash
   docker exec ai-lab-in-a-box-ollama-1 ollama pull qwen2.5-coder:14b
   docker exec ai-lab-in-a-box-ollama-1 ollama pull qwen2.5-coder:7b
   docker exec ai-lab-in-a-box-ollama-1 ollama run qwen2.5-coder:7b "Write a DAX measure for YTD Sales"
   docker exec ai-lab-in-a-box-ollama-1 ollama ps      # PROCESSOR should show "100% GPU" (or a GPU/CPU split)
   ```
   (`scripts/pull-models.sh` / `.ps1` also pulls whatever `DEFAULT_MODEL` + `EMBED_MODEL` are set to.)

5. **Open the UI and lock it down:** browse to `http://localhost:3000`, create the first account
   (it becomes admin), then set `ENABLE_SIGNUP=false` in `.env` and re-run the compose command from
   step 3 so nobody else can register.

### On-demand, not 24/7
The base Lab is built to stay on. On a laptop you usually want it **on demand**:
- Start when you need it: the compose command in step 3.
- Stop when done: `docker compose stop` (state persists in `./data`).
- Idle cost is near-zero anyway — the model unloads from RAM after `OLLAMA_KEEP_ALIVE`.
- Run on mains power during heavy inference (GPU + 24 cores will spin the fans and drain battery).

---

## Phase 2 — connect a local MCP tool (e.g. Power BI)

This lets the local model call tools — query a semantic model, draft measures against the live
schema — the way a cloud assistant would, but entirely offline.

1. **Bridge the MCP server to OpenAPI with [`mcpo`](https://github.com/open-webui/mcpo)** (Open
   WebUI's official MCP→OpenAPI proxy). Run it next to the MCP server (e.g. in WSL2):
   ```bash
   uvx mcpo --port 8000 -- <your-mcp-launch-command>
   # Power BI example: the MCP reaches the model via the WSL2 -> powershell.exe TOM route,
   # with Power BI Desktop open (or an XMLA endpoint) so there's a live semantic model to query.
   ```

2. **Register it in Open WebUI:** *Admin Settings → Tools → add an OpenAPI server*
   → `http://host.docker.internal:8000` (the container reaches the Windows/WSL host via
   `host.docker.internal`).

3. **Use `qwen2.5-coder:14b`** for tool-calling — the 7b works for simple calls but 14b is markedly
   more reliable on multi-tool prompts.

> Prefer a code-editor surface? **VS Code + Cline pointed at the local Ollama** (`http://localhost:11434`)
> supports MCP servers natively and is often a nicer surface than chat for tool-driven dev work.

---

## NDA hardening checklist

- [ ] `COMPOSE_PROFILES=` — **no** `proxy` (no public HTTPS), **no** `automation`, **no** Tailscale.
- [ ] Ollama host port stays commented out in `docker-compose.yml` (UI reaches it internally).
- [ ] Everything binds to `localhost` only — nothing exposed to the LAN or internet.
- [ ] `ENABLE_SIGNUP=false` after the admin account exists.
- [ ] Open WebUI telemetry off (it ships off; the env vars `ANONYMIZED_TELEMETRY=false`,
      `DO_NOT_TRACK=true`, `SCARF_NO_ANALYTICS=true` keep it that way if you add them).
- [ ] Belt-and-braces (optional): a Windows Firewall outbound-block rule on the Ollama/Docker process.
      Not required — Ollama doesn't transmit prompts — but it makes "nothing left the box" auditable.

---

## Record the deployment

Copy `clients/_template/` → `clients/<slug>/` and fill in `config.json`. Keep the slug **generic**
in this public repo — never a real client name or NDA detail:

```json
{
  "slug": "offline-client-example",
  "display_name": "Offline Client (NDA)",
  "hardware_tier": "MEDIUM",
  "hardware_notes": "GPU laptop — RTX 5060 8GB VRAM, 64GB RAM, 24-core CPU",
  "default_model": "qwen2.5-coder:14b",
  "embed_model": "mxbai-embed-large",
  "compose_profiles": [],
  "remote_access": "none",
  "domain": "",
  "deployed_on": "",
  "notes": "Offline-only for NDA compliance. GPU override on. MCP tool bridge (mcpo) for BI work."
}
```
