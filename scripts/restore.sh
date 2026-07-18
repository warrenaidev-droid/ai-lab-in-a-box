#!/usr/bin/env bash
# AI Lab in a Box — restore a snapshot created by backup.sh.
#   usage: scripts/restore.sh backups/<timestamp>
set -euo pipefail
cd "$(dirname "$0")/.."

SNAP="${1:-}"
[ -n "$SNAP" ] && [ -d "$SNAP" ] || { echo "usage: scripts/restore.sh backups/<timestamp>" >&2; exit 1; }
[ -f "${SNAP}/data.tgz" ] || { echo "ERROR: ${SNAP}/data.tgz not found" >&2; exit 1; }
say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }

say "stopping stack"
docker compose down

say "extracting ${SNAP}/data.tgz -> ./"
tar -xzf "${SNAP}/data.tgz"

# --- Bring DB up first and replay the dump if present (automation profile) ---
if [ -f "${SNAP}/postgres.sql" ]; then
  # shellcheck disable=SC1091
  [ -f .env ] && { set -a; . ./.env; set +a; }
  say "starting postgres and replaying postgres.sql"
  docker compose up -d postgres
  # wait for readiness
  for _ in $(seq 1 30); do
    docker compose exec -T postgres pg_isready -U "${POSTGRES_USER:-warrenlab}" >/dev/null 2>&1 && break
    sleep 2
  done
  docker compose exec -T postgres psql -U "${POSTGRES_USER:-warrenlab}" -d "${POSTGRES_DB:-warrenlab}" < "${SNAP}/postgres.sql"
fi

say "starting full stack"
docker compose up -d

say "re-pulling models (in case blobs weren't in the snapshot)"
bash scripts/pull-models.sh || true

say "restore complete from ${SNAP}"
