# AI Lab in a Box - pull the chat + embedding models named in .env into the running Ollama container.
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

if (-not (Test-Path .env)) { Write-Host "ERROR: .env not found. Run setup first." -ForegroundColor Red; exit 1 }

function Get-EnvVal([string]$key, [string]$default) {
  $m = Select-String -Path .env -Pattern "^$key=(.+)$"
  if ($m) { return $m.Matches.Groups[1].Value } else { return $default }
}
$chat  = Get-EnvVal 'DEFAULT_MODEL' 'llama3.2:3b'
$embed = Get-EnvVal 'EMBED_MODEL'   'nomic-embed-text'

foreach ($m in @($chat, $embed)) {
  Write-Host "==> pulling $m" -ForegroundColor Cyan
  docker compose exec -T ollama ollama pull $m
}
Write-Host "==> models present:" -ForegroundColor Cyan
docker compose exec -T ollama ollama list
