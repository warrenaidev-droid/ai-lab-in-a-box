#!/usr/bin/env bash
# AI Lab in a Box — first-run setup (Linux / WSL2).
# Verifies Docker, generates secrets into .env, creates data dirs, brings the stack up, pulls models.
set -euo pipefail

cd "$(dirname "$0")/.."   # stack root (folder containing docker-compose.yml)

say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# --- 1. Preconditions ---------------------------------------------------------
command -v docker >/dev/null 2>&1 || die "Docker not found. Install Docker Desktop (WSL2 backend) first."
docker compose version >/dev/null 2>&1 || die "'docker compose' not available. Update Docker Desktop."
docker info >/dev/null 2>&1 || die "Docker daemon not running. Start Docker Desktop."

# Warn if the stack lives on the slow Windows-mounted filesystem instead of WSL2 ext4.
case "$(pwd -P)" in
  /mnt/*) echo "WARNING: this folder is under /mnt (Windows filesystem). Bind-mount I/O will be very slow." >&2
          echo "         Move the stack onto the WSL2 side (e.g. ~/ai-projects/...) for good performance." >&2 ;;
esac

# --- 2. .env ------------------------------------------------------------------
gen() { openssl rand -hex "$1" 2>/dev/null || head -c "$1" /dev/urandom | od -An -tx1 | tr -d ' \n'; }
fill() { # fill <KEY> <bytes>  — replace placeholder with a generated secret if still unset
  local key="$1" bytes="$2"
  if grep -q "^${key}=your_value_here$" .env; then
    local val; val="$(gen "$bytes")"
    # portable in-place edit
    sed -i.bak "s|^${key}=your_value_here$|${key}=${val}|" .env && rm -f .env.bak
    say "generated ${key}"
  fi
}
if [ ! -f .env ]; then
  cp .env.example .env
  say "created .env from .env.example"
fi
fill WEBUI_SECRET_KEY 32
fill N8N_ENCRYPTION_KEY 32
fill POSTGRES_PASSWORD 24

# --- 3. Data dirs -------------------------------------------------------------
mkdir -p data/ollama data/open-webui data/n8n data/postgres data/qdrant data/caddy backups
say "data directories ready"

# --- 4. Up + models -----------------------------------------------------------
say "starting the stack (docker compose up -d) ..."
docker compose up -d

say "pulling models (this can take a while on first run) ..."
bash scripts/pull-models.sh

say "done. Run 'docker compose ps' to check health. Open WebUI: http://localhost:${OPEN_WEBUI_PORT:-3000}"
say "First visit: create the admin account, then set ENABLE_SIGNUP=false in .env and 'docker compose up -d'."
