# AI Lab in a Box

Turn any spare PC or mini PC into a **24/7 self-hosted AI server** with one command.
Everything runs locally under Docker Compose — free, private, and portable. Copy the folder
(or clone this repo) onto any machine, run the setup script, and you have your own private
ChatGPT plus a document knowledge base. Scale the AI model up or down to match the hardware
by changing a single line.

> **Built for reuse.** Nothing personal or client-specific is baked in. Deploy it for yourself,
> or hand it to anyone — they just run the setup script on their own box.

- **Runs by default:** [Ollama](https://ollama.com) (local LLM) + [Open WebUI](https://openwebui.com) (ChatGPT-style UI + document knowledge base / RAG)
- **One flag away:** [n8n](https://n8n.io) automation, a [Qdrant](https://qdrant.tech) vector DB, and a [Caddy](https://caddyserver.com) HTTPS proxy — pre-built, off until you want them
- **No cloud, no API keys, no per-token bills.** The model runs on your own CPU.

---

## Requirements

- A PC that stays on. A small box with **4 cores + 12 GB RAM** comfortably runs the default mini model (CPU-only, no graphics card needed). More RAM / a GPU = bigger models.
- **Docker** — on Windows/Mac install [Docker Desktop](https://www.docker.com/products/docker-desktop/); on Linux install Docker Engine + the Compose plugin.
- ~10 GB free disk for the images and the first model.

> **Windows note:** Docker Desktop uses a WSL2 Linux environment. Keep this folder **inside** the
> WSL2 Linux filesystem (e.g. `~/ai-lab-in-a-box`), **not** under `/mnt/c/...` — files on the
> Windows side make the containers dramatically slow.

## Quick start

**Windows (PowerShell):**
```powershell
powershell -ExecutionPolicy Bypass -File scripts\setup.ps1
```

**Linux / WSL2 / Mac:**
```bash
bash scripts/setup.sh
```

The script generates its own secrets, creates the data folders, starts the stack, and downloads the
default model. When it finishes, open **http://localhost:3000**, create the first account (it becomes
the admin — nobody else can self-register), pick the `llama3.2:3b` model, and start chatting.

## What's running

| Service | On by default? | URL | What it's for |
|---|---|---|---|
| Ollama | ✅ | internal | Runs the AI model on your CPU |
| Open WebUI | ✅ | http://localhost:3000 | The chat UI + upload documents for the AI to answer from |
| n8n | profile `automation` | http://localhost:5678 | Build automations / workflows |
| Postgres | profile `automation` | internal | Database behind n8n |
| Qdrant | profile `vector` | http://localhost:6333 | Vector DB for large document collections |
| Caddy | profile `proxy` | :80 / :443 | Auto-HTTPS on a real domain for public demos |

Turn extras on by editing `COMPOSE_PROFILES` in your `.env` (e.g. `COMPOSE_PROFILES=automation`) and
running `docker compose up -d`.

## Pick a model for your hardware

Change **one line** — `DEFAULT_MODEL` in `.env` — then run the pull-models script.

| Tier | Hardware | `DEFAULT_MODEL` | Embedding model | ~RAM for the model |
|---|---|---|---|---|
| **Mini (default)** | 4-core / ≤12 GB, CPU-only | `llama3.2:3b` | `nomic-embed-text` | ~2.5 GB |
| Small | 16–32 GB, CPU-only | `qwen2.5:7b` | `nomic-embed-text` | ~5–6 GB |
| Medium | 32–64 GB or an entry GPU | `qwen2.5:14b` | `mxbai-embed-large` | ~10–12 GB |
| Large | GPU server (≥16 GB VRAM) | `qwen2.5:32b` / `llama3.1:70b` | `mxbai-embed-large` | 20 GB+ |

On a very small/slow box, `gemma2:2b` is a lighter, faster fallback (weaker reasoning).

## Reach it from other devices

The simplest secure way is [**Tailscale**](https://tailscale.com): install it on the host machine and
on your laptop/phone (same account), then open `http://<machine-name>:3000` from anywhere — no ports
opened to the internet. For a public demo on a real domain, use the `proxy` profile (edit `Caddyfile`
first).

## Everyday commands

| Task | Command |
|---|---|
| Start / apply changes | `docker compose up -d` |
| Stop | `docker compose stop` |
| Status + health | `docker compose ps` |
| Logs | `docker compose logs -f <service>` |
| Pull the models named in `.env` | `bash scripts/pull-models.sh` · `scripts\pull-models.ps1` |
| Back up | `bash scripts/backup.sh` · `scripts\backup.ps1` |
| Restore | `bash scripts/restore.sh backups/<ts>` · `scripts\restore.ps1 -Snapshot backups\<ts>` |
| Update images | `bash scripts/update.sh` · `scripts\update.ps1` |

## Back up / move to another machine

All state lives in `./data`, so a backup is just an archive of that folder — the scripts do it safely
(and include a database dump when the automation profile is on). To migrate, copy the folder (or a
restored backup) to the new machine and run the setup script.

## Deploy for someone else

1. Copy this folder onto their machine (inside WSL2 on Windows).
2. Copy `clients/_template/` → `clients/<their-name>/` and note their hardware tier, chosen model, and any profiles in `config.json`.
3. Set `DEFAULT_MODEL` (and `COMPOSE_PROFILES`) in `.env` to match — secrets are auto-generated by setup.
4. Run the setup script. Done.

## Notes

- **Never commit `.env`, `data/`, or `backups/`** — they're gitignored (secrets + local data).
- Secrets are generated locally on first setup; nothing sensitive ships in this repo.
- Image tags are **pinned** in `docker-compose.yml` (never `:latest`) so rebuilds are identical. Bump them deliberately via the update script.

## License

MIT — see [LICENSE](LICENSE). Use it, fork it, deploy it for clients. No warranty.
