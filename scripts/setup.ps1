# AI Lab in a Box - first-run setup (Windows PowerShell).
# Verifies Docker, generates secrets into .env, creates data dirs, brings the stack up, pulls models.
# Run from anywhere:  powershell -ExecutionPolicy Bypass -File scripts\setup.ps1
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)   # stack root

function Say($m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Die($m) { Write-Host "ERROR: $m" -ForegroundColor Red; exit 1 }

# --- 1. Preconditions ---
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { Die "Docker not found. Install Docker Desktop (WSL2 backend)." }
try { docker compose version | Out-Null } catch { Die "'docker compose' not available. Update Docker Desktop." }
try { docker info | Out-Null } catch { Die "Docker daemon not running. Start Docker Desktop." }

# --- 2. .env ---
function New-Secret([int]$bytes) {
  $b = New-Object 'System.Byte[]' $bytes
  [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b)
  ($b | ForEach-Object { $_.ToString('x2') }) -join ''
}
function Set-Secret([string]$key, [int]$bytes) {
  $c = Get-Content .env -Raw
  if ($c -match "(?m)^$key=your_value_here$") {
    $c = $c -replace "(?m)^$key=your_value_here$", "$key=$(New-Secret $bytes)"
    Set-Content .env -Value $c -NoNewline
    Say "generated $key"
  }
}
if (-not (Test-Path .env)) { Copy-Item .env.example .env; Say "created .env from .env.example" }
Set-Secret 'WEBUI_SECRET_KEY' 32
Set-Secret 'N8N_ENCRYPTION_KEY' 32
Set-Secret 'POSTGRES_PASSWORD' 24

# --- 3. Data dirs ---
'data/ollama','data/open-webui','data/n8n','data/postgres','data/toolserver','data/qdrant','data/caddy','backups' |
  ForEach-Object { New-Item -ItemType Directory -Force -Path $_ | Out-Null }
Say "data directories ready"

# --- 4. Up + models ---
Say "starting the stack (docker compose up -d) ..."
docker compose up -d

Say "pulling models (first run can take a while) ..."
& "$PSScriptRoot\pull-models.ps1"

$port = (Select-String -Path .env -Pattern '^OPEN_WEBUI_PORT=(.+)$').Matches.Groups[1].Value
if (-not $port) { $port = '3000' }
Say "done. Check 'docker compose ps'. Open WebUI: http://localhost:$port"
Say "First visit: create the admin account, then set ENABLE_SIGNUP=false in .env and 'docker compose up -d'."
