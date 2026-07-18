# AI Lab in a Box - restore a snapshot created by backup.ps1.
#   usage: powershell -ExecutionPolicy Bypass -File scripts\restore.ps1 -Snapshot backups\<timestamp>
param([Parameter(Mandatory=$true)][string]$Snapshot)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
function Say($m) { Write-Host "==> $m" -ForegroundColor Cyan }

if (-not (Test-Path $Snapshot)) { Write-Host "ERROR: $Snapshot not found" -ForegroundColor Red; exit 1 }
if (-not (Test-Path "$Snapshot\data.tgz")) { Write-Host "ERROR: $Snapshot\data.tgz not found" -ForegroundColor Red; exit 1 }

function Get-EnvVal([string]$key, [string]$default) {
  if (-not (Test-Path .env)) { return $default }
  $m = Select-String -Path .env -Pattern "^$key=(.+)$"
  if ($m) { return $m.Matches.Groups[1].Value } else { return $default }
}

Say "stopping stack"
docker compose down

Say "extracting $Snapshot\data.tgz"
tar -xzf "$Snapshot\data.tgz"

if (Test-Path "$Snapshot\postgres.sql") {
  $pgUser = Get-EnvVal 'POSTGRES_USER' 'warrenlab'
  $pgDb   = Get-EnvVal 'POSTGRES_DB'   'warrenlab'
  Say "starting postgres and replaying postgres.sql"
  docker compose up -d postgres
  for ($i=0; $i -lt 30; $i++) {
    docker compose exec -T postgres pg_isready -U $pgUser 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { break }
    Start-Sleep -Seconds 2
  }
  Get-Content "$Snapshot\postgres.sql" | docker compose exec -T postgres psql -U $pgUser -d $pgDb
}

Say "starting full stack"
docker compose up -d

Say "re-pulling models (in case blobs weren't in the snapshot)"
try { & "$PSScriptRoot\pull-models.ps1" } catch { }

Say "restore complete from $Snapshot"
