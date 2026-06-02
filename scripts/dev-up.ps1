# Запуск postgres + backend + ml из корня репозитория
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)
if (-not (Test-Path ".env") -and (Test-Path ".env.example")) {
    Copy-Item ".env.example" ".env"
    Write-Host "Created .env from .env.example"
}
docker compose up --build -d
Write-Host "API:  http://localhost:8000/docs"
Write-Host "ML:   http://localhost:8001/health"
