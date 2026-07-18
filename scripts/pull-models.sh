#!/usr/bin/env bash
# AI Lab in a Box — pull the chat + embedding models named in .env into the running Ollama container.
set -euo pipefail
cd "$(dirname "$0")/.."

[ -f .env ] || { echo "ERROR: .env not found. Run setup first." >&2; exit 1; }
# shellcheck disable=SC1091
set -a; . ./.env; set +a

CHAT="${DEFAULT_MODEL:-llama3.2:3b}"
EMBED="${EMBED_MODEL:-nomic-embed-text}"

for m in "$CHAT" "$EMBED"; do
  printf '\033[1;36m==>\033[0m pulling %s\n' "$m"
  docker compose exec -T ollama ollama pull "$m"
done

printf '\033[1;36m==>\033[0m models present:\n'
docker compose exec -T ollama ollama list
