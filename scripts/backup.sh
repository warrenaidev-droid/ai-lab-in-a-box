#!/usr/bin/env bash
# AI Lab in a Box — snapshot the stack into backups/<timestamp>/.
# Archives app state (open-webui, n8n) + config, does a consistent pg_dump when Postgres is running,
# and writes a manifest of image tags + models. Ollama model blobs are skipped by default (re-pullable);
# pass --with-models to include them.
set -euo pipefail
cd "$(dirname "$0")/.."

WITH_MODELS=0
[ "${1:-}" = "--with-models" ] && WITH_MODELS=1

TS="$(date +%Y%m%d-%H%M%S)"
OUT="backups/${TS}"
mkdir -p "$OUT"
say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }

# shellcheck disable=SC1091
[ -f .env ] && { set -a; . ./.env; set +a; }

# --- Consistent DB dump if Postgres is up (automation profile) ---
if docker compose ps --services --status running 2>/dev/null | grep -qx postgres; then
  say "pg_dump -> ${OUT}/postgres.sql"
  docker compose exec -T postgres pg_dump -U "${POSTGRES_USER:-warrenlab}" "${POSTGRES_DB:-warrenlab}" > "${OUT}/postgres.sql"
fi

# --- Stop for a consistent file snapshot, archive, restart ---
say "stopping stack for a consistent file snapshot"
docker compose stop

ARCHIVE_DIRS=(data/open-webui)
[ -d data/n8n ]   && ARCHIVE_DIRS+=(data/n8n)
[ -d data/qdrant ] && ARCHIVE_DIRS+=(data/qdrant)
[ "$WITH_MODELS" = "1" ] && ARCHIVE_DIRS+=(data/ollama)

say "archiving: ${ARCHIVE_DIRS[*]}"
tar -czf "${OUT}/data.tgz" "${ARCHIVE_DIRS[@]}"

cp .env "${OUT}/.env" 2>/dev/null || true
cp docker-compose.yml "${OUT}/docker-compose.yml"

{
  echo "{"
  echo "  \"timestamp\": \"${TS}\","
  echo "  \"with_models\": ${WITH_MODELS},"
  echo "  \"default_model\": \"${DEFAULT_MODEL:-}\","
  echo "  \"embed_model\": \"${EMBED_MODEL:-}\","
  echo "  \"images\": ["
  docker compose config --images 2>/dev/null | sed 's/^/    "/; s/$/",/' | sed '$ s/,$//'
  echo "  ]"
  echo "}"
} > "${OUT}/manifest.json"

say "restarting stack"
docker compose start

say "backup complete -> ${OUT}"
