#!/usr/bin/env bash
# AI Lab in a Box — pull newer images for the pinned tags, recreate, prune dangling layers.
# Note: tags are pinned in docker-compose.yml, so this pulls patch updates for the CURRENT tags.
# To move to a newer minor/major, edit the tags in docker-compose.yml first, then run this.
set -euo pipefail
cd "$(dirname "$0")/.."
say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }

say "images before:"
docker compose config --images

say "pulling ..."
docker compose pull

say "recreating changed containers ..."
docker compose up -d

say "pruning dangling images ..."
docker image prune -f

say "done. Verify with 'docker compose ps' and commit any docker-compose.yml tag bumps."
