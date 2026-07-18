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
>
> **Windows tip:** if the `docker` command seems "not found" in your Ubuntu/WSL window, Docker Desktop
> is probably in **Resource Saver mode** — press ▶ in Docker Desktop to wake it, wait for the green
> **"Engine running"**, then retry. (Also make sure **Settings → Resources → WSL Integration → Ubuntu**
> is on.)

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
default model. When it finishes, open **http://localhost:3000** and create the first account — it
becomes the **admin**. Then pick the `llama3.2:3b` model and start chatting.

> **Lock sign-ups after first run:** the Lab ships with `ENABLE_SIGNUP=true` so you can create that
> first admin account. Once you're in, set `ENABLE_SIGNUP=false` in `.env` and run
> `docker compose up -d` again so nobody else can register.

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

## Back up, and move to another machine (keeping your history)

All state lives in `./data`. `backup.sh` snapshots it safely into `backups/<timestamp>/` — your
account, chats, and uploaded documents (plus a Postgres dump when the automation profile is on). The
large model files are **skipped by default** because they re-download automatically, keeping the
snapshot small.

**Back up:**
```bash
bash scripts/backup.sh            # Windows: scripts\backup.ps1  (add --with-models / -WithModels to include model files)
```

**Move to a new machine, with all your history:**
1. On the new machine, do a normal **clean install first** (clone the repo + run `setup`).
2. Copy the `backups/<timestamp>/` folder from the old machine to the new machine's `backups/` folder
   (via a USB stick, a shared drive, or a cloud folder like OneDrive/Dropbox).
3. Restore it **on top** of the clean install:
   ```bash
   bash scripts/restore.sh backups/<timestamp>      # Windows: scripts\restore.ps1 -Snapshot backups\<timestamp>
   ```
4. Open `http://localhost:3000` and sign in with your **existing account** — chats and documents are
   all there. (You may need to log in again after a move; your data is intact.)

> Migrating the *whole box* (not just history) is even simpler: copy the entire folder to the new
> machine and run `setup` — everything's in `./data`.

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
