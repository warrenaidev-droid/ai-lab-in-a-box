# AI Lab in a Box - pull newer images for the pinned tags, recreate, prune dangling layers.
# Tags are pinned in docker-compose.yml (this pulls patch updates for the CURRENT tags).
# To move to a newer minor/major, edit the tags first, then run this.
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
function Say($m) { Write-Host "==> $m" -ForegroundColor Cyan }

Say "images before:"
docker compose config --images

Say "pulling ..."
docker compose pull

Say "recreating changed containers ..."
docker compose up -d

Say "pruning dangling images ..."
docker image prune -f

Say "done. Verify with 'docker compose ps' and commit any docker-compose.yml tag bumps."
