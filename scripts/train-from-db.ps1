# Обучение ML-модели на данных PostgreSQL (нужен запущенный postgres + seed)
param(
    [int]$LimitSessions = 0,
    [int]$MinEvents = 10
)
$ErrorActionPreference = "Stop"
$backend = Join-Path (Split-Path $PSScriptRoot -Parent) "backend"
if (-not $env:DB_HOST) { $env:DB_HOST = "localhost" }
if (-not $env:DB_PASSWORD) { $env:DB_PASSWORD = "postgres" }
if (-not $env:DB_USER) { $env:DB_USER = "postgres" }
if (-not $env:DB_NAME) { $env:DB_NAME = "gamedb" }
if (-not $env:DB_PORT) { $env:DB_PORT = "5432" }

Set-Location $backend
pip install -q -r requirements.txt
pip install -q -r ..\ml\requirements.txt

$argsList = @("..\ml\scripts\train_from_postgres.py", "--min-events", $MinEvents)
if ($LimitSessions -gt 0) {
    $argsList += @("--limit-sessions", $LimitSessions)
}
py -3 @argsList
Write-Host "Restart ML container to load new model: docker compose restart ml"
