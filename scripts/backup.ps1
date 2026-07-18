# AI Lab in a Box - snapshot the stack into backups\<timestamp>\.
# Archives app state + config, pg_dump when Postgres is running, writes a manifest.
# Ollama model blobs skipped by default (re-pullable); pass -WithModels to include them.
param([switch]$WithModels)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
function Say($m) { Write-Host "==> $m" -ForegroundColor Cyan }

$ts  = Get-Date -Format 'yyyyMMdd-HHmmss'
$out = "backups\$ts"
New-Item -ItemType Directory -Force -Path $out | Out-Null

function Get-EnvVal([string]$key, [string]$default) {
  if (-not (Test-Path .env)) { return $default }
  $m = Select-String -Path .env -Pattern "^$key=(.+)$"
  if ($m) { return $m.Matches.Groups[1].Value } else { return $default }
}
$pgUser = Get-EnvVal 'POSTGRES_USER' 'warrenlab'
$pgDb   = Get-EnvVal 'POSTGRES_DB'   'warrenlab'

$running = docker compose ps --services --status running 2>$null
if ($running -contains 'postgres') {
  Say "pg_dump -> $out\postgres.sql"
  docker compose exec -T postgres pg_dump -U $pgUser $pgDb | Set-Content "$out\postgres.sql"
}

Say "stopping stack for a consistent file snapshot"
docker compose stop

$dirs = @('data/open-webui')
if (Test-Path data/n8n)    { $dirs += 'data/n8n' }
if (Test-Path data/qdrant) { $dirs += 'data/qdrant' }
if ($WithModels)           { $dirs += 'data/ollama' }

Say "archiving: $($dirs -join ', ')"
tar -czf "$out\data.tgz" $dirs

if (Test-Path .env) { Copy-Item .env "$out\.env" }
Copy-Item docker-compose.yml "$out\docker-compose.yml"

$images = docker compose config --images 2>$null
@{
  timestamp     = $ts
  with_models   = [bool]$WithModels
  default_model = (Get-EnvVal 'DEFAULT_MODEL' '')
  embed_model   = (Get-EnvVal 'EMBED_MODEL' '')
  images        = @($images)
} | ConvertTo-Json | Set-Content "$out\manifest.json"

Say "restarting stack"
docker compose start
Say "backup complete -> $out"
